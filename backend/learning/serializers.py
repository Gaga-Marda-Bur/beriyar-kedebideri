from rest_framework import serializers

from alphabet.serializers import CharacterSerializer
from vocabulary.serializers import WordSerializer
from .models import LearningTheme, LearningUnit


class LearningUnitCompactSerializer(serializers.ModelSerializer):
    characters_count = serializers.SerializerMethodField()
    words_count = serializers.SerializerMethodField()

    class Meta:
        model = LearningUnit
        fields = [
            'id',
            'theme',
            'slug',
            'title_fr',
            'title_en',
            'title_ar',
            'description_fr',
            'description_en',
            'description_ar',
            'level',
            'estimated_minutes',
            'min_score_to_pass',
            'order_index',
            'status',
            'is_active',
            'available_offline',
            'characters_count',
            'words_count',
            'created_at',
            'updated_at',
        ]

    def get_characters_count(self, obj):
        return obj.characters.count()

    def get_words_count(self, obj):
        return obj.words.count()


class LearningThemeSerializer(serializers.ModelSerializer):
    units = LearningUnitCompactSerializer(many=True, read_only=True)
    units_count = serializers.SerializerMethodField()

    class Meta:
        model = LearningTheme
        fields = [
            'id',
            'slug',
            'title_fr',
            'title_en',
            'title_ar',
            'description_fr',
            'description_en',
            'description_ar',
            'level',
            'cover_image',
            'order_index',
            'status',
            'is_active',
            'available_offline',
            'units_count',
            'units',
            'created_at',
            'updated_at',
        ]

    def get_units_count(self, obj):
        return obj.units.count()


class LearningUnitSerializer(serializers.ModelSerializer):
    theme_slug = serializers.CharField(source='theme.slug', read_only=True)
    theme_title_fr = serializers.CharField(source='theme.title_fr', read_only=True)
    theme_title_en = serializers.CharField(source='theme.title_en', read_only=True)
    theme_title_ar = serializers.CharField(source='theme.title_ar', read_only=True)

    characters = CharacterSerializer(many=True, read_only=True)
    words = WordSerializer(many=True, read_only=True)

    character_ids = serializers.SerializerMethodField()
    word_ids = serializers.SerializerMethodField()

    class Meta:
        model = LearningUnit
        fields = [
            'id',
            'theme',
            'theme_slug',
            'theme_title_fr',
            'theme_title_en',
            'theme_title_ar',
            'slug',
            'title_fr',
            'title_en',
            'title_ar',
            'description_fr',
            'description_en',
            'description_ar',
            'level',
            'characters',
            'words',
            'character_ids',
            'word_ids',
            'estimated_minutes',
            'min_score_to_pass',
            'order_index',
            'status',
            'is_active',
            'available_offline',
            'created_at',
            'updated_at',
        ]

    def get_character_ids(self, obj):
        return list(obj.characters.values_list('id', flat=True))

    def get_word_ids(self, obj):
        return list(obj.words.values_list('id', flat=True))