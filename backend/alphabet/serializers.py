from rest_framework import serializers

from audio_assets.utils import get_linked_audio_url
from .models import Character


class CharacterSerializer(serializers.ModelSerializer):
    audio_url = serializers.SerializerMethodField()
    slow_audio_url = serializers.SerializerMethodField()

    class Meta:
        model = Character
        fields = [
            'id',
            'symbol',
            'unicode_code',
            'name',
            'name_fr',
            'name_en',
            'name_ar',
            'latin_transcription',
            'arabic_transcription',
            'character_type',
            'order_index',
            'description',
            'validation_status',
            'is_active',
            'available_offline',
            'audio_url',
            'slow_audio_url',
            'created_at',
            'updated_at',
        ]

    def get_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='normal',
            request=self.context.get('request'),
        )

    def get_slow_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='slow',
            request=self.context.get('request'),
        )