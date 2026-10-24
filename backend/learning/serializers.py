from rest_framework import serializers

from alphabet.serializers import CharacterSerializer
from core.permissions import is_staff_preview
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
        request = self.context.get('request')
        qs = obj.characters.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(validation_status='published')
        return qs.count()

    def get_words_count(self, obj):
        request = self.context.get('request')
        qs = obj.words.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(validation_status='published')
        return qs.count()


class LearningThemeSerializer(serializers.ModelSerializer):
    units = serializers.SerializerMethodField()
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

    def get_units(self, obj):
        request = self.context.get('request')
        qs = obj.units.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(status='published')
        return LearningUnitCompactSerializer(
            qs.order_by('order_index', 'title_fr'),
            many=True,
            context=self.context,
        ).data

    def get_units_count(self, obj):
        request = self.context.get('request')
        qs = obj.units.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(status='published')
        return qs.count()


class LearningUnitSerializer(serializers.ModelSerializer):
    theme_slug = serializers.CharField(source='theme.slug', read_only=True)
    theme_title_fr = serializers.CharField(source='theme.title_fr', read_only=True)
    theme_title_en = serializers.CharField(source='theme.title_en', read_only=True)
    theme_title_ar = serializers.CharField(source='theme.title_ar', read_only=True)

    characters = CharacterSerializer(many=True, read_only=True)
    distractor_characters = CharacterSerializer(many=True, read_only=True)
    words = WordSerializer(many=True, read_only=True)
    target_word = WordSerializer(read_only=True)

    character_ids = serializers.SerializerMethodField()
    distractor_character_ids = serializers.SerializerMethodField()
    word_ids = serializers.SerializerMethodField()
    core_flow = serializers.SerializerMethodField()

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
            'distractor_characters',
            'words',
            'target_word',
            'character_ids',
            'distractor_character_ids',
            'word_ids',
            'weight_recognition',
            'weight_tracing',
            'weight_encoding',
            'enable_tracing',
            'pedagogy_config',
            'core_flow',
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
        request = self.context.get('request')
        qs = obj.characters.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(validation_status='published')
        return list(qs.values_list('id', flat=True))

    def get_distractor_character_ids(self, obj):
        request = self.context.get('request')
        qs = obj.distractor_characters.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(validation_status='published')
        return list(qs.values_list('id', flat=True))

    def get_word_ids(self, obj):
        request = self.context.get('request')
        qs = obj.words.filter(is_active=True)
        if request is not None and not is_staff_preview(request):
            qs = qs.filter(validation_status='published')
        return list(qs.values_list('id', flat=True))

    def get_core_flow(self, obj):
        return obj.generate_core_flow(request=self.context.get('request'))

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')

        # Filtrage strict pour les requêtes HTTP publiques : exclure tout élément non publié
        if request is not None and not is_staff_preview(request):
            if data.get('characters'):
                data['characters'] = [
                    c for c in data['characters'] if c.get('validation_status') == 'published'
                ]
            if data.get('distractor_characters'):
                data['distractor_characters'] = [
                    c for c in data['distractor_characters'] if c.get('validation_status') == 'published'
                ]
            if data.get('words'):
                data['words'] = [
                    w for w in data['words'] if w.get('validation_status') == 'published'
                ]
            if instance.target_word and instance.target_word.validation_status != 'published':
                data['target_word'] = None

        return data
