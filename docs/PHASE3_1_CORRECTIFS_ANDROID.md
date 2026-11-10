# BERIYAR KEDEBIDERI — RAPPORT PHASE 3.1
## Correction et Validation des Quatre Anomalies Android Confirmées

**Date :** 9 novembre 2026  
**Périmètre :** Correctifs ciblés des anomalies `P3-01` à `P3-04` (sans refonte graphique UX/UI globale, sans migration destructive, sans altération des contenus Beřiya/Erfe ni de la base `backend/db.sqlite3`).  
**Cibles de validation :**
1.Suites automatisées : Django (`94/94`), Flutter (`83/83`, `flutter analyze : 0 issue`), JavaScript (`3/3`).
2. Émulateur Android isolé : `Medium_Phone` (`sdk_gphone64_x86_64`, Android 16 / API 36, `emulator-5580`).
3. Téléphone physique réel : **Samsung Galaxy SM-A336E** (`arm64-v8a`, Android 16 / API 36, `1080x2400`, densité `450`, RAM `5,5 Go`).

---

## 1. Causes Racines Identifiées

### Correctif 1 — Résolution des fichiers audio (`P3-01`)
* **Symptôme constaté en Phase 3 :** En mode hors ligne, `CachedContentService.loadUnits()` (ainsi que `loadCharacters()`, `loadWords()`, `loadLessons()`, `loadQuizzes()`) lisait prioritairement le cache JSON d'API (`OnlineContentCacheService` dans `SharedPreferences`) ou le cache mémoire (`MemoryContentCache`) contenant des URLs distantes `http://...`. Comme `cached.isNotEmpty` court-circuitait la lecture d'`OfflineContentService`, l'application passait une URL HTTP distante à `AudioUrlPlayer.playUrl()` hors ligne, provoquant un délai d'attente de 30 secondes puis `AudioPlaybackStatus.failed`.
* **Cause racine :** Absence d'étape de réconciliation entre les entités issues du cache (`OnlineContentCacheService` / `MemoryContentCache`) et les ressources locales extraites des packs installés (`OfflineContentService`), combinée à l'absence de nettoyage du cache mémoire lors de la suppression d'un pack (`LocalPackReaderService.deletePack()`).

### Correctif 2 — Doublons de quiz lors des imports et rafraîchissements (`P3-02`)
* **Symptôme constaté en Phase 3 :** `CachedContentService.loadQuizzes()` accumulait des doublons (`cached_count: 4` pour `unique_ids: 2`) après des rafraîchissements ou réimports successifs.
* **Cause racine :**
  1. Dans `CachedContentService.loadQuizzes()` et `loadLessons()`, lors d'un appel global (`unitSlug == null`), le filtre `where((quiz) => quiz.unitSlug != unitSlug)` conservait toutes les questions existantes (`'premiers-5-caracteres' != null` étant toujours vrai) puis concaténait `[...existing, ...items]` sans déduplication par clé stable.
  2. Dans `LocalPackReaderService.listInstalledPacks()` et `OfflinePackDownloadService.downloadAndExtract()`, les répertoires temporaires (`_staging_`, `_bak_`) ou d'anciennes versions d'un même `slug` pouvaient coexister si un import était interrompu ou mis à jour, et `OfflineContentService.loadThemes()` concaténait les thèmes/unités sans déduplication par clé stable.

### Correctif 3 — Accès aux packs hors ligne depuis le catalogue (`P3-03`)
* **Symptôme constaté en Phase 3 :** L'ouverture de `OfflinePacksScreen` (`/offline-packs`) en mode avion échouait immédiatement et masquait les packs téléchargés ainsi que le bouton « Mes téléchargements ».
* **Cause racine :** `_OfflinePacksScreenState._load()` exécutait `await _apiService.fetchPacks()` sans bloc `try/catch` isolé. En l'absence de réseau, l'exception `SocketException`/`ClientException` faisait basculer le `FutureBuilder` dans la branche `snapshot.hasError`, laquelle n'affichait ni la liste `installedPacks` issue de `LocalPackReaderService.listInstalledPacks()`, ni le bouton d'accès à `MyPacksScreen`.

### Correctif 4 — Cohérence entre le feedback visuel et le score du quiz (`P3-04`)
* **Symptôme constaté en Phase 3 :** Dans `QuizScreen`, une réponse exacte incrémentait le score (`Score provisoire : 1/2`) mais affichait le message d'erreur `« Pas grave, écoute encore et continue. »` (ou inversement).
* **Cause racine :** Divergence entre deux logiques d'évaluation après le mélange aléatoire des options (`_optionOrders`) :
  - `_selectAnswer(displayIndex)` résolvait `originalIndex = order[displayIndex]` et comparait `originalIndex == question.correctIndex` pour incrémenter `_correctCount`.
  - `_QuizQuestionView` et `_AnswerCard` comparaient directement `selectedIndex == correctIndex` (index d'affichage mélangé contre index d'origine non mélangé).

