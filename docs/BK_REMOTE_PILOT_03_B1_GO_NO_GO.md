# BK-REMOTE-PILOT-03 — Phase B1 : Décision GO / NO-GO pour la Phase B2

**Décision :** **GO POUR PHASE B2** (sous réserve de validation explicite du responsable et d'autorisation de déploiement)

---

## 1. Risques confirmés vs hypothétiques

- **Confirmé et corrigé localement :** `LessonPack.file` utilisait `STORAGES['default']` (bucket R2 public si `USE_R2=True`). Corrigé par l'ajout de `PrivatePackStorage` (`private_file`), la synchronisation automatique de stockage sur transition de statut (`_sync_storage_for_status`), l'endpoint authentifié `/api/offline-packs/<pk>/download/`, et le support `Cookie` same-origin (avec blocage des cookies sur redirection cross-origin) dans `OfflinePackDownloadService`.
- **Confirmé (limite assumée) :** un pack déjà téléchargé hors ligne reste lisible sans réseau jusqu'à la reconnexion ou déconnexion explicite.
- **Non vérifié jusqu'à inspection du compte :** confidentialité effective des règles Cloudflare (R2 / accès public / WAF), chaîne proxy réelle (`NUM_PROXIES`), plan/expiration Render, configuration R2 distante (à vérifier lors du provisionnement Phase B2).

## 2. Fichiers modifiés / ajoutés (non commités)

- `backend/core/media_storage.py` (`PrivatePackStorage`)
- `backend/offline_packs/models.py` (`VALIDATED`, `private_file`, `active_file`, `update_file_metadata`)
- `backend/offline_packs/migrations/0002_lessonpack_private_file_alter_lessonpack_status.py` (migration additive requise lors du déploiement)
- `backend/offline_packs/services/offline_pack_generator.py` (routage vers `private_file` hors `published`)
- `backend/offline_packs/serializers.py` (`file_url` authentifié et `is_downloadable` pour `validated`/staff)
- `backend/offline_packs/views.py` & `urls.py` (`LessonPackDownloadAPIView`)
- `backend/core/tests_auth.py` (test de stockage privé et téléchargement authentifié)
- `mobile/lib/features/offline_packs/services/offline_pack_download_service.dart` (cookie same-origin + gestion `401`)
- `mobile/test/offline_pack_auth_download_test.dart` (2 tests unitaires Flutter)

## 3. Impacts sur la production

- **Aucun impact sur la production actuelle** : les packs `published` continuent d'utiliser `LessonPack.file` et `file_url` publics ; aucun déploiement, aucun push et aucune modification distante effectués.

## 4. Opérations nécessitant une autorisation explicite (Phase B2)

1. Autoriser le commit local (et éventuellement le push) des modifications B1 sur `dev`.
2. Autoriser le provisionnement Render (service Web pilote + PostgreSQL dédiée + stockage privé/R2 dédié) et DNS (`pilot-api.beriyarkedebideri.com`).
3. Exécuter `release.sh` (`migrate` incluant `0002_lessonpack_private_file_alter_lessonpack_status`) et importer `ERF-01`..`ERF-05` en `validated`.
4. Compiler l'APK pilote final et exécuter la qualification HTTPS distante (Phase 6) avant d'inviter les 5–10 apprenants.
