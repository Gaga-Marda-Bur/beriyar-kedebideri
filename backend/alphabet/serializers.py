from rest_framework import serializers

from audio_assets.utils import get_linked_audio_url
from .models import Character


class CharacterSerializer(serializers.ModelSerializer):
    audio_url = serializers.SerializerMethodField()
    slow_audio_url = serializers.SerializerMethodField()
    phoneme_audio_url = serializers.SerializerMethodField()
    letter_name_audio_url = serializers.SerializerMethodField()

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
            'latin_grapheme',
            'phoneme_ipa',
            'tone_pattern',
            'vowel_length',
            'stroke_path_data',
            'stroke_order_rules',
            'character_type',
            'order_index',
            'description',
            'validation_status',
            'is_active',
            'available_offline',
            'audio_url',
            'slow_audio_url',
            'phoneme_audio_url',
            'letter_name_audio_url',
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

    def get_phoneme_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='phoneme',
            request=self.context.get('request'),
        ) or self.get_audio_url(obj)

    def get_letter_name_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='letter_name',
            request=self.context.get('request'),
        )