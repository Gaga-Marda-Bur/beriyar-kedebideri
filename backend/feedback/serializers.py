from django.contrib.contenttypes.models import ContentType
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from audio_assets.utils import build_file_url
from . import validation
from .models import FeedbackReport


class FeedbackReportSerializer(serializers.ModelSerializer):
    content_type_app_label = serializers.CharField(
        source='content_type.app_label',
        read_only=True,
    )
    content_type_model = serializers.CharField(
        source='content_type.model',
        read_only=True,
    )

    audio_feedback_url = serializers.SerializerMethodField()
    screenshot_url = serializers.SerializerMethodField()

    target_app_label = serializers.CharField(write_only=True, required=False, allow_blank=True)
    target_model = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = FeedbackReport
        fields = [
            'id',
            'user',
            'device_id',

            'feedback_type',
            'title',
            'message',

            'content_type',
            'content_type_app_label',
            'content_type_model',
            'object_id',

            'target_app_label',
            'target_model',

            'audio_feedback',
            'audio_feedback_url',
            'screenshot',
            'screenshot_url',

            'app_version',
            'platform',
            'language_code',

            'priority',
            'status',
            'admin_note',

            'client_created_at',
            'synced_at',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'content_type',
            'content_type_app_label',
            'content_type_model',
            'audio_feedback_url',
            'screenshot_url',
            'priority',
            'status',
            'admin_note',
            'synced_at',
            'created_at',
            'updated_at',
        ]

    def get_audio_feedback_url(self, obj):
        if obj.audio_feedback:
            return build_file_url(
                obj.audio_feedback.file,
                request=self.context.get('request'),
            )

        return None

    def get_screenshot_url(self, obj):
        return build_file_url(
            obj.screenshot,
            request=self.context.get('request'),
        )

    def validate(self, attrs):
        target_app_label = attrs.pop('target_app_label', '')
        target_model = attrs.pop('target_model', '')

        message = attrs.get('message', '').strip()
        title = attrs.get('title', '').strip()

        if not message and not title:
            raise serializers.ValidationError(
                {'message': 'A message or title is required.'}
            )

        if target_app_label and target_model:
            content_type = ContentType.objects.filter(
                app_label=target_app_label,
                model=target_model.lower(),
            ).first()

            if not content_type:
                raise serializers.ValidationError(
                    'Target content type not found.'
                )

            attrs['content_type'] = content_type

        return attrs

    def create(self, validated_data):
        request = self.context.get('request')

        if request and request.user.is_authenticated:
            validated_data['user'] = request.user

        return super().create(validated_data)


class FeedbackReportCreateSerializer(serializers.ModelSerializer):
    """Création publique d'un feedback (A15) : champs limités et validés.

    Les champs de traitement (statut, priorité, note admin, utilisateur) et le
    lien vers un AudioAsset existant ne sont pas modifiables par le public.
    """

    target_app_label = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=100)
    target_model = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=100)
    feedback_type = serializers.CharField(required=False, allow_blank=True, max_length=40)
    title = serializers.CharField(required=False, allow_blank=True, trim_whitespace=False, max_length=10000)
    message = serializers.CharField(required=False, allow_blank=True, trim_whitespace=False, max_length=50000)
    device_id = serializers.CharField(required=False, allow_blank=True, max_length=200)
    app_version = serializers.CharField(required=False, allow_blank=True, max_length=100)
    platform = serializers.CharField(required=False, allow_blank=True, max_length=100)
    language_code = serializers.CharField(required=False, allow_blank=True, max_length=50)

    class Meta:
        model = FeedbackReport
        fields = [
            'feedback_type',
            'title',
            'message',
            'device_id',
            'target_app_label',
            'target_model',
            'object_id',
            'screenshot',
            'app_version',
            'platform',
            'language_code',
            'client_created_at',
        ]

    def to_internal_value(self, data):
        if hasattr(data, 'keys'):
            unknown = set(data.keys()) - set(self.fields)
            if unknown:
                raise serializers.ValidationError({'non_field_errors': [
                    validation.message('invalid_choice', self._lang())]})
            for name in data.keys():
                if isinstance(self.fields[name], serializers.CharField) and not isinstance(data[name], str):
                    raise serializers.ValidationError({name: validation.message('invalid_format', self._lang())})
        return super().to_internal_value(data)

    def _lang(self):
        raw = (self.initial_data.get('language_code') or '') if hasattr(self.initial_data, 'get') else ''
        code = str(raw)[:2].lower()
        if code in ('fr', 'en', 'ar'):
            return code
        request = self.context.get('request')
        accept = (request.META.get('HTTP_ACCEPT_LANGUAGE', '') if request else '')[:2].lower()
        return accept if accept in ('fr', 'en', 'ar') else 'en'

    def _run(self, func, value, *args):
        try:
            return func(value, *args, self._lang())
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages, code=getattr(exc, 'code', None))

    def validate_feedback_type(self, value):
        return self._run(validation.clean_feedback_type, value)

    def validate_title(self, value):
        return self._run(validation.clean_text, value, validation.MAX_TITLE_LENGTH)

    def validate_message(self, value):
        return self._run(validation.clean_text, value, validation.MAX_MESSAGE_LENGTH)

    def validate_device_id(self, value):
        return self._run(validation.clean_device_id, value)

    def validate_app_version(self, value):
        return self._run(validation.clean_app_version, value)

    def validate_platform(self, value):
        return self._run(validation.clean_platform, value)

    def validate_language_code(self, value):
        return self._run(validation.clean_language_code, value)

    def validate_client_created_at(self, value):
        return self._run(validation.clean_client_created_at, value)

    def validate_screenshot(self, value):
        return self._run(validation.clean_screenshot, value)

    def validate(self, attrs):
        lang = self._lang()
        app_label = attrs.pop('target_app_label', '')
        model = attrs.pop('target_model', '')
        try:
            validation.require_title_or_message(attrs.get('title', ''), attrs.get('message', ''), lang)
            content_type = validation.resolve_target(app_label, model, attrs.get('object_id'), lang)
        except DjangoValidationError as exc:
            field = 'message' if exc.code == 'required' else 'target'
            raise serializers.ValidationError({field: exc.messages}, code=exc.code)
        attrs['content_type'] = content_type
        attrs.setdefault('feedback_type', FeedbackReport.OTHER)
        if not attrs['feedback_type']:
            attrs['feedback_type'] = FeedbackReport.OTHER
        return attrs

    def create(self, validated_data):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['user'] = request.user
        return FeedbackReport.objects.create(**validated_data)
