from rest_framework import serializers

from core.permissions import is_staff_preview
from .models import AudioAsset


class AudioAssetSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = AudioAsset
        fields = [
            'id',
            'title',
            'file_url',
            'audio_type',
            'speed',
            'speaker_name',
            'speaker_gender',
            'dialect_region',
            'mime_type',
            'duration_ms',
            'transcript',
            'recording_quality',
            'validation_status',
            'available_offline',
            'notes',
            'created_at',
            'updated_at',
        ]

    def get_file_url(self, obj):
        request = self.context.get('request')

        if obj.file and request:
            return request.build_absolute_uri(obj.file.url)

        if obj.file:
            return obj.file.url

        return None

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        # Masquer les métadonnées internes audio pour les requêtes publiques
        if request is not None and not is_staff_preview(request):
            data.pop('notes', None)
            data.pop('speaker_name', None)
            data.pop('recording_quality', None)
        return data
