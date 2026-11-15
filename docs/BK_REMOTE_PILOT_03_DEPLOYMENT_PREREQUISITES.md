# BK-REMOTE-PILOT-03 — Prérequis pour un futur déploiement autorisé (Phase B)

Aucun de ces éléments n'a été exécuté durant la Phase A. Chaque point nécessite la validation préalable du responsable.

---

## 1. Vérifications manuelles dans Render & Cloudflare (lecture seule avant action)
1. Vérifier dans le tableau de bord Render le plan actif, l'état de facturation et la date d'expiration éventuelle de la base PostgreSQL existante.
2. Vérifier dans Cloudflare le domaine `beriyarkedebideri.com` (enregistrement DNS disponible pour créer `pilot-api.beriyarkedebideri.com`).
3. Vérifier le contenu et les règles d'accès du bucket R2 `beriyar-kedebideri-media` pour confirmer qu'aucun pack non publié n'y est stocké.

## 2. Ressources d'infrastructure à provisionner (après autorisation)
1. **Service Web Render dédié** (ex. `beriyar-pilot-api`, branche `dev` ou branche de release pilote, `autoDeploy` désactivé ou contrôlé).
2. **Base PostgreSQL Render dédiée** (isolée de la production, avec sauvegardes actives).
3. **Sous-domaine HTTPS :** `pilot-api.beriyarkedebideri.com` pointant vers le service pilote Render, certificat TLS actif.
4. **Stockage média pilote isolé :** disque persistant Render (`MEDIA_STORAGE_PERSISTENT=True`) ou bucket R2 privé dédié (`USE_R2=True` + `R2_PRIVATE_BUCKET_NAME` distinct).

## 3. Variables d'environnement cibles (hors Git)
- `DJANGO_ENV=staging`
- `DEBUG=False`
- `SECRET_KEY=<nouvelle clé aléatoire >= 50 caractères>`
- `ALLOWED_HOSTS=pilot-api.beriyarkedebideri.com`
- `CSRF_TRUSTED_ORIGINS=https://pilot-api.beriyarkedebideri.com`
- `DATABASE_URL=<URL PostgreSQL dédiée>`
- `TRUST_X_FORWARDED_PROTO=True`
- `NUM_PROXIES=<mesuré via /api/core/diagnostics/https/>`
- `FEEDBACK_CACHE_BACKEND=django.core.cache.backends.db.DatabaseCache`
- `FEEDBACK_CACHE_LOCATION=feedback_rate_limit_cache`
- `ADMIN_URL=<chemin d'administration secret dédié>`

## 4. Préparation applicative & données avant ouverture aux testeurs
1. Si des `LessonPack` ZIP pilote sont distribués via R2, basculer leur champ/stockage vers le stockage privé authentifié (écart critique #1).
2. Exécuter `build.sh`, `release.sh` (`migrate`, `createcachetable`, `bootstrap_render`) puis `manage.py check --deploy`.
3. Importer/valider uniquement `bk-preprod-erf-01`..`05` en `validated` (conserver `P01..P06` et `V01..V03` en `draft`, ne pas publier).
4. Compiler l'APK pilote signé final avec `--dart-define=API_FLAVOR=staging --dart-define=API_BASE_URL=https://pilot-api.beriyarkedebideri.com/api --dart-define=BK_PILOT=true`.
5. Exécuter la **Phase 6** (tests distants HTTPS sur Samsung SM-A336E sans ADB) avant d'inviter les 5–10 apprenants.
