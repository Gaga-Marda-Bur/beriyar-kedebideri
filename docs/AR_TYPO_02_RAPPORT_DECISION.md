# BERIYAR KEDEBIDERI — RAPPORT DE DÉCISION LOT AR-TYPO-02
**Référence :** `AR-TYPO-02`  
**Date :** 13 novembre 2026  
**Base technique :** branche `dev`, commit `5836c63` (aucune modification du code de production)  
**Spécification amont :** `docs/BK-LING-AR-DIAC-001_VALIDATION_TYPOGRAPHIQUE.md` (Convention candidate A)  

---

## 1. Décision recommandée : **B — GO conditionnel**

Une solution typographique fiable **sans modifier la représentation Unicode** des 16 formes candidates existe sous la forme d'une police dérivée **SIL OFL 1.1** (`BeriyaArabicProto-Regular.ttf`) ajoutant les 4 marques combinantes latines (`U+0300`, `U+0301`, `U+0304`, `U+0307`) dans `cmap`, `GDEF` et `GPOS` (`MarkBasePos` Lookup 3, Classe 0) avec ajustement des ancres de `ی` (`uni06CC`, `uniFBFD`).

Le passage en **GO complet (A)** est conditionné à deux vérifications non réalisables dans ce lot :
1. **Validation physique Android (Samsung SM-A336E)** — appareil non connecté via `adb` lors de l'exécution.
2. **Vérification du moteur PDF Dart (`package:pdf` / `pw.Font.ttf`)** — le rendu PDF validé ici repose sur Chrome/Skia/PDFium (`HarfBuzz`), qui applique `GPOS` ; la gestion `GPOS` de `package:pdf` dans Flutter devra être testée sur cible.

---

## 2. Tableau comparatif des polices évaluées

| Police | Version | Licence | Bases arabes (`cmap`) | Marques `U+0300/0301/0304/0307` (`cmap`) | `GPOS` `MarkBasePos` | Verdict visuel (16 formes, Chrome) |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| `NotoSansArabic-Regular.ttf` (actuelle) | `2.009` | SIL OFL 1.1 | 5 / 5 | 0 / 4 (`null`) | Absent pour ces 4 marques (fallback latin) | **KO** (`ا̄` ressemble à `7`, marques décalées à gauche) |
| `NotoNaskhArabic-Regular.ttf` (variable `[wght]`) | `2.021` | SIL OFL 1.1 | 5 / 5 | 4 / 4 | Présent (`acutecomb`, `gravecomb`, `uni0304`, `uni0307`) | **KO** (marques non centrées / flottantes sur `ا̄`, `آ̄`, `ی̄`) |
| `Amiri-Regular.ttf` | `1.002` | SIL OFL 1.1 | 5 / 5 | 4 / 4 | Absent (`[]`) | **KO** (fallback/non-ancrage des marques) |
| `ScheherazadeNew-Regular.ttf` | `4.500` | SIL OFL 1.1 | 5 / 5 | 0 / 4 | Absent | **KO** (fallback latin) |
| **`BeriyaArabicProto-Regular.ttf`** (prototype dérivé) | Dérivée de `2.009` | SIL OFL 1.1 (renommée `Beriya Arabic Proto`) | 5 / 5 | **4 / 4** (`bk_gravecomb`, `bk_acutecomb`, `bk_macroncomb`, `bk_dotabovecomb`) | **Actif** (Lookup 3 `MarkBasePos`, Classe 0 + ancres `uni06CC`/`uniFBFD` relevées) | **OK (16 / 16)** sur HTML, Sticker PNG et PDFium |

---

## 3. Analyse GPOS / GSUB & collisions (`آ`, `ی`)

1. **Cause racine sur `NotoSansArabic-Regular.ttf` (`2.009`) :**
   - Les 5 bases (`ا` `U+0627`, `آ` `U+0622`, `ی` `U+06CC`, `ۆ` `U+06C6`, `ۇ` `U+06C7`) et leurs formes contextuelles `GSUB` (`uniFE8E`, `uniFE82`, `uniFBDA`, `uniFBD8`, `uniFBFD`, `uniFBFE`, `uniFBFF`) possèdent déjà des ancres supérieures **Classe 0** dans `GPOS` Lookup 3 (`MarkBasePos`).
   - En revanche, `U+0300`, `U+0301`, `U+0304` et `U+0307` sont **absents de `cmap`** : le moteur retombe sur une police latine de secours (`Noto Sans` / `Arial`), perdant l'ancrage `GPOS` arabe (`ا̄` forme un `7`, les accents flottent à gauche).
2. **Problème spécifique observé sur `ی` (`uni06CC` / `uniFBFD`) :**
   - Dans `NotoSansArabic-Regular.ttf`, l'ancre Classe 0 de `uni06CC` est à `y = 150` alors que `yMax = 419` (crochet droit) et `uniFBFD` est à `y = 150` (`yMax = 176`).
   - Lors du premier essai du prototype, les marques sur `ی` se positionnaient dans le creux du glyphe. Le relèvement à `Y = 435` (`uni06CC`) et `Y = 235` (`uniFBFD`) a supprimé toute collision.