---

## 2. Fichiers Modifiés

| Fichier | Anomalie(s) | Modifications appliquées |
| :--- | :---: | :--- |
| `mobile/lib/core/cache/cached_content_service.dart` | `P3-01`, `P3-02` | Réconciliation systématique des URI audio/médias (`_resolveAudioUri`, `_resolveMediaUri`, `_resolveUnitsMedia`, `_resolveQuizzesMedia`, `_resolveLessonsMedia`, `_resolveCharactersMedia`, `_resolveWordsMedia`) y compris sur les entrées du cache mémoire ; priorité aux fichiers locaux valides (`existsSync() && lengthSync() > 0`) ; préservation du streaming HTTP en ligne lorsqu'aucun fichier local n'existe ; invalidation (`null`) des chemins locaux supprimés/0 octet ou des URLs HTTP hors ligne ; fusion idempotente et auto-réparation sur disque par clé stable (`stableKey`). |
| `mobile/lib/features/quiz/models/quiz_question_model.dart` | `P3-02`, `P3-04` | Ajout de `stableKey` (identité stable primaire `id:<id>` ou composite) et centralisation de l'évaluation des réponses via `evaluateOptionChoice()` (QCM/écoute avec options mélangées) et `evaluateTextAnswer()` (saisie clavier avec rejet strict des réponses vides et préservation exacte des caractères Erfe `U+16EA0..U+16EDF`). |
| `mobile/lib/features/quiz/screens/quiz_screen.dart` | `P3-04` | Utilisation de la source de vérité unique `question.evaluateOptionChoice()` stockée dans `_lastAnswerCorrect` pour piloter simultanément `_correctCount`, l'état de `_AnswerCard` et la bannière de feedback ; positionnement du bandeau de feedback immédiatement visible au-dessus des options après sélection. |
| `mobile/lib/features/learning/screens/learning_core_unit_screen.dart` | `P3-04` | Utilisation de `QuizQuestionModel.evaluateTextAnswer()` pour l'encodage clavier Beřiya (`_buildKeyboardWordCard`) et désactivation de la validation sur saisie vide ou composée uniquement d'espaces. |
| `mobile/lib/features/offline_packs/screens/offline_packs_screen.dart` | `P3-03` | Découplage du chargement local (`listInstalledPacks()`) et du chargement distant (`fetchPacks()`) dans `_load()` ; maintien permanent du bouton « Mes téléchargements », des cartes de packs installés avec badge « Installé » et action « Ouvrir le pack » (`PackDetailScreen`) ; affichage d'un bandeau explicite de mode hors ligne et d'un état vide informatif si aucun pack n'est installé. |
| `mobile/lib/features/offline_packs/services/local_pack_reader_service.dart` | `P3-01`, `P3-02` | Filtrage des répertoires temporaires (`_staging_`, `_bak_`) et des packs non validés ; déduplication par `slug` en conservant la version la plus récente ; purge de `MemoryContentCache` et `ContentSourceState` lors de `deletePack()`. |
| `mobile/lib/features/offline_packs/services/offline_pack_download_service.dart` | `P3-02` | Nettoyage atomique des éventuels répertoires d'anciennes versions ou backups résiduels du même `slug` après validation et renommage du répertoire cible. |
| `mobile/lib/features/offline_packs/services/offline_content_service.dart` | `P3-02` | Déduplication idempotente par clé stable sur `loadCharacters()`, `loadWords()`, `loadThemes()`, `loadUnits()`, `loadLessons()` et `loadQuizzes()`. |
| `mobile/test/phase3_1_defects_test.dart` | `P3-01`..`P3-04` | Suite de 10 tests automatisés couvrant la reproduction et la non-régression des 4 anomalies et de leurs cas limites. |
| `docs/qa_android/phase3_android_test.dart` | `P3-01`..`P3-04` | Ajout de la vérification du double import consécutif du pack `qa-phase3` et du double rafraîchissement du cache de quiz dans le harnais d'intégration Android natif. |

---

## 3. Résultats des Tests Automatisés (Avant / Après)

### 3.1. Tests unitaires et widgets ciblés (`mobile/test/phase3_1_defects_test.dart`)

| Groupe / Test | État avant correction | État après correction |
| :--- | :---: | :---: |
| **P3-01** — Résolution des URLs audio distantes du cache vers les fichiers locaux du pack hors ligne | ÉCHEC (`http://...` conservé) | **SUCCÈS** (chemin local résolu) |
| **P3-01** — Conservation du streaming distant en ligne quand aucun média local n'est présent | SUCCÈS | **SUCCÈS** |
| **P3-01** — Rejet des médias absents, corrompus (0 octet) et supprimés sans chemin local obsolète | ÉCHEC (chemin obsolète en mémoire) | **SUCCÈS** (`null` + `AudioPlaybackStatus.failed`) |
| **P3-02** — Idempotence de `loadQuizzes()` répété (global et filtré par `unitSlug`) | ÉCHEC (`4` entrées pour `2` quiz) | **SUCCÈS** (`2` entrées uniques) |
| **P3-02** — Auto-réparation des doublons existants sur disque et préservation des progressions (`UnitProgressLocalStorage`) | ÉCHEC (doublons persistants) | **SUCCÈS** (cache assaini à `2`, progression intacte à `95 %`) |
| **P3-03** — Catalogue hors ligne : affichage des packs installés, bouton « Ouvrir le pack » et « Mes téléchargements » | ÉCHEC (`ErrorLoading` masquant tout) | **SUCCÈS** |
| **P3-03** — État vide informatif hors ligne lorsqu'aucun pack n'est installé | ÉCHEC | **SUCCÈS** |
| **P3-04** — Cohérence feedback positif (`Correct, très bien !`) et score (`1/1`) sur QCM/écoute avec options mélangées | ÉCHEC (score `1/1` mais feedback négatif) | **SUCCÈS** |
| **P3-04** — Mauvaise réponse (`0/1`) et verrouillage contre les tentatives répétées | SUCCÈS | **SUCCÈS** |
| **P3-04** — Évaluation centralisée des saisies clavier (cas vides, espaces, Unicode Erfe `𖺡𖺣`, rejet d'erreurs linguistiques) | Non centralisé | **SUCCÈS** |

### 3.2. Non-régression globale

| Suite de tests | Commande exécutée | Résultat |
| :--- | :--- | :---: |
| **Flutter (suite complète)** | `flutter test --no-pub` | **83 / 83 réussis** (`0` échec) |
| **Flutter (analyse statique)** | `flutter analyze --no-pub` | **0 problème détecté** (`No issues found!`) |
| **Django (backend complet)** | `backend\venv\Scripts\python.exe docs/run_backend_checks.py` | **94 / 94 réussis** (`System check identified no issues`) |
| **JavaScript (lecteur audio web)** | `node --test backend/webapp/tests_audio_player.cjs` | **3 / 3 réussis** (`0` échec) |

---

## 4. Preuves des Essais Android (Émulateur & Samsung SM-A336E Réel)

Les essais ont été exécutés avec le harnais d'intégration natif `docs/qa_android/phase3_android_test.dart` sur le clone isolé `com.afrigama.beriyarkedebideri.qa`, sans toucher à l'application principale ni à `backend/db.sqlite3`. Les preuves brutes sont archivées dans `docs/qa_android/PHASE3_RESULTS.json`.

| Scénario de recette Android | Émulateur `sdk_gphone64_x86_64` (API 36) | Samsung `SM-A336E` réel (API 36) | Statut |
| :--- | :--- | :--- | :---: |
| **1. `online` — Téléchargement, double import idempotent, lecture audio locale et sauvegarde étape 2** | `pack_download_extract_ms: 829`<br>`pack_reimported_twice_idempotent: true`<br>`native_audio_duration_ms: 4485`<br>`saved_step_before_process_stop: 2` | `pack_download_extract_ms: 962`<br>`pack_reimported_twice_idempotent: true`<br>`native_audio_duration_ms: 4485`<br>`saved_step_before_process_stop: 2` | **PASS** |
| **2. `offline` — Reprise après arrêt forcé en mode avion + tunnel USB coupé, complétion hors ligne** | `restored_step: 2`<br>`offline_completed: true`<br>`offline_score: 100`<br>`offline_sync_rejected_and_local_preserved: true` | `restored_step: 2`<br>`offline_completed: true`<br>`offline_score: 100`<br>`offline_sync_rejected_and_local_preserved: true` | **PASS** |
| **3. `cached_audio` (`P3-01`) — Lecture audio hors ligne via `CachedContentService.loadUnits()`** | `cached_reference_is_remote: false`<br>`native_status: "playing"`<br>`passed: true` | `cached_reference_is_remote: false`<br>`native_status: "playing"`<br>`passed: true` | **PASS** |
| **4. `cached_quizzes` (`P3-02`) — Unicité des quiz en cache hors ligne après réimports et rafraîchissements** | `cached_count: 2`<br>`unique_ids: 2`<br>`passed: true` | `cached_count: 2`<br>`unique_ids: 2`<br>`passed: true` | **PASS** |
| **5. `offline_catalogue` (`P3-03`) — Accès aux packs installés et à « Mes téléchargements » en mode avion** | `installed_packs: 1`<br>`my_downloads_link_present: true`<br>`passed: true` | `installed_packs: 1`<br>`my_downloads_link_present: true`<br>`passed: true` | **PASS** |
| **6. `resync` — Synchronisation après reconnexion, rejet de jeton invalide, protection anti-écrasement** | `sync_success: true`<br>`invalid_token_rejected: true`<br>`stale_update_preserved_score: true`<br>`passed: true` | `sync_success: true`<br>`invalid_token_rejected: true`<br>`stale_update_preserved_score: true`<br>`passed: true` | **PASS** |
| **7. `quiz-check` (`P3-04`) — Cohérence entre score (`1/2`) et feedback positif (`Correct, très bien !`)** | `answer_scored_correct: true`<br>`correct_feedback_displayed: true`<br>`standalone_quiz_resets_after_reopen: true`<br>`passed: true` | `answer_scored_correct: true`<br>`correct_feedback_displayed: true`<br>`standalone_quiz_resets_after_reopen: true`<br>`passed: true` | **PASS** |

### Intégrité de l'environnement et du téléphone physique
* **Base de données source `backend/db.sqlite3` :** SHA-256 avant et après = `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b` (`source_unchanged: true`).
* **État réseau du Samsung SM-A336E restauré et vérifié :** `airplane_mode_on: 0`, `wifi_on: 1`, `mobile_data: 1`, tunnel ADB `tcp:8765` retiré.

---

## 5. Compatibilité avec les Données Existantes

1. **Aucune migration de schéma ni rupture de contrat API :** Les endpoints Django (`/api/learning/`, `/api/quizzes/`, `/api/offline-packs/`, `/api/progress/`) et le format des archives ZIP de packs sont inchangés.
2. **Auto-réparation transparente des caches existants :** Si un appareil disposait déjà d'un cache `SharedPreferences` (`online_cache_quizzes` ou `online_cache_lessons`) contenant des doublons accumulés avant la Phase 3.1, le premier appel à `loadQuizzes()` ou `loadLessons()` déduplique automatiquement la liste par `stableKey` et réécrit la liste assainie sur disque.
3. **Préservation totale des progressions :** `UnitProgressLocalStorage` (`unit_progress_v1`) et les identifiants/jetons d'appareil (`DeviceIdService`) ne sont jamais effacés ni altérés par l'assainissement du cache de contenu.
4. **Intégrité linguistique Beřiya et Unicode Erfe :** Aucune traduction Beřiya ni aucun point de code Erfe (`U+16EA0..U+16EDF`) n'a été modifié.

---

## 6. Risques Résiduels

* **Dédoublonnage binaire des médias à l'intérieur du ZIP de pack (non bloquant, hors périmètre des 4 anomalies) :** Comme noté en Phase 3 (`pack_analysis`), `OfflinePackGenerator` copie un fichier audio par rôle/entité dans l'archive (`3,95 Mo` non compressés pour `791 Ko` uniques dans le pack de test). Cela n'affecte ni la résolution locale ni le fonctionnement hors ligne, mais pourra faire l'objet d'une optimisation de taille d'archive ultérieure.
* **Authentification utilisateur interactive sur mobile :** La synchronisation utilise l'identité d'appareil signée par jeton (`X-Device-Id` / `X-Device-Token`). L'interface de connexion/inscription utilisateur sur mobile reste hors périmètre de cette phase.

---

## 7. Procédure de Retour Arrière (Rollback)

Les correctifs de la Phase 3.1 étant strictement confinés à la couche cliente Flutter (`mobile/lib/` et `mobile/test/`) sans modification de schéma de base de données ni de format de stockage local :
1. Exécuter `git checkout HEAD -- mobile/lib/core/cache/cached_content_service.dart mobile/lib/features/quiz/models/quiz_question_model.dart mobile/lib/features/quiz/screens/quiz_screen.dart mobile/lib/features/learning/screens/learning_core_unit_screen.dart mobile/lib/features/offline_packs/screens/offline_packs_screen.dart mobile/lib/features/offline_packs/services/local_pack_reader_service.dart mobile/lib/features/offline_packs/services/offline_pack_download_service.dart mobile/lib/features/offline_packs/services/offline_content_service.dart` pour restaurer l'état antérieur des fichiers Dart.
2. Aucune opération de migration inverse n'est requise côté serveur Django ni sur les données de progression locales des utilisateurs.

---

## 8. Décision Finale : GO

* **Statut des 4 anomalies Android confirmées (`P3-01`, `P3-02`, `P3-03`, `P3-04`) :** **CORRIGÉES ET VÉRIFIÉES** (tests automatisés + émulateur Android API 36 + Samsung Galaxy SM-A336E réel).
* **Décision pour la suite du programme :** **GO** — Les quatre blocages techniques de la Phase 3 sont levés ; le socle fonctionnel offline-first est validé pour autoriser l'ouverture de la phase suivante.
