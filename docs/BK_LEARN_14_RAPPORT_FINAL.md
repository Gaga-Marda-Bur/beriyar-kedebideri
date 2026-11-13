# Rapport Final — LOT BK-LEARN-14
## Fusion contrôlée et qualification pédagogique de bout en bout

**Branche active :** `dev` (commit de fusion `b60a6df` depuis `fix/bk-learn-13-stabilization`)  
**Branche de sauvegarde locale :** `backup/pre-bk-learn-14` (`6ccc389`)  
**Appareil physique :** Samsung SM-A336E (`R6CT6003WRT`), profil QA isolé (`--dart-define=BK_TOOLS_QA=true`, `com.afrigama.beriyarkedebideri.qa_tools`)

---

## 1. Audit final et durcissement pré-fusion (Phase 1)

Un audit complémentaire des correctifs de BK-LEARN-13 a permis d'appliquer un durcissement ciblé sur `OfflineMediaResolver.resolve` (`mobile/lib/features/offline_packs/services/offline_media_resolver.dart`) :
- **Protection contre la traversée de répertoire :** rejet (`null`) des segments `..` et de tout chemin absolu pointant en dehors de `localPackPath`.
- **Compatibilité `assets/` :** préservation explicite des URI bundlées `assets/...` dans `OfflineMediaResolver.resolve` et `CachedContentService._resolveAudioUri`.
- **Conservation des séparateurs locaux :** préservation du chemin `localPackPath` d'origine lors de la concaténation tout en normalisant la vérification de confinement.
- **Priorité déterministe & déduplication :** dans `CachedContentService`, le pack hors ligne est chargé puis fusionné avec le cache local (`cached` prioritaire à clé identique, leçons dédupliquées via `_lessonStableKey`, thèmes et unités triés par `orderIndex`).
- **Non-duplication des distracteurs :** dans `LearningUnitModel._generateLocalCoreFlow`, aucun distracteur portant le même symbole que le caractère cible n'est sélectionné ; si aucun autre symbole n'est disponible, l'étape `discrimination` est omise.

---

## 2. État Git et fichiers fusionnés (Phases 2 & 3)

- **Commits sur `fix/bk-learn-13-stabilization` :**
  - `ead2f5e` — `fix(learning): stabilize offline media resolution, catalog merge and distractor selection (BK-LEARN-13)`
  - `ae829c6` — `test(learning): add BK-LEARN-13 stabilization and Samsung physical QA tests`
  - `9fd8097` — `docs(qa): add BK-LEARN-13 final stabilization report`
- **Fusion locale dans `dev` :** `b60a6df` (`merge: integrate BK-LEARN-13 audio-first and offline learning stabilization`, sans push ni déploiement).
- **Fichiers fusionnés :**
  - `mobile/lib/features/offline_packs/services/offline_media_resolver.dart`
  - `mobile/lib/core/cache/cached_content_service.dart`
  - `mobile/lib/features/learning/models/learning_unit_model.dart`
  - `mobile/test/bk_learn_13_stabilization_test.dart`
  - `mobile/integration_test/bk_learn_13_physical_test.dart`
  - `docs/BK_LEARN_13_RAPPORT_FINAL.md`
- **Ajout de qualification BK-LEARN-14 :**
  - `mobile/integration_test/bk_learn_14_e2e_physical_test.dart`
  - `docs/BK_LEARN_14_RAPPORT_FINAL.md`

Aucune modification apportée au moteur PDF arabe (`experimentalArabicPdfEnabled == false`), aux traductions Beřiya, ni aux contenus pédagogiques publiés.

---

## 3. Qualification pédagogique sur Samsung SM-A336E (Phase 4)

Exécution de `flutter test integration_test/bk_learn_14_e2e_physical_test.dart -d R6CT6003WRT --dart-define=BK_TOOLS_QA=true` avec Wi-Fi et données mobiles désactivés via ADB (`svc wifi disable`, `svc data disable`) : **1/1 réussi (`00:15 +1: All tests passed!`)**.

