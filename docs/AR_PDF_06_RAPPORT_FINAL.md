# BERIYAR KEDEBIDERI — RAPPORT FINAL LOT AR-PDF-06
## Qualification finale des chaînes arabes multi-clusters et préparation de l'intégration

**Référence :** `AR-PDF-06`  
**Date :** 13 novembre 2026  
**Base technique :** branche `dev`, commit `5836c63` (aucune modification du code de production)  
**Prototype évalué :** `docs/qa_arabic_diacritics/dart_pdf_qa/bin/proto_ar_pdf_06.dart`  

---

## 1. Décision : **GO technique pour intégration contrôlée (sous réserves documentées)**

1. **16/16 formes isolées** extraites dans l'ordre logique exact par `pypdf` **et** `pdfminer.six`.
2. **100 % des chaînes arabes multi-clusters (`S01`–`S07`, `S07b`, `S10`)** extraites caractère par caractère dans leur ordre logique Unicode exact par `pypdf` **et** `pdfminer.six`, **sans aucun post-traitement heuristique**, tout en affichant un rendu RTL visuellement exact (formes contextuelles `GSUB` + ancres `GPOS` + retour à la ligne RTL).
3. **Chaînes mixtes (`S08`, `S09`) :** tous les segments arabes, latins, chiffres, ponctuation et Erfe (`𖺠𖺣𖺧`) sont rendus et extraits dans leur ordre logique ; seule la séparation d'espaces/retours à la ligne entre widgets `pw.Text` et `_LogicalRtlArabicBlock` au sein d'un `pw.Row` varie selon les heuristiques de `pypdf`/`pdfminer.six`.
4. **Portée de la décision :** Ce GO est strictement **technique**. Il n'autorise ni l'activation publique de la convention arabe A, ni l'homologation linguistique, et reste subordonné à la passe physique Android (Samsung SM-A336E) et à votre approbation avant intégration.

---

## 2. Diagnostic de l'anomalie et solution démontrée (Phases 1–3)

### Cause de l'anomalie dans AR-PDF-05
Dans AR-PDF-05, `pw.Row` plaçait les clusters visuellement de gauche à droite (`cluster_N ... cluster_0`). Le flux PDF recevait donc `cluster_N` en premier, ce qui inversait les mots arabes multi-clusters lors de l'extraction (`pypdf` et `pdfminer.six`).

### Solution implémentée dans `_LogicalRtlArabicBlock` (`proto_ar_pdf_06.dart`)
- **Émission en ordre logique + curseur décroissant :** pour chaque ligne (du haut vers le bas), `paint()` parcourt les mots et les clusters **dans l'ordre logique `0..N-1`**, en déplaçant `cursorX` de la droite vers la gauche (`cursorX -= cluster.width`, puis `cursorX -= spaceWidth`).
- **Ancrage `GPOS` & formes `GSUB` :** chaque cluster `(base, marque)` utilise les formes contextuelles (`isol`/`init`/`medi`/`fina`) et les décalages `(dx, dy)` de `proto_arabic_layout.json` avec des glyphes de marques centrés autour de `x = 0` (`0 < dx < xAdvance`).
- **`/ToUnicode` nominal :** `_NominalArabicAndUtf16Cmap` (sous-classe de `PdfUnicodeCmap`) mappe les Formes de présentation B vers `U+06xx` et encode les plans supplémentaires Erfe (`U+16Exx`) en UTF-16BE.

---

## 3. Matrice de validation stricte (Phase 4 — sans post-traitement)

PDF de référence : `docs/qa_arabic_diacritics/ar_pdf_06_reference.pdf` (`1` page, `16 074` octets) ; capture PDFium : `ar_pdf_06_ref_p1.png` ; rapport JSON complet : `ar_pdf_06_validation.json`.

