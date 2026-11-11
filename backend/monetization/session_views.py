"""Additive mobile bridge to Django sessions; never issues another identity token."""
import json
from django.contrib.auth import authenticate, login, logout
from django.http import JsonResponse
from django.middleware.csrf import get_token
from django.utils.decorators import method_decorator
from django.views import View
from django.views.decorators.csrf import csrf_protect
from rest_framework.throttling import AnonRateThrottle
from .services import state_for


class LoginThrottle(AnonRateThrottle):
    rate = '15/min'

    def get_cache_key(self, request, view):
        # Apply also when an existing session attempts another login.
        return self.cache_format % {'scope':'commerce_login','ident':self.get_ident(request)}


@method_decorator(csrf_protect, name='dispatch')
class SessionView(View):
    action = 'identity'

    def dispatch(self, request, *args, **kwargs):
        response = super().dispatch(request, *args, **kwargs)
        response['Cache-Control'] = 'private, no-store'
        response['Vary'] = 'Cookie'
        return response

    def get(self, request):
        if self.action == 'csrf':
            return JsonResponse({'csrf_token':get_token(request)})
        if not request.user.is_authenticated or not request.user.is_active:
            return JsonResponse({'detail':'Authentication required'},status=401)
        return JsonResponse({'subject':str(state_for(request.user).subject),'mode':'simulation',
                             'csrf_token':get_token(request)})

    def post(self, request):
        if self.action == 'logout':
            logout(request)
            return JsonResponse({'signed_out':True})
        if self.action != 'login':
            return JsonResponse({'detail':'Method not allowed'},status=405)
        if not LoginThrottle().allow_request(request,self):
            return JsonResponse({'detail':'Retry later'},status=429)
        if len(request.body) > 4096:
            return JsonResponse({'detail':'Invalid credentials'},status=400)
        try:
            body=json.loads(request.body)
            username,password=body['username'],body['password']
            if not isinstance(username,str) or not isinstance(password,str) or len(username)>150 or len(password)>1024:
                raise ValueError
        except (ValueError,TypeError,KeyError):
            return JsonResponse({'detail':'Invalid credentials'},status=400)
        user=authenticate(request,username=username,password=password)
        if user is None or not user.is_active:
            return JsonResponse({'detail':'Invalid credentials'},status=400)
        login(request,user)  # Django rotates the session and CSRF secret.
        return JsonResponse({'subject':str(state_for(user).subject),'mode':'simulation',
                             'csrf_token':get_token(request)})
