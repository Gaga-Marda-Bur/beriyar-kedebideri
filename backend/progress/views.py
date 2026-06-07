from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from learning.models import LearningUnit
from .models import UnitProgress
from .serializers import UnitProgressSerializer


class UnitProgressListAPIView(generics.ListAPIView):
    serializer_class = UnitProgressSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = UnitProgress.objects.select_related(
            'unit',
            'user',
        )

        device_id = self.request.query_params.get('device_id')
        completed = self.request.query_params.get('completed')
        unit = self.request.query_params.get('unit')

        if device_id:
            queryset = queryset.filter(device_id=device_id)

        if unit:
            queryset = queryset.filter(unit__slug=unit)

        if completed in ['true', '1', 'yes']:
            queryset = queryset.filter(completed=True)

        if completed in ['false', '0', 'no']:
            queryset = queryset.filter(completed=False)

        return queryset.order_by('-client_updated_at', '-synced_at')


class UnitProgressSyncAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @transaction.atomic
    def post(self, request):
        items = request.data.get('items', [])

        if not isinstance(items, list):
            return Response(
                {'detail': 'items must be a list.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        synced = []
        errors = []

        for raw in items:
            try:
                unit = self._get_unit(raw)

                device_id = str(raw.get('device_id', '')).strip()

                if not device_id:
                    raise ValueError('device_id is required.')

                incoming_completed = raw.get('completed') is True
                incoming_score = self._safe_int(raw.get('score_percent'))

                progress, _ = UnitProgress.objects.get_or_create(
                    device_id=device_id,
                    unit=unit,
                    defaults={
                        'user': request.user if request.user.is_authenticated else None,
                        'started_at': raw.get('started_at'),
                    },
                )

                if request.user.is_authenticated:
                    progress.user = request.user

                progress.last_stage = str(
                    raw.get('last_stage') or progress.last_stage or 'intro'
                )

                progress.lessons_seen = self._safe_int(raw.get('lessons_seen'))
                progress.characters_seen = self._safe_int(raw.get('characters_seen'))
                progress.words_seen = self._safe_int(raw.get('words_seen'))
                progress.quizzes_answered = self._safe_int(raw.get('quizzes_answered'))
                progress.correct_answers = self._safe_int(raw.get('correct_answers'))

                progress.best_score_percent = max(
                    progress.best_score_percent,
                    incoming_score,
                )

                progress.completed = progress.completed or incoming_completed

                if progress.completed:
                    progress.status = UnitProgress.COMPLETED
                else:
                    incoming_status = raw.get('status') or UnitProgress.STARTED

                    if incoming_status in [
                        UnitProgress.STARTED,
                        UnitProgress.REVIEW,
                        UnitProgress.COMPLETED,
                    ]:
                        progress.status = incoming_status
                    else:
                        progress.status = UnitProgress.STARTED

                if progress.started_at is None:
                    progress.started_at = raw.get('started_at')

                if progress.completed and progress.completed_at is None:
                    progress.completed_at = raw.get('completed_at') or timezone.now()

                progress.client_updated_at = raw.get('updated_at') or raw.get('client_updated_at')

                progress.save()

                synced.append({
                    'unit_id': unit.id,
                    'unit_slug': unit.slug,
                    'device_id': device_id,
                    'completed': progress.completed,
                    'best_score_percent': progress.best_score_percent,
                    'status': progress.status,
                    'synced_at': progress.synced_at.isoformat(),
                })

            except Exception as error:
                errors.append({
                    'unit_id': raw.get('unit_id'),
                    'unit_slug': raw.get('unit_slug'),
                    'error': str(error),
                })

        return Response({
            'synced_count': len(synced),
            'error_count': len(errors),
            'synced': synced,
            'errors': errors,
        })

    def _get_unit(self, raw):
        unit_id = raw.get('unit_id')
        unit_slug = raw.get('unit_slug')

        if unit_id:
            unit = LearningUnit.objects.filter(id=unit_id).first()

            if unit:
                return unit

        if unit_slug:
            unit = LearningUnit.objects.filter(slug=unit_slug).first()

            if unit:
                return unit

        raise ValueError('Learning unit not found.')

    def _safe_int(self, value):
        try:
            return max(0, int(value or 0))
        except (TypeError, ValueError):
            return 0