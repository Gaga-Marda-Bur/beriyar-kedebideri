from rest_framework import generics

from .models import Character
from .serializers import CharacterSerializer


class CharacterListAPIView(generics.ListAPIView):
    serializer_class = CharacterSerializer

    def get_queryset(self):
        queryset = Character.objects.filter(
            is_active=True,
        ).prefetch_related(
            'audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        character_type = self.request.query_params.get('type')
        offline = self.request.query_params.get('offline')

        if status_param:
            queryset = queryset.filter(validation_status=status_param)

        if character_type:
            queryset = queryset.filter(character_type=character_type)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by('order_index', 'unicode_code')


class CharacterDetailAPIView(generics.RetrieveAPIView):
    serializer_class = CharacterSerializer

    def get_queryset(self):
        return Character.objects.filter(
            is_active=True,
        ).prefetch_related(
            'audio_links__audio_asset',
        )