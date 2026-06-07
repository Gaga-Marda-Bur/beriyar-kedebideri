from rest_framework import serializers

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