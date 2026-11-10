from django.urls import path

from .views import (
    FeedbackReportCreateAPIView,
    FeedbackReportDetailAPIView,
    FeedbackReportListAPIView,
)
from .private_media import FeedbackAttachmentAPIView, FeedbackAudioAPIView, FeedbackAudioFileAPIView

urlpatterns = [
    path('attachments/<path:name>', FeedbackAttachmentAPIView.as_view(), name='feedback-attachment'),
    path('audio-file/<path:name>', FeedbackAudioFileAPIView.as_view(), name='feedback-audio-file'),
    path('audio/<uuid:pk>/', FeedbackAudioAPIView.as_view(), name='feedback-audio'),
    path('', FeedbackReportListAPIView.as_view(), name='feedback-list'),
    path('create/', FeedbackReportCreateAPIView.as_view(), name='feedback-create'),
    path('<int:pk>/', FeedbackReportDetailAPIView.as_view(), name='feedback-detail'),
]
