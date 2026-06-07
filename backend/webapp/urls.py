from django.http import HttpResponse
from django.urls import path


def home(request):
    return HttpResponse("Beřiyar Kedebideři — backend clean is running.")


urlpatterns = [
    path('', home, name='web-home'),
]