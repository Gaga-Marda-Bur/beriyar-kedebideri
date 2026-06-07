from django.urls import path

from .views import CharacterDetailAPIView, CharacterListAPIView

urlpatterns = [
    path('characters/', CharacterListAPIView.as_view(), name='character-list'),
    path('characters/<int:pk>/', CharacterDetailAPIView.as_view(), name='character-detail'),
]