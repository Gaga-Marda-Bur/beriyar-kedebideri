# BK-AUTH-PILOT-01 — Rapport Final : Authentification mobile et déblocage du pilote privé Erfe V1

**Branche :** `dev` (base `dcc48a4`)  
**Appareil physique qualifié :** Samsung SM-A336E (`R6CT6003WRT`)  
**Décision :** **GO — Pilote privé Erfe V1 débloqué et qualifié**

---

## 1. Résumé exécutif

Le client mobile Flutter ne transmettait auparavant aucune identité apprenant à l'API pédagogique Django, ce qui bloquait l'accès au catalogue du pilote privé `pilot_erfe_v1` (« Aucun thème disponible »).

L'authentification apprenant a été implémentée de manière minimale et sécurisée en réutilisant le mécanisme natif **Django Session + CSRF** déjà présent dans le backend, sans introduire d'architecture parallèle (ni JWT, ni `SharedPreferences` non chiffré), et sans modifier le transport de monétisation existant.

---

## 2. Choix techniques et architecture

### 2.1 Backend Django
- **Endpoints ajoutés dans `backend/core/auth_views.py` et `backend/core/urls.py` (`LearnerAuthView`) :**
  - `GET /api/auth/csrf/` : émission du cookie CSRF.
  - `POST /api/auth/login/` : authentification par session Django, protégée par `csrf_protect` et `LearnerLoginThrottle` (`15/min`), avec `Cache-Control: private, no-store` et `Vary: Cookie`. Retourne l'état apprenant vérifié côté serveur (`is_pilot`, `is_staff`).
  - `POST /api/auth/logout/` : fermeture de session côté serveur.
  - `GET /api/auth/me/` : vérification de session courante et des droits (`is_pilot`, `is_staff`).
- **Autorisations :** Aucune confiance accordée à des indicateurs côté client ; l'appartenance au groupe `pilot_erfe_v1` reste vérifiée exclusivement côté serveur.

### 2.2 Stockage sécurisé Android & Client Flutter
- **Coffre Android dédié (`LearnerAuthVaultChannel.kt`) :**
  - Canal `MethodChannel("bk/learner_auth_v1")` enregistré dans `MainActivity.kt`, distinct de `CommerceVaultChannel` (`bk/commerce_v1`).
  - Chiffrement via `AndroidKeyStore` (`bk-learner-auth-vault-v1`, `AES/GCM/NoPadding`) et écriture atomique (`AtomicFile`) dans `noBackupFilesDir`.
- **Service d'authentification (`mobile/lib/core/auth/learner_auth_service.dart` & `learner_auth_vault.dart`) :**
  - Restauration de session au démarrage dans `main.dart` (`await LearnerAuthService.instance.restore()`).
  - Vérification HTTPS (HTTP autorisé uniquement en debug sur loopback).
  - Aucun mot de passe, cookie ou jeton n'est journalisé.
  - En cas de perte réseau lors de `refreshSession()`, la session locale est conservée pour préserver l'usage hors ligne ; en cas de `401`, la session expire et le coffre est vidé.
- **Intégration `ApiClient` (`mobile/lib/core/api/api_client.dart`) :**
  - Injection de `Cookie` sur `getMap`, et de `Cookie` + `X-CSRFToken` + `Origin` sur `postMap`.
  - Gestion de `401` (`handleUnauthorized()` + `ApiRequestException(401, ...)`) et `403` (`ApiRequestException(403, ...)` sans déconnexion).
- **Isolation de la synchronisation (`mobile/lib/features/progress/services/unit_progress_sync_service.dart`) :**
  - Lorsque l'apprenant est authentifié, `device_id` et `device_token` invité sont omis afin que Django attribue la progression à `account:{user.pk}` et évite les collisions `ProgressDeviceCredential` lors des changements de compte sur un même téléphone.
- **Nettoyage lors de la déconnexion / changement de compte (`mobile/lib/core/auth/learner_session_cleanup.dart`) :**
  - `LearnerSessionCleanup.clearUserSessionData()` purge `MemoryContentCache`, `OnlineContentCacheService`, `bk_unit_progress_*`, `bk_learning_session_*`, `bk_learning_history_*`, `bk_srs_v1_*` et `AppDirectories.getPacksDirectory()` uniquement sur déconnexion explicite ou changement de compte (jamais sur coupure réseau).
