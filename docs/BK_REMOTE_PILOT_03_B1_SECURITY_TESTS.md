# BK-REMOTE-PILOT-03 — Phase B1 : Résultats des tests de sécurité

**Branche :** `dev` (modifications locales non commitées)

---

## 1. Tests ajoutés

### Backend (`backend/core/tests_auth.py`)
- `test_private_pilot_pack_storage_and_authenticated_download` :
  - Vérifie que `OfflinePackGenerator` écrit les packs `validated` et `draft` dans `private_file` (`PrivatePackStorage` -> `PRIVATE_MEDIA_ROOT`), jamais dans `MEDIA_ROOT` ni `LessonPack.file`.
  - Vérifie que `PrivatePackStorage.url(...)` retourne `''` (aucune URL publique permanente).
  - Vérifie que `LessonPackSerializer` expose `/api/offline-packs/<pk>/download/` pour le compte pilote.
  - Vérifie le refus (`404`) pour l'utilisateur anonyme, l'utilisateur ordinaire, les packs `validated` hors liste pilote, les packs `draft`, et immédiatement après révocation du groupe `pilot_erfe_v1`.
  - Vérifie les en-têtes `Cache-Control: private, no-store`, `Vary: Cookie`, `X-Content-Type-Options: nosniff` et le contenu ZIP valide (`PK...`) lors du téléchargement pilote authentifié (`200`).

### Flutter (`mobile/test/offline_pack_auth_download_test.dart`)
- `attaches session Cookie only for same-origin API pack downloads` :
  - Vérifie que `OfflinePackDownloadService` envoie le cookie `sessionid` pour `/api/offline-packs/1/download/` (même origine que `ApiConfig.baseUrl`) et n'envoie **aucun** cookie vers un CDN externe (`media.beriyarkedebideri.com`).
- `401 on same-origin private pack download invalidates session` :
  - Vérifie qu'une réponse `401` sur téléchargement privé déclenche `LearnerAuthService.handleUnauthorized()`.

---

## 2. Exécution des suites complètes

- **Django (`.\venv\Scripts\python.exe manage.py test`) :**
  - `Ran 192 tests in 85.804s` — `OK (skipped=2)` — `System check identified no issues (0 silenced).`
- **Flutter (`flutter test`) :**
  - `198` tests réussis (`All tests passed!`).
