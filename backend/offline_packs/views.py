from django.db.models import Q
from rest_framework import generics

from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, filter_by_access
from .models import LessonPack
from .serializers import LessonPackSerializer


class LessonPackListAPIView(generics.ListAPIView):
    serializer_class = LessonPackSerializer

    def get_queryset(self):
        queryset = LessonPack.objects.filter(
            is_active=True,
        )

        status_param = self.request.query_params.get('status')
        level = self.request.query_params.get('level')
        featured = self.request.query_params.get('featured')

        from learning.models import LearningUnit
        non_pilot_units = LearningUnit.objects.exclude(slug__in=PILOT_ALLOWED_UNIT_SLUGS)
        queryset = filter_by_access(
            queryset,
            self.request,
            status_param=status_param,
            pilot_q=Q(units__slug__in=PILOT_ALLOWED_UNIT_SLUGS) & ~Q(units__in=non_pilot_units),
        )

        if level:
            queryset = queryset.filter(level=level)

        if featured in ['true', '1', 'yes']:
            queryset = queryset.filter(is_featured=True)

        return queryset.order_by(
            '-is_featured',
            'level',
            'title_fr',
            'version',
        )


class LessonPackDetailAPIView(generics.RetrieveAPIView):
    serializer_class = LessonPackSerializer

    def get_queryset(self):
        queryset = LessonPack.objects.filter(is_active=True)
        from learning.models import LearningUnit
        non_pilot_units = LearningUnit.objects.exclude(slug__in=PILOT_ALLOWED_UNIT_SLUGS)
        return filter_by_access(
            queryset,
            self.request,
            pilot_q=Q(units__slug__in=PILOT_ALLOWED_UNIT_SLUGS) & ~Q(units__in=non_pilot_units),
        )
