from django.urls import path

from .views import QuizQuestionDetailAPIView, QuizQuestionListAPIView

urlpatterns = [
    path('', QuizQuestionListAPIView.as_view(), name='quiz-question-list'),
    path('<int:pk>/', QuizQuestionDetailAPIView.as_view(), name='quiz-question-detail'),
]