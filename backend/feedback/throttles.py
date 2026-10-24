"""Limites de fréquence des feedbacks (audit A15).

- ``feedback_burst`` / ``feedback_sustained`` : par client (IP derrière le
  proxy de confiance, ou utilisateur authentifié) ;
- ``feedback_device`` : par identifiant d'installation, en complément.

Les comptes staff ne sont pas limités. Les taux sont lus dynamiquement depuis
``REST_FRAMEWORK['DEFAULT_THROTTLE_RATES']`` (variables FEEDBACK_RATE_*).
Ces limites applicatives ne remplacent pas une protection réseau/DDoS.
"""
import hashlib
from rest_framework.settings import api_settings
from rest_framework.throttling import SimpleRateThrottle
from django.core.cache import caches


class _FeedbackThrottle(SimpleRateThrottle):
    def __init__(self):
        self.cache = caches['feedback']
        super().__init__()

    def get_rate(self):
        return api_settings.DEFAULT_THROTTLE_RATES.get(self.scope)

    @staticmethod
    def _is_staff(request):
        user = getattr(request, 'user', None)
        return bool(user and user.is_authenticated and user.is_staff)


class FeedbackClientThrottle(_FeedbackThrottle):
    def get_cache_key(self, request, view):
        if self._is_staff(request):
            return None
        user = getattr(request, 'user', None)
        if user and user.is_authenticated:
            ident = f'user-{user.pk}'
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class FeedbackBurstThrottle(FeedbackClientThrottle):
    scope = 'feedback_burst'


class FeedbackSustainedThrottle(FeedbackClientThrottle):
    scope = 'feedback_sustained'


class FeedbackDeviceThrottle(_FeedbackThrottle):
    scope = 'feedback_device'

    def get_cache_key(self, request, view):
        if self._is_staff(request):
            return None
        data = getattr(request, 'data', None)
        device_id = ''
        if hasattr(data, 'get'):
            raw = data.get('device_id')
            device_id = raw.strip()[:120] if isinstance(raw, str) else ''
        if not device_id:
            return None
        ident = hashlib.sha256(device_id.encode('utf-8', errors='replace')).hexdigest()
        return self.cache_format % {'scope': self.scope, 'ident': ident}


CLIENT_THROTTLES = (FeedbackBurstThrottle, FeedbackSustainedThrottle)
API_THROTTLES = CLIENT_THROTTLES + (FeedbackDeviceThrottle,)


def check_submission_limits(request, view=None):
    checks = [throttle() for throttle in CLIENT_THROTTLES]
    waits = [check.wait() for check in checks if not check.allow_request(request, view)]
    return max((wait for wait in waits if wait is not None), default=None)
