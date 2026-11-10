from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import UnitProgress
from .serializers import UnitProgressSerializer, UnitProgressSyncItemSerializer
from .ownership import guest_progress_queryset, progress_for_sync

MAX_SYNC_ITEMS = 100


class UnitProgressListAPIView(generics.ListAPIView):
    """
    Lecture des progressions d'apprentissage.

    Règles de sécurité (A01) :
    - Staff avec permission view_unitprogress : accès global avec filtres.
    - Utilisateurs connectés : uniquement leurs propres progressions (user=request.user).
    - Utilisateurs anonymes : doivent obligatoirement fournir device_id ET X-Device-Token
      (ou paramètre device_token). Une liste globale anonyme est strictement interdite (403).
      Le jeton doit correspondre à chaque ligne invitée ; aucune donnée de compte.
    """
    serializer_class = UnitProgressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user = self.request.user
        queryset = UnitProgress.objects.select_related('unit', 'user')

        device_id = (self.request.query_params.get('device_id') or '').strip()
        device_token = (
            self.request.headers.get('X-Device-Token') or
            self.request.query_params.get('device_token') or
            ''
        ).strip()
        completed = self.request.query_params.get('completed')
        unit = self.request.query_params.get('unit')

        if user.is_authenticated and user.is_staff and user.has_perm('progress.view_unitprogress'):
            if device_id:
                queryset = queryset.filter(device_id=device_id)
        elif user.is_authenticated:
            queryset = queryset.filter(user=user)
        else:
            queryset = queryset.filter(pk__in=guest_progress_queryset(device_id, device_token).values('pk'))

        if unit:
            queryset = queryset.filter(unit__slug=unit)

        if completed in ['true', '1', 'yes']:
            queryset = queryset.filter(completed=True)
        elif completed in ['false', '0', 'no']:
            queryset = queryset.filter(completed=False)

        return queryset.order_by('-client_updated_at', '-synced_at')


