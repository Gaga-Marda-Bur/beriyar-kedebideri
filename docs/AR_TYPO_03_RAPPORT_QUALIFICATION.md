# BERIYAR KEDEBIDERI — RAPPORT DE QUALIFICATION LOT AR-TYPO-03
**Référence :** `AR-TYPO-03`  
**Date :** 13 novembre 2026  
**Base technique :** branche `dev`, commit `5836c63` (aucune modification du code de production)  
**Police évaluée :** `docs/qa_arabic_diacritics/fonts/BeriyaArabicProto-Regular.ttf` (dérivée SIL OFL 1.1)  

---

## 1. Synthèse et Recommandation finale : **NO-GO intégration immédiate (statut mixte par plateforme)**

1. **PDF Dart (`package:pdf 3.12.0` + `pw.Font.ttf`) : NO-GO en l'état.**  
   Le moteur `package:pdf 3.12.0` utilisé par `Beriya Erfe Editor` (`beriya_pdf_service.dart`) **n'exécute pas les tables `GPOS` (`MarkBasePos`)** et convertit les lettres arabes en **Formes de présentation B (`U+FBFC`, `U+FBD7`, `U+FBD9`, `U+FE8D`, `U+FE81`)** tout en inversant l'ordre `base + marque` en `marque + base` dans les champs `pw.TextDirection.rtl`.  
   Par conséquent, une simple substitution de police par `BeriyaArabicProto-Regular.ttf` **ne résout pas** l'export PDF de `Beriya Erfe Editor` : il faudrait soit un positionnement explicite analogue à `erfe_pdf_text.dart` (hors périmètre ici), soit un moteur PDF basé sur HarfBuzz/Skia.
2. **Android physique (Samsung SM-A336E) : NON TESTÉ.**  
   Aucun appareil n'était connecté lors de l'exécution (`adb devices -l` vide). Conformément au protocole, aucun GO complet ne peut être prononcé.
3. **Web / Chrome (HarfBuzz / Skia / PDFium) : GO technique confirmé** (hérité de AR-TYPO-02).

---

## 2. Tableau GO / NO-GO par plateforme

| Plateforme / Moteur | Résultat | Détail factuel |
| :--- | :---: | :--- |
| **Web / Chrome (HarfBuzz / Blink)** | **GO** | 16/16 formes ancrées (`GPOS` Lookup 3 + `GSUB`), lisibles à 12/16/24/36 px et zoom 200 %, RTL/mixte OK (`ar_typo_02_proto_comparison.png`). |
| **PDF Chrome / PDFium (HarfBuzz)** | **GO** | Rendu fidèle (`ar_typo_02_pdf_render_p1.png`), `/ToUnicode` complet (`0627/0622/06CC/06C6/06C7` + `0300/0301/0304/0307`), 0 perte (`pypdf`, `pdfminer.six`, DOM). |
| **PDF Dart (`package:pdf 3.12.0` + `pw.Font.ttf`)** | **NO-GO** | `GPOS` ignoré (marques décalées à gauche, `ا̄` = `7`), `/ToUnicode` écrit des Formes de présentation B, ordre `marque + base` inversé en RTL, chaînes mixtes RTL inversées. |
| **Android physique (Samsung SM-A336E)** | **NON TESTÉ** | Appareil absent (`adb devices -l` vide). Captures physiques et tests de saisie/sélection non réalisés. |

---

## 3. Qualification Android physique (Samsung SM-A336E)

- **Statut :** **NON TESTÉE** (`adb.exe devices -l` : `List of devices attached` vide).
- **Captures physiques :** aucune.
- **Impact décisionnel :** interdit toute conclusion **GO complet**, même si Flutter utilise Skia/HarfBuzz sur Android (comportement réel et polices de substitution système non vérifiés physiquement).

---

## 4. Qualification du PDF Dart (`package:pdf 3.12.0` + `pw.Font.ttf`)

- **Environnement isolé :** `docs/qa_arabic_diacritics/dart_pdf_qa/` (sans modification de `mobile/`).
- **Artefact généré :** `docs/qa_arabic_diacritics/ar_typo_03_dart_pdf.pdf` (`20 912` octets).
- **Captures PDFium du PDF Dart :** `docs/qa_arabic_diacritics/ar_typo_03_dart_pdf_p1.png` et `ar_typo_03_dart_pdf_p2.png`.

