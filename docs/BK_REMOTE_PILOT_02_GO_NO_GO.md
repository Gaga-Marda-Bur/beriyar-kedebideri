# BK-REMOTE-PILOT-02 — Rapport GO / NO-GO : Pilote privé à distance (Alphabet Erfe V1)

**Branche :** `dev`  
**Décision technique :** **GO CONDITIONNEL** (prêt pour déploiement serveur pilote et qualification HTTPS distante après validation du responsable)

---

## 1. Réalisé et testé

- **Audit complet du dépôt :** configuration Django (`config/settings.py`, `config/security.py`, `build.sh`, `release.sh`), authentification Session + CSRF (`core/auth_views.py`), permissions `pilot_erfe_v1` (`core/permissions.py`), packs hors ligne (`offline_packs/views.py`), stockage Android Keystore (`LearnerAuthVaultChannel.kt`) et garde-fous A13 (`mobile/android/app/build.gradle.kts`, `api_config.dart`).
- **Durcissement multi-workers du throttling de connexion :**
  - `LearnerLoginThrottle` dans `backend/core/auth_views.py` branché sur `caches['feedback']` (cache partagé `DatabaseCache`/`RedisCache` exigé en `staging`/`production`), avec test dédié dans `backend/core/tests_auth.py`.
- **Variante Android pilote isolée (`BK_PILOT=true`) :**
  - `mobile/android/app/build.gradle.kts` : `applicationIdSuffix = ".pilot"` (`com.afrigama.beriyarkedebideri.pilot`), `versionNameSuffix = "-pilot"`, `app_name = "Beřiyar Pilote"`.
  - `mobile/android/app/src/main/AndroidManifest.xml` et `res/values/strings.xml` : `android:allowBackup="false"` pour bloquer la sauvegarde/restauration Android Auto Backup des données privées.
- **Vérifications exécutées :**
  - `manage.py check --deploy` (environnement `staging` simulé) : `0` erreur bloquante, `2` avertissements attendus (`security.W005`, `security.W021` sur HSTS subdomains/preload volontairement différés).
  - Suite Django complète (`.\venv\Scripts\python.exe manage.py test`) : `Ran 191 tests in 96.167s` — `OK (skipped=2)` — `System check identified no issues (0 silenced).`
  - Tests ciblés auth/permissions/throttle/offline-packs (`core.tests_auth`) : `5/5` réussis.
  - `flutter analyze` : `No issues found! (ran in 12.7s)`.
  - Suite Flutter complète (`flutter test`) : `196` tests réussis (`All tests passed!`).
  - Build Android release pilote signé (`flutter build apk --release --dart-define=API_FLAVOR=staging --dart-define=API_BASE_URL=https://pilot-api.beriyarkedebideri.com/api --dart-define=BK_PILOT=true`) : `app-release.apk` (`66.8MB`) généré, vérifié par `aapt2` (`com.afrigama.beriyarkedebideri.pilot`, `1.0.0-pilot`, `Beřiyar Pilote`, non-debuggable) et signé avec le certificat de release (`apksigner verify` OK).
  - Qualification physique antérieure confirmée sur Samsung SM-A336E (`R6CT6003WRT`) en QA locale isolée (authentification, `ERF-01` hors ligne, reprise après `am force-stop`, resynchronisation idempotente, nettoyage au changement de compte).

---

## 2. Préparé mais non déployé

- Plan de déploiement, variables d'environnement et procédure de gestion des 5–10 testeurs : [BK_REMOTE_PILOT_02_RELEASE_PLAN.md](BK_REMOTE_PILOT_02_RELEASE_PLAN.md).
- Checklist de sécurité (incluant la limite de révocation hors ligne) : [BK_REMOTE_PILOT_02_SECURITY_CHECKLIST.md](BK_REMOTE_PILOT_02_SECURITY_CHECKLIST.md).
- Scénarios de distribution privée (Play Console test fermé et APK signé privé) : [BK_REMOTE_PILOT_02_ANDROID_DISTRIBUTION.md](BK_REMOTE_PILOT_02_ANDROID_DISTRIBUTION.md).
- Aucun push distant, aucun déploiement serveur, aucune création de comptes réels et aucune publication effectués.

---

## 3. Nécessitant une décision du responsable

1. Autoriser et provisionner l'hébergement pilote HTTPS dédié + domaine cible (ex. `pilot-api.beriyarkedebideri.com` ou `staging-api.beriyarkedebideri.com`).
2. Provisionner la base PostgreSQL isolée et le stockage média persistant (ou R2 dédié).
3. Confirmer le nombre exact de proxys TLS (`NUM_PROXIES`) sur l'hébergeur choisi.
4. Choisir le canal de distribution Android pour les 5–10 testeurs (Scénario A Google Play test fermé ou Scénario B APK privé).
5. Valider l'import des unités `ERF-01`..`ERF-05` en statut `validated` (en maintenant `P01..P06` et `V01..V03` en `draft`) et autoriser la création individuelle des 5–10 comptes `pilot_erfe_v1`.

---

## 4. Non testé ou bloqué

- **Phase 6 — Tests distants sur serveur HTTPS réel :** non exécutée car aucun serveur pilote distant n'est encore déployé (conformément à l'interdiction de déploiement automatique). À exécuter immédiatement après déploiement autorisé avec :
  - 1 compte `pilot_erfe_v1`, 1 compte ordinaire, 1 compte pilote révoqué ;
  - le véritable APK pilote `com.afrigama.beriyarkedebideri.pilot` compilé sur l'URL HTTPS définitive, sans ADB.