- **Interface utilisateur (`mobile/lib/features/auth/screens/learner_login_screen.dart`, `app.dart`, `settings_screen.dart`) :**
  - Route `/login` avec `LearnerLoginScreen` (vidage de cache et `AppPreloadService.instance.resetAndPreloadAgain()` à la connexion).
  - Carte `_LearnerAccountCard` dans `Paramètres` affichant l'identité, le statut vérifié serveur (`Accès pilote Erfe V1 actif (vérifié serveur)` ou `Compte standard`), et les actions `Se connecter` / `Se déconnecter`.

---

## 3. Limite connue : révocation hors ligne

En mode strictement hors ligne (avion ou perte réseau totale), les contenus et packs déjà téléchargés et mis en cache localement restent lisibles jusqu'à la prochaine reconnexion réseau déclenchant `refreshSession()` ou une déconnexion explicite, ou jusqu'à un appel API retournant `401`/`403`. Dès le retour du réseau, la révocation côté serveur est appliquée immédiatement.

---

## 4. Résultats des tests automatisés

- **Django (suite complète) :** `.\venv\Scripts\python.exe manage.py test`
  - `Ran 190 tests in 70.867s` — `OK (skipped=2)` — `System check identified no issues (0 silenced).`
  - Inclut `backend/core/tests_auth.py` (4 tests couvrant cycle auth, rejet anonyme/utilisateur standard même avec indices client, périmètre pilote + révocation, et accès staff).
- **Flutter :**
  - `flutter analyze` : `No issues found! (ran in 12.9s)`
  - `flutter test` : `193` tests réussis (`All tests passed!`), incluant `mobile/test/learner_auth_test.dart` (4 tests unitaires et widgets).

---

## 5. Qualification physique sur Samsung SM-A336E (`R6CT6003WRT`)

Qualification réalisée dans un environnement QA isolé (`com.afrigama.beriyarkedebideri.qa_tools`, serveur `qa_pilot_server.py`, comptes `pilot_qa_1` et `ordinary_qa_1`, 5 unités pilote `validated`, 6e unité `validated` hors pilote `bk-hors-pilote-06`, 9 unités `draft` `P01..P06` / `V01..V03`) :

1. **Connexion pilote (`pilot_qa_1`) :**
   - `Paramètres` affiche `Connecté en tant que pilot_qa_1` et `Accès pilote Erfe V1 actif (vérifié serveur)`.
   - `Leçons` affiche `0 / 5 unités validées`, le thème `Alphabet Erfe (Préproduction)` (`5 unités`), `Alphabet Erfe — groupe 1` (`Disponible`), sans aucune fuite de `bk-hors-pilote-06` ni des brouillons `P01..P06` / `V01..V03`.
2. **Parcours pédagogique hors ligne complet (`ERF-01`) :**
   - Wi-Fi et données mobiles désactivés, `adb reverse --remove-all` exécuté.
   - Réalisation des 12 étapes de `ERF-01` avec erreur volontaire à l'étape 2/12 (`Réponse à réessayer`), réponses correctes, saisie clavier Erfe (`𖺠` + `Valider` à l'étape 11/12), bilan à 12/12 (`68% · Seuil 70%`, `À réviser`, `Éléments réussis (3)`, `Éléments à consolider (3)`), et ouverture de `Séance de révision espacée (6)` (`Révision SRS (1/6)`).
3. **Continuité après arrêt complet du processus OS :**
   - `am force-stop com.afrigama.beriyarkedebideri.qa_tools` puis relance hors ligne : restauration de `EN COURS • 92%` (`Alphabet Erfe — groupe 1`) et `Vos 6 élément(s) mémorisé(s) sont à jour.`, sans nouvelle demande de connexion.
4. **Resynchronisation idempotente au retour réseau :**
   - Réactivation Wi-Fi + `adb reverse tcp:8010 tcp:8010`, deux appuis successifs sur `Synchroniser maintenant` : `Synchronisation réussie • Éléments synchronisés: 1`.
   - Vérification SQLite (`qa_pilot_db.sqlite3`) : 1 seule ligne `[('pilot_qa_1', 'bk-preprod-erf-01', 'account:1', 'started', 0, None, 0)]` (aucun doublon).
5. **Déconnexion et changement vers compte standard (`ordinary_qa_1`) :**
   - Après `Se déconnecter` (`Déconnecté`) puis connexion avec `ordinary_qa_1` : `Paramètres` affiche `Connecté en tant que ordinary_qa_1` / `Compte standard`, l'accueil affiche `Aucun élément étudié pour le moment.`, et `Leçons` affiche `Aucun thème disponible.`.

---

## 6. Décision finale

**GO** pour le pilote privé Alphabet Erfe V1 (`ERF-01` à `ERF-05`), sans publication publique ni déploiement automatique.