### Constats visuels et typographiques sur `package:pdf 3.12.0`

| Critère | Résultat | Preuve observée |
| :--- | :---: | :--- |
| Chargement `pw.Font.ttf(BeriyaArabicProto)` | **OK** | Police embarquée `/F16 /BeriyaArabicProto-Regular` (`Type0`, `Identity-H`). |
| Façonnage contextuel arabe (`GSUB` / formes) | **Partiel** | `package:pdf` applique sa table interne de Formes de présentation B (ex. `با́ب` relié visuellement sur `ar_typo_03_dart_pdf_p2.png`), sans utiliser `GSUB` OpenType. |
| Positionnement des diacritiques (`GPOS`) | **KO** | **`GPOS` `MarkBasePos` ignoré.** Toutes les marques (`U+0300/0301/0304/0307`) sont dessinées à gauche de la base (`ا̄` ressemble à `7`, `ی̄` détaché à gauche) à 12, 16, 24 et 36 pt, identique à `NotoSansArabic-Regular`. |
| Rendu RTL sur texte mixte | **KO** | `pw.Text('Voyelles consécutives: ...', textDirection: pw.TextDirection.rtl)` inverse les mots français (`:sev it ucésnoc selleyoV`, `:selleutxetnoc semroF`). |
| Texte Erfe mixte sans `erfePdfText` | **KO (attendu)** | En appel brut sans `erfe_pdf_text.dart`, les marques Erfe ne s'ancrent pas et `/ToUnicode` produit des hex impairs (`16EA0`) avertis par `pypdf` et tronqués en `ᛪ` par `pdfminer.six`. |

---

## 5. Contrôle Unicode, `/ToUnicode`, extraction et réversibilité (PDF Dart)

Diagnostic complet : `docs/qa_arabic_diacritics/ar_typo_03_dart_pdf_diag.json`.

### 5.1 Table `/ToUnicode` générée par `package:pdf 3.12.0` (`/F16 /BeriyaArabicProto-Regular`)
- Les 4 marques combinantes sont mappées : `<0307>`, `<0304>`, `<0300>`, `<0301>`.
- Les lettres arabes sont mappées **via leurs Formes de présentation B** (`<FBFC>`, `<FBD7>`, `<FBD9>`, `<FE8D>`, `<FE81>`, `<FBDA>`, `<FBFE>`, `<FE8E>`, `<FE82>`, `<FBFF>`, `<FBD8>`), en plus des points de code nominaux `<0627>`, `<0622>`, `<06CC>`, `<06C6>`, `<06C7>` lorsqu'ils apparaissent en contexte mixte LTR.

### 5.2 Extraction comparée (`pypdf` vs `pdfminer.six`) et diagnostic des écarts

| Source / Contexte dans le PDF Dart | Texte extrait (`pypdf` & `pdfminer.six`) | Après `NFKC` | Diagnostic exact |
| :--- | :--- | :--- | :--- |
| Cellules tableau `NotoSansArabic` (LTR) | `ﯼ̇`, `ﯼ̄`, `ﯗ̄`, `ﯙ̄`, `ﺍ̄`, `ﺁ̄`, `ﺍ̀`, `ﺍ́`… | `ی̇`, `ی̄`, `ۇ̄`, `ۆ̄`, `ا̄`, `آ̄`… | **Altération par le générateur PDF** (Formes de présentation B au lieu de `U+06xx`). Nécessite `NFKC` pour retrouver les points de code nominaux. |
| Cellules tableau `BeriyaArabicProto (RTL)` | `̇ﯼ`, `̄ﯼ`, `̄ﯗ`, `̄ﯙ`, `̄ﺍ`, `̀ﺁ`, `́ﺍ`… | `̇ی`, `̄ی`, `̄ۇ`, `̄ۆ`, `̄ا`, `̀آ`, `́ا`… | **Inversion `marque + base` + Formes B par le générateur PDF** (`bidi` dans `package:pdf`). **Non réversible** tel quel par un moteur de translittération attendant `base + marque`. |
| Ligne `12pt`–`36pt` (RTL) | `̇ﯼ̄ﯼ̄ﯗ̄ﯙ̄ﺍ̄ﺁ̀ﺍ́ﺍ̀ﺁ́ﺁ̀ﯼ́ﯼ̀ﯗ́ﯗ̀ﯙ́ﯙ` | `̇ی̄ی̄ۇ̄ۆ̄ا̄آ̀ا́ا̀آ́آ̀ی́ی̀ۇ́ۇ̀ۆ́ۆ` | **Inversion logique `marque + base`** : la marque précède la lettre suivante ou se place devant la base. |
| Ligne mixte LTR (`Mixte Latin / Arabe / Erfe`) | `ا́آ̀ی̄ — (ۆ́, ۇ̀, ی̇)` | `ا́آ̀ی̄ — (ۆ́, ۇ̀, ی̇)` | Ordre logique conservé en paragraphe LTR (hors `TextDirection.rtl`). |

