import os
from pathlib import Path

import dj_database_url
from decouple import config, Csv

from .security import build_security_settings, build_feedback_rates

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

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
]

MIDDLEWARE = [
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

DATABASES = {
    "default": dj_database_url.config(
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
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



CORS_ALLOWED_ORIGINS = config(
    "CORS_ALLOWED_ORIGINS",
    default="",
    cast=Csv(),
)

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

ANDROID_APK_URL = config(
    "ANDROID_APK_URL",
    default="https://media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.apk",
)

# Réglages HTTPS / HSTS / cookies : voir config/security.py (bloc unique A14).

ADMIN_URL = config("ADMIN_URL", default="admin-bk-secure-2026-panel/")
