from rest_framework import serializers

from learning.models import LearningUnit
from .models import UnitProgress


class UnitProgressSerializer(serializers.ModelSerializer):
    unit_slug = serializers.CharField(source='unit.slug', read_only=True)
    unit_title_fr = serializers.CharField(source='unit.title_fr', read_only=True)
    unit_title_en = serializers.CharField(source='unit.title_en', read_only=True)
    unit_title_ar = serializers.CharField(source='unit.title_ar', read_only=True)

    class Meta:
        model = UnitProgress
        fields = [
            'id',
            'user',
            'device_id',
            'unit',
            'unit_slug',
            'unit_title_fr',
            'unit_title_en',
            'unit_title_ar',
            'status',
            'last_stage',
            'lessons_seen',
            'characters_seen',
            'words_seen',
            'quizzes_answered',
            'correct_answers',
            'best_score_percent',
            'scoring_version',
            'last_session_score',
            'completed',
            'started_at',
            'completed_at',
            'client_updated_at',
            'synced_at',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'user',
            'device_id',
            'unit_slug',
            'unit_title_fr',
            'unit_title_en',
            'unit_title_ar',
            'synced_at',
            'created_at',
        ]


class UnitProgressSyncItemSerializer(serializers.Serializer):
    unit_id = serializers.IntegerField(required=False, allow_null=True)
    unit_slug = serializers.CharField(required=False, allow_blank=True, max_length=120)
    device_id = serializers.CharField(required=False, allow_blank=True, max_length=120)
    status = serializers.ChoiceField(
        choices=[UnitProgress.STARTED, UnitProgress.REVIEW, UnitProgress.COMPLETED],
        required=False,
        default=UnitProgress.STARTED,
    )
    last_stage = serializers.CharField(required=False, allow_blank=True, max_length=50, default='intro')
    lessons_seen = serializers.IntegerField(required=False, min_value=0, default=0)
    characters_seen = serializers.IntegerField(required=False, min_value=0, default=0)
    words_seen = serializers.IntegerField(required=False, min_value=0, default=0)
    quizzes_answered = serializers.IntegerField(required=False, min_value=0, default=0)
    correct_answers = serializers.IntegerField(required=False, min_value=0, default=0)
    score_percent = serializers.IntegerField(required=False, min_value=0, max_value=100, default=0)
    scoring_version = serializers.IntegerField(required=False, min_value=1, max_value=2)
    last_session_score = serializers.IntegerField(required=False, min_value=0, max_value=100, allow_null=True)
    completed = serializers.BooleanField(required=False, default=False)
    started_at = serializers.DateTimeField(required=False, allow_null=True)
    completed_at = serializers.DateTimeField(required=False, allow_null=True)
    updated_at = serializers.DateTimeField(required=False, allow_null=True)
    client_updated_at = serializers.DateTimeField(required=False, allow_null=True)

    def validate(self, attrs):
        unit_id = attrs.get('unit_id')
        unit_slug = (attrs.get('unit_slug') or '').strip()

        if not unit_id and not unit_slug:
            raise serializers.ValidationError('unit_id or unit_slug is required.')

        unit = None
        if unit_id:
            unit = LearningUnit.objects.filter(id=unit_id).first()
        if not unit and unit_slug:
            unit = LearningUnit.objects.filter(slug=unit_slug).first()

        if not unit:
            raise serializers.ValidationError('Learning unit not found.')

        attrs['resolved_unit'] = unit

        correct = attrs.get('correct_answers', 0)
        quizzes = attrs.get('quizzes_answered', 0)
        if quizzes > 0 and correct > quizzes:
            raise serializers.ValidationError('correct_answers cannot exceed quizzes_answered.')

        return attrs
