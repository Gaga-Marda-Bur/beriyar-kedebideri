# BERIYAR KEDEBIDERI — LOT BK-CONTENT-16
## Rapport final : intégration contrôlée et validation du premier parcours Erfe

**Branche active :** `dev` (commit de fusion `2fadcd3`)  
**Branche source conservée :** `feat/bk-content-15-pilot-courses` (`6f606f8`)  
**Sauvegarde locale de `dev` :** `backup/dev-pre-bk-content-16` (`3f3d9bd`)  
**Statut de publication :** **Aucune publication automatique**, **aucun push distant**, **aucun déploiement**.

---

## 1. Contrôles de publication et de sécurité (Phase 1)

L'audit des vues, permissions, serializers et du générateur de packs (`backend/core/permissions.py`, `backend/learning/views.py`, `backend/lessons/views.py`, `backend/quizzes/views.py`, `backend/alphabet/views.py`, `backend/vocabulary/views.py`, `backend/offline_packs/views.py`, `backend/offline_packs/services/offline_pack_generator.py`) confirme :

- Tous les endpoints publics filtrent strictement sur `status='published'` / `validation_status='published'` lorsque `is_staff_preview(request)` est faux.
- Les utilisateurs anonymes et les utilisateurs authentifiés non-staff (`is_staff=False`) reçoivent **0** élément de préproduction sur les 8 endpoints publics (`/api/learning/themes/`, `/api/learning/units/`, `/api/lessons/`, `/api/lessons/items/`, `/api/alphabet/characters/`, `/api/vocabulary/words/`, `/api/quizzes/`, `/api/offline-packs/`), et `404` sur les détails / `core-flow` des unités `draft`.
- Un utilisateur staff (`is_staff=True`) peut consulter les contenus `draft` via `?status=draft` pour prévisualisation/validation.
- `OfflinePackGenerator` exclut tout thème, unité, caractère ou mot non `published` lorsque `LessonPack.status == 'published'`.
- Tests de non-exposition ajoutés : [`backend/learning/tests_non_exposure.py`](../backend/learning/tests_non_exposure.py) (**4/4 réussis**).

---

## 2. État Git et fusion locale (Phase 2)

- Sauvegarde créée : `backup/dev-pre-bk-content-16` → `3f3d9bd`
- Fusion locale sans fast-forward dans `dev` : `2fadcd3` (`Merge branch 'feat/bk-content-15-pilot-courses' into dev (BK-CONTENT-16)`)
- Branche `feat/bk-content-15-pilot-courses` conservée intacte (`6f606f8`).

---

## 3. Import dans une base isolée (Phase 3)

Exécution de `import_preprod_courses` sur une base SQLite temporaire isolée (aucune base de production touchée) :

| Étape | `created` | `skipped_existing` | `skipped_protected` | `rejected` | État base après exécution |
|---|---|---|---|---|---|
| 1. `--dry-run` | 980 | 0 | 0 | 0 | `units=0, lessons=0, quiz=0` (rollback complet) |
| 2. Import réel | 980 | 0 | 0 | 0 | `themes=3, units=14, lessons=14, items=73, chars=25, words=48, quiz=219` |
| 3. Réimport idempotent | 0 | 396 | 0 | 0 | Aucun doublon (`units=14, items=73, quiz=219`) |
| 4. Protection éditions humaines (`ERF-01` → `validated`, `human_edited=True`) | 0 | 395 | 1 | 0 | Titre et statut `validated` préservés ; `published=0`, `active_quizzes=0` |

---

## 4. Tests Django et Flutter sur `dev`

- **Django (`manage.py test`)** : **181 tests exécutés**, 179 réussis, 2 ignorés (`OK (skipped=2)`), `System check identified no issues (0 silenced)`.
- **Flutter (`flutter test`)** : **183/183 tests réussis** (`All tests passed!`), incluant [`mobile/test/preprod_pilot_courses_qualification_test.dart`](../mobile/test/preprod_pilot_courses_qualification_test.dart) (ordre `ERF-01`..`ERF-05`, 25 caractères Erfe, `effectiveCoreFlow`, rendu/saisie `BeriyaKeyboard`, gestion des audios absents).

