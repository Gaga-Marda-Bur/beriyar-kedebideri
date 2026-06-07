from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path('admin/', admin.site.urls),

    # Web frontend responsive
    path('', include('webapp.urls')),

    # API
    path('api/audio/', include('audio_assets.urls')),
    path('api/alphabet/', include('alphabet.urls')),
    path('api/vocabulary/', include('vocabulary.urls')),
    path('api/learning/', include('learning.urls')),
    path('api/lessons/', include('lessons.urls')),
    path('api/quizzes/', include('quizzes.urls')),
    path('api/offline-packs/', include('offline_packs.urls')),
    path('api/progress/', include('progress.urls')),
    path('api/feedback/', include('feedback.urls')),
    path('api/no-ena/', include('no_ena.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)