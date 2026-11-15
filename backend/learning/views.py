from django.db.models import Q
from rest_framework import generics

from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, filter_by_access
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

        queryset = filter_by_access(
            queryset,
            self.request,
            status_param=status_param,
            pilot_q=Q(units__slug__in=PILOT_ALLOWED_UNIT_SLUGS, units__status='validated', units__is_active=True),
        )

        if level:
            queryset = queryset.filter(level=level)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by('level', 'order_index', 'title_fr')


class LearningThemeDetailAPIView(generics.RetrieveAPIView):
    serializer_class = LearningThemeSerializer

    def get_queryset(self):
        queryset = LearningTheme.objects.filter(
            is_active=True,
        ).prefetch_related(
            'units',
            'units__characters',
            'units__words',
        )
        return filter_by_access(
            queryset,
            self.request,
            pilot_q=Q(units__slug__in=PILOT_ALLOWED_UNIT_SLUGS, units__status='validated', units__is_active=True),
        )


class LearningUnitListAPIView(generics.ListAPIView):
    serializer_class = LearningUnitSerializer

    def get_queryset(self):
        queryset = LearningUnit.objects.filter(
            is_active=True,
        ).select_related(
            'theme',
            'target_word',
            'target_word__category',
        ).prefetch_related(
            'characters',
            'characters__audio_links__audio_asset',
            'distractor_characters',
            'distractor_characters__audio_links__audio_asset',
            'words',
            'words__category',
            'words__audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        level = self.request.query_params.get('level')
        theme = self.request.query_params.get('theme')
        offline = self.request.query_params.get('offline')

        queryset = filter_by_access(
            queryset,
            self.request,
            status_param=status_param,
            pilot_q=Q(slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )

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
        queryset = LearningUnit.objects.filter(
            is_active=True,
        ).select_related(
            'theme',
            'target_word',
            'target_word__category',
        ).prefetch_related(
            'characters',
            'characters__audio_links__audio_asset',
            'distractor_characters',
            'distractor_characters__audio_links__audio_asset',
            'words',
            'words__category',
            'words__audio_links__audio_asset',
        )
        return filter_by_access(
            queryset,
            self.request,
            pilot_q=Q(slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )


class LearningUnitCoreFlowAPIView(generics.GenericAPIView):
    def get(self, request, pk, *args, **kwargs):
        from rest_framework.response import Response
        base_qs = LearningUnit.objects.filter(is_active=True).prefetch_related(
            'characters',
            'distractor_characters',
            'words',
        ).select_related('target_word', 'theme')

        base_qs = filter_by_access(
            base_qs,
            request,
            pilot_q=Q(slug__in=PILOT_ALLOWED_UNIT_SLUGS),
        )

        unit = generics.get_object_or_404(
            base_qs,
            pk=pk,
        )
        flow = unit.generate_core_flow(request=request)
        return Response({
            'unit_id': unit.id,
            'unit_title': unit.title_fr,
            'theme_title': unit.theme.title_fr if unit.theme else '',
            'total_steps': len(flow),
            'weights': {
                'recognition': unit.weight_recognition,
                'tracing': unit.weight_tracing,
                'encoding': unit.weight_encoding,
            },
            'steps': flow,
        })
