from rest_framework import serializers

from audio_assets.utils import build_file_url, get_linked_audio_url
from .models import Word, WordCategory


class WordCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = WordCategory
        fields = [
            'id',
            'slug',
            'name_fr',
            'name_en',
            'name_ar',
            'order_index',
            'is_active',
        ]


class WordSerializer(serializers.ModelSerializer):
    category_slug = serializers.CharField(source='category.slug', read_only=True)
    category_fr = serializers.CharField(source='category.name_fr', read_only=True)
    category_en = serializers.CharField(source='category.name_en', read_only=True)
    category_ar = serializers.CharField(source='category.name_ar', read_only=True)

    translation_fr = serializers.CharField(source='french_translation', read_only=True)
    translation_en = serializers.CharField(source='english_translation', read_only=True)
    translation_ar = serializers.CharField(source='arabic_translation', read_only=True)

    level = serializers.CharField(source='difficulty', read_only=True)

    image_url = serializers.SerializerMethodField()
    audio_url = serializers.SerializerMethodField()
    slow_audio_url = serializers.SerializerMethodField()
    example_audio_url = serializers.SerializerMethodField()

    class Meta:
        model = Word
        fields = [
            'id',
            'beriya_text',
            'latin_transcription',
            'arabic_transcription',

            'french_translation',
            'english_translation',
            'arabic_translation',
            'translation_fr',
            'translation_en',
            'translation_ar',

            'category',
            'category_slug',
            'category_fr',
            'category_en',
            'category_ar',

            'difficulty',
            'level',
            'difficulty_order',

            'image_url',
            'audio_url',
            'slow_audio_url',
            'example_audio_url',

            'oral_prompt',
            'pronunciation_note',
            'dialect_note',
            'example_sentence',

            'validation_status',
            'is_active',
            'available_offline',
            'created_at',
            'updated_at',
        ]

    def get_image_url(self, obj):
        return build_file_url(
            obj.image,
            request=self.context.get('request'),
        )

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

    def get_example_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='example',
            request=self.context.get('request'),
        )