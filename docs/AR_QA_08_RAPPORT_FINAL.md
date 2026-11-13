# BERIYAR KEDEBIDERI — RAPPORT FINAL D'AUDIT ET DE QUALIFICATION (LOT AR-QA-08)

**Référence :** `AR-QA-08`  
**Date :** 13 novembre 2026  
**Branche auditée :** `feature/arabic-pdf-experimental`  
**Référence de départ :** `dev` (`5836c63fbb475b03e42e829a07fd4c0e20642dd3`)

---

## 1. État Git et inventaire des fichiers

- **Branche active :** `feature/arabic-pdf-experimental`
- **`HEAD` :** `5836c63fbb475b03e42e829a07fd4c0e20642dd3`
- **`git merge-base dev HEAD` :** `5836c63fbb475b03e42e829a07fd4c0e20642dd3` (aucun commit sur `dev`, aucune fusion, aucun push distant)
- **Diff suivi (`5836c63..HEAD`, 3 fichiers modifiés, `+111 / -23` lignes) :**
  - `mobile/lib/features/editor/services/beriya_pdf_service.dart` (`+90` / `-23` dans le diff, drapeau QA + routage conditionnel)
  - `mobile/lib/features/editor/services/pdf_unicode_cmap.dart` (`+43` / `-0`, `ensureNominalArabicPdfUnicode` et `_NominalArabicAndUtf16Cmap`)
  - `mobile/pubspec.yaml` (`+1`, déclaration de l'asset `assets/fonts/experimental/`)
- **Fichiers non suivis ajoutés :**
  - Code applicatif & tests (`mobile/`) :
    - `mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf` (`239 864` octets)
    - `mobile/assets/fonts/experimental/OFL.txt` (`SIL OFL 1.1`)
    - `mobile/lib/features/editor/services/arabic_pdf_layout_data.dart` (`39` lettres arabes, `500` entrées `GPOS`)
    - `mobile/lib/features/editor/services/arabic_pdf_text.dart` (`LogicalRtlArabicBlock`, `arabicPdfText`, `ArabicPdfDiagnostics`)
    - `mobile/test/arabic_pdf_experimental_test.dart` (`4` tests)
  - Livrables QA (`docs/`, conservés intacts) :
    - `docs/BK-LING-AR-DIAC-001_VALIDATION_TYPOGRAPHIQUE.md`
    - `docs/AR_TYPO_02_RAPPORT_DECISION.md`
    - `docs/AR_TYPO_03_RAPPORT_QUALIFICATION.md`
    - `docs/AR_PDF_04_RAPPORT_ARCHITECTURES.md`
    - `docs/AR_PDF_05_RAPPORT_FINAL.md`
    - `docs/AR_PDF_06_RAPPORT_FINAL.md`
    - `docs/AR_INT_07_RAPPORT_INTEGRATION.md`
    - `docs/AR_QA_08_RAPPORT_FINAL.md` (présent rapport)
    - `docs/qa_arabic_diacritics/` (`75+` fichiers d'audit, incluant `ar_qa_08_robustness.pdf`)
- **Absence de modifications involontaires :** aucun fichier hors périmètre (les fichiers `backend/*/__pycache__/*.pyc` générés pendant les tests Django ont été restaurés via `git checkout -- backend/`). Aucun fichier temporaire QA n'est présent dans `mobile/assets/` en dehors de la police expérimentale et de sa licence `OFL.txt`.

---

## 2. Audit du moteur PDF

- **Séparation historique / expérimental :**
  - `mobile/lib/features/editor/services/erfe_pdf_text.dart` est intact.
  - `BeriyaPdfService.experimentalArabicPdfEnabled` vaut `false` par défaut.
  - La recherche statique sur `mobile/lib/` et `mobile/test/` confirme qu'aucun écran utilisateur, réglage public, ou service autre que `beriya_pdf_service.dart` et `arabic_pdf_experimental_test.dart` ne référence `experimentalArabicPdfEnabled`, `useExperimentalArabicPdf`, `arabicPdfText` ou `LogicalRtlArabicBlock`.
  - Lorsque `useExperimentalArabic` est `false`, `BeriyaPdfService.generatePdfBytes` ne charge pas `BeriyaArabicProto-Regular.ttf` et emprunte exclusivement `erfePdfText`.
- **Gestion des erreurs et caractères non pris en charge :**
  - Les caractères arabes hors table (`arabicContextualForms`) sont consignés dans `ArabicPdfDiagnostics.unsupportedCharacters` et rendus via `fallbackFont` si leur largeur dans la police arabe est `<= 0` (avec repli largeur `fontSize * 0.5`), sans exception.
  - Les marques combinantes hors `{U+0300, U+0301, U+0304, U+0307}` sont consignées dans `ArabicPdfDiagnostics.unsupportedCombiningMarks`.
- **Hors ligne :** `BeriyaPdfService.generatePdfBytes` charge uniquement les polices embarquées via `rootBundle` et génère le PDF localement sans aucun appel réseau.

---

## 3. Résultats des tests de robustesse et non-régression

| Suite / Vérification | Résultat | Détails |
| :--- | :--- | :--- |
| **`flutter analyze` (`mobile/`)** | **PASS (`0` anomalie)** | `No issues found! (ran in 8.6s)` après correction du commentaire doc ligne 182 de `arabic_pdf_layout_data.dart` |
| **Tests PDF expérimentaux (`arabic_pdf_experimental_test.dart`)** | **4 / 4 PASS** | Drapeau désactivé par défaut ; export historique Erfe + 25 lettres fondamentales ; multipage/RTL/mixte/Erfe + diagnostics (`0x06FA`, `0x06B5`, `0x0308`, `0x0651`) ; chaînes synthétiques contextuelles, retours à la ligne et paragraphe vide |
| **Suite Flutter complète (`flutter test`)** | **176 / 176 PASS** | `0` échec, `0` ignoré (inclut Erfe, translittération, Studio Sticker, No Ena, sécurité commerciale, PDF) |
| **Suite Django complète (`manage.py test`)** | **173 exécutés, OK (`skipped=2`)** | `Ran 173 tests in 51.714s` ; 2 tests de concurrence PostgreSQL ignorés sur SQLite |

*Note de traçabilité :* `arabic_pdf_experimental_test.dart` utilise exclusivement les lettres officielles de `shared/linguistics/beriya_erfe_transliteration_mapping.json`, les 16 formes candidates et des chaînes synthétiques explicitement préfixées `SYNTH-` (aucun vocabulaire Beřiya inventé).

---

## 4. Contrôle PDF (`docs/qa_arabic_diacritics/ar_qa_08_robustness.pdf`)

- **Dimensions :** `27 581` octets, `3` pages.
- **Tables `/ToUnicode` :** `0` entrée `Presentation Forms-B` (`FBxx` / `FExx`) détectée dans les flux `/ToUnicode` (conservation nominale `U+06xx`).
- **Extraction brute sans post-traitement :**
  - **16 formes accentuées :** `pypdf` = **`16 / 16`**, `pdfminer.six` = **`16 / 16`**.
  - **25 lettres fondamentales Erfe :** `pypdf` = **`25 / 25`**, `pdfminer.six` = **`25 / 25`**.
  - **25 lettres fondamentales arabes :** `pypdf` = **`25 / 25`**, `pdfminer.six` = **`25 / 25`**.
  - **Chaînes contextuelles arabes (`بتثج`, `عغفق`, `بۆب`, etc.) :** `pypdf` = **`true`**, `pdfminer.six` = **`true`**.
  - **Chaînes longues multipages (`SYNTH-1..24`, page 3) :** `pypdf` = **`true`**, `pdfminer.six` = **`true`**.
- **Rendu visuel :** validé précédemment sur `docs/qa_arabic_diacritics/ar_int_07_p1.png` ; aucun outil CLI `pdftoppm` / `pymupdf` n'est installé sur ce poste pour re-rasteriser `ar_qa_08_robustness.pdf` en PNG.
- **Copier-coller depuis un lecteur PDF interactif :** **NON TESTÉ** (aucun appareil Android connecté, vérification automatisée via `pypdf` et `pdfminer.six` uniquement).
- **Limites des extracteurs documentées séparément :**
  1. `pypdf` et `pdfminer.six` ne reflètent pas nécessairement l'heuristique de sélection de tous les lecteurs PDF mobiles (notamment les espaces inter-widgets sur des lignes mixtes `pw.Wrap`).
  2. Les marques combinantes empilées (> 1 marque sur une même lettre de base, `cl.length > 2`) ne sont pas dessinées au-delà de `cl[1]` dans `LogicalRtlArabicBlock` (non bloquant pour les 16 formes qui n'ont qu'une marque combinante, mais à noter pour l'évolution future).

---

## 5. Qualification Android (Samsung SM-A336E)

- **Commande exécutée :** `adb.exe devices -l` -> `List of devices attached` (aucun appareil détecté).
- **Statut :** **NON TESTÉ**.
- L'application de production n'a pas été modifiée ni touchée.

---

## 6. Licence et reproductibilité de la police

- **Police embarquée :** `mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf` (`239 864` octets).
- **Empreinte SHA-256 :** `ff976ce200192dcafae66271d6db28d8980cc1f190ee3361b3cbfa8f7361baa8` — **100 % identique** à la copie QA `docs/qa_arabic_diacritics/BeriyaArabicProto-Regular.ttf`.
- **Métadonnées `name` (plateforme Windows `3`) :**
  - `nameID=0` (Copyright) : `Copyright 2015-2021 Google LLC. All Rights Reserved.`
  - `nameID=1` (Family) : `Beriya Arabic Proto` (aucun nom réservé `Noto` dans les noms de famille)
  - `nameID=2` (Subfamily) : `Regular`
  - `nameID=3` (Unique ID) : `2.009;BERIYA;BeriyaArabicProto-Regular`
  - `nameID=13` / `14` : `SIL Open Font License, Version 1.1` (`http://scripts.sil.org/OFL`), accompagnée de `mobile/assets/fonts/experimental/OFL.txt`.
- **Impact taille :** `+239 864` octets (~`234` Ko) tant que `NotoSansArabic-Regular.ttf` (`240 456` octets) est conservée en parallèle.
- **Reproductibilité :** `docs/qa_arabic_diacritics/generate_arabic_pdf_layout_dart.py` régénère exactement `39` lettres et `500` entrées `GPOS` ; anomalie mineure constatée et corrigée manuellement sur `arabic_pdf_layout_data.dart` ligne 182 (les chevrons `<nominalHex>:<formIdx>:<markHex>` sans backticks déclenchaient `unintended_html_in_doc_comment` dans `flutter analyze`).

---

## 7. Anomalies résiduelles et risques de sécurité / maintenance

1. **Absence de qualification physique Android (Samsung SM-A336E) :** rendu réel, saisie RTL, zoom et copier-coller depuis un lecteur PDF Android non vérifiés.
2. **Paragraphe unique > 1 page :** `LogicalRtlArabicBlock` hérite de `pw.Widget` (non `SpanningWidget`) ; `MultiPage` découpe entre paragraphes (`\n`), mais un paragraphe arabe unique sans retour à la ligne dépassant la hauteur d'une page ne se scinderait pas automatiquement.
3. **Empilement de diacritiques (`cl.length > 2`) :** seule la première marque combinante (`cl[1]`) est rendue/ancrée.
4. **Générateur Python :** `generate_arabic_pdf_layout_dart.py` produit un commentaire doc sans backticks à la ligne 182 (à corriger si le générateur est réutilisé ultérieurement).
5. **Sécurité :** aucun risque d'exposition involontaire identifié tant que `experimentalArabicPdfEnabled` reste `false` et non exposé dans l'UI.

---

## 8. Conditions de validation linguistique et décision finale

### Conditions préalables à toute fusion dans `dev` ou activation
1. **Qualification physique sur Samsung SM-A336E** (build QA avec `applicationId` distinct, rendu des 16 formes, saisie RTL, copier-coller et lecteur PDF Android hors ligne).
2. **Homologation linguistique formelle** de la convention candidate A (`BK-LING-AR-DIAC-001`) sur les 16 formes arabes.
3. **Approbation explicite** pour la fusion dans `dev`.

### Décision : **NO-GO pour fusion immédiate dans `dev`**

- **Sur le plan logiciel / non-régression :** l'intégration expérimentale est propre, isolée, 100 % hors ligne, désactivée par défaut (`176/176` Flutter, `0` erreur `flutter analyze`, `173` Django OK, `16/16` + `25/25` extraction PDF logique vérifiée).
- **Blocage formel maintenu :** **Android physique (`Samsung SM-A336E`) NON TESTÉ** et homologation linguistique en attente -> **NO-GO pour la fusion dans `dev`**.
