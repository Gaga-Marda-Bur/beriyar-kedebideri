import os
from pathlib import Path
from urllib.parse import urlsplit

import dj_database_url
from decouple import config
from django.core.exceptions import ImproperlyConfigured

from .security import build_security_settings, build_feedback_rates

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# External simulation signer; no fallback to Django SECRET_KEY or automatic key generation.
MONETIZATION_SIGNING_KEY_FILE = config('MONETIZATION_SIGNING_KEY_FILE', default='')
MONETIZATION_SIGNING_KID = config('MONETIZATION_SIGNING_KID', default='')

# A14 : SECRET_KEY, DEBUG, ALLOWED_HOSTS, CSRF_TRUSTED_ORIGINS, proxy, HTTPS,
# HSTS et cookies sont décidés en un seul endroit (config/security.py). En
# production, un secret manquant ou une valeur dangereuse empêche le démarrage.
_SECURITY = build_security_settings(lambda name: config(name, default=None))
globals().update(_SECURITY)


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
     # Third-party
    'rest_framework',
    'corsheaders',
    'storages',

    # Local apps
    'core',
    'audio_assets',
    'alphabet',
    'vocabulary',
    'learning',
    'lessons',
    'quizzes',
    'offline_packs',
    'progress',
    'feedback',
    'no_ena',
    'webapp',
    'monetization',
]

MIDDLEWARE = [
    'core.media_access.PublicMediaGuard',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    "whitenoise.middleware.WhiteNoiseMiddleware",
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'webapp.context_processors.public_links',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'


# Database
# https://docs.djangoproject.com/en/6.0/ref/settings/#databases

_database_url = config('DATABASE_URL', default=None)
if IS_DEPLOYED and not _database_url:
    raise ImproperlyConfigured('DATABASE_URL explicite requis en staging/production.')
if IS_DEPLOYED and not _database_url.startswith(('postgres://', 'postgresql://')):
    raise ImproperlyConfigured('Une base PostgreSQL dédiée est requise en staging/production.')
_database_ssl = config('DATABASE_REQUIRE_SSL', default=IS_DEPLOYED, cast=bool)
if IS_DEPLOYED and not _database_ssl and config('DATABASE_NETWORK', default='') != 'private':
    raise ImproperlyConfigured('TLS base obligatoire hors réseau privé explicitement déclaré.')
DATABASES = {
    "default": dj_database_url.config(
        default=_database_url or f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
        ssl_require=_database_ssl,
    )
}


# Password validation
# https://docs.djangoproject.com/en/6.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/6.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/6.0/howto/static-files/


STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

STATICFILES_DIRS = [
    BASE_DIR / "static",
]

USE_R2 = config("USE_R2", default=False, cast=bool)
if IS_DEPLOYED and not USE_R2 and not config('MEDIA_STORAGE_PERSISTENT',default=False,cast=bool):
    raise ImproperlyConfigured('Déclarer un stockage média persistant ou configurer R2 en staging/production.')

if USE_R2:
    AWS_ACCESS_KEY_ID = config("R2_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY = config("R2_SECRET_ACCESS_KEY")
    AWS_STORAGE_BUCKET_NAME = config("R2_BUCKET_NAME")
    AWS_S3_ENDPOINT_URL = config("R2_ENDPOINT_URL")
    AWS_S3_REGION_NAME = "auto"
    AWS_S3_SIGNATURE_VERSION = "s3v4"

    AWS_S3_FILE_OVERWRITE = False
    AWS_DEFAULT_ACL = None
    AWS_QUERYSTRING_AUTH = False

    AWS_S3_OBJECT_PARAMETERS = {
        "CacheControl": "max-age=86400",
    }

    R2_PUBLIC_BASE_URL = config("R2_PUBLIC_BASE_URL")
    for _origin in (R2_PUBLIC_BASE_URL,AWS_S3_ENDPOINT_URL):
        _parsed = urlsplit(_origin)
        if (_parsed.scheme != 'https' or not _parsed.hostname or _parsed.username
                or _parsed.password or _parsed.path not in ('','/') or _parsed.query or _parsed.fragment):
            raise ImproperlyConfigured('Les origines R2 doivent être HTTPS, sans chemin ni identifiants.')
    R2_PUBLIC_DOMAIN = R2_PUBLIC_BASE_URL.replace("https://", "").replace("http://", "").rstrip("/")

    AWS_S3_CUSTOM_DOMAIN = R2_PUBLIC_DOMAIN
    AWS_S3_URL_PROTOCOL = "https:"

    MEDIA_URL = f"https://{R2_PUBLIC_DOMAIN}/media/"

    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3boto3.S3Boto3Storage",
            "OPTIONS": {
                "location": "media",
                "custom_domain": R2_PUBLIC_DOMAIN,
                "url_protocol": "https:",
            },
        },
        "staticfiles": {
            "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
        },
    }