3. **Cas de `آ` (`U+0622`, alif madda) :**
   - `uni0622` (`yMax = 842`, ancre Classe 0 à `(115, 845)`) et `uniFE82` placent la marque au-dessus du madda (`~`), sans collision observée sur `آ̄`, `آ̀`, `آ́` (isolé ou contextuel `بآ̀ب`).

---

## 4. Résultats visuels (banc isolé `docs/qa_arabic_diacritics/`)

- **16 formes isolées (table comparative) :** `docs/qa_arabic_diacritics/ar_typo_02_proto_comparison.png` — les 16 formes sont distinctes, centrées et lisibles.
- **Tailles `12`, `16`, `24`, `36 px` + Zoom `200 %` :** lisibilité maintenue sur toutes les tailles ; aucune troncature verticale ni fusion entre la madda de `آ` et les diacritiques.
- **Contextes RTL et mixtes :**
  - Voyelles consécutives (`ا́آ̀ی̄ۆ́ۇ̀`) : ancres conservées sur chaque base.
  - Consonne avant/après (`با́ب بآ̀ب بی̄ب بۆ́ب بۇ̀ب بی̇ب`) : formes contextuelles `GSUB` et positionnement `GPOS` préservés.
  - Mixte LTR/RTL/chiffres (`Beřiya 2026 : ا́آ̀ی̄ — 16 formes (ۆ́, ۇ̀, ی̇)!`) : ordre logique et affichage corrects.
- **Studio Sticker PNG :** `docs/qa_arabic_diacritics/ar_typo_02_sticker_proto.png` — 16/16 glyphes nets, centrés, sans repli de police.

---

## 5. Diagnostic PDF approfondi (`ar_typo_02_proto_pdf.pdf`)

1. **Rendu visuel PDF (Chrome / PDFium) :** `docs/qa_arabic_diacritics/ar_typo_02_pdf_render_p1.png` — rendu fidèle à l'aperçu HTML, sous-ensemble de police `BeriyaArabicProto-Regular` embarqué.
2. **Table `/ToUnicode` :**
   - Police embarquée `/F10 /FAAAAA+BeriyaArabicProto-Regular` : `beginbfchar` mappe `U+0627`, `U+0622`, `U+06C6`, `U+06C7`, `U+06CC` (ainsi que `FE8E`, `FE82`, `FBDA`, `FBD8`, `FBFE`, `FBFF`), `U+0304`, `U+0307`, et `beginbfrange <067D> <067E> <0300>` mappe `U+0300` et `U+0301`.
3. **Extraction indépendante par deux moteurs + sélection DOM :**
   - `pypdf` : `7/16` en ordre logique direct, `9/16` en ordre visuel BiDi inversé (`ar[::-1]`), **`0` perte de caractère** (`lost: []`).
   - `pdfminer.six` : `5/16` en ordre logique direct, `11/16` en ordre visuel BiDi inversé, **`0` perte de caractère** (`lost: []`).
   - Sélection DOM Chrome (`window.getSelection().toString()`) : **`16/16`** en ordre logique exact.
   - **Conclusion PDF :** aucun caractère n'est perdu ; les écarts d'ordre entre extracteurs proviennent uniquement de l'ordre visuel BiDi du flux PDF et non d'une altération Unicode.

---

## 6. Statut Android physique (Samsung SM-A336E)

- **Non testé (appareil non connecté)** : `adb devices` a retourné une liste vide au début et à la fin du lot.

---

## 7. Limites connues, licence et complexité de maintenance

1. **Licence SIL OFL 1.1 :** la modification et la redistribution sont autorisées sous réserve de **ne pas utiliser le Reserved Font Name** (`Noto`), condition respectée par le renommage en `Beriya Arabic Proto` (`BeriyaArabicProto-Regular.ttf`) et la conservation de `Noto-OFL.txt`.
2. **Complexité de maintenance :** **faible et reproductible** — le script `docs/qa_arabic_diacritics/build_proto_font.py` (environ 105 lignes `fontTools`) reconstruit la police de façon déterministe à partir de `NotoSansArabic-Regular.ttf` et `NotoSans-Regular.ttf` sans modifier le moteur de translittération.
3. **Risques restants avant intégration future :**
   - Comportement du shaper Dart `package:pdf` (`pw.Font.ttf`) avec `GPOS` Lookup 3 (non testé dans ce lot).
   - Rendu réel sur Android (Skia/HarfBuzz sur Samsung SM-A336E).
   - Empilement éventuel de plusieurs marques sur une même lettre (non requis par les 16 formes simples actuelles, mais à noter).

---

## 8. Artefacts produits (hors code de production)

- `docs/qa_arabic_diacritics/audit_noto_sans_arabic.py` & `noto_sans_arabic_deep_audit.json`
- `docs/qa_arabic_diacritics/audit_candidate_fonts.py` & `candidate_fonts_audit.json`
- `docs/qa_arabic_diacritics/build_proto_font.py` & `fonts/BeriyaArabicProto-Regular.ttf`
- `docs/qa_arabic_diacritics/run_proto_bench.py`, `ar_typo_02_proto_comparison.png`, `ar_typo_02_sticker_proto.png`, `ar_typo_02_proto_pdf.pdf`
- `docs/qa_arabic_diacritics/verify_proto_pdf.py`, `ar_typo_02_dual_pdf_verify.json`, `ar_typo_02_pdf_render_p1.png`
