# BK-REMOTE-PILOT-03 — Phase B1 : Préparation de l'environnement pilote Render

**Statut :** Préparé localement — **Aucun service Render, aucune base PostgreSQL, aucun enregistrement DNS et aucun bucket R2 modifiés ou créés.**

---

## 1. Isolation par rapport au service de production

- Le service de production existant (`beriyar-kedebideri.onrender.com` / `beriyarkedebideri.com`) n'est **pas** modifié.
- La migration `offline_packs/migrations/0002_lessonpack_private_file_alter_lessonpack_status.py` est purement additive (`private_file` nullable + choix `validated` sur `status`) et n'altère aucun pack `published` existant.

---

## 2. Profil cible du futur service pilote Render (Scénario B)

- **Service Web dédié :** Gunicorn (`config.wsgi:application`), scripts `backend/build.sh` et `backend/release.sh` (`migrate`, `createcachetable`, `bootstrap_render`).
- **Base de données dédiée :** PostgreSQL Render isolée (`DATABASE_URL=postgresql://...`, `DATABASE_REQUIRE_SSL=True`).
- **Stockage privé dédié :**
  - Option 1 : Disque persistant Render (`MEDIA_STORAGE_PERSISTENT=True`, `PRIVATE_MEDIA_ROOT` hors `MEDIA_ROOT`/`STATIC_ROOT`).
  - Option 2 : Bucket R2 dédié (`USE_R2=True`, `R2_PUBLIC_BASE_URL`, `R2_BUCKET_NAME` + `R2_PRIVATE_BUCKET_NAME` distinct pour `STORAGES['private']` et `PrivatePackStorage`).
- **Cache partagé multi-workers :**
  - `FEEDBACK_CACHE_BACKEND=django.core.cache.backends.db.DatabaseCache`
  - `FEEDBACK_CACHE_LOCATION=feedback_rate_limit_cache`
  - Utilisé par `FeedbackThrottle` et `LearnerLoginThrottle` (`15/min`).
- **Variables HTTPS / CSRF / Secrets (à saisir uniquement dans Render, jamais dans Git) :**
  - `DJANGO_ENV=staging`
  - `DEBUG=False`
  - `SECRET_KEY=<clé dédiée >= 50 caractères>`
  - `ALLOWED_HOSTS=pilot-api.beriyarkedebideri.com`
  - `CSRF_TRUSTED_ORIGINS=https://pilot-api.beriyarkedebideri.com`
  - `TRUST_X_FORWARDED_PROTO=True`
  - `NUM_PROXIES=<à mesurer via /api/core/diagnostics/https/>`
  - `ADMIN_URL=<chemin d'administration secret dédié>`
- **Sauvegardes & restauration :** suivre `docs/BACKUP_AND_RESTORE.md` (`pg_dump -Fc --no-acl --no-owner` avant migration/import).
