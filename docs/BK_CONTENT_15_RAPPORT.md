# BERIYAR KEDEBIDERI — RAPPORT LOT BK-CONTENT-15

**Branche :** `feat/bk-content-15-pilot-courses` (créée depuis `dev` au commit `3f3d9bd`)  
**Statut :** Préparation et intégration contrôlée terminées — **aucune publication automatique, aucun push distant, aucun déploiement**.

---

## 1. Livrables produits

1. **Pack de préproduction versionné** : [`backend/learning/fixtures/bk_preprod_pack_fr_beriya.json`](../backend/learning/fixtures/bk_preprod_pack_fr_beriya.json)
   - `package_id` : `BK_FR_BERIYA_PREPROD_2026_11_13`
   - `public_enabled: false`, `production_import_ready: false`, `status: "DRAFT_REVIEW_REQUIRED"`
   - 14 leçons :
     - **5 leçons pilotes Alphabet Erfe** (`ERF-01`..`ERF-05`, niveau `A0`, 25 lettres `𖺠`..`𖺸` avec correspondances latines `A`..`Y` et références arabes)
     - **6 leçons brouillons Lecture de phrases** (`P01`..`P06`, niveaux `A2` à `B1-B2`, 30 phrases issues de `corpus_en_français_beriya.xlsx / Feuille 1`)
     - **3 leçons brouillons Lexique DF/ADES 2007** (`V01`..`V03`, niveau `A1-A2`, 18 lexèmes issus de `Dictionnaire_Beriya_Lexique_structure_extraction_v2.xlsx`, avec `beriya_erfe: null` conservé sans conversion automatique)
   - 219 exercices (`73 mcq`, `73 listen_select`, `73 listen_type`), tous désactivés par défaut (`enabled: false`, `status: "PREPROD_A_VALIDER"`), 0 fichier audio factice.

2. **Cartographie JSON → Django & Flutter** : [`docs/BK_CONTENT_15_MAPPING.md`](BK_CONTENT_15_MAPPING.md)
   - Réutilisation stricte des modèles existants (`LearningTheme`, `LearningUnit`, `Lesson`, `LessonItem`, `Character`, `Word`, `WordCategory`, `QuizQuestion`, `QuizOption`) sans création de nouveau modèle.
   - Visibilité publique protégée par le mécanisme existant `is_staff_preview` (`status='draft'`, `validation_status='draft'`, `is_active=False` sur les exercices sans audio).

3. **Importateur Django idempotent et atomique** : [`backend/learning/management/commands/import_preprod_courses.py`](../backend/learning/management/commands/import_preprod_courses.py)
   - Options : `--file`, `--dry-run` (rollback transactionnel complet), `--tracks`.
   - Protections :
     - Aucune suppression implicite.
     - Aucun écrasement de contenus déjà sortis du statut `draft` ou marqués `pedagogy_config["human_edited"] == True`.
     - Rejet explicite des contenus non conformes (ex. `public_enabled=true` en préproduction ou publication audio sans fichier audio).
     - Rapport structuré (`created`, `skipped_existing`, `skipped_protected`, `rejected`).

4. **Tableau de validation linguistique humaine** : [`docs/BK_CONTENT_15_VALIDATION_LINGUISTIQUE.csv`](BK_CONTENT_15_VALIDATION_LINGUISTIQUE.csv)
   - Couvre les 73 items (25 lettres + 30 phrases + 18 lexèmes) avec les colonnes sources et le statut humain initial `À vérifier` (aucun item marqué `Prêt pour publication`).

---

## 2. Anomalies sources documentées (sans modification automatique des sources)

D'après l'audit du classeur `BK_audit_et_cours_preproduction_2026-11-13.xlsx` (`Vue generale`, `Anomalies`) :
- Corpus : 321 phrases Erfe, 320 phrases françaises (ligne 67 manquante `FR_ABSENT`), ligne 55 contenant `U+16EC6` (`ERFE_NON_MAPPE_U+16EC6`), espaces doubles (lignes 4, 80, 147, 179), jetons latins dans Erfe (`GPU`, `5G`, etc.).
- Glossaire annexe : 82 entrées dont 53 formules `AI()` non reproductibles (51 arabe + 2 français).
- Lexique v2 : 1 513 entrées (`NON VÉRIFIÉ NATIF`), 1 725 formes, 43 groupes d'homographes (jamais fusionnés automatiquement).
- Audio : 0 fichier audio fourni (`A_ENREGISTRER`).

---

## 3. Vérifications exécutées et résultats

- **Tests d'import Django (`learning.tests_import_preprod`)** : 4/4 réussis (`--dry-run` sans persistance, import complet en `draft` + idempotence, protection des modifications humaines, rejet des données non conformes).
- **Suite complète Django (`manage.py test`)** : 177 tests exécutés, 175 réussis, 2 ignorés (`OK (skipped=2)`), `System check identified no issues (0 silenced)`.
- **Analyse statique Flutter (`flutter analyze`)** : `No issues found!`.
- **Tests Flutter ciblés (`test/preprod_pilot_courses_qualification_test.dart`)** : 2/2 réussis (25 lettres Erfe des 5 leçons pilotes `ERF-01`..`ERF-05` sans doublon en `draft`, `effectiveCoreFlow`, rendu et saisie sur `BeriyaKeyboard`).
- **Suite complète Flutter (`flutter test`)** : 183/183 réussis (`All tests passed!`).
- **Appareil Android physique (`adb devices -l`)** : Samsung SM-A336E (`R6CT6003WRT`) détecté (`device`), non déployé conformément aux consignes de non-déploiement.
