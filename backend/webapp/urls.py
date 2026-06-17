from django.urls import path

from .views import (
    alphabet_page,
    home,
    learning_path_page,
    no_ena_detail_page,
    no_ena_list_page,
    unit_detail_page,
    vocabulary_page,
    feedback_page,
    quiz_page,
    android_apk_download,
    sticker_studio_page,
)

urlpatterns = [
    path('', home, name='web-home'),
    path('alphabet/', alphabet_page, name='web-alphabet'),
    path('vocabulaire/', vocabulary_page, name='web-vocabulary'),
    path('parcours/', learning_path_page, name='web-learning-path'),
    path('parcours/<slug:slug>/', unit_detail_page, name='web-unit-detail'),
    path('no-ena/', no_ena_list_page, name='web-no-ena-list'),
    path('no-ena/<slug:slug>/', no_ena_detail_page, name='web-no-ena-detail'),
    path("feedback/", feedback_page, name="web-feedback"),
    path("quiz/", quiz_page, name="web-quiz"),
    path("download/android/", android_apk_download, name="web-download-android"),
    path("sticker-studio/", sticker_studio_page, name="web-sticker-studio"),
]