class UnitProgressSyncAPIView(APIView):
    """
    Synchronisation montante des progressions d'apprentissage.

    Règles de sécurité et robustesse (A01 & A03) :
    - Validation stricte des données entrantes via UnitProgressSyncItemSerializer.
    - Aucune 500 sur lot contenant un élément nul, non-dictionnaire ou invalide.
    - Score plafonné entre 0 et 100.
    - Monotonie temporelle : un lot obsolète (client_updated_at antérieur) ne fait
      pas reculer les compteurs d'exercices ni les étapes.
    - Contrôle de propriété côté serveur, registre unique des installations,
      et aucun rattachement automatique d'un historique sans preuve.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        items = request.data.get('items', []) if isinstance(request.data, dict) else None

        if not isinstance(items, list):
            return Response(
                {'detail': 'items must be a list.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(items) > MAX_SYNC_ITEMS:
            return Response(
                {'detail': f'Lot trop volumineux. Maximum {MAX_SYNC_ITEMS} éléments par synchronisation.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        header_token = (request.headers.get('X-Device-Token') or '').strip()
        header_device_id = (request.headers.get('X-Device-Id') or '').strip()
        if len(header_token) > 128 or len(header_device_id) > 120:
            return Response({'detail': 'Identifiants d’installation invalides.'}, status=status.HTTP_400_BAD_REQUEST)

        synced = []
        errors = []

        for index, raw in enumerate(items):
            if not isinstance(raw, dict):
                errors.append({
                    'index': index,
                    'unit_id': None,
                    'unit_slug': None,
                    'error': 'Chaque élément du lot doit être un objet JSON valide.',
                })
                continue

            serializer = UnitProgressSyncItemSerializer(data=raw)
            if not serializer.is_valid():
                errors.append({
                    'index': index,
                    'unit_id': raw.get('unit_id'),
                    'unit_slug': raw.get('unit_slug'),
                    'error': serializer.errors,
                })
                continue

            data = serializer.validated_data
            unit = data['resolved_unit']

            device_id = (data.get('device_id') or header_device_id).strip()
            item_token = (data.get('device_token') or header_token).strip()

            if ((header_device_id and device_id != header_device_id) or
                    (header_token and item_token != header_token)):
                errors.append({'index': index, 'unit_id': unit.id, 'unit_slug': unit.slug,
                               'error': 'Identifiants d’installation incohérents.'})
                continue

            if not device_id and not request.user.is_authenticated:
                errors.append({
                    'index': index,
                    'unit_id': unit.id,
                    'unit_slug': unit.slug,
                    'error': 'device_id est requis pour un utilisateur non connecté.',
                })
                continue

            try:
                with transaction.atomic():
                    progress = progress_for_sync(request.user, unit, device_id, item_token)
                    if progress.pk is None:
                        progress.started_at = data.get('started_at') or timezone.now()

                    incoming_updated_at = (
                        data.get('client_updated_at') or
                        data.get('updated_at')
                    )

                    # Stratégie anti-régression temporelle (A03)
                    # Si la mise à jour client est plus ancienne que l'état enregistré,
                    # on ne fait pas régresser les compteurs, tout en préservant le meilleur score.
                    is_newer = True
                    if progress.client_updated_at and incoming_updated_at:
                        if incoming_updated_at < progress.client_updated_at:
                            is_newer = False

                    incoming_score = data.get('score_percent', 0)
                    if incoming_score > progress.best_score_percent:
                        progress.scoring_version = data.get('scoring_version', 1)
                    if is_newer and data.get('last_session_score') is not None:
                        progress.last_session_score = data['last_session_score']
                    progress.best_score_percent = max(
                        progress.best_score_percent or 0,
                        min(100, incoming_score),
                    )

                    incoming_completed = data.get('completed', False)
                    if incoming_completed and not progress.completed and incoming_score < unit.min_score_to_pass:
                        raise ValidationError('Score below the unit mastery threshold.')
                    progress.completed = progress.completed or incoming_completed

                    if is_newer:
                        progress.last_stage = data.get('last_stage') or progress.last_stage or 'intro'
                        progress.lessons_seen = max(progress.lessons_seen, data.get('lessons_seen', 0))
                        progress.characters_seen = max(progress.characters_seen, data.get('characters_seen', 0))
                        progress.words_seen = max(progress.words_seen, data.get('words_seen', 0))
                        progress.quizzes_answered = max(progress.quizzes_answered, data.get('quizzes_answered', 0))
                        progress.correct_answers = max(progress.correct_answers, data.get('correct_answers', 0))

                        incoming_status = data.get('status') or UnitProgress.STARTED
                        if progress.completed:
                            progress.status = UnitProgress.COMPLETED
                        else:
                            progress.status = UnitProgress.REVIEW if incoming_status == UnitProgress.COMPLETED else incoming_status

                        progress.client_updated_at = incoming_updated_at
                    else:
                        # Mise à jour ancienne : fusion monotone des compteurs pour éviter tout recul
                        progress.lessons_seen = max(progress.lessons_seen, data.get('lessons_seen', 0))
                        progress.characters_seen = max(progress.characters_seen, data.get('characters_seen', 0))
                        progress.words_seen = max(progress.words_seen, data.get('words_seen', 0))
                        progress.quizzes_answered = max(progress.quizzes_answered, data.get('quizzes_answered', 0))
                        progress.correct_answers = max(progress.correct_answers, data.get('correct_answers', 0))

                    if progress.completed:
                        progress.status = UnitProgress.COMPLETED
                    if progress.completed and not progress.completed_at:
                        progress.completed_at = data.get('completed_at') or timezone.now()

                    if data.get('started_at') and not progress.started_at:
                        progress.started_at = data.get('started_at')

                    progress.save()

                    synced.append({
                        'unit_id': unit.id,
                        'unit_slug': unit.slug,
                        'device_id': progress.device_id,
                        'completed': progress.completed,
                        'best_score_percent': progress.best_score_percent,
                        'scoring_version': progress.scoring_version,
                        'last_session_score': progress.last_session_score,
                        'status': progress.status,
                        'synced_at': progress.synced_at.isoformat(),
                    })

            except Exception as error:
                errors.append({
                    'index': index,
                    'unit_id': unit.id if unit else raw.get('unit_id'),
                    'unit_slug': unit.slug if unit else raw.get('unit_slug'),
                    'error': str(error) if isinstance(error, (PermissionDenied, ValidationError)) else 'Synchronisation impossible.',
                })

        return Response({
            'synced_count': len(synced),
            'error_count': len(errors),
            'synced': synced,
            'errors': errors,
        })
