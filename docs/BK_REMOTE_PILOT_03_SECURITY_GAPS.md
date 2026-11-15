# BK-REMOTE-PILOT-03 — Écarts de sécurité et mesures recommandées

Les écarts ci-dessous sont classés par criticité, sans modification du code durant la Phase A.

---

## Critique / Bloquant pour le pilote sur infra partagée

### 1. Exposition potentielle des ZIP `LessonPack` sur le bucket R2 public
- **Élément contrôlé :** `LessonPack.file` (`backend/offline_packs/models.py:126`) et `STORAGES['default']` (`backend/config/settings.py:184-196`).
- **Source de preuve :** Dépôt local.
- **État :** **Confirmé (risque architectural si `USE_R2=True` avec bucket public)**.
- **Risque :** Lorsque `USE_R2=True`, `LessonPack.file` écrit dans `STORAGES['default']` (`AWS_QUERYSTRING_AUTH = False`, `custom_domain = R2_PUBLIC_DOMAIN`). Même si l'API `/api/offline-packs/` filtre l'accès, le fichier ZIP lui-même est servi sur une URL publique non authentifiée (`media.beriyarkedebideri.com/media/offline_packs/files/...`). De plus, `LessonPackSerializer.get_is_downloadable` vérifie `obj.status == LessonPack.PUBLISHED`, alors que `LessonPack.STATUS_CHOICES` ne contient pas `validated`.
- **Recommandation :** Pour le pilote, soit servir les packs pilote depuis `STORAGES['private']` (bucket R2 privé avec `querystring_auth=True` ou proxy Django authentifié), soit utiliser un stockage dédié non partagé avec le bucket public de production.
- **Action nécessitant autorisation :** Décider entre stockage disque persistant Render dédié au pilote ou bucket R2 privé dédié (`R2_PRIVATE_BUCKET_NAME`) en Phase B.

---

## Élevé

### 2. Risque de mélange production / pilote en cas de réutilisation du service existant
- **Élément contrôlé :** Service `beriyar-kedebideri.onrender.com` / `beriyarkedebideri.com`.
- **Source de preuve :** Probe HTTP (`HTTP 200 OK` actif en ligne) + `docs/BACKUP_AND_RESTORE.md`.
- **État :** **Confirmé**.
- **Risque :** Déployer la branche `dev` et créer des comptes `pilot_erfe_v1` sur le service/BDD de production expose les utilisateurs publics existants aux migrations de pilote, et mélange les sauvegardes, logs, et secrets.
- **Recommandation :** Isoler le pilote dans un service Web Render dédié + une base PostgreSQL dédiée (**Scénario B**).
- **Action nécessitant autorisation :** Autoriser la création d'un service et d'une base dédiés (Phase B).

### 3. Chaîne proxy TLS (`NUM_PROXIES` et `TRUST_X_FORWARDED_PROTO`) non mesurée sur cible
- **Élément contrôlé :** `backend/config/security.py:191-232`.
- **Source de preuve :** Dépôt + en-têtes `Server: cloudflare` et `x-render-origin-server: gunicorn`.
- **État :** **Non confirmé** (non vérifiable sur le futur service avant déploiement).
- **Risque :** Un `NUM_PROXIES` inexact fausse l'IP client dans `LearnerLoginThrottle` et `FeedbackThrottle` (blocage collectif ou contournement).
- **Recommandation :** Après déploiement du service pilote, vérifier `/api/core/diagnostics/https/` avec un compte staff avant d'ouvrir aux testeurs.
- **Action nécessitant autorisation :** Validation du déploiement pilote et vérification staff post-déploiement.

---

## Moyen

### 4. HSTS sous-domaines / préchargement (`security.W005`, `security.W021`)
- **Élément contrôlé :** `manage.py check --deploy` en `staging`.
- **Source de preuve :** Exécution locale `manage.py check --deploy`.
- **État :** **Confirmé (avertissements intentionnels)**.
- **Risque :** Faible en pilote sur sous-domaine HTTPS dédié (`SECURE_HSTS_SECONDS=300` actif par défaut).
- **Recommandation :** Conserver `INCLUDE_SUBDOMAINS=False` et `PRELOAD=False` pendant le pilote pour garder la réversibilité.

### 5. Révocation hors ligne différée
- **Élément contrôlé :** Cache local Android (`OnlineContentCacheService`, `OfflineMediaResolver`).
- **Source de preuve :** Dépôt local + `BK_AUTH_PILOT_01_RAPPORT_FINAL.md`.
- **État :** **Confirmé (limite connue)**.
- **Risque :** Un contenu déjà téléchargé reste lisible hors ligne jusqu'à la prochaine reconnexion (`refreshSession()` -> `401`/`403`) ou déconnexion.
- **Recommandation :** Documenter dans la notice testeur et appliquer la révocation côté serveur dès le retour réseau.

---

## Conforme / Vérifié sans écart bloquant
- `DEBUG=False`, `SECRET_KEY` stricte, `ALLOWED_HOSTS` explicite, `CSRF_TRUSTED_ORIGINS` HTTPS, `SESSION_COOKIE_SECURE=True`, `CSRF_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True`.
- Administration Django protégée derrière `ADMIN_URL` non standard (`admin/` renvoie 404).
- Aucun mot de passe/cookie/jeton journalisé dans `LearnerAuthView` ; `Cache-Control: private, no-store`.
- APK pilote Android : `com.afrigama.beriyarkedebideri.pilot`, `android:allowBackup="false"`, `AndroidKeyStore` (`noBackupFilesDir`), TLS standard sans HTTP en clair.
