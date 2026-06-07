from rest_framework import generics

from .models import QuizQuestion
from .serializers import QuizQuestionSerializer


class QuizQuestionListAPIView(generics.ListAPIView):
    serializer_class = QuizQuestionSerializer

    def get_queryset(self):
        queryset = QuizQuestion.objects.filter(
            is_active=True,
        ).select_related(
            'unit',
            'lesson',
            'character',
            'word',
        ).prefetch_related(
            'options',
            'options__character',
            'options__word',
            'audio_links__audio_asset',
        )

        status_param = self.request.query_params.get('status')
        question_type = self.request.query_params.get('type')
        difficulty = self.request.query_params.get('difficulty')
        unit = self.request.query_params.get('unit')
        lesson = self.request.query_params.get('lesson')
        offline = self.request.query_params.get('offline')

        if status_param:
            queryset = queryset.filter(status=status_param)

        if question_type:
            queryset = queryset.filter(question_type=question_type)

        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)

        if unit:
            queryset = queryset.filter(unit__slug=unit)

        if lesson:
            queryset = queryset.filter(lesson__slug=lesson)

        if offline in ['true', '1', 'yes']:
            queryset = queryset.filter(available_offline=True)

        return queryset.order_by(
            'unit__order_index',
            'lesson__order_index',
            'order_index',
            'id',
        )


class QuizQuestionDetailAPIView(generics.RetrieveAPIView):
    serializer_class = QuizQuestionSerializer

    def get_queryset(self):
        return QuizQuestion.objects.filter(
            is_active=True,
        ).select_related(
            'unit',
            'lesson',
            'character',
            'word',
        ).prefetch_related(
            'options',
            'options__character',
            'options__word',
            'audio_links__audio_asset',
        )