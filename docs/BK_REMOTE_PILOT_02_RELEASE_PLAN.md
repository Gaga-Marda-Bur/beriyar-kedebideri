# BK-REMOTE-PILOT-02 — Plan de mise en ligne du pilote privé distant (Alphabet Erfe V1)

**Branche de référence :** `dev`  
**Statut :** Préparé et vérifié localement — **Aucun déploiement exécuté** (en attente de validation du responsable)

---

## 1. État initial constaté lors de l'audit

- **Backend Django (`backend/config/settings.py`, `backend/config/security.py`) :**
  - Architecture de sécurité stricte pilotée par `DJANGO_ENV` (`staging` ou `production`), `build_security_settings()`, `build.sh` (`pip install`, `collectstatic`), et `release.sh` (`migrate`, `createcachetable`, `bootstrap_render`).
  - Exige en `staging`/`production` : `DEBUG=False`, `SECRET_KEY` (>= 50 caractères variés, non `django-insecure`), `ALLOWED_HOSTS` explicite, `CSRF_TRUSTED_ORIGINS` en `https://`, `SECURE_SSL_REDIRECT=True`, `DATABASE_URL` PostgreSQL dédiée avec SSL (`DATABASE_REQUIRE_SSL=True` hors réseau privé), `FEEDBACK_CACHE_BACKEND` partagé (`DatabaseCache` ou `RedisCache`), et stockage média persistant (`MEDIA_STORAGE_PERSISTENT=True` ou Cloudflare R2).
  - `LearnerLoginThrottle` mis à jour dans `backend/core/auth_views.py` pour utiliser `caches['feedback']` (cache partagé multi-workers).
- **Hébergement / Domaine / Base :**
  - Aucun serveur pilote distant n'est encore provisionné ni vérifié en ligne depuis ce poste ; les URL par défaut dans `ApiConfig` sont `https://staging-api.beriyarkedebideri.com/api` et `https://api.beriyarkedebideri.com/api`.
- **Application Android (`mobile/android/app/build.gradle.kts`, `AndroidManifest.xml`) :**
  - Garde-fous A13 actifs en `release` (`API_FLAVOR=staging|production`, `API_BASE_URL` HTTPS public, `key.properties` présent et valide).
  - Variante pilote ajoutée via `--dart-define=BK_PILOT=true` : `applicationIdSuffix = ".pilot"` (`com.afrigama.beriyarkedebideri.pilot`), `versionNameSuffix = "-pilot"`, libellé `Beřiyar Pilote`, et `android:allowBackup="false"` dans `AndroidManifest.xml`.

---

## 2. Décisions d'infrastructure requises avant déploiement

1. **Choix du service d'hébergement pilote** (ex. service Render dédié `staging`/`pilot`, isolé de la production).
2. **Nom de domaine HTTPS dédié au pilote** (ex. `pilot-api.beriyarkedebideri.com` ou `staging-api.beriyarkedebideri.com`) avec certificat TLS valide.
3. **Base de données PostgreSQL isolée** dédiée au pilote (aucun partage avec une base de production).
4. **Stockage média persistant** : soit disque persistant (`MEDIA_STORAGE_PERSISTENT=True`), soit bucket Cloudflare R2 dédié + bucket privé distinct (`R2_PRIVATE_BUCKET_NAME`) pour les pièces jointes feedback.
5. **Vérification du proxy TLS** : confirmer le nombre exact de proxys (`NUM_PROXIES=1` sur Render direct, `2` si Cloudflare devant Render) et `TRUST_X_FORWARDED_PROTO=True`.
6. **Politique de rétention et sauvegarde** : activer les sauvegardes automatiques PostgreSQL chez l'hébergeur et valider la procédure de restauration (`docs/BACKUP_AND_RESTORE.md`).

---

## 3. Procédure de déploiement du serveur pilote (après autorisation)

1. Provisionner la base PostgreSQL isolée et le service Web (Gunicorn/WSGI) sur la branche validée.
2. Configurer les variables d'environnement secrètes dans le panneau de l'hébergeur (jamais dans Git) :
   - `DJANGO_ENV=staging`
   - `SECRET_KEY=<clé aléatoire >= 50 caractères>`
   - `ALLOWED_HOSTS=<domaine-pilote>`
   - `CSRF_TRUSTED_ORIGINS=https://<domaine-pilote>`
   - `DATABASE_URL=postgresql://...`
   - `TRUST_X_FORWARDED_PROTO=True`
   - `NUM_PROXIES=<nombre vérifié>`
   - `FEEDBACK_CACHE_BACKEND=django.core.cache.backends.db.DatabaseCache`
   - `FEEDBACK_CACHE_LOCATION=feedback_rate_limit_cache`
   - `MEDIA_STORAGE_PERSISTENT=True` (ou variables `USE_R2=True` + R2 public/privé)
3. Exécuter `build.sh` puis `release.sh` (`migrate`, `createcachetable`, `bootstrap_render`).
4. Exécuter `python manage.py check --deploy` sur l'environnement cible.
5. Vérifier l'état des données pédagogiques :
   - `ERF-01` à `ERF-05` en statut `validated` (jamais `published`).
   - `P01..P06` et `V01..V03` en statut `draft`.
   - Aucun audio fictif ajouté.
6. Créer le groupe `pilot_erfe_v1` (s'il n'existe pas) et les comptes testeurs uniquement après accord du responsable.

---

## 4. Plan de gestion des 5–10 apprenants testeurs

- **Création individuelle :** 1 compte Django nominatif/pseudonymisé par testeur (`is_staff=False`, `is_superuser=False`), rattaché au groupe `pilot_erfe_v1`.
- **Transmission privée :** mot de passe temporaire généré hors Git et transmis individuellement par canal privé chiffré ; changement de mot de passe demandé au premier usage ou sur demande.
- **Réinitialisation / Révocation :** réinitialisation via l'administration Django ou commande d'administration ; révocation immédiate en retirant l'utilisateur du groupe `pilot_erfe_v1` ou en passant `is_active=False`.
- **Information et consentement :** informer les testeurs avant l'invitation des données collectées (progression pédagogique par unité, journal de synchronisation lié au compte, retours éventuels) et du caractère privé du test.
- **Fin du pilote :** exporter les retours anonymisés, puis supprimer ou archiver selon la décision du responsable les comptes et progressions de l'environnement pilote.

---

## 5. Sauvegarde, restauration et plan de retour arrière

- **Sauvegardes :** `pg_dump` avant toute migration/import + snapshots automatiques quotidiens PostgreSQL.
- **Restauration :** procédure documentée dans `docs/BACKUP_AND_RESTORE.md`.
- **Retour arrière :** révocation immédiate d'un compte (`is_active=False` ou retrait du groupe `pilot_erfe_v1`), ou arrêt/mise en maintenance du service pilote sans impact sur l'application publique.
