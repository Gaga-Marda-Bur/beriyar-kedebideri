# BK-CONTENT-15 — Cartographie JSON → Modèles Django & Flutter

Ce document décrit la correspondance exacte entre le pack de préproduction `BK_pack_cours_preproduction_fr_beriya.json` (`schema_version: "bk-preproduction-0.1"`, copié dans `backend/learning/fixtures/bk_preprod_pack_fr_beriya.json`) et les modèles existants de Django et Flutter, **sans création de nouveaux modèles inutiles**.

---

## 1. Principes de conception

1. **Réutilisation stricte des modèles existants** : `LearningTheme`, `LearningUnit`, `Lesson`, `LessonItem`, `Character`, `Word`, `WordCategory`, `QuizQuestion`, `QuizOption`, `AudioAsset`.
2. **Non-publication par défaut** : tout élément importé reçoit `status = 'draft'` (ou `validation_status = 'draft'`) et les exercices sans audio authentique restent `is_active = False` et `status = 'draft'`. La visibilité publique Django (`is_staff_preview`) exclut automatiquement ces contenus tant qu'ils ne sont pas validés et publiés manuellement.
3. **Intégrité linguistique** :
   - Aucune traduction Beřiya inventée.
   - Aucune translittération automatique DF/ADES 2007 → Erfe (`beriya_erfe = null` conservé).
   - Aucun audio factice (`audio_path = null` → `AudioAsset` non créé ; `QuizQuestion.clean()` bloque déjà toute publication d'un quiz audio sans `AudioAsset` publié).
4. **Identifiants stables et idempotence** : chaque entité reçoit un `slug` déterministe préfixé par `bk-preprod-` ou un marqueur `[bk_id:<ID>]` dans `explanation_fr` / `pedagogy_config`.

---

## 2. Correspondance JSON → Modèles Django

### 2.1 Parcours (`track`) → `LearningTheme` (`backend/learning/models.py`)

| `track` JSON | `LearningTheme.slug` | `title_fr` | `level` | `order_index` | `status` |
|---|---|---|---|---|---|
| `ALPHABET_ERFE` | `bk-preprod-alphabet-erfe` | `Alphabet Erfe (Préproduction)` | `beginner` | `101` | `draft` |
| `LECTURE_PHRASES` | `bk-preprod-lecture-phrases` | `Lecture de phrases (Préproduction)` | `intermediate` | `102` | `draft` |
| `LEXIQUE_LATIN_SOURCE` | `bk-preprod-lexique-latin-source` | `Lexique DF/ADES 2007 (Préproduction)` | `beginner` | `103` | `draft` |

### 2.2 Leçons (`lessons[]`) → `LearningUnit` + `Lesson` (`backend/learning/models.py`, `backend/lessons/models.py`)

Pour chaque objet `lesson` dans `pack["lessons"]` (`ERF-01`..`ERF-05`, `P01`..`P06`, `V01`..`V03`) :

| Champ JSON | Modèle & champ Django | Règle de mapping |
|---|---|---|
| `lesson.id` (ex. `ERF-01`) | `LearningUnit.slug` & `Lesson.slug` | `bk-preprod-{lesson.id.lower()}` (ex. `bk-preprod-erf-01`) |
| `lesson.title` | `LearningUnit.title_fr` & `Lesson.title_fr` | Copie exacte |
| `lesson.objective` | `LearningUnit.description_fr` & `Lesson.description_fr` | Copie exacte |
| `lesson.level` | `LearningUnit.level` & `Lesson.level` | `A0` / `A1-A2` / `A2` → `beginner` ; `A2-B1` / `B1` / `B1-B2` → `intermediate` |
| `lesson.status` / `public_enabled` | `LearningUnit.status` & `Lesson.status` | Toujours forcé à `'draft'` (même si `public_enabled: false`) |
| Ordre dans le pack | `LearningUnit.order_index` & `Lesson.order_index` | Index séquentiel par parcours (`1..5`, `1..6`, `1..3`) |
| Métadonnées | `LearningUnit.pedagogy_config` | `{"preprod_id": ..., "track": ..., "cefr_level": ..., "source_package_id": ..., "audio_status": "A_ENREGISTRER", "publication_blocked": true, "human_edited": false}` |

### 2.3 Contenus (`lesson.items[]`) → `Character`, `Word`, `LessonItem`

#### Cas A : `item.kind == "alphabet"` (`ERF-01`..`ERF-05`, 25 lettres)

| Champ JSON | Modèle & champ Django | Règle de mapping |
|---|---|---|
| `item.beriya_erfe` | `Character.symbol` | Clé de correspondance (`get_or_create` sur `symbol`). Ne modifie jamais un `Character` déjà `validated` ou `published`. |
| `ord(item.beriya_erfe)` | `Character.unicode_code` | `U+{ord:04X}` (ex. `U+16EA0`) |
| `item.beriya_latin` | `Character.latin_transcription`, `latin_grapheme` | Conservé tel quel (`A`..`Y`), `latin_grapheme = item.beriya_latin.lower()` |
| `item.arabic_reference` | `Character.arabic_transcription` | Conservé tel quel |
| `item.french` | `LessonItem.title_fr` | Ex. `Lettre latine A` |
| `item.id`, `source_ref`, `notes` | `LessonItem.explanation_fr` | `[bk_id:{item.id}] {notes} (Source: {source_ref})` |
| Liaison unité | `LearningUnit.characters` | Ajouté au M2M `characters` de l'unité |
| `item_type` | `LessonItem.item_type` | `LessonItem.CHARACTER` |

#### Cas B : `item.kind == "phrase"` (`P01`..`P06`, 30 phrases)

| Champ JSON | Modèle & champ Django | Règle de mapping |
|---|---|---|
| `item.beriya_erfe` | `Word.beriya_text` | Conservé à l'identique (aucune correction automatique) |
| `item.french` | `Word.french_translation`, `LessonItem.title_fr` | Copie exacte |
| `item.beriya_latin` | `Word.latin_transcription` | `item.beriya_latin or ''` |
| `Word.category` | `WordCategory` (`slug='bk-preprod-phrases'`) | Catégorie dédiée préproduction |
| `Word.validation_status` | `Word.DRAFT` | Toujours `'draft'` |
| `item.id`, `source_ref`, `source_row`, `notes` | `Word.notes`, `LessonItem.explanation_fr` | `[bk_id:{item.id}] Source: {source_ref} (row {source_row}) — {notes}` |
| Liaison unité | `LearningUnit.words` & `LessonItem.word` | Ajouté au M2M `words`, `LessonItem.item_type = LessonItem.WORD` |

#### Cas C : `item.kind == "lexique"` (`V01`..`V03`, 18 lexèmes DF/ADES 2007)

| Champ JSON | Modèle & champ Django | Règle de mapping |
|---|---|---|
| `item.beriya_latin` | `Word.latin_transcription`, `Word.beriya_text` | Orthographe DF/ADES 2007 conservée ; `beriya_erfe = null` respecté (aucune conversion automatique en Erfe) |
| `item.french` | `Word.french_translation`, `LessonItem.title_fr` | Copie exacte |
| `Word.category` | `WordCategory` (`slug='bk-preprod-lexique-df-ades'`) | Catégorie dédiée préproduction |
| `Word.validation_status` | `Word.DRAFT` | Toujours `'draft'` |
| `item.id`, `source_ref`, `notes` | `Word.notes`, `LessonItem.explanation_fr` | `[bk_id:{item.id}] Orthographe DF/ADES 2007 (Erfe non généré) — Source: {source_ref}` |

### 2.4 Exercices (`pack["exercises"]`) → `QuizQuestion` + `QuizOption` (`backend/quizzes/models.py`)

| Champ JSON | Modèle & champ Django | Règle de mapping |
|---|---|---|
| `ex.type == "mcq"` | `QuizQuestion.question_type` | `QuizQuestion.TEXT_TO_CHARACTER` |
| `ex.type == "listen_select"` | `QuizQuestion.question_type` | `QuizQuestion.AUDIO_TO_CHARACTER` |
| `ex.type == "listen_type"` | `QuizQuestion.question_type` | `QuizQuestion.GUIDED_KEYBOARD` |
| `ex.prompt` | `QuizQuestion.prompt_fr` | Copie exacte |
| `ex.expected_text` | `QuizQuestion.correct_text_answer` | `ex.expected_text or ''` |
| `ex.enabled` (`false`) | `QuizQuestion.is_active` & `status` | `is_active = False`, `status = QuizQuestion.DRAFT` |
| `ex.id`, `ex.disabled_reason`, `ex.source_ref` | `QuizQuestion.explanation_fr` | `[bk_id:{ex.id}] {disabled_reason} (Source: {source_ref})` |
| `ex.options[]` / `ex.correct_index` | `QuizOption` | `text_fr = opt`, `is_correct = (idx == ex.correct_index)`, `order_index = idx + 1` |

---

## 3. Correspondance Django → Modèles Flutter

Les modèles Flutter existants consomment directement les API et les packs hors ligne (`OfflinePackGenerator` v2) sans modification de schéma :

- `LearningThemeModel` (`mobile/lib/features/learning/models/learning_theme_model.dart`) ← `LearningThemeSerializer` / `themes.json`
- `LearningUnitModel` (`mobile/lib/features/learning/models/learning_unit_model.dart`) ← `LearningUnitSerializer` / `units.json` (`effectiveCoreFlow` génère localement le flux si `coreFlow` est vide)
- `LessonModel` & `LessonItemModel` (`mobile/lib/features/lessons/models/lesson_model.dart`) ← `LessonSerializer` / `lessons.json`
- `QuizQuestionModel` & `QuizOptionModel` (`mobile/lib/features/quiz/models/quiz_question_model.dart`) ← `QuizQuestionSerializer` / `quizzes.json`
- `UnitProgress` / `ProgressSyncService` ← synchronisés par `unit.id` / `unit.slug`
