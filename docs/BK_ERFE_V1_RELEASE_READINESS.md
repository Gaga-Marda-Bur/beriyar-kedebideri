# BK-ERFE-V1 — Release Readiness (Qualification finale utilisateur sans audio)

**Date :** 2026-11-14  
**Branche :** `dev` (base `fb6f623`)  
**Périmètre :** Parcours Alphabet Erfe V1 (`ERF-01` à `ERF-05`, 25 lettres Erfe)  
**Statut actuel :** `validated` (`CANDIDAT_SANS_AUDIO`) — **non publié, non déployé, aucun push distant**

---

## 1. Activités réellement disponibles sans audio

### A. Parcours cœur des unités (`LearningUnit` — `ERF-01` à `ERF-05`)
Chaque leçon (`bk-preprod-erf-01` .. `bk-preprod-erf-05`) génère **12 étapes** entièrement fonctionnelles sans audio (soit **60 étapes** sur les 5 leçons) :
- **Découverte (`discovery`)** — 5 étapes/leçon (25 au total) : affiche la lettre Erfe et l'indice latin (`Découvre la lettre « {latin_hint} » ({symbol})`).
- **Discrimination visuelle (`discrimination`)** — 5 étapes/leçon (25 au total) : affiche la consigne latine (`Touche la lettre Erfe correspondant à « {latin_hint} »`) et les cartes Erfe cliquables.
- **Saisie au clavier Erfe (`keyboard_encoding`)** — 1 étape/leçon (5 au total) : utilise `BeriyaKeyboard` (`scaffoldedKeys` des 5 lettres de la leçon) avec consigne textuelle (`Écris la lettre « {latin_hint} » au clavier Erfe :`). **Autorisé sans audio.**
- **Bilan (`celebration`)** — 1 étape/leçon (5 au total) : récapitulatif et calcul du score (`50 %` reconnaissance + `50 %` encodage clavier).

### B. Quiz (`QuizQuestion` — `ERF-01` à `ERF-05`)
L'audit du pack de préproduction (`75` exercices `ERF-01`..`ERF-05`) confirme :
- **`TEXT_TO_CHARACTER` (`mcq`, 25 exercices)** : **ACTIVÉS** (`status='validated'`, `is_active=True`). Contiennent la lettre Erfe dans l'énoncé et 4 choix latins ; fonctionnent à 100 % sans audio.
- **`AUDIO_TO_CHARACTER` (`listen_select`, 25 exercices)** : **MAINTENUS DÉSACTIVÉS** (`status='draft'`, `is_active=False`). Énoncé `"Écoute puis sélectionne la bonne réponse."`, `stimulus=null`, `audio_path=null` : nécessitent réellement un fichier audio.
- **`GUIDED_KEYBOARD` (`listen_type`, 25 exercices)** : **MAINTENUS DÉSACTIVÉS** (`status='draft'`, `is_active=False`). Bien que `QuizQuestionModel.requiresAudio` ne classe pas `guided_keyboard` comme audio par défaut, les 25 items `listen_type` de `ERF-01`..`ERF-05` ont `prompt="Écoute puis écris la réponse."`, `stimulus=null`, `audio_path=null` : sans son, l'apprenant ne sait pas quelle lettre saisir. Ils restent donc désactivés tant que les audios ne sont pas enregistrés (la pratique clavier sans audio est assurée par `keyboard_encoding` dans le parcours cœur).

---

## 2. Résultats des tests utilisateurs simulés (environnement QA isolé)

| Scénario simulé | Outil / Environnement | Résultat observé |
| :--- | :--- | :--- |
| **Parcours complet apprenant débutant sur `ERF-01`** (ouverture UI `LearningCoreUnitScreen`, `discovery`, `discrimination`, fermeture à mi-parcours, réouverture et reprise hors ligne, clavier `BeriyaKeyboard`, `Valider`, `5. RÉVISER` / `Terminer`, score `100 %` dans `UnitProgressLocalStorage`) | Flutter Widget Test ([bk_erfe_v1_user_qualification_test.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/test/bk_erfe_v1_user_qualification_test.dart)) | **PASS** (`2/2` tests du fichier réussis) |
| **Contrôles complets `ERF-01` à `ERF-05`** (12 étapes × 5 leçons, sauvegarde/reprise hors ligne `SharedPreferences`, score `100 %`, `completed=true`) | Flutter Test ([bk_erfe_v1_user_qualification_test.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/test/bk_erfe_v1_user_qualification_test.dart)) | **PASS** (5/5 unités validées) |
| **Préparation des futurs audios** (ajout d'un `AudioAsset` `published` + `CharacterAudio` sur `ERF-01`, vérification des IDs/slugs et de `LearningSession.revision`) | Backend QA SQLite isolée + Flutter Test | **PASS** (`unit.id`/`slug` et `lesson.id`/`slug` inchangés, instructions identiques, `LearningSession.revision` inchangée, reprise préservée) |
| **Contrôle de publication et isolation `draft`** (`public` vs `staff_preview=1`, simulation de publication contrôlée de `ERF-01`..`ERF-05` uniquement) | Backend QA SQLite isolée (API DRF `APIClient`) | **PASS** (Public avant pub : `0` unité, `0` quiz ; Staff preview : `14` unités dont `5` `ERF` validées, `25` quiz actifs ; Après pub simulée `ERF-01`..`05` : `5` unités publiques, `25` quiz `text_to_character` ; `P01`..`P06` + `V01`..`V03` = `9` unités / `9` leçons / `144` quiz restés en `draft`) |
| **Suite complète Django** | `.\venv\Scripts\python.exe manage.py test` | **PASS** (`Ran 184 tests in 63.931s — OK (skipped=2)`) |
| **Analyse statique Flutter** | `flutter analyze` | **PASS** (`No issues found! (ran in 8.9s)`) |
| **Suite complète Flutter** | `flutter test` | **PASS** (`187/187 — All tests passed!`) |

---

## 3. Résultats des tests Android

- Vérification `adb.exe devices -l` : `List of devices attached` vide.
- **Aucun appareil physique Android n'était connecté** durant cette session : les tests sur appareil physique (ex. Samsung `SM_A336E`) n'ont pas pu être exécutés.

---

## 4. Anomalies restantes

- **Aucune anomalie logicielle bloquante détectée** sur les parcours sans audio `ERF-01`..`ERF-05`, le clavier Erfe, la reprise hors ligne, le calcul du score ou l'isolation de publication.
- **Points d'attention non bloquants :**
  1. Les 50 quiz `AUDIO_TO_CHARACTER` et `GUIDED_KEYBOARD` (`listen_select` / `listen_type`) restent désactivés jusqu'à l'ajout des enregistrements audio authentiques.
  2. La validation visuelle sur appareil Android physique (`staff_preview`) reste à effectuer lorsque le téléphone de test sera connecté.

---

## 5. Décision GO / NO-GO pour publication ultérieure

**Décision : GO (prêt pour publication contrôlée après autorisation explicite)**

- Les 5 leçons `ERF-01` à `ERF-05` et leurs 25 lettres Erfe sont utilisables de bout en bout par un apprenant débutant sans audio, avec reprise hors ligne fiable et continuité garantie lors de l'ajout futur des audios.
- Seules les 5 leçons validées (`ERF-01`..`ERF-05`) et leurs 25 quiz `TEXT_TO_CHARACTER` seront publiables lors de l'autorisation ; les leçons `P01`..`P06` et `V01`..`V03` restent strictement en `draft`.
