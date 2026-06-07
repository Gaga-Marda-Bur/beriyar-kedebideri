from django.urls import path

from .views import (
    FeedbackReportCreateAPIView,
    FeedbackReportDetailAPIView,
    FeedbackReportListAPIView,
)

urlpatterns = [
    path('', FeedbackReportListAPIView.as_view(), name='feedback-list'),
    path('create/', FeedbackReportCreateAPIView.as_view(), name='feedback-create'),
    path('<int:pk>/', FeedbackReportDetailAPIView.as_view(), name='feedback-detail'),
]