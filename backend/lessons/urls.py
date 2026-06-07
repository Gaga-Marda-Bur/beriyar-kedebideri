from django.urls import path

from .views import (
    LessonDetailAPIView,
    LessonItemDetailAPIView,
    LessonItemListAPIView,
    LessonListAPIView,
)

urlpatterns = [
    path('', LessonListAPIView.as_view(), name='lesson-list'),
    path('<int:pk>/', LessonDetailAPIView.as_view(), name='lesson-detail'),
    path('items/', LessonItemListAPIView.as_view(), name='lesson-item-list'),
    path('items/<int:pk>/', LessonItemDetailAPIView.as_view(), name='lesson-item-detail'),
]