from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import NoEnaPublication
from .serializers import NoEnaPublicationSerializer
from .services import record_publication_view


class NoEnaPublicationListAPIView(generics.ListAPIView):
    serializer_class = NoEnaPublicationSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = NoEnaPublication.objects.filter(
            is_active=True,
            status=NoEnaPublication.PUBLISHED,
        ).select_related(
            'primary_audio_asset',
            'related_character',
            'related_word',
            'related_unit',
        )

        publication_type = self.request.query_params.get('type')
        featured = self.request.query_params.get('featured')
        offline = self.request.query_params.get('offline')
        culture_theme = self.request.query_params.get('theme')

        if publication_type:
            queryset = queryset.filter(publication_type=publication_type)

        if featured in ['true', '1', 'yes']:
            queryset = queryset.filter(is_featured=True)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        if culture_theme:
            queryset = queryset.filter(culture_theme__icontains=culture_theme)

        return queryset.order_by(
            '-is_featured',
            'order_index',
            '-published_at',
            '-created_at',
        )


class NoEnaPublicationDetailAPIView(generics.RetrieveAPIView):
    serializer_class = NoEnaPublicationSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'slug'

    def get_queryset(self):
        return NoEnaPublication.objects.filter(
            is_active=True,
            status=NoEnaPublication.PUBLISHED,
        ).select_related(
            'primary_audio_asset',
            'related_character',
            'related_word',
            'related_unit',
        )


class NoEnaPublicationViewAPIView(APIView):
    """Enregistre un incrément de vue atomique et dédoublonné pour une publication No Ena."""
    permission_classes = [permissions.AllowAny]

    def post(self, request, slug):
        publication = NoEnaPublication.objects.filter(
            slug=slug,
            is_active=True,
            status=NoEnaPublication.PUBLISHED,
        ).first()

        if not publication:
            return Response({
                'detail': 'Publication not found.'
            }, status=404)

        device_id = None
        if hasattr(request, 'data') and hasattr(request.data, 'get'):
            device_id = request.data.get('device_id')

        view_count, was_counted = record_publication_view(
            publication, request=request, device_id=device_id
        )

        return Response({
            'slug': publication.slug,
            'view_count': view_count,
            'counted': was_counted,
        })
