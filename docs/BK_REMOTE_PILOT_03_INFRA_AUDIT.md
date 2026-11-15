# BK-REMOTE-PILOT-03 — Audit de l'infrastructure existante

**Branche auditée :** `dev` (commit `c1df76b`)  
**Périmètre :** Lecture seule (dépôt local, résolution DNS publique, en-têtes HTTP/TLS publics). Aucune modification distante ni aucun déploiement.

---

## 1. Inventaire du dépôt local

| Élément contrôlé | Source de preuve | État | Détail observé |
|---|---|---|---|
| Réglages Django & sécurité | `backend/config/settings.py`, `backend/config/security.py` | **Confirmé** | `build_security_settings()` impose `DEBUG=False`, `SECRET_KEY` (>= 50 car.), `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS` (`https://`), `SECURE_SSL_REDIRECT=True`, `SESSION_COOKIE_SECURE=True`, `CSRF_COOKIE_SECURE=True`, `DATABASE_URL` PostgreSQL SSL, `FEEDBACK_CACHE_BACKEND` partagé (`DatabaseCache`/`RedisCache`), et stockage média persistant ou R2. |
| Build & Release | `backend/build.sh`, `backend/release.sh`, `backend/requirements.txt` | **Confirmé** | `gunicorn==26.0.0`, `whitenoise==6.12.0`, `django-storages==1.14.6`, `boto3==1.43.29`, `psycopg2-binary==2.9.12`. `build.sh` sépare `pip install`/`collectstatic` ; `release.sh` exécute `migrate`, `createcachetable`, `bootstrap_render`. Aucun `render.yaml` dans le dépôt. |
| Auth & Throttling | `backend/core/auth_views.py`, `backend/core/urls.py` | **Confirmé** | Endpoints `/api/core/auth/{csrf,login,logout,me}/` sous `csrf_protect` + `LearnerLoginThrottle` (`15/min`) sur `caches['feedback']`. |
| Permissions pilote | `backend/core/permissions.py` | **Confirmé** | `PILOT_GROUP_NAME = 'pilot_erfe_v1'`, limité explicitement à `bk-preprod-erf-01`..`05`. |
| Packs hors ligne | `backend/offline_packs/models.py`, `views.py`, `serializers.py` | **Confirmé** | Filtrage strict par `PILOT_ALLOWED_UNIT_SLUGS` dans les vues, mais `LessonPack.file` utilise `STORAGES['default']` (public si `USE_R2=True`). |
| Client mobile & Android | `mobile/lib/core/api/api_config.dart`, `mobile/lib/core/auth/learner_auth_service.dart`, `mobile/android/app/build.gradle.kts`, `AndroidManifest.xml` | **Confirmé** | Appels `/core/auth/*` alignés sur Django ; variante `BK_PILOT=true` -> `com.afrigama.beriyarkedebideri.pilot`, `Beřiyar Pilote`, `android:allowBackup="false"`, garde-fous A13 actifs en `release`. |

---

## 2. Inventaire Render, DNS et Cloudflare (probes publiques en lecture seule)

| Élément contrôlé | Source de preuve | État | Détail observé |
|---|---|---|---|
| `beriyar-kedebideri.onrender.com` | DNS + `curl.exe -sI https://beriyar-kedebideri.onrender.com/` | **Confirmé** | CNAME `gcp-us-west1-1.origin.onrender.com` -> `216.24.57.16` / `.18` (Cloudflare). Répond `HTTP/1.1 200 OK`, `x-render-origin-server: gunicorn`, `Set-Cookie: sessionid=...; HttpOnly; SameSite=Lax; Secure`. Service **actif** (non suspendu lors de ce contrôle). |
| `beriyarkedebideri.com` & `www` | DNS + `curl.exe -sI https://beriyarkedebideri.com/` | **Confirmé** | A `216.24.57.16` / `.18` (www CNAME vers Render). Répond `HTTP/1.1 200 OK` avec les mêmes en-têtes Render/Gunicorn/Cloudflare. |
| `media.beriyarkedebideri.com` | DNS + `curl.exe -sI https://media.beriyarkedebideri.com/` | **Confirmé** | A/AAAA Cloudflare (`104.21.76.238`, `172.67.202.24`), `HTTP/1.1 404 Not Found` à la racine (domaine R2 actif). |
| `pilot-api.beriyarkedebideri.com`, `staging-api.beriyarkedebideri.com`, `api.beriyarkedebideri.com` | DNS (`Resolve-DnsName`) | **Confirmé (absents)** | Aucun enregistrement DNS actif (`NXDOMAIN` / refusé). |
| Tableau de bord Render (plan, région exacte, commit déployé, expiration PostgreSQL, sauvegardes, auto-deploy, coûts) | Tableau de bord Render / Cloudflare | **Non confirmé** | Accès authentifié au tableau de bord Render et Cloudflare non disponible depuis cet environnement. Les causes d'une éventuelle suspension passée ne peuvent pas être confirmées sans accès aux journaux/facturation Render. |
