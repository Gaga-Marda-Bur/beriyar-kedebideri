# BK-ERFE-V1 — Rapport de préparation du pilote utilisateur privé (5 à 10 apprenants)

**Date :** 2026-11-15  
**Branche :** `dev` (base `72927e2`)  
**Périmètre :** Alphabet Erfe V1 (`ERF-01` à `ERF-05`, 25 lettres Erfe, sans audio)  
**Statut :** Version candidate prête pour pilote privé (**aucune publication publique, aucun déploiement en production, aucun push distant**)

---

## 1. Contrôle d'accès et périmètre pilote

- **Groupe pilote dédié (`pilot_erfe_v1`)** dans [permissions.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/core/permissions.py) (`is_pilot_user`, `allowed_statuses_for_request`, `filter_by_access`) :
  - **Utilisateur public / anonyme (`is_staff=False`, hors `pilot_erfe_v1`) :** accès uniquement aux contenus `published` (`0` unité / `0` quiz préproduction).
  - **Apprenant pilote (`is_staff=False`, membre de `pilot_erfe_v1`) :** accès uniquement aux contenus `published` et `validated` (**uniquement `ERF-01` à `ERF-05`**, leurs `25` lettres et leurs `25` quiz `TEXT_TO_CHARACTER`). **Jamais** d'accès `is_staff`, et **jamais** d'accès aux brouillons (`P01`–`P06`, `V01`–`V03`, même via `?status=draft`).
  - **Équipe éditoriale (`is_staff=True`) :** accès complet de prévisualisation (`draft`, `validated`, `published`).
- La commande [validate_erfe_alphabet_v1.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/management/commands/validate_erfe_alphabet_v1.py) crée automatiquement le groupe `pilot_erfe_v1` si absent et maintient `P01`–`P06` et `V01`–`V03` en `draft`.

---

## 2. Correctifs et vérifications effectués pour le pilote

1. **Réponses correctes, incorrectes, scores et révision SRS sans audio :**
   - Correction dans [learning_core_unit_screen.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/learning/screens/learning_core_unit_screen.dart) (`_recordStepSrs`) : repli sur `step['latin_transcription']` pour alimenter `SrsItemRecord.translationFr` lors des étapes de discrimination (auparavant vide sans mot associé).
   - Correction dans [srs_review_session_screen.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/learning/screens/srs_review_session_screen.dart) : lorsqu'aucun audio n'est présent, `SrsReviewSessionScreen` affiche une consigne explicite sans audio (`Touchez l'écriture Erfe correspondant à « A »`) avec le bandeau d'absence de pénalité.
   - Testé de bout en bout dans [bk_erfe_v1_pilot_test.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/test/bk_erfe_v1_pilot_test.dart) (`2/2` réussis) : erreur en discrimination, erreur + correction au clavier `BeriyaKeyboard`, calcul du score (`40 %` -> `completed=false`, `80 % >= 70 %` -> `passed=true`, `10 % < 70 %` -> `passed=false`), et séance SRS complète sans audio.
2. **Fonctionnement hors ligne après fermeture complète et réouverture :**
   - Vérifié via `UnitProgressLocalStorage` et `SharedPreferences` dans [bk_erfe_v1_user_qualification_test.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/test/bk_erfe_v1_user_qualification_test.dart) et [bk_erfe_v1_pilot_test.dart](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/test/bk_erfe_v1_pilot_test.dart).
3. **Suites complètes exécutées après les dernières modifications :**
   - **Django (`.\venv\Scripts\python.exe manage.py test`) :** `Ran 185 tests in 60.092s — OK (skipped=2)` (dont `4/4` dans [tests_erfe_alphabet_v1.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/tests_erfe_alphabet_v1.py) incluant `test_pilot_group_access_sees_only_erf_01_to_05_never_draft`).
   - **Flutter (`flutter analyze`) :** `No issues found! (ran in 77.2s)`.
   - **Flutter (`flutter test`) :** `189/189 — All tests passed!`.

---

## 3. Appareil Android physique et livrables associés

- **État Android physique (`adb.exe devices -l`) :** aucun appareil connecté (`List of devices attached` vide). **Les tests sur appareil Android physique n'ont pas pu être exécutés.**
- **Procédure de test physique restante :** [BK_ERFE_V1_PROCEDURE_TEST_ANDROID.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/BK_ERFE_V1_PROCEDURE_TEST_ANDROID.md)
- **Fiche de retour d'expérience apprenants :** [BK_ERFE_V1_FICHE_RETOUR_PILOTE.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/BK_ERFE_V1_FICHE_RETOUR_PILOTE.md)

---

## 4. Décision GO / NO-GO pour le pilote privé

**Décision : GO CONDITIONNEL (prêt pour pilote privé de 5 à 10 apprenants après passe de contrôle sur 1 appareil Android physique)**

- **Aucune anomalie logicielle bloquante** détectée côté backend (isolation `pilot_erfe_v1` / `draft` / `public`) ni côté mobile (parcours sans audio, erreurs/scores, clavier Erfe, révision SRS sans audio, reprise hors ligne).
- **Condition avant remise aux 5–10 apprenants :** exécuter la passe de vérification physique décrite dans [BK_ERFE_V1_PROCEDURE_TEST_ANDROID.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/BK_ERFE_V1_PROCEDURE_TEST_ANDROID.md) dès qu'un téléphone Android est branché (rendu police Erfe, fermeture complète + reprise hors ligne réelle).
