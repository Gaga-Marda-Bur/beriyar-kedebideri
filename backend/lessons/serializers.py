from rest_framework import serializers

from alphabet.serializers import CharacterSerializer
from audio_assets.utils import build_file_url, get_linked_audio_url
from vocabulary.serializers import WordSerializer
from .models import Lesson, LessonItem


class LessonItemSerializer(serializers.ModelSerializer):
    character = CharacterSerializer(read_only=True)
    word = WordSerializer(read_only=True)

    character_id = serializers.IntegerField(source='character.id', read_only=True)
    word_id = serializers.IntegerField(source='word.id', read_only=True)

    audio_url = serializers.SerializerMethodField()
    slow_audio_url = serializers.SerializerMethodField()
    prompt_audio_url = serializers.SerializerMethodField()
    explanation_audio_url = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = LessonItem
        fields = [
            'id',
            'lesson',
            'item_type',
            'character',
            'character_id',
            'word',
            'word_id',
            'title_fr',
            'title_en',
            'title_ar',
            'oral_prompt_fr',
            'oral_prompt_en',
            'oral_prompt_ar',
            'explanation_fr',
            'explanation_en',
            'explanation_ar',
            'writing_hint_fr',
            'writing_hint_en',
            'writing_hint_ar',
            'repeat_count',
            'image_url',
            'audio_url',
            'slow_audio_url',
            'prompt_audio_url',
            'explanation_audio_url',
            'order_index',
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

    def get_prompt_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='prompt',
            request=self.context.get('request'),
        )

    def get_explanation_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role='explanation',
            request=self.context.get('request'),
        )


class LessonSerializer(serializers.ModelSerializer):
    items = LessonItemSerializer(many=True, read_only=True)

    unit_slug = serializers.CharField(source='unit.slug', read_only=True)
    unit_title_fr = serializers.CharField(source='unit.title_fr', read_only=True)
    unit_title_en = serializers.CharField(source='unit.title_en', read_only=True)
    unit_title_ar = serializers.CharField(source='unit.title_ar', read_only=True)

    items_count = serializers.SerializerMethodField()

    class Meta:
        model = Lesson
        fields = [
            'id',
            'unit',
            'unit_slug',
            'unit_title_fr',
            'unit_title_en',
            'unit_title_ar',
            'slug',
            'title_fr',
            'title_en',
            'title_ar',
            'description_fr',
            'description_en',
            'description_ar',
            'oral_intro_fr',
            'oral_intro_en',
            'oral_intro_ar',
            'level',
            'order_index',
            'estimated_minutes',
            'status',
            'is_active',
            'available_offline',
            'items_count',
            'items',
            'created_at',
            'updated_at',
        ]

    def get_items_count(self, obj):
        return obj.items.count()