from django.urls import path

from .auth_views import LearnerAuthView
from .views import HttpsProxyDiagnosticAPIView
from .transliteration_views import TransliterationAPIView

urlpatterns = [
    path('auth/csrf/', LearnerAuthView.as_view(action='csrf'), name='core-auth-csrf'),
    path('auth/login/', LearnerAuthView.as_view(action='login'), name='core-auth-login'),
    path(
        'auth/registration-orientation/',
        LearnerAuthView.as_view(action='registration_orientation'),
        name='core-auth-registration-orientation',
    ),
    path('auth/register/', LearnerAuthView.as_view(action='register'), name='core-auth-register'),
    path('auth/logout/', LearnerAuthView.as_view(action='logout'), name='core-auth-logout'),
    path('auth/me/', LearnerAuthView.as_view(action='me'), name='core-auth-me'),
    path(
        'auth/deletion-request/',
        LearnerAuthView.as_view(action='deletion_request'),
        name='core-auth-deletion-request',
    ),
    path('transliterate/', TransliterationAPIView.as_view(), name='core-transliterate'),
    path('diagnostics/https/', HttpsProxyDiagnosticAPIView.as_view(), name='core-https-diagnostic'),
]
