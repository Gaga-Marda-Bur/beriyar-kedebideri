# BERIYAR KEDEBIDERI — RAPPORT FINAL D'INTÉGRATION LOCALE (AR-MERGE-12)

**Référence :** `AR-MERGE-12`  
**Date :** 13 novembre 2026  
**Branche finale :** `dev`  
**Branche de sauvegarde pré-fusion :** `backup/dev-pre-ar-merge-12` (`5836c63fbb475b03e42e829a07fd4c0e20642dd3`)  
**Branche expérimentale préservée :** `feature/arabic-pdf-experimental` (`206382b`)

---

## 1. Commits créés et fusion locale

1. `1a1f512` — `feat(pdf): add experimental reversible Arabic PDF engine behind QA flag`
2. `d105f47` — `assets(fonts): bundle BeriyaArabicProto-Regular (SIL OFL 1.1) and build scripts`
3. `2f83805` — `test(pdf): add experimental Arabic PDF unit and Samsung QA integration tests`
4. `206382b` — `docs(qa): record Arabic diacritics qualification and homologation reports`
5. `cf6ccf7` — `merge: integrate experimental Arabic PDF engine (disabled by default, AR-MERGE-12)` (fusion `--no-ff` sur `dev`)

*(Aucun push distant, aucun déploiement.)*

---

## 2. Fichiers fusionnés dans `dev` (22 fichiers)

- **Moteur PDF :**
  - `mobile/lib/features/editor/services/beriya_pdf_service.dart`
  - `mobile/lib/features/editor/services/pdf_unicode_cmap.dart`
  - `mobile/lib/features/editor/services/arabic_pdf_text.dart`
  - `mobile/lib/features/editor/services/arabic_pdf_layout_data.dart`
- **Police, licence & scripts reproductibles :**
  - `mobile/pubspec.yaml`
  - `mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf` (`239 864` octets, `SIL OFL 1.1`)
  - `mobile/assets/fonts/experimental/OFL.txt`
  - `docs/qa_arabic_diacritics/build_proto_font.py`
  - `docs/qa_arabic_diacritics/generate_arabic_pdf_layout_dart.py`
- **Tests :**
  - `mobile/test/arabic_pdf_experimental_test.dart`
  - `mobile/integration_test/arabic_pdf_physical_test.dart`
- **Documentation linguistique & technique :**
  - `docs/BK-LING-AR-DIAC-001_VALIDATION_TYPOGRAPHIQUE.md`
  - `docs/AR_TYPO_02_RAPPORT_DECISION.md`
  - `docs/AR_TYPO_03_RAPPORT_QUALIFICATION.md`
  - `docs/AR_PDF_04_RAPPORT_ARCHITECTURES.md`
  - `docs/AR_PDF_05_RAPPORT_FINAL.md`
  - `docs/AR_PDF_06_RAPPORT_FINAL.md`
  - `docs/AR_INT_07_RAPPORT_INTEGRATION.md`
  - `docs/AR_QA_08_RAPPORT_FINAL.md`
  - `docs/AR_DEVICE_09_RAPPORT_FINAL.md`
  - `docs/AR_CLOSE_10_RAPPORT_CLOTURE.md`
  - `docs/AR_MERGE_READY_11_RAPPORT.md`
  - `docs/AR_MERGE_12_RAPPORT_FINAL.md` (présent rapport)

---

## 3. Documents QA exclus de `dev` (conservés localement)

Les preuves QA volumineuses et fichiers intermédiaires de `docs/qa_arabic_diacritics/` (captures PNG, PDFs générés, fichiers HTML/JSON de benchmark, sous-dossiers `device_09/`, `close_10/`, `dart_pdf_qa/`, `fonts/`, scripts `verify_*.py` / `run_*.py` / `audit_*.py`) ont été volontairement exclus de `dev` et conservés intacts localement sur disque sans suppression ni écrasement.

---

## 4. Résultats des tests après fusion sur `dev`

| Suite / Vérification | Résultat | Détails |
| :--- | :--- | :--- |
| **`flutter analyze` (`mobile/`)** | **PASS (`0` anomalie)** | `No issues found! (ran in 10.3s)` |
| **Suite Flutter complète (`flutter test`)** | **176 / 176 PASS** | `0` échec, `0` ignoré (inclut PDF arabe expérimental, exports Erfe historiques, translittération, Sticker Studio, No Ena, commerce) |
| **Suite Django complète (`manage.py test`)** | **173 exécutés, OK (`skipped=2`)** | `Ran 173 tests in 57.023s` (2 tests de concurrence PostgreSQL ignorés sur SQLite) |

---

## 5. État du drapeau expérimental et invariants

- `BeriyaPdfService.experimentalArabicPdfEnabled` = **`false`** (vérifié dans `beriya_pdf_service.dart` et par test unitaire).
- Aucun écran ou parcours utilisateur public ne référence `experimentalArabicPdfEnabled` ou `useExperimentalArabicPdf`.
- `erfe_pdf_text.dart`, le moteur de translittération officiel, les données pédagogiques, No Ena et Sticker Studio sont inchangés.

---

## 6. Limitations connues

1. **Quatre lettres Beřiya étendues (`U+067E` پ, `U+0695` ڕ, `U+06A0` ڠ, `U+06BD` ڽ) :** absentes de `arabicContextualForms` dans ce lot (rendues en forme isolée et consignées dans `ArabicPdfDiagnostics.unsupportedCharacters`).
2. **Paragraphe unique > 1 page sans `\n` :** `LogicalRtlArabicBlock` ne s'étend pas au travers d'un saut de page (découpage `MultiPage` entre paragraphes uniquement).
3. **Empilement > 1 marque combinante (`cl.length > 2`) :** seule la première marque combinante est rendue.

---

## 7. Procédure de retour arrière non destructive

- **Désactivation immédiate sans changement Git :** `BeriyaPdfService.experimentalArabicPdfEnabled` est déjà `false` par défaut.
- **Annulation non destructive de la fusion sur `dev` :**
  ```powershell
  git revert -m 1 cf6ccf7
  ```
- **Branche de sauvegarde pré-fusion disponible localement :** `backup/dev-pre-ar-merge-12` (`5836c63`).

---

## 8. Décision finale : **GO validé pour l'intégration locale dans `dev`**

L'intégration locale dans `dev` est **validée et sans régression** (`176/176` Flutter, `0` anomalie `flutter analyze`, `173` Django OK), avec le moteur PDF arabe expérimental **désactivé par défaut**. Tout push distant, déploiement ou activation publique reste suspendu jusqu'à nouvelle autorisation explicite.