| Étape | Scénario | Statut réel | Détail d'exécution |
| :---: | :--- | :--- | :--- |
| 1 | Ouvrir le catalogue | **RÉUSSI** | Chargement `CachedContentService` (thèmes, unités, leçons) |
| 2 | Télécharger une leçon et ses ressources audio | **PARTIEL (local)** | Téléchargement HTTP loopback (`127.0.0.1`) + extraction ZIP `LocalPackReaderService` ; téléchargement serveur distant : **NON TESTÉ** |
| 3 | Désactiver Wi-Fi et données mobiles | **RÉUSSI** | Radio Wi-Fi et données mobiles coupées via ADB |
| 4 | Fermer et rouvrir l'application | **SIMULÉ** | Vidage `MemoryContentCache` + remontage widget (kill/relance OS : **NON TESTÉ**) |
| 5 | Retrouver la leçon téléchargée | **RÉUSSI** | Fusion cache partiel + pack disque (`u-qa-14`, `l-qa-14`) |
| 6 | Écouter un fichier audio local | **RÉUSSI** | Lecture réelle Android via `AudioUrlPlayer.playUrl` sur `audio/a.wav` extrait |
| 7 | Parcourir les étapes pédagogiques | **PARTIEL** | UI réelle `LearningCoreUnitScreen` parcourue sur `Écouter` (`discovery`), `Reconnaître` (`discrimination`), `Composer` (`keyboard_encoding`) et `Terminer` ; `Lire` (`word_decoding`) et `Réviser` (`SrsReviewSessionScreen`) non inclus dans ce `core_flow` minimal (**NON TESTÉ en E2E UI**) |
| 8 | Terminer sans doublons involontaires | **RÉUSSI** | Unité terminée sans doublon |
| 9 | Cohérence réponses et score | **RÉUSSI** | `bestScorePercent == 100`, `completed == true` |
| 10 | Fermer et rouvrir l'application | **SIMULÉ** | Démontage widget + vidage `MemoryContentCache` |
| 11 | Retrouver la progression | **RÉUSSI** | `UnitProgressLocalStorage.getProgress` + `restoreSession` (`finished == true`) |
| 12 | Réactiver connexion & sync sans doublon | **PARTIEL (mock)** | `SyncManager.syncAll()` x2 sans doublon via `MockClient` ; sync serveur distant réel : **NON TESTÉ** |

---

## 4. Tests post-fusion sur `dev` (Phase 5)

- **`flutter analyze` :** `No issues found!`
- **`flutter test` :** **181/181 tests réussis** (incluant `bk_learn_13_stabilization_test.dart`, `offline_learning_audio_test.dart`, `phase3_1_defects_test.dart`, `unit_progress_sync_service_test.dart`).
- **Django (`backend\venv\Scripts\python.exe manage.py test`) :** **173 tests exécutés, 2 ignorés** (`OK (skipped=2)`).

---

## 5. État des composants et décision

- **Catalogue hors ligne :** Opérationnel et déterministe même en présence d'un cache partiel.
- **Audio local :** Résolution sécurisée (`/media/`, `media/`, `assets/`, confinement dans `localPackPath`) et lecture Android vérifiée.
- **Progression et synchronisation :** Persistance locale et idempotence client/serveur vérifiées.
- **Anomalies résiduelles :**
  - Les scénarios marqués **NON TESTÉ** ci-dessus (téléchargement/sync contre serveur distant de staging, kill/relance OS complet, parcours UI `word_decoding` + `SrsReviewSessionScreen` sur appareil) restent à valider lors d'une passe QA manuelle ou staging avant mise en production.
  - Avertissements Gradle KGP (`audioplayers_android`, `share_plus`) sans impact sur le build actuel.
- **Décision :** **GO** pour la stabilité pédagogique locale sur `dev` (sous réserve de la passe staging manuelle avant tout déploiement production). Aucun push ni déploiement effectués.
