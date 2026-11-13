# BERIYAR KEDEBIDERI — RAPPORT FINAL LOT AR-PDF-05
## Finalisation de la preuve de faisabilité PDF arabe réversible

**Référence :** `AR-PDF-05`  
**Date :** 13 novembre 2026  
**Base technique :** branche `dev`, commit `5836c63` (aucune modification du code de production)  
**Architecture évaluée :** Option A — Extension ciblée de `package:pdf 3.12.0` sans fork  

---

## 1. Décision : **GO technique pour préparer une intégration (avec réserve documentée sur les mots arabes multi-clusters)**

- **Critères satisfaits à 100 % :**
  1. **16/16 formes** rendues correctement (`GPOS` Lookup 3 + `GSUB` + `12/16/24/36 pt`).
  2. **16/16 formes** extraites dans l'ordre logique Unicode exact (`U+06xx + U+030x`) par `pypdf` **et** `pdfminer.six` (`0` inversé, `0` perdu, sans post-traitement).
  3. **Chaînes synthétiques** (voyelles consécutives, contextes `ب...ب`, retour à la ligne `pw.Wrap`, mixte Latin/Arabe/Erfe/chiffres/ponctuation) fonctionnelles.
  4. **Police `BeriyaArabicProto-Regular.ttf`** conforme **SIL OFL 1.1** (`nameID=3` corrigé en `2.009;BERIYA;BeriyaArabicProto-Regular`) et reproductible via `build_proto_font.py`.
  5. **Non-régression Flutter :** `31/31` tests passés.
- **Limitation documentée (transparente) :** dans un mot arabe multi-clusters (ex. `ا́آ̀ی̄ۆ́ۇ̀`), chaque paire `base + marque` est bien en ordre logique (`U+06xx U+030x`), mais `pw.Row` dessine les clusters de gauche à droite (`ۇ̀ ۆ́ ی̄ آ̀ ا́`), ce qui inverse l'ordre des lettres d'un mot multi-syllabique lors d'une extraction brute par `pypdf`/`pdfminer.six`. Une passe ultérieure d'intégration devra soit utiliser `/ActualText`, soit rester sur des glyphes/mots courts si l'extraction multi-syllabique stricte est exigée, et valider le rendu physique sur Samsung SM-A336E.

---

## 2. Phase 1 — Diagnostic des 5 échecs d'AR-PDF-04 et comparaison avant / après

Dans `ar_pdf_04_option_a.pdf`, 5 formes échouaient (`À/à`, `È/è`, `É/é`, `Ù/ù`, `Ò/ò`) :
- **Contenu du flux PDF avant correction :**
  `BT /F19 20 Tf 0 14.76 Td [<0004>]TJ ET BT /F19 20 Tf 12.6 17.72 Td [<0008>]TJ ET`
- **Cause technique démontrée :**
  Dans `NotoSans-Regular.ttf`, les marques `U+0300` (`bk_gravecomb`) et `U+0301` (`bk_acutecomb`) avaient des coordonnées négatives (`xMin = -393`, `cx = -279`). Pour centrer la marque sur la base (`BaseAnchor.X ≈ 115..237`), `dx = BaseAnchor.X - cx` devenait **supérieur à `xAdvance` de la base** (`dx = 508..514` vs `xAdvance = 235..238` sur `ا`/`آ`, ou `dx > xAdvance` sur `ۆ`/`ۇ`). Les extracteurs `pypdf` et `pdfminer.six` interprétaient `x_mark > x_end` comme un **espace** (`ا ̀`, `آ ̀`, `آ ́`, `ۇ ̀`, `ۆ ̀`).
- **Correction appliquée (sans toucher `package:pdf`) :**
  Centrage horizontal des 4 glyphes de marques autour de `x = 0` (`cx = 0`) dans `build_proto_font.py` via `TransformPen` (`(-cx_orig, 0)`). Désormais, `0 < dx < xAdvance` pour toutes les bases (`115..237 < 235..760`), donc aucun espace parasite n'est inféré entre `base` et `mark` (même avec deux `drawString` nécessaires au décalage vertical `dy`).

