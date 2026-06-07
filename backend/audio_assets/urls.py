from django.urls import path

from .views import AudioAssetDetailAPIView, AudioAssetListAPIView

urlpatterns = [
    path('', AudioAssetListAPIView.as_view(), name='audio-asset-list'),
    path('<uuid:pk>/', AudioAssetDetailAPIView.as_view(), name='audio-asset-detail'),
]