**Synthèse chiffrée de l'extraction sur les 16 séquences exactes (`U+06xx + U+030x`) :**
- `pypdf` : `6/16` en ordre logique exact, `2/16` en ordre inversé, **`8/16` absentes en Unicode nominal** (remplacées par des Formes de présentation B ou inversées).
- `pdfminer.six` : `6/16` en ordre logique exact, `2/16` en ordre inversé, **`8/16` absentes en Unicode nominal**.
- **Réversibilité après copier-coller :** **ÉCHEC** pour les blocs `pw.TextDirection.rtl` de `package:pdf 3.12.0`, car même après `NFKC`, la séquence extraite devient `marque + base` (`̇ی`) au lieu de `base + marque` (`ی̇`), ce qui casse la reconnaissance par le moteur de translittération.

---

## 6. Compatibilité `GPOS` / `GSUB`

- **Moteurs complets (HarfBuzz : Chrome, Skia, PDFium) :** `GPOS` Lookup 3 (`MarkBasePos` Classe 0) et `GSUB` (`isol/init/medi/fina`) fonctionnent pleinement sur `BeriyaArabicProto-Regular.ttf`.
- **Moteur Dart `package:pdf 3.12.0` (`pw.Font.ttf`) :** ne lit ni `GPOS` ni `GSUB`. Toute solution PDF dans Flutter reposant sur `package:pdf` nécessiterait une couche dédiée (analogue à `erfe_pdf_text.dart`) pour positionner les marques arabes et préserver `/ToUnicode` nominal, ou un changement de moteur PDF.

---

## 7. Vérification de la licence SIL OFL 1.1

Contrôle effectué sur `BeriyaArabicProto-Regular.ttf` et `mobile/assets/fonts/Noto-OFL.txt` :

| Exigence SIL OFL 1.1 | Statut | Observation |
| :--- | :---: | :--- |
| Reserved Font Names (RFN) | **Conforme (sous réserve)** | `Noto-OFL.txt` ne déclare pas de RFN explicite, et `Noto` est une marque Google LLC (`nameID=7`). `nameID=1/4/6` sont renommés (`Beriya Arabic Proto` / `BeriyaArabicProto-Regular`). **Point à corriger avant diffusion :** `nameID=3` contient encore `2.009;GOOG;NotoSansArabic-Regular` — le passer à `2.009;BERIYA;BeriyaArabicProto-Regular`. |
| Conservation copyright & licence | **Conforme** | `nameID=0` (`Copyright 2015-2021 Google LLC`), `nameID=13` (SIL OFL 1.1) et `nameID=14` (`http://scripts.sil.org/OFL`) conservés ; `Noto-OFL.txt` présent dans le dépôt. |
| Documentation des modifications | **À inclure** | Documenter la dérivation (ajout `U+0300/0301/0304/0307` depuis `NotoSans-Regular.ttf` + `GPOS` Classe 0) via `build_proto_font.py` dans un fichier de licence accompagnant la police. |
| Redistribution Android / Web / PDF | **Autorisée** | La licence OFL 1.1 autorise l'embarquement APK/web et l'incorporation dans les PDF (les documents créés avec la police ne sont pas soumis à l'OFL), sans vente isolée du fichier de police. |

---

## 8. Non-régression de l'existant

- Aucun fichier de production modifié (`git status --short` limité à `docs/`).
- Suite Flutter ciblée (`transliteration_test.dart`, `transliteration_diacritics_test.dart`, `erfe_typography_test.dart`, `beriya_editor_test.dart`, `sticker_studio_test.dart`, `historical_tools_navigation_test.dart`) exécutée sur `dev` (`5836c63`) : **0 régression** (Erfe, 25 lettres fondamentales, 16 formes diacritiques Erfe, Studio Sticker, PDF Erfe existant et No Ena inchangés).
