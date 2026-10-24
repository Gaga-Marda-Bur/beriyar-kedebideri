from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.exceptions import Throttled, APIException, ParseError

from .models import FeedbackReport
from .serializers import FeedbackReportSerializer, FeedbackReportCreateSerializer
from .throttles import API_THROTTLES
from .validation import message, humanize_wait


class FeedbackRequestTooLarge(APIException):
    status_code = 413
    default_detail = 'Feedback request exceeds 3 MB.'



class FeedbackReportCreateAPIView(generics.CreateAPIView):
    serializer_class = FeedbackReportCreateSerializer
    permission_classes = [permissions.AllowAny]
    throttle_classes = API_THROTTLES

    def initial(self, request, *args, **kwargs):
        length = request.META.get('CONTENT_LENGTH')
        if length:
            try:
                if int(length) > 3 * 1024 * 1024:
                    raise FeedbackRequestTooLarge()
            except ValueError as error:
                raise ParseError('Invalid request length.') from error
        return super().initial(request, *args, **kwargs)

    def throttled(self, request, wait):
        lang = request.META.get('HTTP_ACCEPT_LANGUAGE', 'en')[:2].lower()
        raise Throttled(wait=wait, detail=message('throttled', lang,
            wait=humanize_wait(wait, lang)))

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
