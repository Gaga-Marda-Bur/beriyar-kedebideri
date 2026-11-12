from django.urls import path

from .views import HttpsProxyDiagnosticAPIView
from .transliteration_views import TransliterationAPIView

urlpatterns = [
    path('transliterate/', TransliterationAPIView.as_view(), name='core-transliterate'),
    path('diagnostics/https/', HttpsProxyDiagnosticAPIView.as_view(), name='core-https-diagnostic'),
]
