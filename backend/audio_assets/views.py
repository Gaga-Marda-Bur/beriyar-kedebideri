from rest_framework import generics

from core.permissions import is_staff_preview
from .models import AudioAsset
from .serializers import AudioAssetSerializer


class AudioAssetListAPIView(generics.ListAPIView):
    serializer_class = AudioAssetSerializer

    def get_queryset(self):
        queryset = AudioAsset.objects.all()

        audio_type = self.request.query_params.get('type')
        speed = self.request.query_params.get('speed')
        status_param = self.request.query_params.get('status')
        offline = self.request.query_params.get('offline')

        is_staff = is_staff_preview(self.request)
        if not is_staff:
            queryset = queryset.filter(validation_status='published')
        elif status_param:
            queryset = queryset.filter(validation_status=status_param)

        if audio_type:
            queryset = queryset.filter(audio_type=audio_type)

        if speed:
            queryset = queryset.filter(speed=speed)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by('audio_type', 'title', '-created_at')


class AudioAssetDetailAPIView(generics.RetrieveAPIView):
    serializer_class = AudioAssetSerializer

    def get_queryset(self):
        queryset = AudioAsset.objects.all()
        if not is_staff_preview(self.request):
            queryset = queryset.filter(validation_status='published')
        return queryset
