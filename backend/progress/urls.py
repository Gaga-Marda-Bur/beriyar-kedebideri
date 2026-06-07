from django.urls import path

from .views import UnitProgressListAPIView, UnitProgressSyncAPIView

urlpatterns = [
    path('unit-progress/', UnitProgressListAPIView.as_view(), name='unit-progress-list'),
    path('unit-progress/sync/', UnitProgressSyncAPIView.as_view(), name='unit-progress-sync'),
]