else:
    MEDIA_URL = "/media/"
    MEDIA_ROOT = BASE_DIR / "media"

    STORAGES = {
        "default": {
            "BACKEND": "django.core.files.storage.FileSystemStorage",
        },
        "staticfiles": {
            "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
        },
    }



# Origines CORS validées dans config/security.py, sans wildcard en recette/prod.

REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 50,
    # A15 : identification du client derrière le proxy (voir config/security.py).
    'NUM_PROXIES': NUM_PROXIES,
    # A15 : limites appliquées uniquement aux vues qui déclarent ces portées.
    'DEFAULT_THROTTLE_RATES': build_feedback_rates(lambda name: config(name, default=None)),
}

# A15 : cache utilisé par les limites de fréquence. Par défaut, mémoire locale
# (par processus). Une limite applicative ne remplace pas une protection
# réseau/DDoS en périphérie (Render, Cloudflare).
CACHES = {

    'feedback': {
        'BACKEND': config('FEEDBACK_CACHE_BACKEND', default='django.core.cache.backends.locmem.LocMemCache'),
        'LOCATION': config('FEEDBACK_CACHE_LOCATION', default='beriya-feedback'),
    },
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'beriya-default',
    }
}

if IS_DEPLOYED and CACHES['feedback']['BACKEND'] not in (
    'django.core.cache.backends.db.DatabaseCache',
    'django.core.cache.backends.redis.RedisCache',
):
    raise ImproperlyConfigured('Configurer un cache feedback partagé en staging/production.')

# Physical separation from public MEDIA_ROOT. No public URL for this storage.
PRIVATE_MEDIA_ROOT = Path(config('PRIVATE_MEDIA_ROOT', default=str(BASE_DIR / 'private_media')))
if (PRIVATE_MEDIA_ROOT.resolve().is_relative_to((BASE_DIR / 'media').resolve())
        or PRIVATE_MEDIA_ROOT.resolve().is_relative_to(STATIC_ROOT.resolve())):
    raise ImproperlyConfigured('PRIVATE_MEDIA_ROOT doit rester hors des racines publiques.')
if USE_R2:
    _private_bucket = config('R2_PRIVATE_BUCKET_NAME', default='').strip()
    _private_access_key = config('R2_PRIVATE_ACCESS_KEY_ID', default='').strip()
    _private_secret_key = config('R2_PRIVATE_SECRET_ACCESS_KEY', default='').strip()
    if (_private_bucket and _private_bucket == AWS_STORAGE_BUCKET_NAME) or (IS_DEPLOYED and not _private_bucket):
        raise ImproperlyConfigured('Un bucket privé distinct est requis pour les pièces jointes feedback.')
    if (_private_bucket or IS_DEPLOYED) and (not _private_access_key or not _private_secret_key):
        raise ImproperlyConfigured(
            'Des identifiants S3 privés distincts (R2_PRIVATE_ACCESS_KEY_ID et R2_PRIVATE_SECRET_ACCESS_KEY) sont requis.'
        )
    if _private_bucket and (
        _private_access_key == AWS_ACCESS_KEY_ID or _private_secret_key == AWS_SECRET_ACCESS_KEY
    ):
        raise ImproperlyConfigured(
            'Les identifiants du stockage privé R2 doivent être distincts des identifiants publics.'
        )
    STORAGES['private'] = {
        'BACKEND': 'storages.backends.s3boto3.S3Boto3Storage',
        'OPTIONS': {
            'bucket_name': _private_bucket,
            'access_key': _private_access_key,
            'secret_key': _private_secret_key,
            'endpoint_url': AWS_S3_ENDPOINT_URL,
            'region_name': AWS_S3_REGION_NAME,
            'signature_version': AWS_S3_SIGNATURE_VERSION,
            'custom_domain': None,
            'querystring_auth': True,
            'default_acl': None,
            'object_parameters': {'CacheControl': 'private, no-store'},
            'location': 'private',
        },
    } if _private_bucket else {
        'BACKEND': 'django.core.files.storage.FileSystemStorage',
        'OPTIONS': {'location': PRIVATE_MEDIA_ROOT},
    }
else:
    STORAGES['private'] = {
        'BACKEND': 'django.core.files.storage.FileSystemStorage',
        'OPTIONS': {'location':PRIVATE_MEDIA_ROOT},
    }

ANDROID_APK_URL = config(
    "ANDROID_APK_URL",
    default="https://media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.apk",
)
ANDROID_APK_RELEASE_URL = config("ANDROID_APK_RELEASE_URL", default="")

# Réglages HTTPS / HSTS / cookies : voir config/security.py (bloc unique A14).

ADMIN_URL = config("ADMIN_URL", default="admin-bk-secure-2026-panel/")
