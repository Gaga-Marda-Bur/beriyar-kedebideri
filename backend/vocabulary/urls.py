from django.urls import path

from .views import WordCategoryListAPIView, WordDetailAPIView, WordListAPIView

urlpatterns = [
    path('categories/', WordCategoryListAPIView.as_view(), name='word-category-list'),
    path('words/', WordListAPIView.as_view(), name='word-list'),
    path('words/<int:pk>/', WordDetailAPIView.as_view(), name='word-detail'),
]