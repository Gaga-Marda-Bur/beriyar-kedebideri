from django.db.models import Q
from rest_framework import generics

from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, filter_by_access, is_pilot_user, is_staff_preview
from .models import Lesson, LessonItem
from .serializers import LessonItemSerializer, LessonSerializer


def _filter_lesson_unit_access(queryset, request, prefix='unit'):
    """Ensure lessons belong to active, accessible units for non-staff callers."""
    if is_staff_preview(request):
        return queryset
    unit_q = Q(**{
        f'{prefix}__is_active': True,
        f'{prefix}__status': 'published',
        f'{prefix}__theme__is_active': True,
        f'{prefix}__theme__status': 'published',
    })
    if is_pilot_user(request):
        unit_q |= Q(**{
            f'{prefix}__is_active': True,
            f'{prefix}__status': 'validated',
            f'{prefix}__slug__in': PILOT_ALLOWED_UNIT_SLUGS,
            f'{prefix}__theme__is_active': True,
        })
    return queryset.filter(unit_q).distinct()


class LessonListAPIView(generics.ListAPIView):
    serializer_class = LessonSerializer

    def get_queryset(self):
        queryset = Lesson.objects.filter(
            is_active=True,
        ).select_related(
            'unit',
            'unit__theme',
        ).prefetch_related(
            'items',
            'items__character',
            'items__character__audio_links__audio_asset',
            'items__word',
            'items__word__category',
            'items__word__audio_links__audio_asset',
            'items__audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        level = self.request.query_params.get('level')
        unit = self.request.query_params.get('unit')
        offline = self.request.query_params.get('offline')

        queryset = filter_by_access(
            queryset,
            self.request,
            status_param=status_param,
            pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )
        queryset = _filter_lesson_unit_access(queryset, self.request, prefix='unit')

        if level:
            queryset = queryset.filter(level=level)

        if unit:
            queryset = queryset.filter(unit__slug=unit)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by(
            'unit__theme__order_index',
            'unit__order_index',
            'order_index',
        )


class LessonDetailAPIView(generics.RetrieveAPIView):
    serializer_class = LessonSerializer

    def get_queryset(self):
        queryset = Lesson.objects.filter(
            is_active=True,
        ).select_related(
            'unit',
            'unit__theme',
        ).prefetch_related(
            'items',
            'items__character',
            'items__character__audio_links__audio_asset',
            'items__word',
            'items__word__category',
            'items__word__audio_links__audio_asset',
            'items__audio_links__audio_asset',
        )
        queryset = filter_by_access(
            queryset,
            self.request,
            pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )
        return _filter_lesson_unit_access(queryset, self.request, prefix='unit')


class LessonItemListAPIView(generics.ListAPIView):
    serializer_class = LessonItemSerializer

    def get_queryset(self):
        queryset = LessonItem.objects.filter(
            is_active=True,
        ).select_related(
            'lesson',
            'lesson__unit',
            'character',
            'word',
            'word__category',
        ).prefetch_related(
            'audio_links__audio_asset',
            'character__audio_links__audio_asset',
            'word__audio_links__audio_asset',
        )

        lesson = self.request.query_params.get('lesson')
        item_type = self.request.query_params.get('type')
        offline = self.request.query_params.get('offline')

        queryset = filter_by_access(
            queryset,
            self.request,
            status_field='lesson__status',
            pilot_q=Q(lesson__unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )

        if lesson:
            queryset = queryset.filter(lesson__slug=lesson)

        if item_type:
            queryset = queryset.filter(item_type=item_type)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by(
            'lesson__order_index',
            'order_index',
            'id',
        )


class LessonItemDetailAPIView(generics.RetrieveAPIView):
    serializer_class = LessonItemSerializer

    def get_queryset(self):
        queryset = LessonItem.objects.filter(
            is_active=True,
        ).select_related(
            'lesson',
            'lesson__unit',
            'character',
            'word',
            'word__category',
        ).prefetch_related(
            'audio_links__audio_asset',
            'character__audio_links__audio_asset',
            'word__audio_links__audio_asset',
        )
        return filter_by_access(
            queryset,
            self.request,
            status_field='lesson__status',
            pilot_q=Q(lesson__unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )
