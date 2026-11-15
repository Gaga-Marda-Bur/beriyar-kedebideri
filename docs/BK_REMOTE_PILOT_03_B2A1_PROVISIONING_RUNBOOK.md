# BK-REMOTE-PILOT-03 — B2-A.1 : Runbook de provisionnement manuel (Phase B2-B)

**Important :** Ce document décrit la procédure manuelle à exécuter **uniquement après autorisation explicite** du responsable. Aucune ressource n'a été créée.

---

## 1. Préparation Cloudflare (avant Render)

1. **Bucket R2 privé dédié :**
   - Créer un nouveau bucket R2 dédié au pilote (ex. `bk-pilot-private`).
   - Vérifier que **Public Access** (`r2.dev` et *Custom Domains*) est **entièrement désactivé**.
2. **Clés API S3 restreintes :**
   - Créer un jeton API R2 avec permissions **Object Read & Write** limitées aux buckets du pilote (et un bucket public distinct si `USE_R2=True`, sans jamais réutiliser le bucket de production).
3. **DNS sous-domaine pilote (après création du service Render) :**
   - Créer un enregistrement `CNAME` `pilot-api` (pour `pilot-api.beriyarkedebideri.com`) pointant vers le nom d'hôte Render du nouveau service pilote, en mode **Proxied** (HTTPS Full/Strict).
   - Ne modifier aucun enregistrement existant (`@`, `www`, `media`).

---

## 2. Provisionnement Render (isolé de la production)

1. **Base PostgreSQL dédiée :**
   - Créer une instance PostgreSQL Render dans la **même région** que le Web Service pilote (plan recommandé : Basic 256 Mo ; minimum technique : Free éphémère 30 jours, déconseillé).
   - Activer les sauvegardes / snapshots automatiques du plan et noter la commande `pg_dump -Fc --no-acl --no-owner` avant toute opération critique (`docs/BACKUP_AND_RESTORE.md`).
2. **Web Service Django pilote :**
   - Créer un nouveau Web Service pointant sur la branche validée (`dev` ou branche pilote dédiée), Root Directory `backend`.
   - Build Command : `./build.sh`
   - Start Command : `gunicorn config.wsgi:application`
   - Pre-Deploy / Release Command : `./release.sh` (exécute `migrate`, `createcachetable`, `bootstrap_render`).
3. **Variables d'environnement à définir sur Render (noms uniquement, valeurs saisies dans la console) :**
   - `DJANGO_ENV` (`staging`)
   - `DEBUG` (`False`)
   - `SECRET_KEY` (clé dédiée >= 50 caractères)
   - `ALLOWED_HOSTS` (`pilot-api.beriyarkedebideri.com`)
   - `CSRF_TRUSTED_ORIGINS` (`https://pilot-api.beriyarkedebideri.com`)
   - `TRUST_X_FORWARDED_PROTO` (`True`)
   - `NUM_PROXIES` (à calibrer via `/api/core/diagnostics/https/`)
   - `ADMIN_URL` (chemin d'administration secret dédié)
   - `DATABASE_URL` (URL interne/SSL de la PostgreSQL pilote)
   - `DATABASE_REQUIRE_SSL` (`True`, ou `DATABASE_NETWORK=private` si réseau privé Render)
   - `FEEDBACK_CACHE_BACKEND` (`django.core.cache.backends.db.DatabaseCache`)
   - `FEEDBACK_CACHE_LOCATION` (`feedback_rate_limit_cache`)
   - `USE_R2` (`True`)
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`
   - `R2_ENDPOINT_URL`
   - `R2_BUCKET_NAME` (bucket public pilote ou dédié, distinct de la prod)
   - `R2_PUBLIC_BASE_URL`
   - `R2_PRIVATE_BUCKET_NAME` (bucket privé pilote `bk-pilot-private`)

---

## 3. Initialisation, contrôles de sécurité et retour arrière

1. **Migrations & cache initial :**
   - Vérifiés automatiquement par `./release.sh` (`manage.py migrate`, `manage.py createcachetable`).
   - Importer les 5 leçons Erfe (`bk-preprod-erf-01`..`05`) et générer les packs en statut `validated` uniquement.
2. **Contrôles post-déploiement (HTTPS & isolation) :**
   - Vérifier `https://pilot-api.beriyarkedebideri.com/api/core/diagnostics/https/` et calibrer `NUM_PROXIES`.
   - Vérifier qu'un client anonyme reçoit `404` sur `/api/offline-packs/<pk>/download/` et qu'un utilisateur `pilot_erfe_v1` reçoit `200` (`Cache-Control: private, no-store`).
   - Exécuter `python manage.py reconcile_pack_storage` (mode lecture seule) pour vérifier `0` orphelin et `0` pack non publié dans `file`.
3. **Plan de retour arrière (Rollback) :**
   - En cas d'anomalie : suspendre immédiatement le Web Service Render pilote et/ou supprimer l'enregistrement DNS `pilot-api.beriyarkedebideri.com`.
   - Restaurer la PostgreSQL pilote depuis le snapshot / `pg_dump` pré-opération ; la production (`beriyarkedebideri.com` / `media.beriyarkedebideri.com`) reste 100 % intacte.

---

## 4. Inventaire confirmé par le responsable & plan ordonné B2-B

- **Render Web existant (production, à ne pas modifier) :** `beriyar-kedebideri`
- **PostgreSQL existante (production, à ne pas modifier) :** `beriyar-postgres`
- **Domaine :** `beriyarkedebideri.com`
- **Bucket R2 public existant (production, à ne pas modifier) :** `beriyar-kedebideri-media`
- **Facturation actuelle annoncée :** `6,30–12,60 $`
- **Surcoût pilote estimé (à confirmer) :** `13–14 $/mois`

| Ordre | Opération B2-B | Dépendances | Coût estimé | Risque principal | Retour arrière |
|---|---|---|---|---|---|
| 1 | Créer le bucket R2 privé pilote (`bk-pilot-private`) avec accès public désactivé + clés S3 restreintes | Compte Cloudflare | `0 $/mois` (palier gratuit R2) | Oubli de désactivation `r2.dev` | Supprimer le bucket/jeton |
| 2 | Créer la PostgreSQL pilote isolée (ex. `beriyar-pilot-postgres`) dans la même région que `beriyar-kedebideri` | Compte Render | `~6–7 $/mois` (Basic 256 Mo, à confirmer) | DB Free éphémère 30 j si mal choisie | Supprimer l'instance pilote |
| 3 | Créer le Web Service pilote isolé (ex. `beriyar-pilot-api`) sur `dev` (`./build.sh`, `./release.sh`, `gunicorn`) + variables env | Étapes 1 & 2 | `7 $/mois` (Starter, à confirmer) | `NUM_PROXIES` ou secret manquant (`ImproperlyConfigured`) | Suspendre/supprimer le service |
| 4 | Créer le CNAME DNS `pilot-api.beriyarkedebideri.com` (Proxied) vers le Web Service pilote | Étape 3 | `0 $` | Mauvaise cible DNS | Supprimer le CNAME `pilot-api` |
| 5 | Calibrer `NUM_PROXIES`, exécuter `pg_dump`, importer `ERF-01`..`05`, générer les packs en `validated`, vérifier `/download/` et `reconcile_pack_storage --dry-run` | Étape 4 | `0 $` | Exposition non voulue si statut `published` par erreur | Suspendre le service, restaurer snapshot DB |
