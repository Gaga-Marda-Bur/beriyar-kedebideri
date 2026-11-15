from django.db.models import Q
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from rest_framework import generics
from rest_framework.views import APIView

from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, filter_by_access, is_staff_preview
from .models import LessonPack
from .serializers import LessonPackSerializer


def _scoped_pack_queryset(request, status_param=None):
    from learning.models import LearningUnit

    queryset = LessonPack.objects.filter(is_active=True)
    non_pilot_units = LearningUnit.objects.exclude(slug__in=PILOT_ALLOWED_UNIT_SLUGS)
    return filter_by_access(
        queryset,
        request,
        status_param=status_param,
        pilot_q=Q(units__slug__in=PILOT_ALLOWED_UNIT_SLUGS) & ~Q(units__in=non_pilot_units),
    )


class LessonPackListAPIView(generics.ListAPIView):
    serializer_class = LessonPackSerializer

    def get_queryset(self):
        status_param = self.request.query_params.get('status')
        level = self.request.query_params.get('level')
        featured = self.request.query_params.get('featured')

        queryset = _scoped_pack_queryset(self.request, status_param=status_param)

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
        return _scoped_pack_queryset(self.request)


class LessonPackDownloadAPIView(APIView):
    """
    Authenticated download endpoint for private / pilot LessonPack archives.
    Enforces server-side pilot_erfe_v1 permissions on every download without
    exposing raw private storage or R2 credentials/URLs.
    """

    def get(self, request, pk):
        pack = get_object_or_404(_scoped_pack_queryset(request), pk=pk)
        if pack.status not in (LessonPack.PUBLISHED, LessonPack.VALIDATED) and not is_staff_preview(request):
            raise Http404()

        target = pack.active_file
        if not target or not getattr(target, 'name', None):
            raise Http404()

        try:
            stream = target.storage.open(target.name, 'rb')
        except Exception as exc:
            raise Http404() from exc

        response = FileResponse(
            stream,
            as_attachment=True,
            filename=pack.filename,
            content_type='application/zip',
        )
        response['Cache-Control'] = 'private, no-store'
        response['Vary'] = 'Cookie'
        response['X-Content-Type-Options'] = 'nosniff'
        return response
