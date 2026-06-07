from django.urls import path

from .views import (
    LearningThemeDetailAPIView,
    LearningThemeListAPIView,
    LearningUnitDetailAPIView,
    LearningUnitListAPIView,
)

urlpatterns = [
    path('themes/', LearningThemeListAPIView.as_view(), name='learning-theme-list'),
    path('themes/<int:pk>/', LearningThemeDetailAPIView.as_view(), name='learning-theme-detail'),
    path('units/', LearningUnitListAPIView.as_view(), name='learning-unit-list'),
    path('units/<int:pk>/', LearningUnitDetailAPIView.as_view(), name='learning-unit-detail'),
]