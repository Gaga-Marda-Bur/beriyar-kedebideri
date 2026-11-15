# BK-REMOTE-PILOT-03 — Phase B1 : Conception du stockage privé des packs

**Branche :** `dev` (non commitée, en attente de validation)  
**Objectif :** Empêcher toute exposition d'archives `LessonPack` non publiées (`validated`, `review`, `draft`) sur un bucket R2 public ou une URL permanente.

---

## 1. Cycle complet d'un pack (avant / après B1)

1. **Génération (`OfflinePackGenerator.generate`):**
   - Avant : écrivait toujours dans `LessonPack.file` (`STORAGES['default']`), donc sur le bucket R2 public lorsque `USE_R2=True`.
   - Après : si `pack.status == LessonPack.PUBLISHED`, écrit dans `LessonPack.file` (comportement production inchangé). Pour tout statut non publié (`draft`, `review`, `validated`), écrit dans `LessonPack.private_file` (`PrivatePackStorage`) et vide `LessonPack.file`.
2. **Stockage (`PrivatePackStorage` dans `backend/core/media_storage.py`):**
   - Délègue `_open`, `_save`, `exists`, `size`, `delete` à `private_backend()` (`STORAGES['private']`).
   - Avec `USE_R2=False` : stocke dans `PRIVATE_MEDIA_ROOT` (physiquement hors de `MEDIA_ROOT` et `STATIC_ROOT`).
   - Avec `USE_R2=True` : stocke dans le bucket privé distinct `R2_PRIVATE_BUCKET_NAME` (`querystring_auth=True`, `custom_domain=None`, `CacheControl='private, no-store'`).
   - `PrivatePackStorage.url()` retourne `''` : aucune URL CDN/stockage directe n'est jamais exposée.
3. **Sérialisation (`LessonPackSerializer`):**
   - Pour `PUBLISHED` : `file_url` conserve `obj.file.url`.
   - Pour tout pack non publié (`VALIDATED`, `REVIEW`, `DRAFT`) : `file_url` retourne `/api/offline-packs/<pk>/download/` (URL absolue sur l'API Django).
   - `is_downloadable` vaut `True` pour `PUBLISHED` (avec `file`), `VALIDATED` (avec `active_file`), ou pour `staff` en prévisualisation.
4. **Téléchargement authentifié (`LessonPackDownloadAPIView`):**
   - Route : `GET /api/offline-packs/<int:pk>/download/`.
   - Contrôle d'accès identique à `LessonPackDetailAPIView` (`_scoped_pack_queryset` via `filter_by_access(..., pilot_q=...)`).
   - Lecture en flux depuis `target.storage.open(target.name, 'rb')` sans aucun chemin fourni par le client (aucun risque de traversée de chemin).
   - Réponse : `FileResponse` avec `Cache-Control: private, no-store`, `Vary: Cookie`, `X-Content-Type-Options: nosniff`.
   - Aucune clé R2 ni URL présignée permanente n'est transmise au client Flutter.
5. **Client Flutter (`OfflinePackDownloadService`):**
   - Attache l'en-tête `Cookie` de session (`LearnerAuthService.authHeadersForGet()`) **uniquement** si l'URL du pack est de même origine que `ApiConfig.baseUrl` (aucune fuite de cookie vers un CDN externe).
   - En cas de `401`, invalide la session locale via `handleUnauthorized()`.
   - Conserve la vérification SHA-256, la protection anti-ZipSlip, l'extraction atomique dans `AppDirectories`, et la purge complète via `LearnerSessionCleanup` lors de la déconnexion / changement de compte.

---

## 2. Gestion de la révocation et limite hors ligne

- **En ligne :** le retrait d'un utilisateur du groupe `pilot_erfe_v1` (ou sa désactivation) bloque immédiatement `/api/offline-packs/`, `/api/offline-packs/<pk>/` et `/api/offline-packs/<pk>/download/` (`404`).
- **Hors ligne (limite assumée) :** un pack déjà téléchargé et vérifié localement sur le téléphone reste utilisable sans réseau jusqu'à la prochaine reconnexion déclenchant `refreshSession()` / un appel API (`401`/`403`) ou jusqu'à une déconnexion explicite.
