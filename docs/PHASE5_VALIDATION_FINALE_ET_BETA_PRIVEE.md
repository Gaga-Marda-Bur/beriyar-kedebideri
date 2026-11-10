# BERIYAR KEDEBIDERI — PHASE 5
## Validation Android finale et préparation d'une bêta pédagogique privée

- **Date** : 2026-11-10
- **Branche de référence** : `feature/phase4-ux-ui-audio-first`
- **Commit de clôture Phase 4 (Lot 4B.5)** : `f6a27bc` (`feat(lot4b.5): modernisation de HomeScreen et rapport de validation finale Phase 4`)
- **Commit de référence pré-Phase 4 (Phase 3.1 stable)** : `ce4b043`
- **Commit de référence préproduction initiale** : `3081aff`
- **Empreinte `backend/db.sqlite3` (lecture seule)** : `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b` (inchangée)

---

## 1. Étape 1 — Clôture technique et état de référence identifiable

### 1.1 Vérification de l'état Git et de la chaîne des commits
L'arbre de travail Git est **propre** (`git status -sb` : `## feature/phase4-ux-ui-audio-first`) et l'historique des lots est entièrement traçable et atomique :

| Lot / Phase | Commit | Description | Statut |
| :--- | :--- | :--- | :--- |
| **Préproduction** | `3081aff` | Constats d'audit et préparation préproduction (Phases 1 & 2 incluses) | Référence |
| **Phase 3.1** | `ce4b043` | Validation complète Phase 3.1 et correction des 4 anomalies Android | Référence stable |
| **Phase 4A** | `51eeb39` | Livrables de conception UX/UI audio-first et maquettes Sahel Modern | Validé |
| **Lot 4B.1** | `1402a5a` | Implémentation du Design System Sahel Modern et des 4 composants réutilisables | Validé |
| **Lot 4B.2** | `7756d42` | Intégration progressive de la séance pédagogique audio-first en 5 étapes | Validé |
| **Lot 4B.3** | `5f6ab11` | Répétition espacée locale (SRS) et mémorisation audio-first | Validé |
| **Lot 4B.4** | `ea9e4bd` | Modernisation du chemin d'apprentissage (Parcours A & B, `BkLearningNode`, SRS) | Validé |
| **Lot 4B.5** | `f6a27bc` | Modernisation de `HomeScreen` et rapport de validation finale Phase 4 | Validé |

### 1.2 Vérification des suites de tests et de la compatibilité globale

| Périmètre vérifié | Commande exécutée | Résultat observé | Verdict |
| :--- | :--- | :--- | :--- |
| **Compatibilité Backend Django** (API, export audio N14/N15, propriété progressions N01/N02/N03) | `.\backend\venv\Scripts\python.exe docs/run_backend_checks.py` | **94 / 94 tests réussis** (`16.780s`), `System check identified no issues (0 silenced)` | **CONFORME** |
| **Lecteur audio Web JS** | `node --test backend/webapp/tests_audio_player.cjs` | **3 / 3 tests réussis** | **CONFORME** |
| **Suite complète Flutter (Phase 3.1 + Lots 4B.1 à 4B.5)** | `flutter test` | **126 / 126 tests réussis** | **CONFORME** |
| **Analyse statique Flutter** | `flutter analyze` | **0 anomalie** (`No issues found!`) | **CONFORME** |
| **Intégrité des packs hors ligne existants** | Vérification SHA-256 & CRC ZIP (`zipfile.testzip()`) | Pack publié `starter-beriya-erfe_v1_iMr8Evw.zip` (`1 951 973` octets, 12 fichiers, `bad_crc=None`) : SHA-256 `1195e4c54f9ae0b16c246eea5189259e9f2502198ba8efe1edd694a2529bea9b` strictement conforme au manifeste SQLite ; fixture `mobile/test/fixtures/audio_export.zip` (`4 407` octets, 16 fichiers, `bad_crc=None`) intègre | **CONFORME** |
| **Persistance des progressions & SRS** | `UnitProgressLocalStorage` + `LocalSrsService` | Stockage local non concurrent : `UnitProgressLocalStorage` conserve les états/scores d'unités et synchronise vers `/api/progress/unit-progress/sync/`, tandis que `LocalSrsService` stocke les intervalles SM-2 simplifiés (`[1, 3, 7, 14, 30]` jours) sous identifiants stables normalisés (`char:<erfe>`, `word:<erfe>`) | **CONFORME** |
| **Isolation des comptes et des profils** | Backend `ownership.py` + Mobile `LocalSrsService(userScope)` | Côté serveur : séparation stricte entre comptes authentifiés (`request.user`), invités (`device_id` + `ProgressDeviceCredential` SHA-256) et lignes `account_bound` (28 tests `progress.tests_ownership`). Côté mobile : `LocalSrsService` préfixe la clé `SharedPreferences` par `userScope` (`bk_local_srs_v1_<scope>`) ; `UnitProgressLocalStorage` est isolé au niveau de l'installation (un téléphone = un apprenant en mode invité) | **CONFORME** |
| **Changements de parcours A / B** | `LearningPathScreen.saveTrack` / `loadSavedTrack` | Persisté dans `SharedPreferences` (`bk_learning_track_v1`), modifiable à tout moment depuis `HomeScreen` ou `LearningPathScreen` sans perte de progression ni de mémoire SRS | **CONFORME** |

