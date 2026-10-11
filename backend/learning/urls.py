from django.urls import path

from .views import (
    LearningThemeDetailAPIView,
    LearningThemeListAPIView,
    LearningUnitCoreFlowAPIView,
    LearningUnitDetailAPIView,
    LearningUnitListAPIView,
)

urlpatterns = [
    path('themes/', LearningThemeListAPIView.as_view(), name='learning-theme-list'),
    path('themes/<int:pk>/', LearningThemeDetailAPIView.as_view(), name='learning-theme-detail'),
    path('units/', LearningUnitListAPIView.as_view(), name='learning-unit-list'),
    path('units/<int:pk>/', LearningUnitDetailAPIView.as_view(), name='learning-unit-detail'),
    path('units/<int:pk>/core-flow/', LearningUnitCoreFlowAPIView.as_view(), name='learning-unit-core-flow'),
]