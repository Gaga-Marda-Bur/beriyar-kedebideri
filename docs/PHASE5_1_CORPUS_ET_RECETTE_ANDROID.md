# BERIYAR KEDEBIDERI — PHASE 5.1
## Préparation du corpus pédagogique, outils audio/pack pilote et clôture de la recette Android

- **Date** : 2026-11-10
- **Branche** : `feature/phase4-ux-ui-audio-first`
- **Commit de référence Phase 5** : `f59b6ee`
- **Commit de référence pré-Phase 4 (Phase 3.1 stable)** : `ce4b043`
- **Empreinte `backend/db.sqlite3` (lecture seule)** : `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b` (inchangée)

---

## 1. Livrable 1 — Rapport de recette physique Android & APK de recette (Chantier 1)

### 1.1 Vérification de l'autorisation ADB sur le Samsung SM-A336E
Commande exécutée :
```text
adb devices -l
List of devices attached
R6CT6003WRT            authorizing product:a33xnsdtur model:SM_A336E device:a33x transport_id:1
```
Le Samsung Galaxy A33 5G (`SM-A336E`, `R6CT6003WRT`) reste en statut **`authorizing`** sur le bus USB/ADB (attente d'une action physique sur l'écran du téléphone pour accepter la clé RSA de débogage USB). Conformément aux directives du Chantier 1 :
1. **Aucune exécution ADB non réalisée n'est déclarée comme validée.**
2. Un **APK de recette installable manuellement** contenant l'intégralité des Lots 4B.1 à 4B.5 (ainsi que les correctifs Phase 3.1) a été fraîchement compilé et vérifié, accompagné d'une **grille de validation fonctionnelle manuelle** pour les 8 scénarios.

