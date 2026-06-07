from rest_framework import generics

from .models import Word, WordCategory
from .serializers import WordCategorySerializer, WordSerializer


class WordCategoryListAPIView(generics.ListAPIView):
    serializer_class = WordCategorySerializer

    def get_queryset(self):
        return WordCategory.objects.filter(
            is_active=True,
        ).order_by(
            'order_index',
            'name_fr',
        )


class WordListAPIView(generics.ListAPIView):
    serializer_class = WordSerializer

    def get_queryset(self):
        queryset = Word.objects.filter(
            is_active=True,
        ).select_related(
            'category',
        ).prefetch_related(
            'audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        category = self.request.query_params.get('category')
        difficulty = self.request.query_params.get('difficulty')
        offline = self.request.query_params.get('offline')
        search = self.request.query_params.get('search')

        if status_param:
            queryset = queryset.filter(validation_status=status_param)

        if category:
            queryset = queryset.filter(category__slug=category)

        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        if search:
            queryset = queryset.filter(
                beriya_text__icontains=search
            ) | queryset.filter(
                latin_transcription__icontains=search
            ) | queryset.filter(
                french_translation__icontains=search
            ) | queryset.filter(
                english_translation__icontains=search
            ) | queryset.filter(
                arabic_translation__icontains=search
            )

        return queryset.order_by(
            'difficulty_order',
            'beriya_text',
        )


class WordDetailAPIView(generics.RetrieveAPIView):
    serializer_class = WordSerializer

    def get_queryset(self):
        return Word.objects.filter(
            is_active=True,
        ).select_related(
            'category',
        ).prefetch_related(
            'audio_links__audio_asset',
        )