from django.urls import path

from .views import (
    LessonPackDetailAPIView,
    LessonPackDownloadAPIView,
    LessonPackListAPIView,
)

urlpatterns = [
    path('', LessonPackListAPIView.as_view(), name='lesson-pack-list'),
    path('<int:pk>/', LessonPackDetailAPIView.as_view(), name='lesson-pack-detail'),
    path('<int:pk>/download/', LessonPackDownloadAPIView.as_view(), name='lesson-pack-download'),
]