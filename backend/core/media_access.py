"""Guard legacy feedback paths when media is served through Django.

An external public bucket/CDN must be remediated separately before deployment.
"""
from urllib.parse import urlsplit
import posixpath
from django.conf import settings
from django.http import HttpResponseNotFound


class PublicMediaGuard:
    def __init__(self,get_response):
        self.get_response=get_response

    def __call__(self,request):
        prefix=urlsplit(settings.MEDIA_URL).path
        if prefix and request.path.startswith(prefix):
            name=posixpath.normpath(request.path[len(prefix):].replace('\\','/'))
            blocked=name.casefold().startswith('feedback/')
            if name.casefold().startswith('audio_assets/'):
                from audio_assets.models import AudioAsset
                blocked=AudioAsset.objects.filter(file__iexact=name,audio_type='feedback').exists()
            if blocked:
                response=HttpResponseNotFound()
                response['Cache-Control']='private, no-store'
                return response
        return self.get_response(request)
