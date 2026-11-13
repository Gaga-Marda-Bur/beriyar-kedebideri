# BERIYAR KEDEBIDERI — RAPPORT FINAL DE PRÉPARATION À LA FUSION (AR-MERGE-READY-11)

**Référence :** `AR-MERGE-READY-11`  
**Date :** 13 novembre 2026  
**Branche auditée :** `feature/arabic-pdf-experimental`  
**Branche cible (non fusionnée) :** `dev` (`5836c63fbb475b03e42e829a07fd4c0e20642dd3`)

---

## 1. État Git final et distinction applicatif / QA

- **Branche active :** `feature/arabic-pdf-experimental`
- **`HEAD` :** `5836c63fbb475b03e42e829a07fd4c0e20642dd3`
- **`git merge-base dev HEAD` :** `5836c63fbb475b03e42e829a07fd4c0e20642dd3` (aucun commit sur `dev`, aucun push distant)

### A. Fichiers nécessaires à l'application (à fusionner dans `dev`)
- **Moteur PDF (modifiés / ajoutés) :**
  - `mobile/lib/features/editor/services/beriya_pdf_service.dart` (drapeau `experimentalArabicPdfEnabled = false` + routage conditionnel)
  - `mobile/lib/features/editor/services/pdf_unicode_cmap.dart` (`ensureNominalArabicPdfUnicode` + `_NominalArabicAndUtf16Cmap`)
  - `mobile/lib/features/editor/services/arabic_pdf_text.dart` (`LogicalRtlArabicBlock`, `arabicPdfText`, `ArabicPdfDiagnostics`)
  - `mobile/lib/features/editor/services/arabic_pdf_layout_data.dart` (`39` lettres, `500` entrées `GPOS`)
- **Police et ressources :**
  - `mobile/pubspec.yaml` (ajout de `- assets/fonts/experimental/`)
  - `mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf` (`239 864` octets)
  - `mobile/assets/fonts/experimental/OFL.txt` (`SIL OFL 1.1`)
- **Tests :**
  - `mobile/test/arabic_pdf_experimental_test.dart` (`4` tests unitaires/intégration PDF)
  - `mobile/integration_test/arabic_pdf_physical_test.dart` (`1` test physique Samsung SM-A336E, gardé par `BK_TOOLS_QA=true`)

### B. Documentation et preuves QA (hors binaire applicatif, conservées intactes)
- Rapports de synthèse : `docs/BK-LING-AR-DIAC-001_VALIDATION_TYPOGRAPHIQUE.md`, `docs/AR_TYPO_02_RAPPORT_DECISION.md`, `docs/AR_TYPO_03_RAPPORT_QUALIFICATION.md`, `docs/AR_PDF_04_RAPPORT_ARCHITECTURES.md`, `docs/AR_PDF_05_RAPPORT_FINAL.md`, `docs/AR_PDF_06_RAPPORT_FINAL.md`, `docs/AR_INT_07_RAPPORT_INTEGRATION.md`, `docs/AR_QA_08_RAPPORT_FINAL.md`, `docs/AR_DEVICE_09_RAPPORT_FINAL.md`, `docs/AR_CLOSE_10_RAPPORT_CLOTURE.md`, `docs/AR_MERGE_READY_11_RAPPORT.md`.
- Preuves & scripts QA : `docs/qa_arabic_diacritics/` (incluant `build_proto_font.py`, `generate_arabic_pdf_layout_dart.py`, captures PNG, PDFs générés et JSON de contrôle).

---

## 2. Vérification de sécurité et gestion des replis

