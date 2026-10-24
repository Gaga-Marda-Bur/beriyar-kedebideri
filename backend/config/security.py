"""Réglages de sécurité dépendant de l'environnement (audit A14).

Toute la logique est concentrée dans :func:`build_security_settings`, une
fonction pure (aucun accès réseau, aucune écriture) alimentée par un lecteur de
variables d'environnement. Elle est appelée une seule fois par ``settings.py``
et testée directement avec des environnements simulés.

Principes :
- en production, le démarrage échoue si un secret requis manque ou si une
  valeur dangereuse est fournie (``ImproperlyConfigured``) ;
- un seul bloc décide HTTPS / HSTS / cookies ; plus de réglages écrasés ;
- aucune valeur secrète n'est générée, remplacée ou journalisée ici.
"""
from __future__ import annotations

from typing import Callable, Optional
from urllib.parse import urlsplit
import re

from django.core.exceptions import ImproperlyConfigured

# Clé historiquement présente dans le dépôt : publique, donc jamais acceptable
# en production. Conservée uniquement comme valeur de développement local.
INSECURE_DEV_SECRET_KEY = (
    "django-insecure-7m-!!_i5=!jsz09nusf)cmuosf_upsu%*-jh(!v#*=!kt)be3b"
)

ENVIRONMENTS = ("development", "test", "production")

PRODUCTION_DEFAULT_HOSTS = ["beriyarkedebideri.com", "www.beriyarkedebideri.com"]
DEVELOPMENT_DEFAULT_HOSTS = PRODUCTION_DEFAULT_HOSTS + [
    "127.0.0.1",
    "localhost",
    "10.0.2.2",
    "0.0.0.0",
]
LOCAL_HOSTS = {"127.0.0.1", "localhost", "10.0.2.2", "0.0.0.0", "::1", "[::1]"}

TRUE_VALUES = {"1", "true", "yes", "on"}
FALSE_VALUES = {"0", "false", "no", "off", ""}

EnvGetter = Callable[[str], Optional[str]]


def build_feedback_rates(get: EnvGetter) -> dict:
    result = {}
    for scope, variable, default in (
        ('feedback_burst', 'FEEDBACK_RATE_BURST', '5/min'),
        ('feedback_sustained', 'FEEDBACK_RATE_SUSTAINED', '30/hour'),
        ('feedback_device', 'FEEDBACK_RATE_DEVICE', '20/hour'),
    ):
        rate = get(variable) if get(variable) is not None else default
        if not re.fullmatch(r'[1-9]\d*/(?:second|sec|s|minute|min|m|hour|h|day|d)', rate):
            raise ImproperlyConfigured(f'{variable} doit contenir une limite positive, par exemple 5/min.')
        result[scope] = rate
    return result


def _bool(get: EnvGetter, name: str, default: bool) -> bool:
    raw = get(name)
    if raw is None:
        return default
    value = raw.strip().lower()
    if value in TRUE_VALUES:
        return True
    if value in FALSE_VALUES:
        return False
    raise ImproperlyConfigured(f"{name} doit être un booléen (reçu : {raw!r}).")


