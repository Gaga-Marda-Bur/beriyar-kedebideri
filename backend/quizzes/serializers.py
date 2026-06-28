from rest_framework import serializers

from audio_assets.utils import build_file_url, get_linked_audio_url
from .models import QuizOption, QuizQuestion, QuizQuestionAudio


class PublicQuizOptionSerializer(serializers.ModelSerializer):
    character_symbol = serializers.CharField(source='character.symbol', read_only=True)
    character_name = serializers.CharField(source='character.name', read_only=True)
    character_latin = serializers.CharField(source='character.latin_transcription', read_only=True)

    word_text = serializers.CharField(source='word.beriya_text', read_only=True)
    word_latin = serializers.CharField(source='word.latin_transcription', read_only=True)

    image_url = serializers.SerializerMethodField()

    text = serializers.SerializerMethodField()
    text_fr_out = serializers.SerializerMethodField()
    text_en_out = serializers.SerializerMethodField()
    text_ar_out = serializers.SerializerMethodField()

    class Meta:
        model = QuizOption
        fields = [
            'id',
            'question',
            'text',
            'text_fr',
            'text_en',
            'text_ar',
            'text_fr_out',
            'text_en_out',
            'text_ar_out',
            'character',
            'character_symbol',
            'character_name',
            'character_latin',
            'word',
            'word_text',
            'word_latin',
            'image_url',
            'order_index',
        ]

    def get_image_url(self, obj):
        return build_file_url(
            obj.image,
            request=self.context.get('request'),
        )

    def _fallback_text(self, obj):
        if obj.text_fr:
            return obj.text_fr
        if obj.character:
            return obj.character.symbol
        if obj.word:
            return obj.word.beriya_text
        return ''

    def get_text(self, obj):
        return self._fallback_text(obj)

    def get_text_fr_out(self, obj):
        return obj.text_fr or self._fallback_text(obj)

    def get_text_en_out(self, obj):
        return obj.text_en or self._fallback_text(obj)

    def get_text_ar_out(self, obj):
        return obj.text_ar or self._fallback_text(obj)


class QuizQuestionSerializer(serializers.ModelSerializer):
    options = PublicQuizOptionSerializer(many=True, read_only=True)

    unit_slug = serializers.CharField(source='unit.slug', read_only=True)
    lesson_slug = serializers.CharField(source='lesson.slug', read_only=True)

    character_symbol = serializers.CharField(source='character.symbol', read_only=True)
    character_name = serializers.CharField(source='character.name', read_only=True)

    word_text = serializers.CharField(source='word.beriya_text', read_only=True)
    word_latin = serializers.CharField(source='word.latin_transcription', read_only=True)

    question_audio_url = serializers.SerializerMethodField()
    question_slow_audio_url = serializers.SerializerMethodField()
    explanation_audio_url = serializers.SerializerMethodField()
    question_image_url = serializers.SerializerMethodField()

    correct_index = serializers.SerializerMethodField()

    prompt_text = serializers.SerializerMethodField()
    prompt_text_fr = serializers.CharField(source='prompt_fr', read_only=True)
    prompt_text_en = serializers.CharField(source='prompt_en', read_only=True)
    prompt_text_ar = serializers.CharField(source='prompt_ar', read_only=True)

    oral_prompt = serializers.SerializerMethodField()

    explanation = serializers.SerializerMethodField()
    explanation_fr_out = serializers.CharField(source='explanation_fr', read_only=True)
    explanation_en_out = serializers.CharField(source='explanation_en', read_only=True)
    explanation_ar_out = serializers.CharField(source='explanation_ar', read_only=True)

    options_text_fr = serializers.SerializerMethodField()
    options_text_en = serializers.SerializerMethodField()
    options_text_ar = serializers.SerializerMethodField()

    class Meta:
        model = QuizQuestion
        fields = [
            'id',
            'unit',
            'unit_slug',
            'lesson',
            'lesson_slug',

            'question_type',
            'difficulty',

            'prompt_text',
            'prompt_text_fr',
            'prompt_text_en',
            'prompt_text_ar',

            'oral_prompt',
            'oral_prompt_fr',
            'oral_prompt_en',
            'oral_prompt_ar',

            'character',
            'character_symbol',
            'character_name',
            'word',
            'word_text',
            'word_latin',

            'question_image_url',
            'question_audio_url',
            'question_slow_audio_url',

            'correct_text_answer',
            'correct_index',

            'explanation',
            'explanation_fr_out',
            'explanation_en_out',
            'explanation_ar_out',
            'explanation_audio_url',

            'order_index',
            'points',
            'min_options_required',

            'status',
            'is_active',
            'available_offline',

            'options',
            'options_text_fr',
            'options_text_en',
            'options_text_ar',

            'created_at',
            'updated_at',
        ]

    def build_file_url(file_field, request=None):
        if not file_field:
            return None

        try:
            url = file_field.url
        except ValueError:
            return None

        if request is not None and url.startswith("/"):
            return request.build_absolute_uri(url)

        return url


    def get_linked_audio_url(obj, role, request=None):
        audio_link = (
            obj.audio_links
            .filter(
                role=role,
                is_primary=True,
                audio_asset__file__isnull=False,
            )
            .select_related("audio_asset")
            .order_by("order")
            .first()
        )

        if not audio_link or not audio_link.audio_asset or not audio_link.audio_asset.file:
            return None

        return build_file_url(
            audio_link.audio_asset.file,
            request=request,
        )

    def get_question_image_url(self, obj):
        return build_file_url(
            obj.question_image,
            request=self.context.get('request'),
        )

    def get_question_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role=QuizQuestionAudio.QUESTION,
            request=self.context.get("request"),
        )

    def get_question_slow_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role=QuizQuestionAudio.SLOW_QUESTION,
            request=self.context.get("request"),
        )

    def get_explanation_audio_url(self, obj):
        return get_linked_audio_url(
            obj=obj,
            role=QuizQuestionAudio.EXPLANATION,
            request=self.context.get("request"),
        )

    def get_correct_index(self, obj):
        options = list(obj.options.all())

        for index, option in enumerate(options):
            if option.is_correct:
                return index

        return 0

    def get_prompt_text(self, obj):
        return obj.prompt_fr or obj.prompt_en or obj.prompt_ar or ''

    def get_oral_prompt(self, obj):
        return obj.oral_prompt_fr or obj.oral_prompt_en or obj.oral_prompt_ar or ''

    def get_explanation(self, obj):
        return obj.explanation_fr or obj.explanation_en or obj.explanation_ar or ''

    def _option_text_for_lang(self, option, lang):
        if lang == 'fr' and option.text_fr:
            return option.text_fr
        if lang == 'en' and option.text_en:
            return option.text_en
        if lang == 'ar' and option.text_ar:
            return option.text_ar

        if option.character:
            return option.character.symbol

        if option.word:
            return option.word.beriya_text

        return option.text_fr or option.text_en or option.text_ar or ''

    def get_options_text_fr(self, obj):
        return [
            self._option_text_for_lang(option, 'fr')
            for option in obj.options.all()
        ]

    def get_options_text_en(self, obj):
        return [
            self._option_text_for_lang(option, 'en')
            for option in obj.options.all()
        ]

    def get_options_text_ar(self, obj):
        return [
            self._option_text_for_lang(option, 'ar')
            for option in obj.options.all()
        ]