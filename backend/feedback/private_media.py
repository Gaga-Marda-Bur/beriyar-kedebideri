from django.http import FileResponse, Http404
from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView

from audio_assets.models import AudioAsset
from .models import FeedbackReport


def stream_private(field):
    try:
        response=FileResponse(field.open('rb'),as_attachment=True,filename=field.name.rsplit('/',1)[-1])
    except (FileNotFoundError,OSError):
        raise Http404 from None
    response['Cache-Control']='private, no-store'
    response['X-Content-Type-Options']='nosniff'
    return response


class FeedbackAttachmentAPIView(APIView):
    permission_classes=[IsAdminUser]

    def get(self,request,name):
        # Resolve by exact database reference, never by arbitrary filesystem path.
        report=FeedbackReport.objects.filter(screenshot=name).first()
        if report is None:
            raise Http404
        return stream_private(report.screenshot)


class FeedbackAudioAPIView(APIView):
    permission_classes=[IsAdminUser]

    def get(self,request,pk):
        audio=AudioAsset.objects.filter(pk=pk,audio_type='feedback').first()
        if audio is None:
            raise Http404
        return stream_private(audio.file)


class FeedbackAudioFileAPIView(APIView):
    permission_classes=[IsAdminUser]

    def get(self,request,name):
        audio=AudioAsset.objects.filter(file=name,audio_type='feedback').first()
        if audio is None:
            raise Http404
        return stream_private(audio.file)
