from django.urls import path

from .views import HttpsProxyDiagnosticAPIView

urlpatterns = [
    path('diagnostics/https/', HttpsProxyDiagnosticAPIView.as_view(), name='core-https-diagnostic'),
]