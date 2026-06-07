from django.urls import path

from .views import (
    NoEnaPublicationDetailAPIView,
    NoEnaPublicationListAPIView,
    NoEnaPublicationViewAPIView,
)

urlpatterns = [
    path('publications/', NoEnaPublicationListAPIView.as_view(), name='no-ena-publication-list'),
    path('publications/<slug:slug>/', NoEnaPublicationDetailAPIView.as_view(), name='no-ena-publication-detail'),
    path('publications/<slug:slug>/view/', NoEnaPublicationViewAPIView.as_view(), name='no-ena-publication-view'),
]