def _int(get: EnvGetter, name: str, default: int, minimum: int = 0) -> int:
    raw = get(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise ImproperlyConfigured(f"{name} doit être un entier (reçu : {raw!r}).") from exc
    if value < minimum:
        raise ImproperlyConfigured(f"{name} doit être >= {minimum}.")
    return value


def _csv(get: EnvGetter, name: str) -> Optional[list]:
    raw = get(name)
    if raw is None:
        return None
    return [item.strip() for item in raw.split(",") if item.strip()]


def resolve_environment(get: EnvGetter) -> str:
    explicit = (get("DJANGO_ENV") or "").strip().lower()
    if explicit:
        if explicit not in ENVIRONMENTS:
            raise ImproperlyConfigured(
                f"DJANGO_ENV={explicit!r} inconnu ({', '.join(ENVIRONMENTS)})."
            )
        return explicit
    # Render définit RENDER=true sur ses services : par sécurité, un service
    # Render sans DJANGO_ENV est traité comme production (échec fermé).
    if _bool(get, "RENDER", False):
        return "production"
    if get("DEBUG") is not None and not _bool(get, "DEBUG", True):
        return "production"
    return "development"


def _validate_secret_key(secret: Optional[str]) -> str:
    if not secret or not secret.strip():
        raise ImproperlyConfigured(
            "SECRET_KEY est obligatoire en production. Définissez la valeur "
            "actuelle dans l'environnement de l'hébergeur ; aucune clé n'est "
            "générée automatiquement (une rotation doit être planifiée)."
        )
    if secret.strip() == INSECURE_DEV_SECRET_KEY or secret.strip().startswith("django-insecure"):
        raise ImproperlyConfigured(
            "SECRET_KEY de développement (publique) refusée en production."
        )
    if len(secret) < 50 or len(set(secret)) < 5:
        raise ImproperlyConfigured(
            "SECRET_KEY trop faible pour la production (>= 50 caractères variés)."
        )
    return secret


def build_security_settings(get: EnvGetter) -> dict:
    environment = resolve_environment(get)
    production = environment == "production"

    debug = _bool(get, "DEBUG", default=not production)
    if production and debug:
        raise ImproperlyConfigured("DEBUG=True est interdit en production.")

    if production:
        secret_key = _validate_secret_key(get("SECRET_KEY"))
    else:
        secret_key = get("SECRET_KEY") or INSECURE_DEV_SECRET_KEY

    # --- Hôtes ---------------------------------------------------------------
    hosts = _csv(get, "ALLOWED_HOSTS")
    if hosts is None:
        hosts = list(PRODUCTION_DEFAULT_HOSTS if production else DEVELOPMENT_DEFAULT_HOSTS)
    render_host = (get("RENDER_EXTERNAL_HOSTNAME") or "").strip()
    if render_host and render_host not in hosts:
        hosts.append(render_host)
    if production:
        if not hosts:
            raise ImproperlyConfigured("ALLOWED_HOSTS ne peut pas être vide en production.")
        if "*" in hosts:
            raise ImproperlyConfigured("ALLOWED_HOSTS='*' est interdit en production.")
        # Les hôtes locaux sont inutiles derrière le proxy et retirés sans erreur.
        hosts = [host for host in hosts if host not in LOCAL_HOSTS]
        if not hosts:
            raise ImproperlyConfigured("ALLOWED_HOSTS ne contient aucun hôte de production.")

    csrf_origins = _csv(get, "CSRF_TRUSTED_ORIGINS")
    if csrf_origins is None:
        csrf_origins = [f"https://{host}" for host in PRODUCTION_DEFAULT_HOSTS]
    # Django exige un schéma ; une entrée sans schéma lèverait une erreur de
    # vérification. En production, seules les origines HTTPS sont conservées.
    for origin in csrf_origins:
        try:
            parsed = urlsplit(origin)
            parsed.port
        except ValueError as error:
            raise ImproperlyConfigured('CSRF_TRUSTED_ORIGINS contient une origine invalide.') from error
        if (parsed.scheme not in (('https',) if production else ('https', 'http'))
                or not parsed.hostname or parsed.username or parsed.password
                or parsed.path or parsed.query or parsed.fragment):
            raise ImproperlyConfigured("CSRF_TRUSTED_ORIGINS contient une origine invalide.")

    # --- Proxy / HTTPS -------------------------------------------------------
    # Ne faire confiance à X-Forwarded-Proto que derrière un proxy qui écrase
    # cet en-tête (cas de Render). Vérifiable via /api/core/diagnostics/https/.
    trust_proxy = _bool(get, "TRUST_X_FORWARDED_PROTO", default=False)
    https = production
    ssl_redirect = _bool(get, "SECURE_SSL_REDIRECT", default=production)
    if production and not ssl_redirect:
        raise ImproperlyConfigured("SECURE_SSL_REDIRECT doit rester actif en production.")
    if production and _bool(get, "RENDER", False) and not trust_proxy:
        raise ImproperlyConfigured(
            "Vérifiez le proxy TLS Render puis configurez explicitement "
            "TRUST_X_FORWARDED_PROTO=True avant déploiement."
        )

    hsts_seconds = _int(
        get, "SECURE_HSTS_SECONDS", default=300 if production else 0
    )
    hsts_subdomains = _bool(get, "SECURE_HSTS_INCLUDE_SUBDOMAINS", default=False)
    # Le préchargement HSTS est difficilement réversible : décision explicite.
    hsts_preload = _bool(get, "SECURE_HSTS_PRELOAD", default=False)
    if hsts_preload and (hsts_seconds < 31536000 or not hsts_subdomains):
        raise ImproperlyConfigured(
            "SECURE_HSTS_PRELOAD exige SECURE_HSTS_SECONDS >= 31536000 et "
            "SECURE_HSTS_INCLUDE_SUBDOMAINS=True."
        )
    if not production:
        hsts_seconds, hsts_subdomains, hsts_preload = 0, False, False

    # Nombre de proxys de confiance devant l'application, pour l'identification
    # du client par les limites de fréquence (X-Forwarded-For). Ne pas deviner
    # ce nombre : il dépend aussi d'un éventuel CDN devant l'hébergeur.
    num_proxies_raw = get("NUM_PROXIES")
    if num_proxies_raw is None or num_proxies_raw.strip() == "":
        num_proxies = 0
    else:
        num_proxies = _int(get, "NUM_PROXIES", default=0)
    if production and trust_proxy and num_proxies == 0:
        raise ImproperlyConfigured(
            'Après vérification du proxy, NUM_PROXIES doit être explicitement configuré '
            'pour identifier les clients des limites de fréquence.'
        )

    return {
        "DJANGO_ENV": environment,
        "IS_PRODUCTION": production,
        "DEBUG": debug,
        "SECRET_KEY": secret_key,
        "ALLOWED_HOSTS": hosts,
        "CSRF_TRUSTED_ORIGINS": csrf_origins,
        "SECURE_PROXY_SSL_HEADER": ("HTTP_X_FORWARDED_PROTO", "https") if trust_proxy else None,
        "SECURE_SSL_REDIRECT": ssl_redirect,
        "SECURE_HSTS_SECONDS": hsts_seconds,
        "SECURE_HSTS_INCLUDE_SUBDOMAINS": hsts_subdomains,
        "SECURE_HSTS_PRELOAD": hsts_preload,
        "SESSION_COOKIE_SECURE": https,
        "CSRF_COOKIE_SECURE": https,
        "SESSION_COOKIE_HTTPONLY": True,
        "CSRF_COOKIE_HTTPONLY": False,
        "SESSION_COOKIE_SAMESITE": "Lax",
        "CSRF_COOKIE_SAMESITE": "Lax",
        "SECURE_CONTENT_TYPE_NOSNIFF": True,
        "SECURE_REFERRER_POLICY": "same-origin",
        "SECURE_CROSS_ORIGIN_OPENER_POLICY": "same-origin",
        "X_FRAME_OPTIONS": "DENY",
        "NUM_PROXIES": num_proxies,
    }
