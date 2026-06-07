from rest_framework import serializers

from audio_assets.utils import build_file_url
from .models import NoEnaPublication


class NoEnaPublicationSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()
    audio_url = serializers.SerializerMethodField()

    related_character_symbol = serializers.CharField(
        source='related_character.symbol',
        read_only=True,
    )
    related_word_text = serializers.CharField(
        source='related_word.beriya_text',
        read_only=True,
    )
    related_unit_slug = serializers.CharField(
        source='related_unit.slug',
        read_only=True,
    )

    class Meta:
        model = NoEnaPublication
        fields = [
            'id',
            'slug',

            'title_fr',
            'title_en',
            'title_ar',
            'beriya_title',

            'caption_fr',
            'caption_en',
            'caption_ar',
            'beriya_caption',

            'publication_type',

            'image_url',
            'thumbnail_url',
            'video_url',
            'audio_url',

            'primary_audio_asset',

            'related_character',
            'related_character_symbol',
            'related_word',
            'related_word_text',
            'related_unit',
            'related_unit_slug',

            'contributor_name',
            'culture_theme',

            'order_index',
            'view_count',
            'favorite_count',

            'status',
            'is_active',
            'is_featured',
            'available_offline',
            'published_at',

            'created_at',
            'updated_at',
        ]

    def get_image_url(self, obj):
        return build_file_url(
            obj.image_file,
            request=self.context.get('request'),
        )

    def get_thumbnail_url(self, obj):
        return build_file_url(
            obj.thumbnail,
            request=self.context.get('request'),
        )

    def get_video_url(self, obj):
        return build_file_url(
            obj.video_file,
            request=self.context.get('request'),
        )

    def get_audio_url(self, obj):
        if obj.primary_audio_asset:
            return build_file_url(
                obj.primary_audio_asset.file,
                request=self.context.get('request'),
            )

        return None