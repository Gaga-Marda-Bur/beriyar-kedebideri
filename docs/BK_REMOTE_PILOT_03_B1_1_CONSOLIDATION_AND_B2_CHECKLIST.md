# BK-REMOTE-PILOT-03 — B1.1 : Consolidation sécurité & préparation B2

## 1. Vérification du stockage R2 (`backend/config/settings.py` & `core/media_storage.py`)

- **`STORAGES['private']` distinct lorsque `USE_R2=True`** : oui. `settings.py` configure `STORAGES['private']` avec `S3Boto3Storage` pointant vers `R2_PRIVATE_BUCKET_NAME`, `custom_domain: None`, `querystring_auth: True`, `default_acl: None`, `object_parameters: {'CacheControl': 'private, no-store'}`, `location: 'private'`.
- **Absence de `R2_PRIVATE_BUCKET_NAME`** : lorsque `IS_DEPLOYED=True` et `USE_R2=True`, l'absence de `R2_PRIVATE_BUCKET_NAME` (ou une valeur identique à `R2_BUCKET_NAME`) lève immédiatement `ImproperlyConfigured` au démarrage, sans repli vers le bucket public. En local (`IS_DEPLOYED=False`), le repli s'effectue uniquement vers `FileSystemStorage(PRIVATE_MEDIA_ROOT)`, jamais vers le bucket public.
- **Aucune URL publique permanente** : `PrivatePackStorage.url()` retourne systématiquement `''`.
- **Secrets R2** : `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_PRIVATE_BUCKET_NAME` restent exclusivement côté `settings.py` et ne sont jamais transmis à Flutter.
- **Téléchargement authentifié** : `LessonPackDownloadAPIView` (`/api/offline-packs/<pk>/download/`) diffuse l'archive en flux via `target.storage.open(target.name, 'rb')` avec `Cache-Control: private, no-store`, `Vary: Cookie` et `X-Content-Type-Options: nosniff`.
- **Confidentialité des règles Cloudflare (R2 / WAF / accès public)** : **non vérifiée** jusqu'à inspection directe du compte Cloudflare en Phase B2.

---

## 2. Vérification des anciens fichiers (`LessonPack.file`)

- **Référencement API** : si un pack non publié possédait déjà un `file` avant la migration `0002`, `LessonPackSerializer.get_file_url()` retourne `/api/offline-packs/<pk>/download/` (plus d'URL publique exposée) et `active_file` lit `private_file or file`.
- **Risque d'objet R2 résiduel** : un objet déjà présent dans le bucket public R2 avant migration reste techniquement accessible à son ancienne URL R2 tant qu'il n'est pas supprimé ou déplacé.
- **Procédure sans perte de données** : `LessonPack._sync_storage_for_status()` (exécuté dans `LessonPack.save()`) et `OfflinePackGenerator.generate()` copient automatiquement les octets de `file` vers `private_file` (si `private_file` est vide) pour tout pack non publié, puis suppriment l'ancien objet public via `file.delete(save=False)`. Aucun fichier distant n'a été déplacé ou supprimé durant B1.1.

---

## 3. Changements de statut et périmètre des packs pilotes

- **Transitions vérifiées (`test_pack_status_transitions_and_pilot_content_scope`)** :
  - `draft` → `validated` : l'archive reste dans `private_file`, `file` reste vide, téléchargement authentifié `200` pour `pilot_erfe_v1`.
  - `validated` → `published` : `_sync_storage_for_status()` copie vers `file` et supprime `private_file` ; `file_url` et `is_downloadable` restent valides immédiatement sans référence cassée.
  - `published` → `draft` : `_sync_storage_for_status()` déplace vers `private_file` et supprime physiquement l'objet public `file` ; l'accès retourne `404`.
  - **Régénération** : `OfflinePackGenerator.generate()` supprime l'éventuel fichier de l'autre stockage via `.delete(save=False)`.
- **Périmètre des 5 unités** : `_scoped_pack_queryset` applique `PILOT_ALLOWED_UNIT_SLUGS` (`bk-preprod-erf-01` à `bk-preprod-erf-05`) avec exclusion stricte de toute autre unité, et le ZIP généré (`units.json`) est vérifié comme sous-ensemble de ces 5 unités.

---

## 4. Vérification Flutter (`OfflinePackDownloadService`)

- **URL relative** : résolue contre `ApiConfig.baseUrl` via `_resolveTargetUri()`, reconnue comme same-origin avec envoi du `Cookie`.
- **URL absolue same-origin** : `Cookie` transmis.
- **URL externe** : aucun `Cookie` transmis.
- **Redirection vers une autre origine** : `_sendGetWithOriginCheck()` utilise `followRedirects = false` (boucle bornée à 5 sauts) et ré-évalue `_isSameApiOrigin()` à chaque saut, garantissant qu'aucun `Cookie` n'est transmis après redirection cross-origin.
- **HTTP 401 / session expirée** : appelle `_auth.handleUnauthorized()`, invalide l'état authentifié local et lève une exception.
- **HTTP 403** : lève une exception sans corrompre la session ni le cache local.
- **Téléchargement interrompu (`SocketException`) & ZIP incomplet** : l'extraction échoue avant validation et aucun `local_metadata.json` n'est écrit.

---

## 5. Migration et impact sur les données existantes

- `makemigrations --check --dry-run` : `No changes detected`.
- `migrate --plan` : inclut `offline_packs.0002_lessonpack_private_file_alter_lessonpack_status` (`Add field private_file`, `Alter field status`).
- **Impact données existantes** : migration 100 % additive, sans perte de données pour les packs `published` existants. En cas de packs non publiés préexistants avec `file` non nul, une passe de ré-enregistrement ou de régénération les bascule vers `private_file`.

---

## 6. Informations à collecter pour la Phase B2 (Render & Cloudflare)

Avant tout provisionnement distant, vérifier et fournir les éléments suivants :
1. **Services actifs Render** : liste des Web Services / Workers existants, URLs et branches suivies.
2. **Plans et coûts** : plan actuel du service Web et de la base PostgreSQL (Starter / Standard / Free, limites RAM/connexions) et budget validé pour un service pilote séparé.
3. **PostgreSQL disponible** : possibilité de créer une instance PostgreSQL dédiée au pilote (version, taille, région identique au Web Service).
4. **Région d'hébergement** : région exacte du service Render actuel (ex. Frankfurt / Oregon) pour co-localiser Web Service et PostgreSQL pilote.
5. **Gestion DNS (Cloudflare)** : confirmation de l'accès pour créer l'enregistrement CNAME `pilot-api.beriyarkedebideri.com` (proxied HTTPS) sans impacter `api.` ni `media.`.
6. **Configuration R2 (Cloudflare)** : création/vérification d'un bucket privé dédié (ex. `bk-pilot-private`) sans accès public r2.dev/custom domain, et clés API S3 restreintes à ce bucket.
7. **Sauvegardes** : politique de snapshots/backups automatiques sur la PostgreSQL pilote et stratégie de conservation/purge à la fin du pilote.
8. **Isolation du pilote** : validation finale que le pilote utilise une base PostgreSQL, un `SECRET_KEY`, un bucket R2 privé et un sous-domaine distincts de la production.
