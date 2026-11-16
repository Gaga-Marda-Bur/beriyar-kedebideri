import json

from django.contrib.auth import authenticate, get_user_model, login, logout
from django.contrib.auth.password_validation import validate_password
from django.core.cache import caches
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.http import JsonResponse
from django.middleware.csrf import get_token
from django.utils.decorators import method_decorator
from django.views import View
from django.views.decorators.csrf import csrf_protect
import re
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


class LearnerRegisterThrottle(AnonRateThrottle):
    rate = '5/min'

    def __init__(self):
        super().__init__()
        self.cache = caches['feedback']

    def get_cache_key(self, request, view):
        return self.cache_format % {
            'scope': 'learner_register',
            'ident': self.get_ident(request),
        }


_USERNAME_RE = re.compile(r'^[A-Za-z0-9_.@-]{3,150}$')


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

        if self.action == 'register':
            return self._handle_register(request)

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

    def _handle_register(self, request):
        if not LearnerRegisterThrottle().allow_request(request, self):
            return JsonResponse({'detail': 'Retry later'}, status=429)

        if len(request.body) > 4096:
            return JsonResponse({'detail': 'Invalid registration payload'}, status=400)

        try:
            body = json.loads(request.body)
            username = body['username']
            password = body['password']
            password_confirm = body.get('password_confirm', password)
            email = body.get('email', '')
            if not isinstance(username, str) or not isinstance(password, str) or not isinstance(email, str):
                raise ValueError
            username = username.strip()
            email = email.strip()
        except (ValueError, TypeError, KeyError):
            return JsonResponse({'detail': 'Invalid registration payload'}, status=400)

        if not _USERNAME_RE.fullmatch(username):
            return JsonResponse(
                {'detail': 'Identifiant invalide (3 à 150 caractères : lettres, chiffres, _, ., @, -).'},
                status=400,
            )

        if email:
            try:
                validate_email(email)
            except ValidationError:
                return JsonResponse({'detail': 'Adresse e-mail invalide.'}, status=400)

        if password != password_confirm:
            return JsonResponse({'detail': 'Les mots de passe ne correspondent pas.'}, status=400)

        if len(password) > 1024:
            return JsonResponse({'detail': 'Mot de passe trop long.'}, status=400)

        User = get_user_model()
        if User.objects.filter(username__iexact=username).exists():
            return JsonResponse({'detail': 'Cet identifiant est déjà utilisé.'}, status=409)
        if email and User.objects.filter(email__iexact=email).exists():
            return JsonResponse({'detail': 'Cette adresse e-mail est déjà utilisée.'}, status=409)

        candidate = User(username=username, email=email)
        try:
            validate_password(password, candidate)
        except ValidationError as exc:
            return JsonResponse({'detail': ' '.join(exc.messages)}, status=400)

        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            is_staff=False,
            is_superuser=False,
        )
        login(request, user)
        if hasattr(request, '_bk_is_pilot_user'):
            delattr(request, '_bk_is_pilot_user')
        return JsonResponse(_user_payload(request, user), status=201)
