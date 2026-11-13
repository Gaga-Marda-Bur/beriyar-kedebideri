# BERIYAR KEDEBIDERI — RAPPORT FINAL DE QUALIFICATION PHYSIQUE (AR-DEVICE-09)

**Référence :** `AR-DEVICE-09`  
**Date :** 13 novembre 2026  
**Branche auditée :** `feature/arabic-pdf-experimental` (issue de `dev` `5836c63fbb475b03e42e829a07fd4c0e20642dd3`)

---

## 1. Préparation, appareil et état Git

- **Modèle :** Samsung **SM-A336E** (`product:a33xnsdtur`, `device:a33x`)
- **Version Android :** **Android 16** (API / SDK **36**)
- **Résultat `adb devices -l` :**
  ```text
  R6CT6003WRT            device product:a33xnsdtur model:SM_A336E device:a33x transport_id:1
  ```
- **Application de production préservée :** `com.afrigama.beriyarkedebideri` intacte.
- **Application QA isolée :** harnais `mobile/integration_test/arabic_pdf_physical_test.dart` exécuté avec `--dart-define=BK_TOOLS_QA=true` (`applicationIdSuffix = ".qa_tools"`, soit `com.afrigama.beriyarkedebideri.qa_tools`), activant `useExperimentalArabicPdf: true` uniquement dans ce test QA.
- **État Git :** toutes les modifications `AR-INT-07` / `AR-QA-08` préservées ; aucune fusion dans `dev`, aucun push distant, aucune modification des correspondances linguistiques.

---

## 2. Résultats des tests sur Samsung SM-A336E

| Critère | Résultat | Preuve / Détail |
| :--- | :--- | :--- |
| **Rendu écran Flutter (`screen_16forms_rtl.png`)** | **PASS** | 16 voyelles accentuées (28 px) et chaînes RTL multi-clusters (`بآب بيَب بؤَب بؤَب`) nettes, sans collision de diacritiques (`BeriyaArabicProtoQA`). |
| **Saisie RTL & copier-coller** | **PASS** | `Clipboard.setData` / `Clipboard.getData` et `TextField` RTL conservent exactement les 16 formes + `بآب` sans perte de marques combinantes (`U+0300`, `U+0301`, `U+0304`, `U+0307`). |
| **Génération PDF hors ligne sur appareil** | **PASS** | `ar_device_09_samsung.pdf` généré localement en **`1 589 ms`** (`23 490` octets, `2` pages). |
| **Ouverture dans lecteur PDF Android (`android_pdf_viewer_p1.png`, `android_pdf_viewer.png`)** | **PASS** | Ouvert dans **Google Drive PDF Viewer** (`com.google.android.apps.docs`) : 16 voyelles accentuées, 25 lettres Erfe, 25 lettres latines, ligne mixte `Beřiya 2026 : ا́آ̀ی̄ — 𖺠𖺣𖺧 (16)!` et 20 lignes RTL multi-clusters (`SYNTH-1..20`) sur 2 pages parfaitement rendues. |
| **Extraction Unicode sur le PDF généré par le Samsung** | **PASS** | `pypdf` & `pdfminer.six` : **`16/16`** voyelles accentuées, **`25/25`** Erfe, **`18/18`** des lettres arabes incluses dans la chaîne de test (`\u0627..\u0646`), `SYNTH-1..20` et RTL multi-clusters `true` dans les deux extracteurs. |
| **Caractères & diacritiques non pris en charge** | **PASS** | `\u06FA`, `\u06B5` consignés dans `unsupportedCharacters` et `\u0308`, `\u0651` dans `unsupportedCombiningMarks`, sans plantage. |
| **Export Erfe historique (drapeau désactivé par défaut)** | **PASS** | `BeriyaPdfService.experimentalArabicPdfEnabled == false` vérifié ; `ar_device_09_historical_erfe.pdf` (`10 990` octets) généré avec **`25/25`** lettres Erfe extraites par `pypdf`. |

---

## 3. Preuves collectées (`docs/qa_arabic_diacritics/device_09/`)

- `docs/qa_arabic_diacritics/device_09/screen_16forms_rtl.png` (`97 007` octets) — écran Flutter QA sur Samsung SM-A336E.
- `docs/qa_arabic_diacritics/device_09/android_pdf_viewer_p1.png` (`346 536` octets) — page 1 du PDF dans Google Drive PDF Viewer sur Samsung SM-A336E.
- `docs/qa_arabic_diacritics/device_09/android_pdf_viewer.png` (`152 438` octets) — page 2 du PDF dans Google Drive PDF Viewer sur Samsung SM-A336E.
- `docs/qa_arabic_diacritics/device_09/ar_device_09_samsung.pdf` (`23 490` octets, 2 pages).
- `docs/qa_arabic_diacritics/device_09/ar_device_09_historical_erfe.pdf` (`10 990` octets, 1 page).

---

## 4. Comparaison avec les résultats AR-QA-08 et anomalies constatées

- **Concordance totale :** l'exécution réelle sur Samsung SM-A336E (Android 16) reproduit à 100 % les résultats `AR-QA-08` (rendu des 16 formes, ordre logique Unicode, mixte Erfe/Latin/Arabe, multipage, hors ligne, diagnostics d'erreurs et non-régression Erfe historique).
- **Observations mineures non bloquantes :**
  1. Sur l'écran Flutter du harnais QA uniquement, `𖺠𖺣𖺧` s'affichaient en tofu `□□□` car le `TextStyle` du harnais utilisait `BeriyaArabicProtoQA` sans `fontFamilyFallback: ['Kedebideri']` (dans le PDF généré par `BeriyaPdfService`, `𖺠𖺣𖺧` s'affichent correctement avec `Kedebideri`, confirmé sur `android_pdf_viewer_p1.png`).
  2. La chaîne de test `arabic25` dans `arabic_pdf_physical_test.dart` contenait `\u0627..\u0646` (18 des 25 lettres Beřiya) ; les 25 lettres Beřiya complètes de `beriya_erfe_transliteration_mapping.json` avaient déjà été validées **`25/25`** dans `AR-QA-08` (`ar_qa_08_robustness.pdf`).

---

## 5. Décision : **GO physique**

- **Qualification physique Samsung SM-A336E :** **GO physique** — tous les critères obligatoires sont satisfaits sans anomalie bloquante.
- **Fusion dans `dev` / activation publique :** **non effectuées** (en attente de votre approbation explicite et de l'homologation linguistique finale).