---

## 5. Cinq fiches pédagogiques — Alphabet Erfe (`ERF-01` à `ERF-05`)

Source commune : `beriya_erfe_transliteration_mapping.json; schema_version 1.0` (alignée avec `shared/linguistics/beriya_erfe_transliteration_mapping.json`).  
**Statut de validation pour les 5 leçons :** `À vérifier` (brouillon `draft`, `public_enabled: false`).  
**État audio :** `A_ENREGISTRER` (0/25 audios disponibles).  
**Exercices par leçon :** 5 `mcq` (reconnaissance), 5 `listen_select` (lecture/écoute), 5 `listen_type` (composition clavier) — tous **désactivés** (`enabled: false`, `is_active: false`) jusqu'à validation linguistique et enregistrement audio.

### Fiche 1 — `ERF-01` : Alphabet Erfe — groupe 1
- **Objectif :** Identifier les caractères Erfe et leurs équivalents latins du référentiel.
- **Lettres & correspondances (ordre 1→5) :**
  1. `𖺠` (`U+16EA0`) → `A` (réf. arabe `ا`) — phonétique existante : `/a/`, exemple : `𖺵𖺠` (`ta` = maison)
  2. `𖺡` (`U+16EA1`) → `B` (réf. arabe `ب`) — phonétique existante : `/b/`, exemple : `𖺡𖺣` (`be` = pays)
  3. `𖺢` (`U+16EA2`) → `D` (réf. arabe `د`) — phonétique existante : `/d/`, exemple : `𖺢𖺣` (`de` = terre)
  4. `𖺣` (`U+16EA3`) → `E` (réf. arabe `آ`) — phonétique existante : `/e/`, exemple : `𖺡𖺣` (`be` = pays)
  5. `𖺤` (`U+16EA4`) → `F` (réf. arabe `ف`) — phonétique/exemple : non renseignés (à vérifier)
- **Exercices :** `5 mcq` (reconnaissance), `5 listen_select`, `5 listen_type` (tous désactivés).

### Fiche 2 — `ERF-02` : Alphabet Erfe — groupe 2
- **Objectif :** Identifier les caractères Erfe et leurs équivalents latins du référentiel.
- **Lettres & correspondances (ordre 1→5) :**
  1. `𖺥` (`U+16EA5`) → `G` (réf. arabe `ق`)
  2. `𖺦` (`U+16EA6`) → `H` (réf. arabe `ه`)
  3. `𖺧` (`U+16EA7`) → `I` (réf. arabe `ی`)
  4. `𖺨` (`U+16EA8`) → `J` (réf. arabe `ج`)
  5. `𖺩` (`U+16EA9`) → `K` (réf. arabe `ك`)
- **Exercices :** `5 mcq`, `5 listen_select`, `5 listen_type` (tous désactivés).

### Fiche 3 — `ERF-03` : Alphabet Erfe — groupe 3
- **Objectif :** Identifier les caractères Erfe et leurs équivalents latins du référentiel.
- **Lettres & correspondances (ordre 1→5) :**
  1. `𖺪` (`U+16EAA`) → `L` (réf. arabe `ل`)
  2. `𖺫` (`U+16EAB`) → `M` (réf. arabe `م`)
  3. `𖺬` (`U+16EAC`) → `N` (réf. arabe `ن`)
  4. `𖺭` (`U+16EAD`) → `Ɲ` (réf. arabe `ڽ`)
  5. `𖺮` (`U+16EAE`) → `Ŋ` (réf. arabe `ڠ`)
- **Exercices :** `5 mcq`, `5 listen_select`, `5 listen_type` (tous désactivés).