### 1.2 APK de recette installable manuellement
- **Chemin du binaire compilé** : `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- **Identifiant d'application** : `com.afrigama.beriyarkedebideri`
- **Taille** : `214 145 507` octets (`204,22 Mo`)
- **Empreinte SHA-256** : `df2b5f757aa67a36f774e54706d638e0522e17fd484ba1f10ef0435baed453c6`
- **Horodatage de génération** : `2026-11-10T14:48:56+03:00`
- **Installation manuelle (sans ADB ou dès qu'ADB passe à `device`)** :
  - *Option A (dès acceptation de la pop-up USB sur l'écran du SM-A336E)* :
    ```powershell
    & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r mobile\build\app\outputs\flutter-apk\app-debug.apk
    ```
  - *Option B (installation manuelle sur le téléphone sans ADB)* :
    Copier `app-debug.apk` sur le stockage MTP du téléphone (dossier `Download/`) ou via partage local, puis l'ouvrir depuis l'application **Mes fichiers** d'Android (*Mise à jour* de l'application existante sans désinstallation préalable afin de conserver toutes les données locales).

### 1.3 Distinction stricte : résultats automatisés, vérifications manuelles et scénarios non exécutés

| # | Scénario Phase 5 | 1. Résultats Automatisés (`flutter test` / `django test`) | 2. Vérification Physique Antérieure (Phase 3.1 sur SM-A336E) | 3. Recette Manuelle Phase 4/5 sur SM-A336E | Protocole de vérification manuelle sur le téléphone (Grille opérateur) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Accueil vers parcours** | **EXÉCUTÉ — PASS** (`lot_4b_5_home_screen_test.dart` #1 & #2) | Ancien accueil validé | **NON EXÉCUTÉ** *(APK prêt)* | Ouvrir l'application → vérifier les 5 blocs hiérarchisés → toucher **« Continuer à apprendre »** ou **« Leçons »** → vérifier l'ouverture de l'unité ou de `LearningPathScreen`.[ ] PASS / [ ] FAIL |
| **2** | **Choix A/B et persistance** | **EXÉCUTÉ — PASS** (`lot_4b_5_home_screen_test.dart` #3, `lot_4b_4_learning_path_test.dart`) | Non applicable (ajout Lot 4B.4/4B.5) | **NON EXÉCUTÉ** *(APK prêt)* | Toucher **Parcours B** sur l'accueil → fermer complètement l'application (swipe dans les applications récentes) → rouvrir → vérifier que **Parcours B** est toujours sélectionné, puis repasser en **Parcours A**.[ ] PASS / [ ] FAIL |
| **3** | **Leçon audio-first** | **EXÉCUTÉ — PASS** (`lot_4b_2_audio_first_session_test.dart`) | Moteur `LearningSession` validé | **NON EXÉCUTÉ** *(APK prêt)* | En Parcours A, lancer la 1re unité → vérifier l'étape `1. ÉCOUTER`, le bouton central `BkAudioHeroButton`, le bouton de réécoute explicite et le commutateur `Auto-play` (ou le bandeau `Audio bientôt disponible` si l'élément n'a pas de son).[ ] PASS / [ ] FAIL |
| **4** | **Reconnaissance Erfe** | **EXÉCUTÉ — PASS** (`lot_4b_2_audio_first_session_test.dart`, `phase3_1_defects_test.dart`) | Quiz `P3-04` validé sur SM-A336E (`PASS`) | **NON EXÉCUTÉ** *(APK prêt)* | À l'étape `2. RECONNAÎTRE`, toucher une carte `BkOptionCard` erronée → vérifier l'ouverture de `BkFeedbackSheet` en ambre d'encouragement avec bouton de réécoute → toucher le bon caractère Erfe → vérifier la validation verte.[ ] PASS / [ ] FAIL |
| **5** | **Saisie au clavier Erfe** | **EXÉCUTÉ — PASS** (`lot_4b_2_audio_first_session_test.dart`, `phase3_1_defects_test.dart`) | Clavier Erfe validé | **NON EXÉCUTÉ** *(APK prêt)* | À l'étape `4. COMPOSER`, saisir le mot cible avec les touches du `BeriyaKeyboard` → vérifier qu'aucun exercice de dessin manuscrit n'apparaît → valider et observer l'écran `5. RÉVISER`.[ ] PASS / [ ] FAIL |
| **6** | **Révisions SRS après redémarrage** | **EXÉCUTÉ — PASS** (`lot_4b_3_srs_test.dart`, `lot_4b_5_home_screen_test.dart` #4) | Non applicable (ajout Lot 4B.3) | **NON EXÉCUTÉ** *(APK prêt)* | Après une séance comportant au moins une erreur, fermer puis rouvrir l'application → vérifier le compteur **« X élément(s) à réviser »** sur l'accueil → toucher **« Lancer la révision »** → terminer `SrsReviewSessionScreen`.[ ] PASS / [ ] FAIL |
| **7** | **Fonctionnement en mode avion** | **EXÉCUTÉ — PASS** (`lot_4b_5_home_screen_test.dart` #5, `phase3_1_defects_test.dart`) | **EXÉCUTÉ — PASS** sur SM-A336E en Phase 3.1 (`P3-01`, `P3-03`) | **PARTIEL** *(socle réseau/audio validé sur SM-A336E ; nouveaux écrans Phase 4 non exécutés sur SM-A336E)* | Activer le **Mode Avion** sur le téléphone → ouvrir l'accueil, le chemin d'apprentissage et **Packs hors ligne** → vérifier l'absence de blocage et la lecture de l'audio local `arkap.wav` du pack installé.[ ] PASS / [ ] FAIL |
| **8** | **Reconnexion et synchronisation** | **EXÉCUTÉ — PASS** (`unit_progress_sync_service_test.dart`, `tests_ownership.py`) | **EXÉCUTÉ — PASS** sur SM-A336E en Phase 3.1 (`resync: true`) | **PARTIEL** *(socle sync validé sur SM-A336E ; non ré-exécuté après Phase 4)* | Désactiver le Mode Avion → tirer vers le bas pour rafraîchir l'accueil → vérifier le passage de la pilule réseau à **« En ligne »** et la conservation de la progression locale et du SRS.[ ] PASS / [ ] FAIL |

---

## 2. Livrable 2 — Fichier de suivi structuré des 12 éléments du Pilote A (Chantier 2)

Le fichier de suivi structuré (exploitable par des outils de vérification et par l'équipe linguistique) est enregistré sous :
- **Fichier JSON structuré** : [`docs/PILOTE_A_SUIVI_12_ELEMENTS.json`](file:///C:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/PILOTE_A_SUIVI_12_ELEMENTS.json)

### Tableau récapitulatif des 12 éléments (état strict sans complétion automatique)

| ID pédagogique | Catégorie | Texte Erfe | Transcription latine | Signification validée | Locuteur | Dialecte | Chemin audio | Contrôle de qualité | Consentement | Statut de validation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`PILOTE-A-C1`** | `character` | `𖺠` (`U+16EA0`, ID `1` `published`) | `a` | Voyelle A *(concordance exacte avec `arkap.wav` à confirmer)* | `Gaga` | *Non renseigné* | `audio_assets/files/arkap.wav` | Fichier WAV 44,1 kHz 16 bits (`4,485 s`) présent ; partagé avec le mot ID `1` ; `recording_quality` vide | **Non documenté** | `en_attente_verification_humaine_et_consentement` |
| **`PILOTE-A-C2`** | `character` | `𖺡` (`U+16EA1`, ID `2` `published`) | `b` | Consonne B | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent (`0` lien `CharacterAudio`) | **Manquant** | `incomplet_audio_manquant` |
| **`PILOTE-A-C3`** | `character` | *À valider* *(candidat ID `4` `𖺣` en `review`, non utilisé comme validé)* | *À valider* | *À valider* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `non_valide_selection_et_audio_requis` |
| **`PILOTE-A-C4`** | `character` | *À valider* *(candidats ID `3` `𖺢` ou ID `22` `𖺵` en `review`, non utilisés comme validés)* | *À valider* | *À valider* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `non_valide_selection_et_audio_requis` |
| **`PILOTE-A-M1`** | `word` | *À qualifier* *(ID `1` `𖺠` `"exemple test"` partage `arkap.wav` ; ID `2` `𖺡𖺣` est en `draft`)* | *À qualifier* | *À qualifier* | *Non renseigné* | *Non renseigné* | *Aucun fichier distinct validé* | Aucun audio de mot distinct vérifié | **Manquant** | `non_valide_mot_et_audio_distinct_requis` |
| **`PILOTE-A-M2`** | `word` | *À valider* *(candidat ID `2` en `draft` non utilisé comme publié)* | *À valider* | *À valider* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `non_valide_selection_et_audio_requis` |
| **`PILOTE-A-M3`** | `word` | *À valider* *(candidat ID `3` en `draft` non utilisé comme publié)* | *À valider* | *À valider* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `non_valide_selection_et_audio_requis` |
| **`PILOTE-A-M4`** | `word` | *À valider* *(candidat ID `4` en `draft` non utilisé comme publié)* | *À valider* | *À valider* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `non_valide_selection_et_audio_requis` |
| **`PILOTE-A-M5`** | `word` | *Manquant* | *Manquant* | *Manquant* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `manquant_collecte_requise` |
| **`PILOTE-A-M6`** | `word` | *Manquant* | *Manquant* | *Manquant* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `manquant_collecte_requise` |
| **`PILOTE-A-P1`** | `short_utterance` | *Manquant* | *Manquant* | *Manquant* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `manquant_collecte_requise` |
| **`PILOTE-A-P2`** | `short_utterance` | *Manquant* | *Manquant* | *Manquant* | *Non renseigné* | *Non renseigné* | *Aucun* | Fichier absent | **Manquant** | `manquant_collecte_requise` |

---

## 3. Livrable 3 — Inventaire des ressources et autorisations manquantes & Audit des outils audio existants (Chantiers 2 & 3)

### 3.1 Ressources et autorisations manquantes pour les 12 éléments
1. **Enregistrements vocaux authentiques manquants (11 à 12 fichiers)** :
   - **C1 (`𖺠`)** : vérifier avec un locuteur si `arkap.wav` (`4,485 s`) correspond bien à l'énonciation attendue pour le caractère `𖺠` ou s'il faut ré-enregistrer un son court du phonème `/a/` et un son du nom de lettre (`letter_name`).
   - **C2 (`𖺡`), C3, C4** : **3 enregistrements de caractères** manquants (prononciation normale + optionnellement lente/phonème).
   - **M1 à M6** : **6 enregistrements de mots familiers** distincts manquants (ainsi que la sélection/validation linguistique finale des 6 mots et leur passage de `draft` à `published` uniquement après relecture humaine).
   - **P1 et P2** : **2 enregistrements d'énoncés courts en contexte** manquants (et saisie de leur texte Erfe + traduction validée).
2. **Métadonnées locuteur et dialecte manquantes** :
   - `dialect_region` est vide sur `arkap.wav` et absent pour les 11 autres éléments.
   - `recording_quality` et `duration_ms` sont vides sur tous les enregistrements.
3. **Preuves de consentement et droits d'utilisation hors ligne manquants (12 / 12)** :
   - Aucune fiche de consentement signée/référencée n'est encore renseignée dans le champ `AudioAsset.notes` (ni archivée).

### 3.2 Audit des outils de préparation audio existants (Chantier 3)

| Capacité vérifiée | Implémentation existante dans le dépôt | Verdict & Besoin de correctif |
| :--- | :--- | :--- |
| **1. Import d'enregistrements** | `AudioAsset` (`backend/audio_assets/models.py`) + `AudioAssetAdmin` (`backend/audio_assets/admin.py`) acceptent l'upload de fichiers `.wav`, `.mp3`, `.m4a` dans `media/audio_assets/files/` avec validation d'extension (`FileExtensionValidator`). | **OPÉRATIONNEL — Aucune modification de code requise.** |
| **2. Association audio-élément** | Modèles de liaison dédiés avec `UniqueConstraint` et `TabularInline` dans Django Admin :<ul><li>`CharacterAudio` (`alphabet/admin.py`) : rôles `phoneme`, `letter_name`, `normal`, `slow`, `example`.</li><li>`WordAudio` (`vocabulary/admin.py`) : rôles `normal`, `slow`, `example`, `syllable`, `syllable_breakdown`.</li><li>`LessonItemAudio` (`lessons/models.py`) : rôles `normal`, `slow`, `prompt`, `explanation`.</li><li>`QuizQuestionAudio` (`quizzes/models.py`) : rôles `question`, `slow_question`, `explanation`, `correction`.</li></ul>Pour les énoncés courts **P1–P2**, ils peuvent être modélisés sans aucune migration soit comme `Word` (avec `orthographic_pattern='PHRASE'` et `WordAudio`), soit comme `LessonItem` (`item_type='practice'` ou `'word'` avec `LessonItemAudio` et `AudioAsset(audio_type='sentence')`). | **OPÉRATIONNEL — Aucune modification de code requise.** |
| **3. Conservation des métadonnées** | `AudioAsset` stocke nativement `title`, `audio_type`, `speed`, `speaker_name`, `speaker_gender`, `dialect_region`, `mime_type`, `duration_ms`, `transcript`, `recording_quality`, `validation_status`, `available_offline` et `notes` (utilisable pour la référence de consentement, ex. `CONSENT-2026-LOC01`). Le test `test_complete_lesson_export_keeps_real_fields_and_all_item_audio_roles` vérifie que la génération de pack ne modifie jamais ces métadonnées. | **OPÉRATIONNEL — Aucune modification de code requise.** |
| **4. Export vers les packs hors ligne** | `OfflinePackGenerator` (`backend/offline_packs/services/offline_pack_generator.py`) et la commande `python manage.py generate_pack <slug>` exportent uniquement les entités et audios `validation_status='published'` (lorsque le pack est `published`), copient tous les rôles audio dans `audio/`, réécrivent les chemins de `core_flow`, génèrent `manifest.json`/`metadata.json` (`schema_version: 2`) et calculent automatiquement `size_mb` et le `checksum` SHA-256. | **OPÉRATIONNEL — Aucune modification de code requise.** |

---

## 4. Livrable 4 — Procédure d'enregistrement audio et d'intégration (Chantiers 2 & 3)

### Étape A — Collecte du consentement préalable
1. Avant toute prise de son, recueillir l'accord éclairé du locuteur Beřiya (autorisation d'enregistrement et d'intégration dans l'application mobile et ses packs hors ligne).
2. Attribuer un identifiant de consentement unique (ex. `CONSENT-BK-2026-001`) sans inclure de données privées sensibles dans les fichiers publics.

### Étape B — Paramètres techniques de prise de son
1. **Format recommandé** : **WAV PCM 16 bits, 44 100 Hz, mono** (pour l'archivage maître et les sons courts de caractères/mots) ou **M4A / MP3 128 kbps minimum** (acceptés par `FileExtensionValidator(['mp3', 'm4a', 'wav'])`).
2. **Environnement** : pièce calme sans réverbération ni bruit de vent/ventilateur ; distance micro constante (~15–20 cm).
3. **Découpage et durée** :
   - Amorces et fins silencieuses taillées proprement (`100 ms` à `200 ms` de silence en début/fin).
   - **Caractères (`C1–C4`)** : `0,8 s` à `2,0 s` (enregistrer séparément le **phonème pur** `role='phoneme'` et/ou la **prononciation normale** `role='normal'`).
   - **Mots (`M1–M6`)** : `1,0 s` à `2,5 s` (`role='normal'` et optionnellement `role='slow'`).
   - **Énoncés courts (`P1–P2`)** : `2,0 s` à `5,0 s` (`role='normal'` et `role='slow'`).
4. **Convention de nommage des fichiers** :
   - `pilote_a_c1_u16ea0_normal.wav`, `pilote_a_c2_u16ea1_normal.wav`, ..., `pilote_a_m1_<transcription>_normal.wav`, `pilote_a_p1_normal.wav`.

### Étape C — Import et association dans Django Admin (sans voix synthétique)
1. Ouvrir `/admin/audio_assets/audioasset/add/` :
   - Importer le fichier audio vérifié.
   - Renseigner obligatoirement : `title`, `audio_type` (`character`, `word` ou `sentence`), `speed` (`normal` ou `slow`), `speaker_name`, `dialect_region` (ex. Borkou, Ennedi, Darfour...), `transcript` (forme Erfe exacte), `recording_quality` (`verified`), et dans `notes` la référence `CONSENT-BK-...`.
   - Ne passer `validation_status` à **`published`** qu'après écoute de contrôle et confirmation de la concordance exacte avec l'élément écrit.
2. Ouvrir la fiche du caractère (`/admin/alphabet/character/`) ou du mot (`/admin/vocabulary/word/`) :
   - Vérifier avec le référent linguistique le glyphe Unicode Erfe, la transcription latine et la traduction.
   - Dans la section inline `CharacterAudio` / `WordAudio`, associer l'`AudioAsset` publié avec le rôle approprié (`normal`, `phoneme`, `slow`) et cocher `is_primary = True`.
   - Passer le `validation_status` du caractère ou du mot à **`published`** (les éléments laissés en `draft` ou `review` sont automatiquement exclus des packs publiés par `OfflinePackGenerator`).
3. Mettre à jour [`docs/PILOTE_A_SUIVI_12_ELEMENTS.json`](file:///C:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/PILOTE_A_SUIVI_12_ELEMENTS.json) avec l'UUID de l'`AudioAsset`, le SHA-256 du fichier et la référence de consentement.

---

## 5. Livrable 5 — Procédure de génération et de validation du pack pilote indépendant (Chantier 4)

Afin de ne jamais altérer le pack publié existant (`starter-beriya-erfe`, `version = 1`, fichier `starter-beriya-erfe_v1_iMr8Evw.zip`, SHA-256 `1195e4c54f9ae0b16c246eea5189259e9f2502198ba8efe1edd694a2529bea9b`), le pack pilote doit être créé comme un **nouvel enregistrement `LessonPack` indépendant** (slug dédié : `pilote-a-oral-erfe`, `version = 1`).

### 5.1 Création et génération du pack pilote (lorsque les 12 éléments sont validés)
1. **Sauvegarde préalable de la base locale** :
   ```powershell
   Copy-Item backend\db.sqlite3 backend\db.sqlite3.bak_before_pilote_a
   ```
2. **Création du `LessonPack` indépendant dans Django Admin** (`/admin/offline_packs/lessonpack/add/`) :
   - `slug` : `pilote-a-oral-erfe` (distinct de `starter-beriya-erfe`)
   - `title_fr` : `Pilote A — De l'oral Beřiya à l'Erfe`
   - `level` : `beginner`
   - `pack_type` : `normal`
   - `version` : `1`
   - Sélectionner uniquement les thèmes, unités (découpées en 3 mini-séances de 4 éléments avec `enable_tracing = False`), les 4 caractères (`C1–C4`), les 6 mots (`M1–M6`), les leçons/items (`P1–P2`) et les questions de quiz dont `validation_status == 'published'`.
   - `status` : `published`, `is_active` : `True`.
3. **Exécution du générateur de pack** :
   ```powershell
   cd C:\Users\MONSTER\Desktop\BeriyaClean\beriyar-kedebideri\backend
   .\venv\Scripts\python.exe manage.py generate_pack pilote-a-oral-erfe
   ```
   Cette commande génère `media/offline_packs/files/pilote-a-oral-erfe_v1.zip`, renseigne `manifest` (`schema_version: 2`), `items_count`, `size_mb` et calcule le `checksum` SHA-256.

### 5.2 Vérification d'intégrité, de l'audio local, des exercices et du SRS
1. **Contrôle cryptographique et structurel du ZIP** :
   ```powershell
   .\venv\Scripts\python.exe -c "import zipfile, json, hashlib, pathlib; p = pathlib.Path('media/offline_packs/files/pilote-a-oral-erfe_v1.zip'); z = zipfile.ZipFile(p); assert z.testzip() is None; m = json.loads(z.read('metadata.json')); assert len(m['media_files']) >= 12; print('SHA256:', hashlib.sha256(p.read_bytes()).hexdigest(), 'MEDIA:', len(m['media_files']))"
   ```
2. **Tests automatisés de contrat d'export et de lecture hors ligne** :
   - Exécuter `.\venv\Scripts\python.exe ../docs/run_backend_checks.py` (`94/94` tests dont `offline_packs.tests_audio_export`).
   - Exécuter `flutter test test/audio_export_contract_test.dart test/lot_4b_2_audio_first_session_test.dart test/lot_4b_3_srs_test.dart`.
3. **Test de bout en bout dans l'application mobile** :
   - Télécharger le pack `pilote-a-oral-erfe` depuis `OfflinePacksScreen`.
   - Passer en **Mode Avion**.
   - Lancer les 3 mini-séances depuis `HomeScreen` (« Continuer à apprendre ») → vérifier que chaque étape (`1. ÉCOUTER`, `2. RECONNAÎTRE`, `3. LIRE`, `4. COMPOSER`, `5. RÉVISER`) joue bien le fichier audio local extrait du pack sans aucun bandeau d'audio manquant.
   - Vérifier que les 12 éléments sont enregistrés dans `LocalSrsService` sous leurs identifiants stables (`char:<erfe>`, `word:<erfe>`) et que `SrsReviewSessionScreen` rejoue les audios locaux après redémarrage de l'application.

---

## 6. Livrable 6 — Décision GO / NO-GO pour la bêta privée

| Critère d'évaluation Phase 5.1 | Statut actuel | Preuve / Référence |
| :--- | :--- | :--- |
| **1. Stabilité logicielle, tests et outils d'export audio/pack** | **GO TECHNIQUE** | `126/126` tests Flutter, `94/94` tests Django, `3/3` tests JS, `0` alerte `flutter analyze`, générateur `OfflinePackGenerator` et commande `generate_pack` opérationnels sans modification requise. |
| **2. Préparation du suivi structuré et de l'APK de recette** | **PRÊT** | Fichier [`docs/PILOTE_A_SUIVI_12_ELEMENTS.json`](file:///C:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/PILOTE_A_SUIVI_12_ELEMENTS.json) créé ; APK installable `mobile/build/app/outputs/flutter-apk/app-debug.apk` compilé (SHA-256 `df2b5f757aa67a36f774e54706d638e0522e17fd484ba1f10ef0435baed453c6`) avec grille de recette des 8 scénarios. |
| **3. Recette physique Android des nouveaux écrans Phase 4 sur Samsung SM-A336E** | **NO-GO MATÉRIEL (`ADB authorizing`)** | Le Samsung SM-A336E (`R6CT6003WRT`) attend toujours la validation de l'invite USB sur son écran physique. Les 8 scénarios de la grille §1.3 doivent être exécutés sur le téléphone (via ADB ou via installation manuelle de `app-debug.apk`). |
| **4. Validation humaine et enregistrement des 12 éléments du Pilote A** | **NO-GO CONTENU (`0 / 12` complets)** | `11` enregistrements audio authentiques sont manquants et `C1` (`arkap.wav`) attend la confirmation de concordance phonétique et la preuve écrite de consentement du locuteur. |

### Décision finale
> **DÉCISION POUR LA BÊTA PRIVÉE : NO-GO TANT QUE LE CORPUS DES 12 ÉLÉMENTS ET LA RECETTE PHYSIQUE NE SONT PAS COMPLÉTÉS.**
>
> Tous les outils techniques, le suivi structuré des 12 éléments ([`PILOTE_A_SUIVI_12_ELEMENTS.json`](file:///C:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/PILOTE_A_SUIVI_12_ELEMENTS.json)), les procédures d'enregistrement et de génération du pack pilote indépendant (`pilote-a-oral-erfe`) ainsi que l'APK de recette (`app-debug.apk`) sont prêts. Le passage en **GO** pour la distribution aux 5–10 volontaires interviendra dès que :
> 1. Les **12 éléments du Pilote A** auront reçu leurs enregistrements authentiques, leur validation linguistique humaine et les consentements des locuteurs, et que le pack `pilote-a-oral-erfe` `v1` aura été généré.
> 2. Les **8 scénarios de la grille §1.3** auront été validés physiquement sur le **Samsung SM-A336E**.
