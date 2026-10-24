# Protocole et Journal de Recette de Préproduction — Beřiyar Kedebideři

Ce document consigne les critères d'acceptation opérationnels avant toute diffusion publique ou déploiement en production. Il distingue formellement les **vérifications locales exécutées** des **jalons distants, physiques ou manuels restant à exécuter**.

Chaque critère est tracé selon trois statuts stricts :
- **RÉUSSI** : Vérification exécutée avec succès dans son périmètre exact, preuve concrète attachée (horodatage, environnement, résultat chiffré, code retour).
- **ÉCHOUÉ** : Vérification exécutée ayant révélé un blocage ou une non-conformité.
- **NON EXÉCUTÉ** : Jalon dépendant d'un environnement distant, d'un appareil physique ou d'un test humain sur écran réel, non prouvable par les seuls tests automatisés locaux.

---

## 1. Synthèse de l'état d'avancement de la recette

| Jalon de recette | Statut | Périmètre & Portée exacte | Preuve attachée |
|---|:---:|---|---|
| **1.1. Intégrité des migrations et tests backend** | **RÉUSSI** | Local (Python 3.13, SQLite) | 59/59 tests OK, dry-run clean |
| **1.2. Analyse statique et tests mobiles** | **RÉUSSI** | Local (Flutter stable, Dart) | 70/70 tests OK, 0 anomalie analyze |
| **1.3. Exécution distante du workflow CI** | **NON EXÉCUTÉ** | Runners distants GitHub Actions | En attente de push du commit sur GitHub |
| **2.1. Parcours clavier réel de bout en bout** | **NON EXÉCUTÉ** | Test humain interactif au clavier | Prérequis CSS/ARIA prêts ; recette physique requise |
| **2.2. Attributs cookies (Session vs CSRF)** | **RÉUSSI** | Local (Django Test Client / Settings) | `docs/test_cookie_attributes.py` (code 0) |
| **2.3. Lecteur d'écran & grossissement réel** | **NON EXÉCUTÉ** | Smartphone réel (TalkBack/NVDA) | Requiert terminal physique sous différentes lumières |
| **3.1. Quotas multi-workers (Cache partagé)** | **RÉUSSI** | Local (Processus distincts / FileBasedCache) | `docs/test_multiworker_throttle.py` (HTTP 201 puis 429) |
| **3.2. Sauvegarde & Restauration physique** | **RÉUSSI** | Local (Base réelle + 100% tables/lignes/médias) | `docs/test_physical_backup_restore.py` (37 tables, SHA-256 OK) |
| **3.3. Mise à jour APK & Mode avion réel** | **NON EXÉCUTÉ** | Smartphone Android physique | Requiert installation manuelle et test en vol/hors réseau |
| **4.1. Diagnostic HTTPS & Proxy de production** | **NON EXÉCUTÉ** | Serveur distant / Staging | Requiert instance hébergée active et compte staff |
| **4.2. Inventaire des archives distantes R2/CDN** | **NON EXÉCUTÉ** | Cloudflare R2 / Bucket distant | Requiert accès aux clés distantes S3/R2 |

---

## 2. Pilier 1 — Intégration Continue (CI) & Qualité du Commit

