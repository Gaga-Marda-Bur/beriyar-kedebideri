from django.db.models import Q
from rest_framework import generics

from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, filter_by_access, is_pilot_user, is_staff_preview
from .models import QuizQuestion
from .serializers import QuizQuestionSerializer


def _filter_quiz_unit_access(queryset, request):
    """Exclude quizzes attached to unpublished or inactive units for non-staff callers."""
    if is_staff_preview(request):
        return queryset
    unit_q = Q(unit__isnull=True) | Q(
        unit__is_active=True,
        unit__status='published',
        unit__theme__is_active=True,
        unit__theme__status='published',
    )
    if is_pilot_user(request):
        unit_q |= Q(
            unit__is_active=True,
            unit__status='validated',
            unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS,
            unit__theme__is_active=True,
        )
    return queryset.filter(unit_q).distinct()


class QuizQuestionListAPIView(generics.ListAPIView):
    serializer_class = QuizQuestionSerializer

    def get_queryset(self):
        queryset = QuizQuestion.objects.filter(
            is_active=True,
        ).select_related(
            'unit',
            'lesson',
            'character',
            'word',
        ).prefetch_related(
            'options',
            'options__character',
            'options__word',
            'audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        question_type = self.request.query_params.get('type')
        difficulty = self.request.query_params.get('difficulty')
        unit = self.request.query_params.get('unit')
        lesson = self.request.query_params.get('lesson')
        offline = self.request.query_params.get('offline')

        queryset = filter_by_access(
            queryset,
            self.request,
            status_param=status_param,
            pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )
        queryset = _filter_quiz_unit_access(queryset, self.request)

        if question_type:
            queryset = queryset.filter(question_type=question_type)

        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)

        if unit:
            queryset = queryset.filter(unit__slug=unit)

        if lesson:
            queryset = queryset.filter(lesson__slug=lesson)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by(
            'unit__order_index',
            'lesson__order_index',
            'order_index',
            'id',
        )


class QuizQuestionDetailAPIView(generics.RetrieveAPIView):
    serializer_class = QuizQuestionSerializer

    def get_queryset(self):
        queryset = QuizQuestion.objects.filter(
            is_active=True,
        ).select_related(
            'unit',
            'lesson',
            'character',
            'word',
        ).prefetch_related(
            'options',
            'options__character',
            'options__word',
            'audio_links__audio_asset',
        )
        queryset = filter_by_access(
            queryset,
            self.request,
            pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )
        return _filter_quiz_unit_access(queryset, self.request)
