from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import UnitProgress
from .serializers import UnitProgressSerializer, UnitProgressSyncItemSerializer

MAX_SYNC_ITEMS = 100


class UnitProgressListAPIView(generics.ListAPIView):
    """
    Lecture des progressions d'apprentissage.

    Règles de sécurité (A01) :
    - Administrateurs / staff : accès complet avec filtres optionnels.
    - Utilisateurs connectés : uniquement leurs propres progressions (user=request.user).
    - Utilisateurs anonymes : doivent obligatoirement fournir device_id ET X-Device-Token
      (ou paramètre device_token). Une liste globale anonyme est strictement interdite (403).
      Si des progressions sont liées à ce device_id avec un device_token, le token fourni
      doit correspondre.
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

        if user.is_authenticated and (user.is_staff or user.is_superuser):
            if device_id:
                queryset = queryset.filter(device_id=device_id)
        elif user.is_authenticated:
            queryset = queryset.filter(user=user)
        else:
            if not device_id:
                raise PermissionDenied(
                    'Accès refusé. La consultation globale des progressions est restreinte.'
                )

            # Vérification de propriété du device_id
            existing_tokens = set(
                UnitProgress.objects.filter(device_id=device_id)
                .exclude(device_token='')
                .values_list('device_token', flat=True)
            )

            if existing_tokens:
                if not device_token or device_token not in existing_tokens:
                    raise PermissionDenied(
                        'Preuve de propriété du terminal requise ou invalide (X-Device-Token).'
                    )
            elif not device_token:
                # Terminal sans token enregistré : pour protéger les historiques
                # contre la lecture publique, un token de session est requis
                raise PermissionDenied(
                    'Preuve de propriété du terminal requise (X-Device-Token).'
                )

            queryset = queryset.filter(device_id=device_id)

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
    - Protection de propriété (A01) :
      * Si user connecté, la progression lui est rattachée. Un utilisateur ne peut
        pas écraser une progression appartenant à un autre user.
      * Si anonyme, device_id obligatoire. Si le device_id possède déjà un device_token,
        le token fourni doit correspondre, empêchant toute usurpation par un tiers.
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
            item_token = (raw.get('device_token') or header_token).strip()

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
                    # Recherche d'un enregistrement existant
                    progress = None
                    if request.user.is_authenticated:
                        progress = UnitProgress.objects.filter(
                            user=request.user,
                            unit=unit,
                        ).first()

                    if not progress and device_id:
                        progress = UnitProgress.objects.filter(
                            device_id=device_id,
                            unit=unit,
                        ).first()

                    # Vérification de propriété
                    if progress:
                        if (
                            progress.user_id and
                            request.user.is_authenticated and
                            progress.user_id != request.user.id
                        ):
                            raise PermissionDenied(
                                'Cette progression appartient à un autre compte utilisateur.'
                            )

                        if progress.device_token and item_token:
                            if progress.device_token != item_token:
                                raise PermissionDenied(
                                    'Preuve de propriété du terminal invalide pour ce device_id.'
                                )
                        elif progress.device_token and not item_token:
                            raise PermissionDenied(
                                'Preuve de propriété (device_token) requise pour ce device_id.'
                            )
                        elif not progress.device_token and item_token:
                            # Enregistrement initial du token lors de la première synchronisation sécurisée
                            progress.device_token = item_token
                    else:
                        progress = UnitProgress(
                            device_id=device_id,
                            unit=unit,
                            user=request.user if request.user.is_authenticated else None,
                            device_token=item_token,
                            started_at=data.get('started_at') or timezone.now(),
                        )

                    if request.user.is_authenticated and not progress.user_id:
                        progress.user = request.user

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
                    'error': str(error),
                })

        return Response({
            'synced_count': len(synced),
            'error_count': len(errors),
            'synced': synced,
            'errors': errors,
        })