### 1.1. Vérifications Backend & Lecteur Audio
- **Statut :** **RÉUSSI**
- **Date :** 2026-10-24 12:39 UTC+3
- **Environnement :** Machine locale Windows (Python 3.13, Django 6.0)
- **Preuve :**
  - Commande : `backend\venv\Scripts\python.exe docs/run_backend_checks.py`
  - Résultat : 59 tests exécutés en 15.685s — `OK`. Zéro changement de modèle orphelin (`makemigrations --check --dry-run`).
  - Commande : `node --test backend/webapp/tests_audio_player.cjs`
  - Résultat : 3 sous-tests réussis (gestion d'état, annonces vocales, concurrence audio).

### 1.2. Vérifications Mobile Flutter
- **Statut :** **RÉUSSI**
- **Date :** 2026-10-24 12:38 UTC+3
- **Environnement :** Flutter 3.x stable / Dart 3.x
- **Preuve :**
  - Commande : `flutter analyze --no-pub`
  - Résultat : `No issues found! (ran in 8.0s)`.
  - Commande : `flutter test`
  - Résultat : 70 tests passés avec succès (couvrant cache A02/A16, pagination A10, audio A12, quotas A15, tokens Lot 3).

### 1.3. Exécution distante GitHub Actions
- **Statut :** **NON EXÉCUTÉ**
- **Condition de déclenchement :** Push de la branche sur le dépôt GitHub distant.
- **Portée :** Valider l'exécution sur Ubuntu-latest avec runners indépendants pour le commit exact à déployer.

---

## 3. Pilier 2 — Accessibilité, Attributs Cookies & Rendu Réel

### 2.1. Parcours Clavier Réel (Interaction humaine)
- **Statut :** **NON EXÉCUTÉ** *(Prérequis techniques implémentés localement)*
- **Constat :** Les règles CSS (`:focus-visible` or `2px`), les attributs ARIA (`aria-expanded`, `aria-controls`) et le gestionnaire de touche `Escape` sont en place dans le code et vérifiés par les tests unitaires.
- **Limite documentée :** La présence du code ne dispense pas d'un parcours humain sans souris sur les pages clés (Accueil, Parcours, Détail d'unité, Alphabet, Vocabulaire, Quiz, Éditeur, Formulaire de feedback). Ce test reste à exécuter lors de la recette interactive.

### 2.2. Contrôle rigoureux des attributs par Cookie (Session vs CSRF)
- **Statut :** **RÉUSSI**
- **Date :** 2026-10-24 12:56 UTC+3
- **Environnement :** Script de validation dédié [`docs/test_cookie_attributes.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/test_cookie_attributes.py)
- **Distinction validée :**
  - Cookie de session (`sessionid`) : `HttpOnly=True` impératif (protection contre le vol de session XSS), `SameSite=Lax`, `Secure=True` en production.
  - Cookie CSRF (`csrftoken`) : `HttpOnly=False` impératif (permet aux scripts clients `beriya_keyboard.js` et formulaires asynchrones de lire le jeton et de l'injecter dans l'en-tête `X-CSRFToken`), `SameSite=Lax`, `Secure=True` en production.
- **Preuve :**
  - Exécution de `docs/test_cookie_attributes.py` : code retour `0`.
  - Émission effective et obligatoire constatée sur `/feedback/` : cookie `csrftoken` sans attribut `HttpOnly` et avec `SameSite=Lax`.
  - Cookie `sessionid` émis lors de session active avec `HttpOnly=True` et `SameSite=Lax`.
  - Rejet automatique des clés de session faibles par le validateur `_validate_secret_key`.
- **Précision d'architecture :** L'attribut `Secure` des cookies est directement positionné par les réglages Django (`SESSION_COOKIE_SECURE` et `CSRF_COOKIE_SECURE`). Le proxy inverse ne détermine pas cet attribut mais assure la terminaison TLS/HTTPS permettant de valider leur acheminement et leur comportement réel via HTTPS sur le réseau public.

### 2.3. Rendu Écran Réel, Lecteur d'Écran & Zoom 200%
- **Statut :** **NON EXÉCUTÉ**
- **Environnement requis :** Smartphone Android avec TalkBack activé et navigateur de bureau avec NVDA/VoiceOver.
- **Points de contrôle à réaliser :**
  - Vocalisation intelligible des caractères Beriya avec leur transcription associée.
  - Absence de chevauchement textuel lors du zoom navigateur 200% et de l'activation des grandes polices système.
  - Mesure colorimétrique du contraste réel $\ge 4.5:1$ sur les cartes translucides (`.glass`).

---

## 4. Pilier 3 — Cache Partagé Multi-Workers & Sauvegarde Physique

### 4.1. Quotas de Feedback Multi-Workers (Cache partagé)
- **Statut :** **RÉUSSI**
- **Date :** 2026-10-24 12:55 UTC+3
- **Environnement :** Script d'épreuve multi-processus HTTP [`docs/test_multiworker_throttle.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/test_multiworker_throttle.py)
- **Constat & Preuve :**
  - **LocMemCache (mémoire locale par processus) :** 4 requêtes POST réparties sur 4 processus distincts aboutissent toutes en HTTP 201 (`['201', '201', '201', '201']`), prouvant que la mémoire n'est pas partagée.
  - **Cache partagé inter-processus (`FileBasedCache`, simulant Redis/DatabaseCache) :** La limite globale (3/min) est strictement respectée quel que soit le worker interrogé : `['201', '201', '201', '429']`. La 4ème requête est immédiatement rejetée en **HTTP 429 Too Many Requests** avec en-tête `Retry-After: 56`.
  - **Accès concurrents simultanés :** 3 workers exécutés en parallèle via `ProcessPoolExecutor` reçoivent tous `HTTP 429`.
