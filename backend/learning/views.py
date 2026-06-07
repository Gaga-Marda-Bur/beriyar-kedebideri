from rest_framework import generics

from .models import LearningTheme, LearningUnit
from .serializers import LearningThemeSerializer, LearningUnitSerializer


class LearningThemeListAPIView(generics.ListAPIView):
    serializer_class = LearningThemeSerializer

    def get_queryset(self):
        queryset = LearningTheme.objects.filter(
            is_active=True,
        ).prefetch_related(
            'units',
            'units__characters',
            'units__words',
        )

        status_param = self.request.query_params.get('status')
        level = self.request.query_params.get('level')
        offline = self.request.query_params.get('offline')

        if status_param:
            queryset = queryset.filter(status=status_param)

        if level:
            queryset = queryset.filter(level=level)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by('level', 'order_index', 'title_fr')


class LearningThemeDetailAPIView(generics.RetrieveAPIView):
    serializer_class = LearningThemeSerializer

    def get_queryset(self):
        return LearningTheme.objects.filter(
            is_active=True,
        ).prefetch_related(
            'units',
            'units__characters',
            'units__words',
        )


class LearningUnitListAPIView(generics.ListAPIView):
    serializer_class = LearningUnitSerializer

    def get_queryset(self):
        queryset = LearningUnit.objects.filter(
            is_active=True,
        ).select_related(
            'theme',
        ).prefetch_related(
            'characters',
            'characters__audio_links__audio_asset',
            'words',
            'words__category',
            'words__audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        level = self.request.query_params.get('level')
        theme = self.request.query_params.get('theme')
        offline = self.request.query_params.get('offline')

        if status_param:
            queryset = queryset.filter(status=status_param)

        if level:
            queryset = queryset.filter(level=level)

        if theme:
            queryset = queryset.filter(theme__slug=theme)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by('theme__order_index', 'order_index', 'title_fr')


class LearningUnitDetailAPIView(generics.RetrieveAPIView):
    serializer_class = LearningUnitSerializer

    def get_queryset(self):
        return LearningUnit.objects.filter(
            is_active=True,
        ).select_related(
            'theme',
        ).prefetch_related(
            'characters',
            'characters__audio_links__audio_asset',
            'words',
            'words__category',
            'words__audio_links__audio_asset',
        )