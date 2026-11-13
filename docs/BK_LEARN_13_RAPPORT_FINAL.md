# Rapport Final — LOT BK-LEARN-13
## Stabilisation du parcours pédagogique audio-first et hors ligne

**Branche :** `fix/bk-learn-13-stabilization` (créée depuis `dev` @ `6ccc389`)  
**Périmètre :** Audit et stabilisation des parcours pédagogiques Flutter hors ligne et audio-first, sans modification du moteur PDF arabe ni des correspondances linguistiques officielles.

---

## 1. Synthèse de l'audit (Phase 1)

| Priorité | Domaine | Statut à l'audit | Constat précis |
| :--- | :--- | :--- | :--- |
| **P1** | Résolution des chemins audio locaux | **Partiellement corrigé (2 anomalies reproduites)** | (a) `OfflineMediaResolver.resolve` traitait les chemins `/media/...` (commençant par `/`) comme des chemins absolus OS au lieu de les résoudre dans `$localPackPath/...`.<br>(b) `CachedContentService._resolveAudioUri` rejetait les chemins bundlés `assets/...` via `_isValidLocalFile` alors que `AudioUrlPlayer.playUrl` supporte `AssetSource`. |
| **P2** | Visibilité des leçons/packs téléchargés hors ligne | **Anomalie reproduite** | Dans `CachedContentService.loadThemes`, `loadUnits` et `loadLessons`, lorsque `online == false` et qu'un cache partiel existait déjà dans `SharedPreferences` (`CacheKeys.*`), `_offlineContentService` n'était jamais fusionné, masquant les packs téléchargés ensuite hors ligne. |
| **P3** | Doublons dans les exercices | **Quasi résolu (1 cas limite reproduit)** | Les quiz et leçons étaient déjà dédupliqués côté `CachedContentService`. En revanche, `LearningUnitModel._generateLocalCoreFlow` utilisait `other ??= (distractors.isNotEmpty ? distractors.first : null)` sans vérifier `d.symbol != c.symbol`. |
| **P4** | Cohérence correction / feedback / score | **Déjà corrigé** | `LearningSession` v2 verrouille `first_correct` par étape ; couvert par `phase3_1_defects_test.dart`. |
| **P5** | Persistance fermeture / réouverture | **Déjà corrigé** | `LearningCoreUnitScreen._persistSession` + `UnitProgressLocalStorage.saveSession`/`restoreSession`. |
| **P6** | Synchronisation sans doublon à la reconnexion | **Déjà corrigé** | `SyncManager.syncAll()` + endpoint Django `progress_for_sync` (upsert atomique idempotent par utilisateur/appareil et unité). |

---

## 2. Correctifs appliqués (Phase 2)

1. **`mobile/lib/features/offline_packs/services/offline_media_resolver.dart`**
   - Résolution des chemins relatifs `/media/...` et `/media\...` vers `$localPackPath/<chemin_relatif>` avant la vérification de chemin absolu OS.
2. **`mobile/lib/core/cache/cached_content_service.dart`**
   - Fusion des contenus issus de `_offlineContentService` avec le cache local dans `loadThemes()`, `loadUnits()` et `loadLessons()` lorsqu'un cache partiel existe hors ligne.
   - Conservation explicite des URI bundlées `assets/...` dans `_resolveAudioUri()`.
3. **`mobile/lib/features/learning/models/learning_unit_model.dart`**
   - Dans `_generateLocalCoreFlow()`, sélection du distracteur de repli uniquement si `d.symbol != c.symbol`.

Aucune modification apportée aux données linguistiques, au moteur PDF arabe expérimental (`experimentalArabicPdfEnabled == false`), ni aux 5 étapes pédagogiques (`Écouter → Reconnaître → Lire → Composer → Réviser`).

---

## 3. Vérification et qualification

### Tests automatisés
- **Analyse statique Flutter (`flutter analyze`) :** `No issues found!`
- **Suite Flutter (`flutter test`) :**
  - Avant lot : **176/176** tests réussis.
  - Après lot : **181/181** tests réussis (176 existants + 5 nouveaux tests ciblés dans `mobile/test/bk_learn_13_stabilization_test.dart`).
- **Suite Django (`python manage.py test`) :** **173** tests exécutés, **2** ignorés (`OK (skipped=2)`), 0 erreur.

### Qualification physique Android — Samsung SM-A336E (`R6CT6003WRT`)
- Exécution isolée avec `--dart-define=BK_TOOLS_QA=true` (identifiant `.qa_tools`, sans impact sur l'application de production) :
  - `flutter test integration_test/bk_learn_13_physical_test.dart -d R6CT6003WRT --dart-define=BK_TOOLS_QA=true` : **1/1 réussi** (`+1: All tests passed!`).
  - Vérifications effectuées sur appareil réel :
    - Garde-fou `BK_TOOLS_QA=true` et `BeriyaPdfService.experimentalArabicPdfEnabled == false`.
    - Résolution `/media/audio/sample.wav` via `OfflineMediaResolver` + lecture/arrêt réel via `AudioUrlPlayer.playUrl()` sur Android.
    - Fusion hors ligne `CachedContentService` avec cache partiel + pack offline.
    - Non-duplication du distracteur dans `LearningUnitModel.effectiveCoreFlow`.
    - Persistance fermeture/réouverture (`LearningSession` + `UnitProgressLocalStorage`) et synchronisation idempotente (`SyncManager.syncAll()`).

---

## 4. Risques résiduels et décision

- **Risques résiduels :**
  - Le test physique `bk_learn_13_physical_test.dart` valide la chaîne hors ligne/audio/persistance avec un pack synthétique et un transport HTTP simulé pour `SyncManager` ; un test de bout en bout contre le serveur de staging lors d'un téléchargement réel de pack reste recommandé avant mise en production.
  - Des avertissements Gradle KGP (`audioplayers_android`, `share_plus`) apparaissent au build debug Android sans bloquer la compilation actuelle.
- **Décision :** **GO** pour revue et intégration locale dans `dev` (aucune fusion, aucun push ni déploiement effectués dans ce lot).
