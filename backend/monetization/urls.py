from django.urls import path
from . import views

urlpatterns = [
    path('public-config/', views.PublicConfig.as_view()),
    path('catalog/', views.Catalog.as_view()),
    path('me/entitlements/', views.Entitlements.as_view()),
    path('me/requests/', views.Requests.as_view()),
    path('me/requests/<uuid:pk>/', views.Requests.as_view()),
    path('me/device-keys/challenge/', views.DeviceChallengeView.as_view()),
    path('me/device-keys/', views.DeviceEnrollView.as_view()),
    path('me/offline-lease/', views.OfflineLeaseView.as_view()),
]
