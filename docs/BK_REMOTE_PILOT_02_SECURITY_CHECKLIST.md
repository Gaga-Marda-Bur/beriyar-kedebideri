# BK-REMOTE-PILOT-02 — Checklist de sécurité (Backend & Android)

## 1. Backend Django (Session + CSRF + Permissions)

- [x] `DEBUG=False` imposé en `staging` et `production` par `backend/config/security.py` (`ImproperlyConfigured` sinon).
- [x] `ALLOWED_HOSTS` explicite et sans wildcard (`*` refusé).
- [x] `SECURE_SSL_REDIRECT=True`, `SESSION_COOKIE_SECURE=True`, `CSRF_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True`, `SESSION_COOKIE_SAMESITE='Lax'`, `CSRF_COOKIE_SAMESITE='Lax'`.
- [x] `CSRF_TRUSTED_ORIGINS` obligatoire en `https://` et `csrf_protect` actif sur `/api/auth/csrf/`, `/api/auth/login/`, `/api/auth/logout/`.
- [x] `SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO', 'https')` activé uniquement si `TRUST_X_FORWARDED_PROTO=True`, avec `NUM_PROXIES` explicite.
- [x] Aucun secret serveur dans le dépôt Git (`backend/.env.production` non suivi par Git).
- [x] Aucun mot de passe, cookie de session ni jeton CSRF journalisé dans `LearnerAuthView` (`Cache-Control: private, no-store`, `Vary: Cookie`).
- [x] `LearnerLoginThrottle` (`15/min`) branché sur le cache partagé `caches['feedback']` (compatible multi-workers).
- [x] Contrôle d'accès serveur strict pour `pilot_erfe_v1` :
  - `ERF-01` à `ERF-05` (`validated`) accessibles uniquement aux membres de `pilot_erfe_v1` (et `staff`).
  - Contenus `published` inchangés pour le public.
  - 6e unité `validated` hors pilote et brouillons (`draft`) bloqués en liste et en accès direct par ID (`404`), y compris leçons, quiz, caractères et `offline-packs`.
- [x] `PublicMediaGuard` actif pour bloquer les chemins médias privés (`feedback/`).

## 2. Application Android pilote (`com.afrigama.beriyarkedebideri.pilot`)

- [x] Variante distincte (`BK_PILOT=true` -> `applicationId` `.pilot`, `versionNameSuffix` `-pilot`, nom `Beřiyar Pilote`) n'écrasant ni la version publique ni `.qa_tools`.
- [x] Garde-fous A13 actifs en `release` : refuse toute URL HTTP en clair, `127.0.0.1`, `localhost`, IP privée ou absence de `API_FLAVOR=staging|production`.
- [x] APK `release` non-debuggable et signé via `mobile/android/key.properties` (`beriyar-release-key.jks`).
- [x] Aucun secret serveur embarqué dans l'APK.
- [x] Aucun assouplissement TLS (`SecurityContext` / `HttpClient` standards).
- [x] Stockage local des cookies/jetons protégé par `AndroidKeyStore` (`AES/GCM/NoPadding`, `AtomicFile` dans `noBackupFilesDir`, canal `bk/learner_auth_v1`).
- [x] `android:allowBackup="false"` défini dans `mobile/android/app/src/main/AndroidManifest.xml` pour empêcher la sauvegarde/restauration Android Auto Backup des `SharedPreferences` de progression/session entre appareils.
- [x] Déconnexion et changement de compte : `LearnerSessionCleanup.clearUserSessionData()` purge caches mémoire/disque, progressions, historique, SRS et packs téléchargés.
- [x] Synchronisation isolée par compte (`account:{user.pk}`) sans collision `ProgressDeviceCredential`.

## 3. Limite documentée : révocation hors ligne

- Si un apprenant a déjà téléchargé les contenus autorisés sur son téléphone et passe en mode hors ligne complet, les contenus déjà stockés localement restent lisibles jusqu'à la prochaine reconnexion réseau déclenchant `refreshSession()` (ou un appel API retournant `401`/`403`) ou jusqu'à une déconnexion explicite. Dès le retour d'Internet, la révocation côté serveur bloque immédiatement tout nouvel accès et invalide la session.
