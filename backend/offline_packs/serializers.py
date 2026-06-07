from rest_framework import serializers

from .models import LessonPack


class LessonPackSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    is_downloadable = serializers.SerializerMethodField()

    class Meta:
        model = LessonPack
        fields = [
            'id',
            'title_fr',
            'title_en',
            'title_ar',
            'slug',
            'description_fr',
            'description_en',
            'description_ar',
            'level',
            'pack_type',
            'version',
            'file_url',
            'is_downloadable',
            'manifest',
            'checksum',
            'size_mb',
            'items_count',
            'status',
            'is_active',
            'is_featured',
            'generated_at',
            'created_at',
            'updated_at',
        ]

    def get_file_url(self, obj):
        request = self.context.get('request')

        if obj.file and request:
            return request.build_absolute_uri(obj.file.url)

        if obj.file:
            return obj.file.url

        return ''

    def get_is_downloadable(self, obj):
        return bool(obj.file and obj.status == LessonPack.PUBLISHED)