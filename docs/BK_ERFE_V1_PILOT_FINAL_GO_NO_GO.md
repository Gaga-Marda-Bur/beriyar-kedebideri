# BK-ERFE-V1 — Rapport Final GO / NO-GO (Contrôle avant pilote privé)

Date : 2026-11-15  
Branche : `dev` (référence initiale `226af88`)  
Décision : **NO-GO** (blocage authentification mobile pour le groupe `pilot_erfe_v1`)

---

## 1. Synthèse exécutive

- **Sécurité backend (Lot A) : CONFORME.** Le groupe `pilot_erfe_v1` n'a plus d'accès générique à tous les contenus `validated`. L'accès pilote est restreint par liste blanche explicite aux cinq unités `bk-preprod-erf-01` à `bk-preprod-erf-05` sur l'ensemble des endpoints concernés (thèmes, unités, core-flow, leçons, quiz, caractères et packs hors ligne). Une sixième unité `validated` hors pilote reste inaccessible, y compris par identifiant direct, et les brouillons (`draft`) restent masqués.
- **Test physique Android (Lot B — Samsung SM-A336E `R6CT6003WRT`) : BLOQUÉ À L'ÉTAPE 2 (`NO-GO`).** L'application Flutter QA isolée (`com.afrigama.beriyarkedebideri.qa_tools`) s'installe et communique avec le serveur QA isolé (`http://127.0.0.1:8010/api`), mais **l'application mobile ne comporte aucun parcours de connexion apprenant relié à `ApiClient`**. Toutes les requêtes éducatives depuis Flutter sont anonymes ; côté téléphone, le catalogue affiche `Aucun thème disponible.` (comportement fail-closed confirmé : aucune fuite de `validated` ou `draft`), mais les étapes 2 à 10 en compte `pilot_erfe_v1` ne peuvent pas être exécutées depuis l'application mobile.
- **Suites automatisées (Lot C) : PASSÉES.** Django (`186` tests exécutés, `OK`, `skipped=2`), `flutter analyze` (`No issues found!`), `flutter test` (`189` tests réussis).

---

## 2. Détail Lot A — Sécurisation des accès backend

### Modifications apportées
- `backend/core/permissions.py` : ajout de `PILOT_ALLOWED_UNIT_SLUGS` (`bk-preprod-erf-01` à `bk-preprod-erf-05`) et mise à jour de `filter_by_access(..., pilot_q=...)` pour n'autoriser `validated` aux membres de `pilot_erfe_v1` que si `pilot_q` correspond explicitement, tout en préservant l'accès normal aux contenus `published`.
- `backend/learning/models.py` : restriction dans `LearningUnit.generate_core_flow` pour n'inclure les caractères `validated` que si `self.slug in PILOT_ALLOWED_UNIT_SLUGS` (ou staff).
- `backend/learning/views.py`, `backend/learning/serializers.py`, `backend/lessons/views.py`, `backend/quizzes/views.py`, `backend/alphabet/views.py`, `backend/offline_packs/views.py` : passage explicite de `pilot_q` restreignant les thèmes, unités, séquences, leçons, questions de quiz, caractères et packs hors ligne aux 5 unités pilotes.
- `backend/learning/tests_erfe_alphabet_v1.py` : ajout de `test_pilot_allowlist_blocks_sixth_validated_unit_even_by_direct_id_and_preserves_published` (sixième unité `validated` `bk-hors-pilote-06` bloquée en liste et en accès direct, contenu `published` conservé, `draft` bloqué).

---

## 3. Détail Lot B — Test physique sur Samsung SM-A336E (`R6CT6003WRT`)

### Ce qui a été exécuté et observé
1. **Environnement QA isolé** :
   - Serveur Django QA isolé sur `127.0.0.1:8010` avec base SQLite dédiée (`BK_FR_BERIYA_PREPROD_2026_11_13` importé, `validate_erfe_alphabet_v1` appliqué, 6e unité `validated` `bk-hors-pilote-06` ajoutée, utilisateur `pilot_qa_1` dans `pilot_erfe_v1`).
   - Build et installation de l'APK QA isolé (`--dart-define=BK_TOOLS_QA=true --dart-define=API_BASE_URL=http://127.0.0.1:8010/api`, package `com.afrigama.beriyarkedebideri.qa_tools`) avec `adb reverse tcp:8010 tcp:8010`.
2. **Constat de blocage à l'étape 2 (connexion `pilot_erfe_v1`)** :
   - `mobile/lib/core/api/api_client.dart` n'envoie aucun en-tête `Authorization` ni cookie de session.
   - `mobile/lib/core/monetization/session_transport.dart` est explicitement réservé aux routes `/monetization/v1/` (`Cookie jar dedicated to commerce, never attached to educational ApiClient`).
   - `mobile/lib/app/app.dart` ne définit aucune route de connexion apprenant (`/premium` est conditionné à `BK_PREMIUM_SIMULATION && !kReleaseMode`).
   - `backend/core/permissions.py` repose sur `request.user` authentifié (`is_pilot_user(request)`).
3. **Vérification fail-closed sur l'appareil** :
   - Navigation vers `Leçons` sur le Samsung SM-A336E (`R6CT6003WRT`) : affichage observé `Aucun thème disponible.`. Aucun contenu `validated` ni `draft` n'est exposé à l'application mobile non authentifiée.
4. **Étapes 3 à 10 non exécutables en session `pilot_erfe_v1` sur l'appareil** :
   - Accès à `ERF-01`..`ERF-05`, téléchargement hors ligne pilote, séance `ERF-01` avec erreur puis réussite, clavier Erfe, SRS, `am force-stop` + reprise et resynchronisation en ligne n'ont pas pu être qualifiés en tant que compte `pilot_erfe_v1` sur le téléphone faute d'authentification mobile.

---

## 4. Détail Lot C — Résultats des tests automatisés

- **Django (`.\venv\Scripts\python.exe manage.py test`)** : `Ran 186 tests in 62.605s — OK (skipped=2)` (dont `learning.tests_erfe_alphabet_v1` : 5/5 réussis).
- **Flutter analyse (`flutter analyze`)** : `No issues found! (ran in 24.9s)`.
- **Flutter tests (`flutter test`)** : `189` tests réussis (`All tests passed!`).

---

## 5. Anomalies et prérequis avant passage en GO

1. **Anomalie bloquante (Critique)** : Absence d'authentification utilisateur côté application Flutter pour les endpoints éducatifs (`ApiClient`). Sans connexion d'un compte `pilot_erfe_v1` dans l'application mobile, les apprenants du pilote privé ne peuvent pas recevoir les unités `validated` `ERF-01`..`ERF-05`.
2. **Action requise avant nouveau contrôle** :
   - Ajouter un mécanisme d'authentification apprenant (endpoint de connexion + token/session côté Django, écran de connexion et injection des identifiants dans `ApiClient` côté Flutter).
   - Rejouer intégralement les étapes 2 à 10 du Lot B sur le Samsung SM-A336E physique avec un compte `pilot_erfe_v1`.

---

## 6. Décision finale

**NO-GO** pour le lancement du pilote privé sur Android tant que l'authentification mobile `pilot_erfe_v1` et la qualification physique complète (étapes 2 à 10) ne sont pas validées.
