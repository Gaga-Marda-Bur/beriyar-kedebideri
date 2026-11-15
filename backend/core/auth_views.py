import json

from django.contrib.auth import authenticate, login, logout
from django.core.cache import caches
from django.http import JsonResponse
from django.middleware.csrf import get_token
from django.utils.decorators import method_decorator
from django.views import View
from django.views.decorators.csrf import csrf_protect
from rest_framework.throttling import AnonRateThrottle

from .permissions import is_pilot_user, is_staff_preview


class LearnerLoginThrottle(AnonRateThrottle):
    rate = '15/min'

    def __init__(self):
        super().__init__()
        self.cache = caches['feedback']

    def get_cache_key(self, request, view):
        return self.cache_format % {
            'scope': 'learner_login',
            'ident': self.get_ident(request),
        }


def _user_payload(request, user):
    return {
        'authenticated': True,
        'user_id': user.pk,
        'username': user.get_username(),
        'is_pilot': is_pilot_user(request),
        'is_staff': is_staff_preview(request),
        'csrf_token': get_token(request),
    }


@method_decorator(csrf_protect, name='dispatch')
class LearnerAuthView(View):
    """
    Authentification apprenant par session Django + CSRF (sans secret parallèle).
    """

    action = 'me'

    def dispatch(self, request, *args, **kwargs):
        response = super().dispatch(request, *args, **kwargs)
        response['Cache-Control'] = 'private, no-store'
        response['Vary'] = 'Cookie'
        return response

    def get(self, request):
        if self.action == 'csrf':
            return JsonResponse({'csrf_token': get_token(request)})

        if self.action != 'me':
            return JsonResponse({'detail': 'Method not allowed'}, status=405)

        if not request.user.is_authenticated or not request.user.is_active:
            return JsonResponse({'detail': 'Authentication required'}, status=401)

        return JsonResponse(_user_payload(request, request.user))

    def post(self, request):
        if self.action == 'logout':
            logout(request)
            return JsonResponse({'signed_out': True})

        if self.action != 'login':
            return JsonResponse({'detail': 'Method not allowed'}, status=405)

        if not LearnerLoginThrottle().allow_request(request, self):
            return JsonResponse({'detail': 'Retry later'}, status=429)

        if len(request.body) > 4096:
            return JsonResponse({'detail': 'Invalid credentials'}, status=400)

        try:
            body = json.loads(request.body)
            username = body['username']
            password = body['password']
            if (
                not isinstance(username, str)
                or not isinstance(password, str)
                or not username.strip()
                or len(username) > 150
                or len(password) > 1024
            ):
                raise ValueError
        except (ValueError, TypeError, KeyError):
            return JsonResponse({'detail': 'Invalid credentials'}, status=400)

        user = authenticate(request, username=username.strip(), password=password)
        if user is None or not user.is_active:
            return JsonResponse({'detail': 'Invalid credentials'}, status=401)

        login(request, user)
        if hasattr(request, '_bk_is_pilot_user'):
            delattr(request, '_bk_is_pilot_user')
        return JsonResponse(_user_payload(request, user))