---

## 2. Livrable 1 — Rapport de recette Android (Étape 2)

### 2.1 État de la connexion ADB avec le Samsung SM-A336E
Vérification effectuée sur le bus USB/ADB :
```text
adb devices -l
List of devices attached
R6CT6003WRT            authorizing product:a33xnsdtur model:SM_A336E device:a33x transport_id:1
```
**Constat matériel** : Le téléphone physique Samsung Galaxy A33 5G (`SM-A336E`, numéro de série `R6CT6003WRT`) est détecté physiquement par le démon ADB mais demeure en état **`authorizing`** (la boîte de dialogue système Android *« Autoriser le débogage USB (clé RSA) ? »* est en attente d'une validation tactile humaine sur l'écran physique verrouillé ou en veille du téléphone, action impossible à déclencher par logiciel depuis le PC hôte sans contournement de sécurité interdit).

Conformément aux règles strictes d'intégrité QA : **aucun des 8 scénarios physiques de la Phase 5 n'est déclaré validé sur le téléphone réel tant que l'autorisation USB n'a pas été acceptée sur l'écran du Samsung SM-A336E.**

### 2.2 Matrice des 8 scénarios de recette Android

| # | Scénario | Couverture automatisée Flutter (`flutter test`) | Exécution sur Samsung SM-A336E (`R6CT6003WRT`) | Détail et observations |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Accueil vers parcours** | **PASS** (`lot_4b_5_home_screen_test.dart` #1 & #2) | **BLOQUÉ (`ADB authorizing`)** | `HomeScreen` affiche les 5 niveaux de hiérarchie et ouvre soit la prochaine unité disponible via « Continuer à apprendre », soit `LearningPathScreen` via l'accès secondaire « Leçons ». |
| **2** | **Choix A/B et persistance** | **PASS** (`lot_4b_5_home_screen_test.dart` #3, `lot_4b_4_learning_path_test.dart`) | **BLOQUÉ (`ADB authorizing`)** | Bascule immédiate entre Parcours A (audio-first guidé avec `BkLearningNode`) et Parcours B (catalogue thématique libre), persistée dans `SharedPreferences` (`bk_learning_track_v1`) après redémarrage. |
| **3** | **Leçon audio-first** | **PASS** (`lot_4b_2_audio_first_session_test.dart`) | **BLOQUÉ (`ADB authorizing`)** | Séance en 5 étapes (`1. ÉCOUTER`, `2. RECONNAÎTRE`, `3. LIRE`, `4. COMPOSER`, `5. RÉVISER`) avec `BkAudioHeroButton`, bouton de réécoute explicite, toggle auto-play et bandeau gracieux `audio-missing-banner` si un son manque. |
| **4** | **Reconnaissance Erfe** | **PASS** (`lot_4b_2_audio_first_session_test.dart`, `phase3_1_defects_test.dart`) | **BLOQUÉ (`ADB authorizing`)** | Étape `2. RECONNAÎTRE` et quiz QCM/écoute : sélection via `BkOptionCard` en police `Kedebideri`, feedback encourageant (`BkFeedbackSheet`) avec réécoute et possibilité de réessayer sans pénalité bloquante. |
| **5** | **Saisie au clavier Erfe** | **PASS** (`lot_4b_2_audio_first_session_test.dart`, `phase3_1_defects_test.dart`) | **BLOQUÉ (`ADB authorizing`)** | Étape `4. COMPOSER` avec `BeriyaKeyboard` (aucun exercice de dessin manuscrit), validation Unicode normalisée (`Utf16Safe.normalizeErfeInput`) et cibles tactiles adaptées. |
| **6** | **Révisions SRS après redémarrage** | **PASS** (`lot_4b_3_srs_test.dart`, `lot_4b_5_home_screen_test.dart` #4) | **BLOQUÉ (`ADB authorizing`)** | Persistance complète des enregistrements `SrsItemRecord` dans `SharedPreferences` après réinstanciation du service/écran, calcul des échéances et exécution de `SrsReviewSessionScreen`. |
| **7** | **Fonctionnement en mode avion** | **PASS** (`lot_4b_5_home_screen_test.dart` #5, `phase3_1_defects_test.dart`, `audio_export_contract_test.dart`) | **BLOQUÉ (`ADB authorizing`)** | En cas de `SocketException`, `HomeScreen`, `LearningPathScreen` et `OfflinePacksScreen` restent 100 % accessibles et non bloquants ; résolution prioritaire des fichiers audio locaux via `OfflineMediaResolver` (validé sur SM-A336E en Phase 3.1). |
| **8** | **Reconnexion et synchronisation** | **PASS** (`unit_progress_sync_service_test.dart`, `phase3_1_defects_test.dart`, backend `tests_ownership.py`) | **BLOQUÉ (`ADB authorizing`)** | Conservation locale en cas d'échec réseau ou de refus serveur, puis synchronisation vers `/api/progress/unit-progress/sync/` avec `device_id` et `X-Device-Token` à la reconnexion (validé sur SM-A336E en Phase 3.1). |

---

## 3. Livrable 2 — Inventaire des ressources audio validées et manquantes & Matrice des 12 éléments du Pilote A (Étape 3)

### 3.1 Audit factuel de la base locale et des fichiers médias (`PILOTE_A_AUDIO_2026-11-09.md`)
L'inspection en lecture seule (`mode=ro`) de `backend/db.sqlite3` et de `backend/media/` établit les faits suivants :
1. **Enregistrements `AudioAsset` présents en base (2 au total)** :
   - `1bb9f0cc13b54d01a662fab130e79a3e` : fichier `audio_assets/files/arkap.wav` (`791 192` octets, WAV PCM 16 bits stéréo 44,1 kHz, durée `4,485 s`, SHA-256 `255e7121ad2d8de443aebad7781c3fa695b81a2425f1cce046420ee83f9db459`). Locuteur renseigné : `Gaga` (`male`). Dialecte/région : **vide (`""`)**. Qualité (`recording_quality`) : **vide (`""`)**. Champs de licence/consentement : **aucun champ dédié en base ni dans `notes` (`""`)**.
   - `35f83da127f144feb3b70a27c6b40032` : fichier `audio_assets/files/I.mp3` (`9 643` octets, `audio_type: quiz_prompt`, locuteur `Gaga`, dialecte `"ll"`, transcript `"i"`). Ce fichier est un prompt de quiz et non un enregistrement de caractère ou de mot du Pilote A.
2. **Autres fichiers présents sur disque** :
   - 18 fichiers `backend/media/audio_assets/files/audio/test*.mp3` de **16 octets chacun** (artefacts de test non référencés, impropres à tout usage pédagogique).
   - Les fichiers WAV de `mobile/test/fixtures/audio_export.zip` sont des **silences synthétiques de test** (Phase 1) et n'appartiennent pas au corpus linguistique.
3. **Caractères et mots en base** :
   - Seuls **2 caractères** ont le statut `published` : ID 1 (`𖺠`, `U+16EA0`, `latin_grapheme: "a"`, lié à `arkap.wav`) et ID 2 (`𖺡`, `U+16EA1`, `latin_grapheme: "b"`, **sans audio**).
   - Trois autres caractères nommés sont en statut `review` sans audio : ID 3 (`𖺢`, `U+16EA2`, `d`), ID 4 (`𖺣`, `U+16EA3`, `e`), ID 22 (`𖺵`, `U+16EB5`, `t`).
   - Seul **1 mot** a le statut `published` : ID 1 (`beriya_text: "𖺠"`, `latin_transcription: "arkap"`, `french_translation: "exemple test"`), qui réutilise le **même fichier `arkap.wav`** que le caractère ID 1.
   - Trois mots sont en statut `draft` sans aucun fichier audio lié : ID 2 (`𖺡𖺣` / `be`), ID 3 (`𖺵𖺠` / `ta`), ID 4 (`𖺢𖺣` / `de`).

### 3.2 Matrice des 12 éléments du Pilote A (4 caractères + 6 mots + 2 énoncés courts)

Conformément aux contraintes strictes : **aucune traduction, transcription ou prononciation Beřiya n'est inventée, et aucun enregistrement n'est déclaré validé sans preuve complète (linguistique + audio distinct + consentement).**

| ID Pilote | Contenu Erfe validé | Forme latine validée | Catégorie pédagogique | Enregistrement audio | Locuteur et dialecte | Consentement d'utilisation | Qualité audio | Statut de validation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **C1** | `𖺠` (`U+16EA0`, ID base `1`, publié) | `a` (en base : `Voyelle A`, phonème `/a/` ; mais lié à `arkap.wav` — concordance exacte son/lettre à confirmer par un locuteur) | Caractère familier (Voyelle) | `audio_assets/files/arkap.wav` (`791 192` octets, SHA-256 `255e7121...`) — partagé avec le mot ID 1 | Locuteur : `Gaga` (`male`) • Dialecte/région : **Non renseigné (`""`)** | **NON PROUVÉ** (aucune trace écrite ni champ de consentement/licence en base) | Technique : WAV 44,1 kHz / 16 bits stéréo (`4,485 s`) • Perceptive (`recording_quality`) : **Non évaluée (`""`)** | **EN ATTENTE DE VALIDATION HUMAINE & CONSENTEMENT** |
| **C2** | `𖺡` (`U+16EA1`, ID base `2`, publié) | `b` (`Consonne B`, phonème `/b/`) | Caractère contrastif (Consonne) | **MANQUANT** (aucun `CharacterAudio` lié en base) | **Non renseigné** | **MANQUANT** | **N/A (fichier absent)** | **INCOMPLET — AUDIO & CONSENTEMENT REQUIS** |
| **C3** | **À valider** *(candidat base en statut `review` : `𖺣` `U+16EA3` — non validé)* | **À valider** *(candidat base en `review` : `e`)* | Caractère 3 (Voyelle ou consonne fréquente) | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A (fichier absent)** | **NON VALIDÉ — CHOIX LINGUISTIQUE & AUDIO REQUIS** |
| **C4** | **À valider** *(candidat base en statut `review` : `𖺢` `U+16EA2` ou `𖺵` `U+16EB5` — non validé)* | **À valider** *(candidat base en `review` : `d` ou `t`)* | Caractère 4 (Consonne fréquente) | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A (fichier absent)** | **NON VALIDÉ — CHOIX LINGUISTIQUE & AUDIO REQUIS** |
| **M1** | **À qualifier** *(candidat base ID `1` : `𖺠`, publié avec traduction `"exemple test"`, ou candidat `draft` ID `2` : `𖺡𖺣`)* | **À qualifier** *(candidat ID `1` : `arkap` ; candidat `draft` ID `2` : `be` — non validé)* | Mot familier 1 | Pour ID `1` : réutilise `arkap.wav` (doublon avec C1, non distinct). Pour ID `2` : **MANQUANT** | Pour ID `1` : `Gaga` (dialecte vide). Pour ID `2` : **Non renseigné** | **NON PROUVÉ / MANQUANT** | **Non qualifiée pour un mot distinct** | **NON VALIDÉ — MOT RÉEL & AUDIO DISTINCT REQUIS** |
| **M2** | **À valider** *(candidat base en statut `draft` : `𖺵𖺠` — non validé)* | **À valider** *(candidat `draft` : `ta` — non validé)* | Mot familier 2 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A (fichier absent)** | **NON VALIDÉ — AUDIO & VALIDATION LINGUISTIQUE REQUIS** |
| **M3** | **À valider** *(candidat base en statut `draft` : `𖺢𖺣` — non validé)* | **À valider** *(candidat `draft` : `de` — non validé)* | Mot familier 3 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A (fichier absent)** | **NON VALIDÉ — AUDIO & VALIDATION LINGUISTIQUE REQUIS** |
| **M4** | **MANQUANT** (aucune entrée en base) | **MANQUANT** | Mot familier 4 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A** | **MANQUANT — SÉLECTION & ENREGISTREMENT LOCUTEUR REQUIS** |
| **M5** | **MANQUANT** (aucune entrée en base) | **MANQUANT** | Mot familier 5 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A** | **MANQUANT — SÉLECTION & ENREGISTREMENT LOCUTEUR REQUIS** |
| **M6** | **MANQUANT** (aucune entrée en base) | **MANQUANT** | Mot familier 6 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A** | **MANQUANT — SÉLECTION & ENREGISTREMENT LOCUTEUR REQUIS** |
| **P1** | **MANQUANT** (aucun énoncé en base) | **MANQUANT** | Énoncé court en contexte 1 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A** | **MANQUANT — SÉLECTION & ENREGISTREMENT LOCUTEUR REQUIS** |
| **P2** | **MANQUANT** (aucun énoncé en base) | **MANQUANT** | Énoncé court en contexte 2 | **MANQUANT** | **Non renseigné** | **MANQUANT** | **N/A** | **MANQUANT — SÉLECTION & ENREGISTREMENT LOCUTEUR REQUIS** |

> **Synthèse de l'inventaire Pilote A** : Sur les **12 éléments cibles**, **0 élément** ne dispose aujourd'hui simultanément d'un contenu linguistique définitif, d'un enregistrement audio propre/distinct et d'une preuve de consentement documentée. Le seul fichier WAV réel (`arkap.wav`) nécessite la confirmation de sa valeur phonétique exacte (`a` vs `arkap`), du dialecte et du consentement écrit du locuteur `Gaga`.

---

## 4. Livrable 3 — Plan de bêta privée auprès de locuteurs Beřiya (Étape 4)

### 4.1 Dimensionnement et profil des participants
- **Effectif cible** : **5 à 10 volontaires adultes** locuteurs natifs ou réguliers du Beřiya (Zaghawa), souhaitant apprendre à lire et composer l'écriture Erfe (**Parcours A : « Je parle Beřiya, j'apprends l'Erfe »**).
- **Adaptation aux ressources réellement disponibles** :
  - **Prérequis absolu avant lancement auprès des volontaires** : compléter et valider au moins la première mini-séance de **4 éléments authentiques** (ou les 12 éléments complets du Pilote A : `C1–C4`, `M1–M6`, `P1–P2`) avec des enregistrements vocaux authentiques vérifiés par le responsable linguistique et un pack hors ligne régénéré (`starter-beriya-erfe` v2).
  - **Interdiction stricte** : ne jamais distribuer aux locuteurs le pack de test contenant des silences synthétiques (`audio_export.zip`), ni des mots de démonstration non validés (`"exemple test"`).
- **Canal de distribution privé** :
  - Distribution fermée par **APK signé de préproduction/bêta privée** installé directement (sideloading contrôlé ou canal privé interne hors Google Play public), accompagné du pack hors ligne pré-téléchargé.

### 4.2 Protocole de déroulement (3 sessions sur 5 à 7 jours)
1. **Jour 1 — Session accompagnée (15–20 min)** :
   - Présentation de l'objectif et signature/validation du **consentement éclairé**.
   - Ouverture de l'accueil (`HomeScreen`), sélection du **Parcours A**, téléchargement du pack hors ligne, puis passage en **mode avion**.
   - Réalisation complète de la **1re séance audio-first en 5 étapes** (`1. ÉCOUTER`, `2. RECONNAÎTRE`, `3. LIRE`, `4. COMPOSER`, `5. RÉVISER`).
2. **Jour 2 à Jour 4 — Usage autonome hors ligne (5–10 min / jour)** :
   - Fermeture et réouverture de l'application hors ligne.
   - Reprise depuis la carte principale **« Continuer à apprendre »** et exécution des **révisions espacées (SRS)** proposées sur l'accueil ou le chemin d'apprentissage.
3. **Jour 5 à Jour 7 — Reconnexion et entretien de clôture (15 min)** :
   - Réactivation du réseau pour vérifier la synchronisation automatique des progressions.
   - Entretien court structuré (grille d'observation des 8 indicateurs ci-dessous).

### 4.3 Grille de mesure des 8 indicateurs pédagogiques et UX

| # | Indicateur mesuré | Méthode de collecte (sans télémétrie intrusive) | Critère de succès pour la bêta |
| :--- | :--- | :--- | :--- |
| **1** | **Compréhension du parcours** | Observation à l'ouverture de `HomeScreen` : le volontaire identifie-t-il spontanément le **Parcours A** et le bouton **« Continuer à apprendre »** sans aide ? | `>= 80 %` des testeurs lancent la séance en moins de 30 secondes sans guidage. |
| **2** | **Capacité à terminer la première leçon** | Complétion des 5 étapes (`ÉCOUTER` → `RÉVISER`) enregistrée dans `UnitProgressLocalStorage` (`completed == true`). | `>= 80 %` terminent la première séance de 3–5 minutes sans blocage technique. |
| **3** | **Utilisation du bouton de réécoute** | Observation de l'usage de `BkAudioHeroButton`, du bouton explicite `bk-audio-replay-button` et de la préférence `Auto-play` (`BkAudioPreferencesService`). | Le bouton de réécoute est identifié et utilisé spontanément ; aucun testeur ne cherche comment relancer le son. |
| **4** | **Difficultés de lecture Erfe** | Entretien + relevé des hésitations sur les étapes `2. RECONNAÎTRE` et `3. LIRE` (lisibilité de la police `Kedebideri`, taille `52 sp` / `34 sp`, contraste Clair/Sombre). | Aucune confusion typographique liée au rendu de la police `Kedebideri` sur l'écran Android du volontaire. |
| **5** | **Utilisation du clavier Erfe** | Observation à l'étape `4. COMPOSER` (`BeriyaKeyboard`) : repérage des touches Erfe, effacement, validation de la réponse. | `>= 75 %` parviennent à composer le mot cible au clavier Erfe en 1 ou 2 essais. |
| **6** | **Compréhension des corrections** | Réaction du volontaire à l'ouverture de `BkFeedbackSheet` après une erreur : comprend-il la distinction entre encouragement ambre et validation verte, et utilise-t-il la réécoute intégrée ? | Le testeur comprend pourquoi sa réponse est incorrecte et réessaie sans frustration. |
| **7** | **Capacité à reprendre une séance hors ligne** | Test en mode avion après fermeture complète de l'application : reprise via `HomeScreen` et lecture des fichiers audio locaux du pack installé. | `100 %` des reprises hors ligne conservent la progression et jouent l'audio local sans erreur réseau. |
| **8** | **Utilité perçue des révisions SRS** | Question dédiée au Jour 5 après utilisation de `SrsReviewSessionScreen` : les éléments difficiles reviennent-ils à un rythme jugé utile ? | Majorité des volontaires jugent la révision audio-first utile et non contraignante. |

### 4.4 Protection de la vie privée, minimisation des données et consentement
- **Minimisation stricte (Privacy by Design)** :
  - Aucun nom civil, numéro de téléphone, adresse e-mail, géolocalisation, carnet de contacts ou enregistrement micro des apprenants n'est collecté par l'application.
  - Les volontaires utilisent l'application en **mode invité local** (identifiant technique pseudonyme `device_id` + code volontaire anonyme `BETA-01` à `BETA-10` sur la fiche d'observation papier/locale).
  - Aucune bibliothèque publicitaire, aucun SDK de tracking tiers ni aucun outil d'analytics commercial n'est embarqué.
- **Consentement éclairé** :
  - **Pour les volontaires testeurs** : formulaire de consentement oral et écrit (expliqué en Beřiya et en français/arabe) précisant le caractère expérimental de la bêta, l'absence de collecte de données nominatives et le droit d'arrêt à tout moment avec effacement immédiat des données locales.
  - **Pour les locuteurs enregistrant leur voix (Pilote A)** : fiche de consentement écrite obligatoire avant toute inclusion d'un fichier audio dans un pack, précisant le nom/pseudonyme souhaité, la variante dialectale, et l'autorisation explicite de diffusion dans l'application Beřiyar Kedebideři (y compris au sein des packs téléchargeables hors ligne).

---

## 5. Livrable 4 — Liste des anomalies et points bloquants avant distribution

Aucune anomalie logicielle (code Flutter ou backend Django) n'est ouverte à l'issue de la Phase 4 (`126/126` tests Flutter, `94/94` tests Django, `3/3` tests JS, `0` alerte `flutter analyze`). En revanche, **deux prérequis opérationnels et matériels sont bloquants** avant la remise de l'application aux volontaires :

| ID | Nature | Description du blocage | Impact | Action corrective requise |
| :--- | :--- | :--- | :--- | :--- |
| **BLK-P5-01** | **Matériel / QA Android physique** | Le téléphone Samsung SM-A336E (`R6CT6003WRT`) est en statut ADB `authorizing`. Les 8 scénarios de la Phase 5 (incluant les lots 4B.2 à 4B.5) sont validés par les tests automatisés mais n'ont pas encore été exécutés sur le téléphone physique. | Pas de preuve visuelle et matérielle sur le SM-A336E pour les nouveaux écrans de la Phase 4. | Déverrouiller l'écran du Samsung SM-A336E, cocher *« Toujours autoriser depuis cet ordinateur »* et appuyer sur **Autoriser** dans la fenêtre USB ADB, puis exécuter les 8 scénarios physiques. |
| **BLK-P5-02** | **Corpus linguistique & droits audio (Pilote A)** | Sur les 12 éléments cibles du Pilote A (`C1–C4`, `M1–M6`, `P1–P2`), seul `arkap.wav` existe en base (sans dialecte ni preuve de consentement documentée, et partagé entre le caractère ID 1 et le mot de test ID 1). Les 11 autres enregistrements authentiques sont manquants. | Impossible de tester l'apprentissage oral réel auprès de locuteurs Beřiya sans enregistrements vocaux authentiques et validés. | Enregistrer et faire valider par le référent linguistique les 12 éléments du Pilote A avec consentement écrit des locuteurs, puis générer une nouvelle version du pack hors ligne (`starter-beriya-erfe` v2). |

---

## 6. Livrable 5 — Procédure de retour arrière (Rollback sécurisé)

Conformément aux règles de sécurité et de préservation des données, **aucun `git reset --hard`, aucune suppression de table ou de média, et aucune désinstallation destructrice des progressions utilisateurs ne doivent être utilisés.**

### 6.1 Retour arrière du code mobile (Branche Phase 4 → Phase 3.1 stable)
- Tout le travail de la Phase 4 (`51eeb39` à `f6a27bc`) est isolé sur la branche `feature/phase4-ux-ui-audio-first`.
- Le commit de référence validé avant Phase 4 est identifié : **`ce4b043`** (`feat(phase3.1): validation complete Phase 3.1 et correction des 4 anomalies Android`).
- **Procédure** :
  1. Pour compiler un APK sans la refonte UX/UI de la Phase 4 tout en conservant les correctifs Android de la Phase 3.1, se positionner sur `ce4b043` dans un worktree ou une branche de secours dédiée (`git checkout -b release/fallback-phase3-1 ce4b043`).
  2. Les clés `SharedPreferences` introduites en Phase 4 (`bk_audio_auto_play_v1`, `bk_local_srs_v1_*`, `bk_learning_track_v1`) sont **strictement additives et isolées** : elles n'altèrent jamais la clé historique des progressions d'unités (`UnitProgressLocalStorage`). Un retour à la version Phase 3.1 conserve donc **100 % des progressions locales et des packs hors ligne déjà téléchargés** sur le téléphone.

### 6.2 Retour arrière des packs hors ligne
- Ne jamais écraser ni supprimer un fichier ZIP de pack existant (`starter-beriya-erfe_v1_iMr8Evw.zip`).
- Toute mise à jour du contenu pilote doit être publiée sous un **nouveau numéro de version (`version = 2`)** avec son propre checksum SHA-256.
- En cas d'anomalie sur un nouveau pack `v2`, désactiver `v2` (`is_active = False` dans l'administration Django) et réactiver `v1` sans purger les fichiers médias ni les progressions locales des testeurs.

### 6.3 Retour arrière Backend / Base de données
- Aucune modification backend ni migration n'a été effectuée durant les Phases 3, 3.1, 4 et 5 (l'empreinte SHA-256 de `backend/db.sqlite3` est restée `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b`).
- Aucun déploiement automatique ni migration en production n'a été exécuté : aucun rollback de production n'est donc requis.

---

## 7. Livrable 6 — Décision GO / NO-GO pour la distribution privée

| Dimension évaluée | Statut | Justification factuelle |
| :--- | :--- | :--- |
| **1. Clôture technique logicielle (Mobile Flutter & Backend Django)** | **GO TECHNIQUE** | `126/126` tests Flutter réussis, `94/94` tests Django réussis, `3/3` tests JS réussis, `0` alerte `flutter analyze`, arbre Git propre sur `feature/phase4-ux-ui-audio-first` (`f6a27bc`), intégrité SHA-256/CRC des packs et de `db.sqlite3` vérifiée. |
| **2. Recette Android physique sur Samsung SM-A336E** | **NO-GO MATÉRIEL (`BLK-P5-01`)** | Le Samsung SM-A336E (`R6CT6003WRT`) reste en statut `authorizing` sur ADB. Les 8 scénarios doivent être exécutés physiquement dès acceptation de la pop-up USB sur le téléphone. |
| **3. Corpus audio et validation linguistique du Pilote A** | **NO-GO CONTENU (`BLK-P5-02`)** | Sur les 12 éléments du Pilote A, les enregistrements vocaux authentiques, l'indication du dialecte et les preuves de consentement des locuteurs restent à compléter avant remise à de vrais apprenants. |

### Verdict final de la Phase 5
> **DÉCISION GLOBALE POUR LA DISTRIBUTION PRIVÉE : NO-GO EN L'ÉTAT (GO TECHNIQUE ACQUIS, DISTRIBUTION CONDITIONNÉE À LA LEVÉE DE `BLK-P5-01` ET `BLK-P5-02`)**
>
> L'application mobile et le backend sont **techniquement prêts, stables et figés** (commit `f6a27bc`). Conformément aux exigences de rigueur linguistique et QA, la distribution de l'APK aux 5–10 volontaires locuteurs Beřiya ne doit être déclenchée qu'après :
> 1. Validation de l'invite USB ADB sur l'écran du **Samsung SM-A336E** et exécution concluante des 8 scénarios physiques (`BLK-P5-01`).
> 2. Intégration des enregistrements audio authentiques validés et dotés du consentement des locuteurs pour le **Pilote A** (`BLK-P5-02`).
