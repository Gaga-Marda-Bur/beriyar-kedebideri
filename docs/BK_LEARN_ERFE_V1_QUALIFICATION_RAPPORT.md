# BK-LEARN — Rapport de qualification Alphabet Erfe V1 (sans audio)

**Date :** 2026-11-14  
**Branche :** `dev` (base `bca9716`)  
**Statut :** Candidat validé linguistiquement (`validated`, non publié automatiquement)

---

## 1. Décision linguistique et périmètre

- **Éléments validés (`validated`, `CANDIDAT_SANS_AUDIO`) :**
  - Thème `bk-preprod-alphabet-erfe`
  - 5 leçons / unités : `ERF-01` à `ERF-05` (`bk-preprod-erf-01` .. `bk-preprod-erf-05`)
  - 25 lettres fondamentales Erfe (`Character`) associées
  - 25 quiz visuels sans audio (`TEXT_TO_CHARACTER`, `is_active=True`, `validation_status='validated'`)
- **Éléments maintenus en brouillon / désactivés :**
  - 50 quiz dépendants de l'audio (`AUDIO_TO_CHARACTER`, `GUIDED_KEYBOARD` issu de `listen_type`) : maintenus en `draft` avec `is_active=False`
  - 6 leçons de phrases (`P01`..`P06`) et 3 leçons de vocabulaire (`V01`..`V03`) : maintenues strictement en `draft` (`À vérifier`) dans [BK_CONTENT_15_VALIDATION_LINGUISTIQUE.csv](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/BK_CONTENT_15_VALIDATION_LINGUISTIQUE.csv) et en base.
- **Traçabilité :**
  - Commande d'administration atomique et idempotente : [validate_erfe_alphabet_v1.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/management/commands/validate_erfe_alphabet_v1.py) (`--validated-by`, `--validated-on`, `--dry-run`), enregistrant `linguistic_validation` dans `pedagogy_config`.
  - Aucune publication automatique (`published`), aucun faux audio généré.

---

## 2. Fonctionnement sans audio et continuité future

- **Parcours sans audio (Backend & Mobile) :**
  - [models.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/models.py) (`LearningUnit.generate_core_flow`) et [learning_unit_model.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/learning/models/learning_unit_model.dart) (`_generateLocalCoreFlow`) :
    - Étape `discovery` : affiche `Découvre la lettre « {latin_hint} » ({symbol})` lorsque `phoneme_ipa` vaut `'À_VALIDER'` ou est vide.
    - Étape `discrimination` : affiche `Touche la lettre Erfe correspondant à « {latin_hint} »` sans nécessiter d'audio.
    - Étape `keyboard_encoding` : génère un exercice de saisie avec `BeriyaKeyboard` (`target_word = chars[0].symbol`, `keyboard_keys` des lettres de l'unité) même sans mot cible associé.
  - [learning_core_unit_screen.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/learning/screens/learning_core_unit_screen.dart) et [learning_session.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/learning/engine/learning_session.dart) :
    - L'absence d'audio ne bloque jamais la séance (`_stepHasAudio`, `_buildMissingAudioBanner`, `AudioPlaybackStatus.idle`).
    - Le calcul du score (`LearningSession.score`) et la sauvegarde/reprise JSON (`toJson`/`restore`) restent cohérents.
- **Ajout ultérieur des audios :**
  - Les libellés `discovery` et `discrimination` ne dépendent plus de la présence de `p_audio` / `hasCharAudio`, ce qui garantit que `LearningSession.revision` (qui ignore les clés `*_url`) reste identique après l'ajout ultérieur d'un `AudioAsset` publié (`CharacterAudio`).
  - Les IDs et slugs des unités et des leçons sont conservés sans recréation.

---

## 3. Résultats des vérifications

| Vérification | Périmètre | Résultat observé |
| :--- | :--- | :--- |
| Import + `validate_erfe_alphabet_v1` (base SQLite temporaire isolée) | `--dry-run` puis application réelle | `created=980`, `units=5 \| chars_validated=25 \| non_audio_quizzes_active=25 \| audio_quizzes_disabled=50` |
| Tests ciblés Django (`learning.tests_erfe_alphabet_v1`) | État `validated`, non-publication, visibilité `staff_preview` uniquement, flux sans audio + ajout audio ultérieur | `Ran 3 tests in 1.736s — OK` |
| Suite complète Django (`manage.py test`) | Ensemble du backend | `Ran 184 tests in 57.287s — OK (skipped=2)` |
| Analyse statique Flutter (`flutter analyze`) | Ensemble de `mobile/` | `No issues found! (ran in 8.5s)` |
| Tests ciblés Flutter (`test/bk_learn_erfe_v1_no_audio_test.dart`) | Flux `ERF-01` sans audio, score 100%, reprise JSON, stabilité de `LearningSession.revision` | `2/2 — All tests passed!` |
| Suite complète Flutter (`flutter test`) | Ensemble de `mobile/` | `185/185 — All tests passed!` |
| Appareil physique Android (`adb devices -l`) | Samsung `SM_A336E` | Non exécuté : aucun appareil Android connecté (`List of devices attached` vide) |

---

## 4. Prochaines étapes recommandées (hors périmètre automatique)

1. Exécuter `validate_erfe_alphabet_v1 --dry-run` puis `validate_erfe_alphabet_v1` sur l'environnement cible lorsque souhaité.
2. Vérifier visuellement le parcours candidat `ERF-01`..`ERF-05` en mode `staff_preview` sur un appareil Android physique.
3. Ajouter ultérieurement les enregistrements `AudioAsset` (`published`) et activer les 50 quiz audio correspondants sans modifier les IDs/slugs existants.