- **Limite documentée :** Ce test valide le partage inter-processus via `FileBasedCache` local. En production avec plusieurs conteneurs distribués, `FEEDBACK_CACHE_BACKEND` doit pointer vers un service Redis ou DatabaseCache partagé.

### 4.2. Sauvegarde & Restauration Physique (Base SQLite réelle et médias)
- **Statut :** **RÉUSSI**
- **Date :** 2026-10-24 12:53 UTC+3
- **Environnement :** Script d'épreuve physique [`docs/test_physical_backup_restore.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/test_physical_backup_restore.py)
- **Protocole exécuté (hors mémoire) :**
  1. Sauvegarde à chaud de la base physique `backend/db.sqlite3` (704 512 octets) et tarball gzip des 36 fichiers médias réels.
  2. Restauration complète vers des cibles physiques séparées (`test_backup_scratch/restored.sqlite3` et dossier média restauré).
  3. Contrôle d'intégrité SQLite : `PRAGMA integrity_check` = `ok` ; `PRAGMA foreign_key_check` = `0 violation`.
  4. **COMPARAISON EXHAUSTIVE :** 100% des 37 tables utilisateur comparées une à une : schémas DDL identiques et 329 enregistrements vérifiés ligne par ligne, strictement identiques au bit près.
  5. Contrôle binaire des médias : 36/36 fichiers médias restaurés à l'identique avec empreinte SHA-256 conforme.
  6. Code retour : `0`.

### 4.3. Mise à jour de l'APK signé & Mode Avion Réel
- **Statut :** **NON EXÉCUTÉ**
- **Environnement requis :** Smartphone Android physique avec version antérieure installée.
- **Protocole à réaliser :**
  - Mise à jour par-dessus l'ancienne version via `adb install -r app-release.apk`.
  - Vérification du maintien des scores, progressions et brouillons stockés dans SharedPreferences.
  - Téléchargement d'un pack d'unité, bascule en mode avion, coupure forcée de l'application, réouverture et complétion de l'unité hors connexion, puis resynchronisation post-reconnexion.

---

## 5. Pilier 4 — Infrastructure de Production & Archives R2/CDN

### 5.1. Proxy inverse, HSTS & Diagnostic HTTPS
- **Statut :** **NON EXÉCUTÉ**
- **Environnement requis :** Instance de préproduction ou serveur Render actif avec compte staff authentifié.
- **Commande à exécuter :**
  ```bash
  # Requiert authentification staff (session ou identifiants autorisés)
  curl -s -i -u "staff_user:password" https://staging.beriyarkedebideri.com/api/core/diagnostics/https/
  ```
- **Vérifications requises :**
  - En-tête `Strict-Transport-Security: max-age=300` (valeur par défaut retenue en production pour la fenêtre de sécurité initiale, avant bascule sur un palier plus long).
  - Réponse JSON confirmant `is_secure: true` et `scheme: "https"`.
  - En-tête `X-Forwarded-Proto` correctement interprété par l'application sans boucle de redirection.

### 5.2. Inventaire et Assainissement des Archives Cloudflare R2 / CDN
- **Statut :** **NON EXÉCUTÉ**
- **Environnement requis :** Accès API / console au bucket Cloudflare R2 / S3 distant.
- **Tâches à exécuter :**
  - Télécharger et inspecter le manifeste `metadata.json` des archives ZIP actuellement publiées sur le CDN.
  - Vérifier l'absence de chemins disques serveurs absolus ou de fichiers brouillons dans les anciens ZIP.
  - Déclencher la commande de régénération des packs pour publier des archives conformes à la spécification A04/A06.