- **Désactivation par défaut :** `BeriyaPdfService.experimentalArabicPdfEnabled == false`. Aucun écran, réglage ou parcours public n'expose ni n'active `useExperimentalArabicPdf` (`erfePdfText` reste l'unique chemin utilisé par défaut).
- **Comportement de repli (`LogicalRtlArabicBlock`) :**
  - Tout caractère arabe absent de `arabicContextualForms` est enregistré dans `ArabicPdfDiagnostics.unsupportedCharacters` et bascule vers `fallbackFont` si `advanceWidth <= 0`.
  - Toute marque combinante absente de `{U+0300, U+0301, U+0304, U+0307}` est enregistrée dans `ArabicPdfDiagnostics.unsupportedCombiningMarks`.
  - **Exigence pédagogique :** pour un futur export pédagogique officiel, aucune perte ou substitution silencieuse n'est acceptable ; il faudra donc exiger `diag.hasWarnings == false` avant de valider l'activation publique sur tout contenu Beřiya complet.

---

## 3. Qualification des quatre lettres étendues (`U+067E`, `U+0695`, `U+06A0`, `U+06BD`)

Audit direct des tables `cmap` et `GSUB` de `BeriyaArabicProto-Regular.ttf` via `fontTools` (sans modification du moteur) :

| Caractère | Unicode | Lettre Beřiya | `cmap` base | Formes contextuelles Unicode (PF-A/B) | `GSUB` dans la police | Comportement actuel du moteur PDF |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **پ** | `U+067E` | `p` (`𖺰`) | Oui (`uni067E`) | **Oui** : `U+FB56` (isol), `U+FB57` (fina), `U+FB58` (init), `U+FB59` (medi) — toutes dans `cmap` | `fina: uniFB57`, `init: uniFB58`, `medi: uniFB59` | Rendue en isolée (`U+067E`) + consignée dans `unsupportedCharacters` |
| **ڕ** | `U+0695` | `ř` (`𖺲`) | Oui (`uni0695`) | **Aucune** en PF-A/B (liaison droite uniquement : isol/fina) | `fina: uni0695.fina` (glyphe non encodé dans `cmap`) | Rendue en isolée (`U+0695`) + consignée dans `unsupportedCharacters` |
| **ڠ** | `U+06A0` | `ŋ` (`𖺮`) | Oui (`uni06A0`) | **Aucune** en PF-A/B (double liaison : isol/fina/init/medi) | `fina: uni06A0.fina`, `init: uni06A0.init`, `medi: uni06A0.medi` (non encodés dans `cmap`) | Rendue en isolée (`U+06A0`) + consignée dans `unsupportedCharacters` |
| **ڽ** | `U+06BD` | `ɲ` (`𖺭`) | Oui (`uni06BD`) | **Aucune** en PF-A/B (double liaison : isol/fina/init/medi) | `fina: uni06BD.fina`, `init: uni06BD.init`, `medi: uni06BD.medi` (non encodés dans `cmap`) | Rendue en isolée (`U+06BD`) + consignée dans `unsupportedCharacters` |

*Constat technique :* `U+067E` est directement supportable via `U+FB56..FB59`. Pour `U+0695`, `U+06A0` et `U+06BD`, `package:pdf 3.12.0` n'adresse les glyphes que par codepoint `cmap` (pas par `GlyphID` GSUB) ; leur liaison contextuelle nécessitera ultérieurement soit un encodage PUA dédié dans la police dérivée + entrée inverse dans `arabicPresentationToNominal` (pour conserver `U+0695`/`U+06A0`/`U+06BD` dans `/ToUnicode`), soit une prise en charge GSUB native.

---

## 4. Reproductibilité et licence SIL OFL 1.1

- **Génération de la police :** `docs/qa_arabic_diacritics/build_proto_font.py` construit `BeriyaArabicProto-Regular.ttf` à partir de `NotoSansArabic-Regular.ttf` + les 4 marques de `NotoSans-Regular.ttf`, en renommant `nameID` `1`, `3`, `4`, `6` vers `Beriya Arabic Proto` / `BeriyaArabicProto` (`;BERIYA;`).
- **Génération des tables Dart :** `docs/qa_arabic_diacritics/generate_arabic_pdf_layout_dart.py` génère `arabic_pdf_layout_data.dart` (`39` lettres, `500` ancres `GPOS`). Note : corriger les backticks autour de `"<nominalHex>:<formIdx>:<markHex>"` ligne 182 si régénéré pour `flutter analyze`.
- **Conformité SIL OFL 1.1 :** `mobile/assets/fonts/experimental/OFL.txt` présent, notice copyright `Google LLC` conservée (`nameID=0`), aucun nom réservé `Noto` dans les noms de famille (`nameID=1`: `Beriya Arabic Proto`).

---

## 5. Découpage Git proposé (commandes non exécutées)

Pour éviter d'inclure par erreur les `75+` fichiers binaires QA de `docs/qa_arabic_diacritics/` si vous ne souhaitez pas les versionner dans `dev`, voici le découpage propre en 4 commits à exécuter après votre validation :

```powershell
# 1. Moteur PDF
git add mobile/lib/features/editor/services/beriya_pdf_service.dart `
        mobile/lib/features/editor/services/pdf_unicode_cmap.dart `
        mobile/lib/features/editor/services/arabic_pdf_text.dart `
        mobile/lib/features/editor/services/arabic_pdf_layout_data.dart
git commit -m "feat(pdf): add experimental reversible Arabic PDF engine behind QA flag"

# 2. Police et ressources
git add mobile/pubspec.yaml `
        mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf `
        mobile/assets/fonts/experimental/OFL.txt
git commit -m "assets(fonts): bundle experimental BeriyaArabicProto-Regular (SIL OFL 1.1)"

# 3. Tests
git add mobile/test/arabic_pdf_experimental_test.dart `
        mobile/integration_test/arabic_pdf_physical_test.dart
git commit -m "test(pdf): add experimental Arabic PDF unit and Samsung QA integration tests"

# 4. Documentation (et optionnellement docs/qa_arabic_diacritics/ selon votre choix)
git add docs/BK-LING-AR-DIAC-001_VALIDATION_TYPOGRAPHIQUE.md `
        docs/AR_TYPO_02_RAPPORT_DECISION.md `
        docs/AR_TYPO_03_RAPPORT_QUALIFICATION.md `
        docs/AR_PDF_04_RAPPORT_ARCHITECTURES.md `
        docs/AR_PDF_05_RAPPORT_FINAL.md `
        docs/AR_PDF_06_RAPPORT_FINAL.md `
        docs/AR_INT_07_RAPPORT_INTEGRATION.md `
        docs/AR_QA_08_RAPPORT_FINAL.md `
        docs/AR_DEVICE_09_RAPPORT_FINAL.md `
        docs/AR_CLOSE_10_RAPPORT_CLOTURE.md `
        docs/AR_MERGE_READY_11_RAPPORT.md
git commit -m "docs(qa): archive Arabic diacritics PDF qualification reports (01-11)"
```

---

## 6. Vérifications finales (comparaison avec AR-QA-08)

| Vérification | AR-QA-08 | AR-MERGE-READY-11 | Écart |
| :--- | :--- | :--- | :--- |
| **`flutter analyze` (`mobile/`)** | `No issues found!` | **`No issues found! (7.8s)`** | Aucun |
| **Suite Flutter complète (`flutter test`)** | `176/176 PASS` | **`176/176 PASS (00:15)`** | Aucun (`0` échec, `0` ignoré) |
| **Tests physiques Samsung SM-A336E** | `NON TESTÉ` | **`1/1 PASS` hors ligne (`25/25` Arabe, `25/25` Erfe, `16/16` formes)** | Comblé en `AR-DEVICE-09` / `AR-CLOSE-10` |
| **Suite Django (`manage.py test`)** | `173` exécutés, `OK (skipped=2)` | Non ré-exécutée (`backend/` inchangé depuis `AR-QA-08`) | Aucun changement `backend/` |

---

## 7. Plan de fusion, retour arrière et conditions d'activation publique

### Plan de fusion dans `dev` (sur autorisation explicite uniquement)
1. Créer une sauvegarde sur `dev` : `git branch backup/dev-pre-arabic-pdf dev` (depuis `5836c63`).
2. Exécuter les 4 commits ci-dessus sur `feature/arabic-pdf-experimental`.
3. Fusionner sans fast-forward : `git checkout dev && git merge --no-ff feature/arabic-pdf-experimental`.
4. Ré-exécuter `flutter analyze`, `flutter test` et `manage.py test` sur `dev`.

### Plan de retour arrière (rollback)
- **Niveau 1 (runtime) :** `BeriyaPdfService.experimentalArabicPdfEnabled` est déjà `false` ; aucune fonctionnalité utilisateur n'est exposée.
- **Niveau 2 (Git) :** `git revert -m 1 <sha_merge_dev>` ou `git reset --hard backup/dev-pre-arabic-pdf` (avant tout push).

### Conditions d'activation publique
1. **Homologation linguistique formelle** de la convention candidate A (`BK-LING-AR-DIAC-001`, 16 formes).
2. **Support contextuel des 4 lettres étendues** (`U+067E`, `U+0695`, `U+06A0`, `U+06BD`) afin qu'aucune lettre Beřiya ne déclenche `unsupportedCharacters` ni ne reste bloquée en forme isolée dans un texte suivi.
3. **Validation `diag.hasWarnings == false`** sur un corpus pédagogique réel avant d'activer `experimentalArabicPdfEnabled = true`.

---

**Conclusion :** La branche `feature/arabic-pdf-experimental` est propre, vérifiée (`176/176` Flutter, `0` anomalie `flutter analyze`), sans régression et **prête pour une fusion contrôlée dans `dev` avec le drapeau désactivé par défaut**, en attente de votre autorisation explicite.
