# BERIYAR KEDEBIDERI — RAPPORT D'INTÉGRATION EXPÉRIMENTALE LOT AR-INT-07

**Référence :** `AR-INT-07`  
**Date :** 13 novembre 2026  

---

## 1. Branche et commit de départ

- **Branche de départ :** `dev`, commit `5836c63`
- **Branche expérimentale créée :** `feature/arabic-pdf-experimental` (aucune fusion dans `dev`, aucun push distant)

---

## 2. Fichiers modifiés et ajoutés

### Fichiers applicatifs (`mobile/`)
- **Ajoutés :**
  - `mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf` (`239 864` octets, SIL OFL 1.1, `nameID=3` = `2.009;BERIYA;BeriyaArabicProto-Regular`)
  - `mobile/assets/fonts/experimental/OFL.txt`
  - `mobile/lib/features/editor/services/arabic_pdf_layout_data.dart` (39 lettres arabes, 500 entrées d'ancres `GPOS`, table `arabicPresentationToNominal`, généré par `docs/qa_arabic_diacritics/generate_arabic_pdf_layout_dart.py`)
  - `mobile/lib/features/editor/services/arabic_pdf_text.dart` (`LogicalRtlArabicBlock`, `arabicPdfText`, `ArabicPdfDiagnostics`)
  - `mobile/test/arabic_pdf_experimental_test.dart` (3 tests automatisés)
- **Modifiés :**
  - `mobile/pubspec.yaml` (déclaration de l'asset `assets/fonts/experimental/`, sans remplacement global de `NotoSansArabic-Regular.ttf`)
  - `mobile/lib/features/editor/services/pdf_unicode_cmap.dart` (`ensurePdfSupplementaryUnicode` conservé intact + ajout de `ensureNominalArabicPdfUnicode`)
  - `mobile/lib/features/editor/services/beriya_pdf_service.dart` (ajout du drapeau QA `experimentalArabicPdfEnabled = false` par défaut + paramètre optionnel `useExperimentalArabicPdf`)
- **Non modifiés (exigence respectée) :** `erfe_pdf_text.dart`, moteur de translittération officiel, données pédagogiques, No Ena, Studio Sticker, `NotoSansArabic-Regular.ttf`.

### Livrables QA (`docs/`)
- Tous les livrables `AR-PDF-01` à `AR-PDF-06` préservés intacts.
- Nouveaux artefacts : `docs/qa_arabic_diacritics/generate_arabic_pdf_layout_dart.py`, `ar_int_07_flutter_app.pdf`, `ar_int_07_p1.png`, `ar_int_07_validation.json`, `docs/AR_INT_07_RAPPORT_INTEGRATION.md`.

---

## 3. Architecture intégrée et activation contrôlée

- **Activation par défaut :** **DÉSACTIVÉE** (`BeriyaPdfService.experimentalArabicPdfEnabled == false`). Aucun réglage public n'expose cette option.
- **Chemin historique inchangé :** lorsque `useExperimentalArabicPdf` est `false` (défaut), `BeriyaPdfService.generatePdfBytes` suit exactement le chemin historique (`NotoSansArabic-Regular.ttf` + `erfePdfText`).
- **Chemin expérimental (QA uniquement) :** charge à la demande `assets/fonts/experimental/BeriyaArabicProto-Regular.ttf`, route uniquement les paragraphes/titres contenant de l'arabe (`U+0600..U+06FF`) vers `arabicPdfText`, et conserve `erfePdfText` pour l'Erfe et le Latin (y compris les segments mixtes).
- **Gestion des erreurs :** les caractères arabes ou marques combinantes non pris en charge (ex. `U+06FA`, `U+0308`) sont consignés dans `ArabicPdfDiagnostics` et rendus via la police de repli sans jamais lever d'exception.

---

## 4. Comparaison prototype (AR-PDF-06) / application réelle (`BeriyaPdfService`)

| Critère | Prototype AR-PDF-06 (`proto_ar_pdf_06.dart`) | Application réelle (`BeriyaPdfService`) |
| :--- | :--- | :--- |
| **Gabarit complet** | Page nue | En-tête, pied de page, thème, titre + paragraphes `BeriyaDraft` |
| **Couverture arabe** | 5 bases + `ب` | **39 lettres arabes + 500 ancres `GPOS`** |
| **Rendu visuel (`ar_int_07_p1.png`)** | 16/16 + RTL OK | **16/16 + RTL multi-lignes + titre mixte + Erfe OK** |
| **Taille du PDF généré** | `16 074` octets | `15 985` octets (1 page, `ar_int_07_flutter_app.pdf`) |

---

## 5. Résultats Unicode & extraction (`ar_int_07_validation.json`)

Extraction brute sans post-traitement sur `ar_int_07_flutter_app.pdf` :
- **16 formes isolées (`16_all`) :** `pypdf` = **16/16** (`true`), `pdfminer.six` = **16/16** (`true`).
- **Chaînes RTL multi-clusters (`S01`–`S07_l2`) :** `pypdf` = **100 % `true`**, `pdfminer.six` = **100 % `true`**.
- **Erfe (`𖺠𖺣𖺧`) dans le même PDF :** `pypdf` = **`true`**, `pdfminer.six` = **`true`**.
- **Diagnostics erreurs/inconnus (`\u06FA \u0627\u0308`) :** `unsupportedCharacters` contient `0x06FA`, `unsupportedCombiningMarks` contient `0x0308`, sans plantage.

---

## 6. Tests PDF (`mobile/test/arabic_pdf_experimental_test.dart`)

- **`3/3` tests passés** : drapeau désactivé par défaut, non-régression export Erfe historique, export multipage/RTL/mixte/Erfe/diagnostics avec `useExperimentalArabicPdf: true`.

---

## 7. Tests de non-régression

- **Suite Flutter complète (`flutter test`) :** **`175/175` tests passés** (`0` échec, `0` ignoré) — incluant `transliteration_test.dart`, `transliteration_diacritics_test.dart`, `erfe_typography_test.dart`, `beriya_editor_test.dart`, `sticker_studio_test.dart`, `historical_tools_navigation_test.dart`, `arabic_pdf_experimental_test.dart`.
- **Suite Django complète (`manage.py test`) :** **`173` tests exécutés, `OK (skipped=2)`** (les 2 tests de concurrence PostgreSQL ignorés sur SQLite, aucun échec).

---

## 8. Résultats Android (Samsung SM-A336E)

- **NON TESTÉ** (`adb.exe devices -l` : `List of devices attached` vide).

---

## 9. Impact sur les performances et la taille

- Police expérimentale embarquée : **`239 864` octets (~234 Ko)** ajoutés dans `assets/fonts/experimental/` (car `NotoSansArabic-Regular.ttf` est conservée en parallèle tant que la fonctionnalité est expérimentale ; l'impact deviendrait `-592` octets en cas de remplacement ultérieur).
- Génération hors ligne à 100 % (`54–160 ms` mesurés sur `package:pdf 3.12.0`).

---

## 10. Risques résiduels

1. **Qualification physique Android (Samsung SM-A336E) absente :** rendu Flutter à l'écran, clavier RTL et lecture PDF sur lecteur Android réel non encore vérifiés physiquement.
2. **Mots mixtes sur une même ligne (`pw.Wrap`) :** les espaces inter-widgets entre `erfePdfText` et `LogicalRtlArabicBlock` peuvent varier selon l'heuristique de l'extracteur PDF.
3. **Validation linguistique :** la convention candidate A reste en attente d'homologation linguistique avant toute activation utilisateur.

---

## 11. Décision : **GO technique sur la branche expérimentale / NO-GO pour fusion immédiate dans `dev`**

- L'intégration modulaire sur `feature/arabic-pdf-experimental` est **techniquement validée**, **désactivée par défaut**, **100 % hors ligne** et **sans régression (`175/175` Flutter, `173` Django OK)**.
- **Condition préalable avant fusion dans `dev` ou activation :** votre approbation explicite + validation physique sur Samsung SM-A336E + homologation linguistique.
