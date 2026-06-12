from rest_framework import generics, permissions, status
from rest_framework.response import Response

from .models import FeedbackReport
from .serializers import FeedbackReportSerializer


class FeedbackReportCreateAPIView(generics.CreateAPIView):
    serializer_class = FeedbackReportSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        feedback = serializer.save()

        return Response(
            {
                "success": True,
                "id": feedback.id,
                "message": "Feedback received.",
            },
            status=status.HTTP_201_CREATED,
        )


class FeedbackReportListAPIView(generics.ListAPIView):
    serializer_class = FeedbackReportSerializer
    permission_classes = [permissions.IsAdminUser]

    def get_queryset(self):
        queryset = FeedbackReport.objects.select_related(
            "user",
            "content_type",
            "audio_feedback",
        )

        device_id = self.request.query_params.get("device_id")
        status_param = self.request.query_params.get("status")
        feedback_type = self.request.query_params.get("type")
        platform = self.request.query_params.get("platform")

        if device_id:
            queryset = queryset.filter(device_id=device_id)

        if status_param:
            queryset = queryset.filter(status=status_param)

        if feedback_type:
            queryset = queryset.filter(feedback_type=feedback_type)

        if platform:
            queryset = queryset.filter(platform=platform)

        return queryset.order_by("-created_at")


class FeedbackReportDetailAPIView(generics.RetrieveAPIView):
    serializer_class = FeedbackReportSerializer
    permission_classes = [permissions.IsAdminUser]

    def get_queryset(self):
        return FeedbackReport.objects.select_related(
            "user",
            "content_type",
            "audio_feedback",
        )