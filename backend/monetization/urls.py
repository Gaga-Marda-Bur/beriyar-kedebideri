from django.urls import path
from . import views
from .session_views import SessionView

urlpatterns = [
    path('session/csrf/', SessionView.as_view(action='csrf')),
    path('session/login/', SessionView.as_view(action='login')),
    path('session/logout/', SessionView.as_view(action='logout')),
    path('session/', SessionView.as_view()),
    path('public-config/', views.PublicConfig.as_view()),
    path('catalog/', views.Catalog.as_view()),
    path('me/entitlements/', views.Entitlements.as_view()),
    path('me/requests/', views.Requests.as_view()),
    path('me/requests/<uuid:pk>/', views.Requests.as_view()),
    path('me/device-keys/challenge/', views.DeviceChallengeView.as_view()),
    path('me/device-keys/', views.DeviceEnrollView.as_view()),
    path('me/offline-lease/', views.OfflineLeaseView.as_view()),
]