| Forme | Source | Avant (`ar_pdf_04_option_a.pdf`) | Après (`ar_pdf_05_reference.pdf`) |
| :--- | :--- | :--- | :--- |
| `À / à` | `U+0627 U+0300` | `ا ̀` (espace parasite, match inversé) | **`ا̀` (exact, ordre logique)** |
| `È / è` | `U+0622 U+0300` | `آ ̀` (espace parasite, match inversé) | **`آ̀` (exact, ordre logique)** |
| `É / é` | `U+0622 U+0301` | `آ ́` (espace parasite, match inversé) | **`آ́` (exact, ordre logique)** |
| `Ù / ù` | `U+06C7 U+0300` | `ۇ ̀` (espace parasite, match inversé) | **`ۇ̀` (exact, ordre logique)** |
| `Ò / ò` | `U+06C6 U+0300` | `ۆ ̀` (perdu dans `pypdf` & `pdfminer`) | **`ۆ̀` (exact, ordre logique)** |

---

## 3. Phases 2 & 3 — Extraction 16/16 et chaînes synthétiques

- **PDF de référence :** `docs/qa_arabic_diacritics/ar_pdf_05_reference.pdf` (`2` pages, `16 836` octets) ; captures : `ar_pdf_05_ref_p1.png`, `ar_pdf_05_ref_p2.png`.
- **Résultats d'extraction (`ar_pdf_05_validation.json`) :**
  - `pypdf` : **`16/16` exactes en ordre logique**, `0` inversée, `0` perdue.
  - `pdfminer.six` : **`16/16` exactes en ordre logique**, `0` inversée, `0` perdue.
  - Erfe dans le même PDF (`𖺠𖺣𖺧`) : **`true`** dans les deux extracteurs (`U+16EA0`, `U+16EA3`, `U+16EA7` préservés).
- **Chaînes synthétiques vérifiées :**
  - Voyelles consécutives (`ا́آ̀ی̄ۆ́ۇ̀`) : rendu net, chaque paire `base + marque` conservée.
  - Contextes & retour à la ligne RTL (`با́ب بآ̀ب بی̄ب بۆ́ب بۇ̀ب بی̇ب` en `pw.Wrap`) : liaisons `GSUB` et ancres `GPOS` correctes sur deux lignes.
  - Mixte Latin / Arabe / Erfe / chiffres / ponctuation (`Beřiya 2026 : ا́ , آ̀ , ی̄ — Erfe: 𖺠𖺣𖺧 (16)!`) : extrait tel quel par `pypdf` (`Beřiya2026: ا́ , آ̀ , ی̄ —Erfe: 𖺠𖺣𖺧(16)!`).

---

## 4. Phase 4 — Contrôle de la police (`BeriyaArabicProto-Regular.ttf`)

| Champ / Table | Valeur vérifiée | Statut |
| :--- | :--- | :---: |
| `nameID=0` | `Copyright 2015-2021 Google LLC. All Rights Reserved.` | Conforme |
| `nameID=1` / `4` / `6` | `Beriya Arabic Proto` / `Beriya Arabic Proto Regular` / `BeriyaArabicProto-Regular` | Conforme |
| `nameID=3` | `2.009;BERIYA;BeriyaArabicProto-Regular` | **Corrigé** |
| `nameID=13` / `14` | SIL Open Font License, Version 1.1 / `http://scripts.sil.org/OFL` | Conforme |
| `GPOS` / `GSUB` / `GDEF` | 4 marques `U+0300/0301/0304/0307` centrées (`cx=0`), `GDEF` Classe 3, `GPOS` Lookup 3 Classe 0, ancres `uni06CC`/`uniFBFD` relevées (`435`/`235`). | Reproductible (`build_proto_font.py`) |

---

## 5. Phase 5 — Mesures de performance et taille

Mesures réelles sur `dart run bin/proto_option_a_full.dart` :
- **PDF de référence (2 pages) :** `16 836` octets, généré en **`160 ms`**.
- **PDF multipage (5 pages, 45 blocs répétés) :** `21 353` octets, généré en **`54 ms`**.
- **Mémoire processus Dart VM (`ProcessInfo.currentRss`) :** `388.64 Mo` avant → `412.35 Mo` après (`+23.71 Mo` incluant les deux générations).
- **Taille réelle de la police :** `BeriyaArabicProto-Regular.ttf` = **`239 864` octets** (vs `NotoSansArabic-Regular.ttf` = `240 456` octets, soit **`-592` octets** en remplacement direct, ou **`+234 Ko`** si conservée en parallèle).

---

## 6. Phase 6 — Non-régression

Exécution de `flutter test` sur les 6 suites ciblées (Erfe, translittération, Sticker, éditeur PDF, navigation historique) :
- **`31/31` tests passés** (`0` échec, `0` ignoré).
- Aucun fichier applicatif modifié (`git status --short` limité à `docs/`).