### Fiche 4 — `ERF-04` : Alphabet Erfe — groupe 4
- **Objectif :** Identifier les caractères Erfe et leurs équivalents latins du référentiel.
- **Lettres & correspondances (ordre 1→5) :**
  1. `𖺯` (`U+16EAF`) → `O` (réf. arabe `ۆ`)
  2. `𖺰` (`U+16EB0`) → `P` (réf. arabe `پ`)
  3. `𖺱` (`U+16EB1`) → `R` (réf. arabe `ر`)
  4. `𖺲` (`U+16EB2`) → `Ř` (réf. arabe `ڕ`)
  5. `𖺳` (`U+16EB3`) → `S` (réf. arabe `س`)
- **Exercices :** `5 mcq`, `5 listen_select`, `5 listen_type` (tous désactivés).

### Fiche 5 — `ERF-05` : Alphabet Erfe — groupe 5
- **Objectif :** Identifier les caractères Erfe et leurs équivalents latins du référentiel.
- **Lettres & correspondances (ordre 1→5) :**
  1. `𖺴` (`U+16EB4`) → `Š` (réf. arabe `ش`)
  2. `𖺵` (`U+16EB5`) → `T` (réf. arabe `ت`) — phonétique existante : `/t/`, exemple : `𖺵𖺠` (`ta` = maison)
  3. `𖺶` (`U+16EB6`) → `U` (réf. arabe `ۇ`)
  4. `𖺷` (`U+16EB7`) → `W` (réf. arabe `و`)
  5. `𖺸` (`U+16EB8`) → `Y` (réf. arabe `ي`)
- **Exercices :** `5 mcq`, `5 listen_select`, `5 listen_type` (tous désactivés).

---

## 6. Tableau Excel de validation & Audios à enregistrer

- **Classeur Excel généré :** [`docs/BK_CONTENT_16_VALIDATION_ALPHABET_ERFE.xlsx`](BK_CONTENT_16_VALIDATION_ALPHABET_ERFE.xlsx)
  - Onglets : `Vue globale (ERF-01..05)`, `ERF-01`, `ERF-02`, `ERF-03`, `ERF-04`, `ERF-05`, `Audios à enregistrer`.
  - Chaque ligne contient : leçon, ordre, ID, lettre Erfe, code Unicode, équivalent latin officiel, référence arabe, valeur phonétique existante (si disponible), exemple existant (si disponible), source, statut audio, anomalie éventuelle, décision du responsable linguistique (`À vérifier` avec liste déroulante `À vérifier` / `Validé linguistiquement` / `Rejeté`), et commentaire.
- **Audios à enregistrer (25 lettres × 3 rôles = 75 captures recommandées, minimum 25 sons purs) :**
  - `ERF-01-I01`..`ERF-01-I05` (`𖺠` A, `𖺡` B, `𖺢` D, `𖺣` E, `𖺤` F)
  - `ERF-02-I01`..`ERF-02-I05` (`𖺥` G, `𖺦` H, `𖺧` I, `𖺨` J, `𖺩` K)
  - `ERF-03-I01`..`ERF-03-I05` (`𖺪` L, `𖺫` M, `𖺬` N, `𖺭` Ɲ, `𖺮` Ŋ)
  - `ERF-04-I01`..`ERF-04-I05` (`𖺯` O, `𖺰` P, `𖺱` R, `𖺲` Ř, `𖺳` S)
  - `ERF-05-I01`..`ERF-05-I05` (`𖺴` Š, `𖺵` T, `𖺶` U, `𖺷` W, `𖺸` Y)

---

## 7. Anomalies restantes

1. **Absence totale d'audio authentique** sur les 25 lettres (`A_ENREGISTRER`), maintenant les exercices d'écoute (`listen_select`, `listen_type`) et la publication bloqués.
2. **Valeurs phonétiques IPA et exemples** absents pour 20/25 lettres dans les référentiels actuels (seuls `A`, `B`, `D`, `E`, `T` disposent déjà d'une entrée phonétique/exemple dans `seed_learning_core.py`).
3. **Anomalies des lots phrases/lexique (`P01..P06`, `V01..V03`)** conservées en `draft` : ligne 55 (`U+16EC6`), ligne 67 (`FR_ABSENT`), 43 groupes d'homographes DF/ADES 2007 et `beriya_erfe = null` non convertis automatiquement.
