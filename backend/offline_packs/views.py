from rest_framework import generics

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

        if status_param:
            queryset = queryset.filter(status=status_param)

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
        return LessonPack.objects.filter(is_active=True)