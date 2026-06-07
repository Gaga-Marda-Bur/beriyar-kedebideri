from rest_framework import generics

from .models import Lesson, LessonItem
from .serializers import LessonItemSerializer, LessonSerializer


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

        if status_param:
            queryset = queryset.filter(status=status_param)

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
        return Lesson.objects.filter(
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
        return LessonItem.objects.filter(
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