| ID | Description | Source attendue | `pypdf` | `pdfminer.six` | Observation exacte |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `S01` | 2 lettres arabes | `با́` (`U+0628 U+0627 U+0301`) | **EXACT** | **EXACT** | `با́` |
| `S02` | 3 lettres contextuelles | `بی̄ب` (`U+0628 U+06CC U+0304 U+0628`) | **EXACT** | **EXACT** | `بی̄ب` |
| `S03` | 3 lettres non-palindromiques | `ی̇ا́ۆ̀` (`U+06CC U+0307 U+0627 U+0301 U+06C6 U+0300`) | **EXACT** | **EXACT** | `ی̇ا́ۆ̀` |
| `S04` | 5 lettres accentuées | `ا́آ̀ی̄ۆ́ۇ̀` | **EXACT** | **EXACT** | `ا́آ̀ی̄ۆ́ۇ̀` |
| `S05` | 5 lettres contextuelles + marques | `بی̇بآ̀ب` | **EXACT** | **EXACT** | `بی̇بآ̀ب` |
| `S06` | 2 mots arabes + espace | `با́ب بۇ̀ب` | **EXACT** | **EXACT** | `با́ب بۇ̀ب` |
| `S07` | Multi-lignes RTL (`\n`) | `با́ب بآ̀ب ی̄ا́` / `بۆ́ب بۇ̀ب بی̇ب` | **EXACT** | **EXACT** | Les 2 lignes exactes |
| `S07b` | Retour à la ligne auto (180 pt) | `با́ب بآ̀ب ی̄ا́ بۆ́ب بۇ̀ب بی̇ب` | **EXACT** | **EXACT** | Retour visuel 2 lignes, flux exact |
| `S08` | Chiffres, ponctuation & arabe | `16 : با́ب (ۆ́, ۇ̀)!` | Partiel* | Partiel* | `pypdf` : `16: با́ب( ۆ́, ۇ̀)!` ; `pdfminer` : `16 :\n\nبا́ب (ۆ́ , ۇ̀ )!` (chaque segment exact, espaces inter-widgets inférés différemment) |
| `S09` | Mixte Latin / Arabe / Erfe | `Beřiya 2026 : ا́آ̀ی̄ — 𖺠𖺣𖺧` | Partiel* | Partiel* | `pypdf` : `Beřiya2026: ا́آ̀ی̄ — 𖺠𖺣𖺧` ; `pdfminer` : `Beřiya 2026 :\n\nا́آ̀ی̄ — 𖺠𖺣𖺧` |
| `S10` | 16 formes isolées | `ی̇ ی̄ ... ۆ̀ ۆ́` | **16/16 EXACT** | **16/16 EXACT** | 100 % exactes en ordre logique |

*\*Écart limité aux espaces/sauts de ligne inférés par les extracteurs entre `pw.Text` et `_LogicalRtlArabicBlock` dans `pw.Row` (la même inférence affecte le texte latin `Beřiya2026:` dans `pypdf`).*

---

## 4. Plan d'intégration technique dans Beriyar Kedebideri (Phase 5 — non exécuté)

### 4.1 Fichiers applicatifs concernés
- **`mobile/assets/fonts/` & `mobile/pubspec.yaml` :** remplacer ou ajouter `BeriyaArabicProto-Regular.ttf` (SIL OFL 1.1, `nameID=3` corrigé) avec sa notice de licence.
- **`mobile/lib/features/editor/services/pdf_unicode_cmap.dart` :** étendre `ensurePdfSupplementaryUnicode` / `_Utf16Cmap` avec la table de correspondance Formes de présentation B → `U+06xx` (`_NominalArabicAndUtf16Cmap`).
- **`mobile/lib/features/editor/services/arabic_pdf_layout_data.dart` (nouveau) :** table `GPOS`/`GSUB` générée par script Python pour l'ensemble de l'alphabet arabe (28+ lettres + `ی`, `ۆ`, `ۇ` + 4 marques).
- **`mobile/lib/features/editor/services/arabic_pdf_text.dart` (nouveau) :** implémentation de `arabicPdfText` / `_LogicalRtlArabicBlock`.
- **`mobile/lib/features/editor/services/beriya_pdf_service.dart` :** router uniquement les paragraphes/segments arabes vers `arabicPdfText` tout en conservant `erfePdfText` pour l'Erfe et le Latin.

### 4.2 Interfaces conservées & risques Erfe
- **Interfaces inchangées :** `BeriyaPdfService.generatePdfBytes(BeriyaDraft)`, `BeriyaPdfService.savePdfToFile(BeriyaDraft)`, `erfePdfText(...)`, `ensurePdfSupplementaryUnicode(...)`.
- **Comportement hors ligne :** 100 % hors ligne, aucune dépendance réseau ni serveur.
- **Risque pour les exports Erfe existants :** **faible**, car `erfePdfText` et `Kedebideri-Regular.ttf` ne sont pas modifiés ; le routage arabe n'est activé que sur les segments contenant des caractères arabes (`U+0600..U+06FF`).
- **Tests de régression requis :** conserver `erfe_typography_test.dart`, `beriya_editor_test.dart`, `transliteration_test.dart`, `transliteration_diacritics_test.dart` et ajouter un test Dart vérifiant la génération PDF multi-clusters arabes et l'extraction `/ToUnicode`.
