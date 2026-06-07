from rest_framework import serializers

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
            'unit_slug',
            'unit_title_fr',
            'unit_title_en',
            'unit_title_ar',
            'synced_at',
            'created_at',
        ]