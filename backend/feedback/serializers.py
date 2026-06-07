from django.contrib.contenttypes.models import ContentType
from rest_framework import serializers

from audio_assets.utils import build_file_url
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