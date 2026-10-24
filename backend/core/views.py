from django.conf import settings
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.throttling import BaseThrottle
from rest_framework.views import APIView


class HttpsProxyDiagnosticAPIView(APIView):
    """A14 : vérification du proxy TLS, réservée au staff authentifié.

    Permet de constater en production, sans rien modifier, ce que Django reçoit
    réellement derrière le proxy (schéma, en-têtes transmis, identifiant client
    utilisé par les limites de fréquence). Aucune valeur secrète n'est renvoyée.
    """

    permission_classes = [IsAdminUser]
    throttle_classes = []

    def get(self, request):
        meta = request.META
        return Response({
            'is_secure': request.is_secure(),
            'scheme': request.scheme,
            'host': request.get_host(),
            'x_forwarded_proto': meta.get('HTTP_X_FORWARDED_PROTO'),
            'x_forwarded_for': meta.get('HTTP_X_FORWARDED_FOR'),
            'remote_addr': meta.get('REMOTE_ADDR'),
            'throttle_client_ident': BaseThrottle().get_ident(request),
            'settings': {
                'DJANGO_ENV': getattr(settings, 'DJANGO_ENV', None),
                'DEBUG': settings.DEBUG,
                'SECURE_PROXY_SSL_HEADER': bool(settings.SECURE_PROXY_SSL_HEADER),
                'SECURE_SSL_REDIRECT': settings.SECURE_SSL_REDIRECT,
                'SECURE_HSTS_SECONDS': settings.SECURE_HSTS_SECONDS,
                'SECURE_HSTS_INCLUDE_SUBDOMAINS': settings.SECURE_HSTS_INCLUDE_SUBDOMAINS,
                'SECURE_HSTS_PRELOAD': settings.SECURE_HSTS_PRELOAD,
                'SESSION_COOKIE_SECURE': settings.SESSION_COOKIE_SECURE,
                'CSRF_COOKIE_SECURE': settings.CSRF_COOKIE_SECURE,
                'NUM_PROXIES': getattr(settings, 'NUM_PROXIES', None),
            },
        })