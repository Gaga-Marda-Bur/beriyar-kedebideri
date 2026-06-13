from django.conf import settings


def public_links(request):
    return {
        "ANDROID_APK_URL": getattr(settings, "ANDROID_APK_URL", "/download/android/"),
    }