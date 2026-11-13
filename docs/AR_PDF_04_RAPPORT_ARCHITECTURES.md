# BERIYAR KEDEBIDERI — RAPPORT LOT AR-PDF-04
## Étude comparative des moteurs PDF pour l'arabe accentué

**Référence :** `AR-PDF-04`  
**Date :** 13 novembre 2026  
**Base technique :** branche `dev`, commit `5836c63` (aucune modification du code applicatif)  
**Police évaluée :** `docs/qa_arabic_diacritics/fonts/BeriyaArabicProto-Regular.ttf` (dérivée SIL OFL 1.1)  

---

## 1. Audit de faisabilité de `package:pdf 3.12.0` (Phase 1)

L'inspection directe des sources de `pdf-3.12.0` (`lib/src/pdf/font/` et `lib/src/pdf/obj/ttffont.dart`) confirme :

| Capacité | État dans `package:pdf 3.12.0` | Détail technique observé |
| :--- | :---: | :--- |
| **Façonnage `GSUB` / `GPOS`** | **Absent** | `ttf_parser.dart` ne lit ni `GSUB` ni `GPOS`. Le façonnage arabe passe par une table statique (`arabic.dart`) vers les Formes de présentation B (`U+FE8x` / `U+FBxx`). |
| **Positionnement des glyphes** | **Séquentiel uniquement** | `drawString` avance horizontalement selon `advanceWidth` (`hmtx`), sans décalage `(dx, dy)` d'ancre `MarkBasePos`. |
| **Marques combinantes `U+0300..0307`** | **Non gérées** | Absentes de `_arabicDiacritics` (`arabic.dart:152`) et `bidi_utils.dart:18` ; elles conservent leur chasse ou décalent le curseur à gauche. |
| **Contrôle `/ToUnicode`** | **Limité par défaut, extensible** | `PdfTtfFont.unicodeCMap` écrit par défaut les codepoints dessinés (Formes B si `arabic.dart` est actif), mais `unicodeCMap` est un champ public remplaçable sans forker `package:pdf` (mécanisme déjà utilisé dans `pdf_unicode_cmap.dart`). |
| **Traitement RTL / BiDi** | **Problématique en mixte** | `arabic.dart` + `bidi` inversent l'ordre des caractères (`newWord.insert(0, ...)`), transformant `base + marque` en `marque + base` et inversant les mots latins sous `pw.TextDirection.rtl`. |
| **Extension sans fork lourd** | **Possible (partiellement)** | Via `pw.Widget` personnalisé + `context.canvas` + sous-classe `PdfUnicodeCmap` (analogue à `erfe_pdf_text.dart`), au prix d'un façonnage et d'un retour à la ligne RTL gérés côté application. |

---

## 2. Comparaison des trois architectures (Phases 2 & 5)

### Option A — Extension ciblée de `package:pdf 3.12.0` (sans fork)
- **Principe :** Conserver `BeriyaPdfService` et `erfe_pdf_text.dart`, ajouter une couche Dart dédiée à l'arabe (`_AnchoredArabicUnit` + table `GPOS`/`GSUB` précalculée `proto_arabic_layout.json` + `_NominalArabicAndUtf16Cmap` mappant les Formes B vers `U+06xx` dans `/ToUnicode`).
- **Dépendances & Licence :** Aucune nouvelle dépendance (`pdf 3.12.0`, Apache 2.0).
- **Android & Hors ligne :** **100 % hors ligne**, multiplateforme, **0 Mo** de surcoût APK.
- **Exports Erfe existants :** Préservés à 100 % (`erfe_pdf_text.dart` inchangé).
- **Complexité / Risques :** Moyenne-élevée si l'on veut gérer des paragraphes arabes complets avec retour à la ligne RTL automatique (`pw.RichText` découpe les lignes en LTR) ; faible si l'arabe reste en unités/mots courts. Un seul objet texte PDF (`BT...ET`) est nécessaire pour éviter l'insertion d'espaces entre base et marque par les extracteurs.

### Option B — Moteur de façonnage arabe natif / spécialisé
Deux variantes évaluées :
1. **B1 — Android natif `android.graphics.pdf.PdfDocument` + `StaticLayout` / `Canvas` (via `MethodChannel`) :**
   - Utilise **Skia + HarfBuzz + ICU BiDi** intégrés à Android.
   - **100 % hors ligne**, **0 Mo** de surcoût APK, licence Android SDK (Apache 2.0), `GPOS`/`GSUB` et retour à la ligne RTL natifs.
   - **Limite majeure :** Spécifique à Android (non portable iOS/Desktop/Web sans code natif par plateforme) et impose de dupliquer toute la mise en page de `BeriyaPdfService` (en-têtes, pieds de page, thèmes, `erfePdfText`).
2. **B2 — FFI `libharfbuzz` + `package:pdf` :**
   - Cross-plateforme, `GPOS`/`GSUB` complets.
   - **Limite majeure :** +2 à 4 Mo par ABI (`armeabi-v7a`, `arm64-v8a`), complexité de build C/FFI et nécessité de toujours réimplémenter la segmentation BiDi/retour à la ligne et `/ToUnicode` dans `package:pdf`.

### Option C — Moteur de rendu validé (Chromium / Android System WebView)
Deux contextes bien distincts :
1. **C1 — Android hors ligne via `printing` (`Printing.convertHtml`, déjà présent dans `mobile/pubspec.yaml` v`5.14.3`) :**
   - Délègue à **Android System WebView (Blink + HarfBuzz + Skia PDF)**.
   - **100 % hors ligne sur Android**, **0 Mo** de surcoût APK, licences permissives (`printing` BSD-3 / WebView système).
   - **Limite :** Port HTML/CSS des thèmes de `BeriyaPdfService` et maintien de `Kedebideri-Regular.ttf` en `@font-face` ; comportement d'extraction PDF identique à Skia PDF (voir Phase 4).
2. **C2 — Chromium headless serveur / desktop (Playwright) :**
   - **Non hors ligne sur mobile** (nécessiterait un serveur distant ou ~150+ Mo hors APK). Non équivalent à une solution mobile hors ligne.

---

## 3. Prototypes isolés et validation empirique (Phases 3 & 4)

Deux prototypes isolés ont été générés et vérifiés sur les 16 formes candidates, les contextes RTL, les tailles `12/16/24/36 pt` et le texte mixte Latin/Arabe/Erfe :
- **Prototype Option A :** `docs/qa_arabic_diacritics/dart_pdf_qa/bin/proto_option_a.dart` → `ar_pdf_04_option_a.pdf` (`17 429` octets), captures `ar_pdf_04_option_a_p1.png`, `ar_pdf_04_option_a_p2.png`.
- **Prototype Option C :** `docs/qa_arabic_diacritics/run_option_c_pdf.py` → `ar_pdf_04_option_c.pdf` (`113 998` octets), capture `ar_pdf_04_option_c_p1.png`.
- **Validation automatisée :** `docs/qa_arabic_diacritics/verify_ar_pdf_04.py` → `ar_pdf_04_validation.json`.

| Mesure observée | Prototype Option A (`package:pdf` étendu) | Prototype Option C (Chromium / Skia PDF) |
| :--- | :--- | :--- |
| **Rendu visuel (16 formes + `GPOS` + `GSUB`)** | **OK (16/16)** : accents centrés, aucune collision sur `آ` ni `ی`, `با́ب بآ̀ب بی̄ب بۆ́ب بۇ̀ب بی̇ب` nets de `12` à `36 pt`. | **OK (16/16)** : rendu HarfBuzz complet, retour à la ligne RTL natif. |
| **Erfe dans le même PDF** | **OK** (`U+16EA0/16EA3/16EA7` conservés via `_NominalArabicAndUtf16Cmap`). | **OK** (`U+16EA0/16EA3/16EA7` conservés). |
| **Extraction `pypdf` (16 formes)** | `11` ordre logique, `4` ordre inversé, `1` séparée par espace (`ۆ ̀`). *Cause identifiée :* 2 appels `drawString` séparés ; corrigeable en 1 opération texte PDF. | `2` ordre logique, `14` ordre BiDi inversé, `0` perte. **Mais** mots contextuels extraits en Formes B (`ﺑﯿ`, `ﺑﯚ`, `ﺑﯘ`) et marques séparées par espaces dans `12–36 pt` (`́ ۆ`). |
| **Extraction `pdfminer.six` (16 formes)** | `11` ordre logique, `4` ordre inversé, `1` séparée par espace (`ۆ ̀`). `has_contextual_beh_nominal: true`. | `0` ordre logique, `16` ordre BiDi inversé, `0` perte. Formes B sur mots contextuels. |
| **Réversibilité après extraction brute** | **Partielle dans le prototype (11/16)** ; **16/16 atteignable** avec émission en un seul `BT..ET` (`TJ` / `Td`). | **Échec sur flux PDF brut** : inversion `marque + base` (`14–16/16`) + Formes B sur mots contextuels (seule la sélection DOM avant export est 16/16). |

---

## 4. Matrice comparative (Phase 6)

| Critère | Option A (`package:pdf` étendu) | Option B (`PdfDocument` Android / `HarfBuzz FFI`) | Option C (`printing` WebView Android / Chromium) |
| :--- | :--- | :--- | :--- |
| **Rendu correct** | **Oui** (via table `GPOS`/`GSUB` précalculée) | **Oui** (HarfBuzz natif) | **Oui** (HarfBuzz / Blink) |
| **Unicode extractible** | **Oui** (`U+06xx` nominal garanti via `PdfUnicodeCmap` ; 1 `BT..ET` requis) | **Oui** (Skia PDF / `ToUnicode` ; Formes B possibles sur contextuels) | **Partiel** (Skia PDF inverse `marque + base` en RTL et émet des Formes B sur contextuels) |
| **Réversibilité** | **Haute** (si 1 seul objet texte PDF + ordre logique) | **Moyenne** (soumise au BiDi visuel de Skia PDF) | **Faible sur PDF brut** (inversion BiDi + Formes B + espaces) |
| **Android** | **Oui** (natif Dart) | **Oui** (natif Android uniquement pour B1 ; FFI pour B2) | **Oui** (via Android System WebView / `printing`) |
| **Hors ligne** | **100 % hors ligne** | **100 % hors ligne** | **100 % hors ligne sur Android (WebView)** ; serveur requis si Chromium distant |
| **Licence** | **Apache 2.0 + SIL OFL 1.1** | **Apache 2.0 (B1) / MIT (B2) + SIL OFL 1.1** | **BSD-3 (`printing`) + SIL OFL 1.1** |
| **Maintenance** | **Moyenne** (générateur Python de table + wrapper RTL) | **Élevée** (code natif par plateforme ou build C/FFI) | **Faible pour le rendu**, **moyenne** (portage HTML/CSS du gabarit PDF) |

---

## 5. Conformité SIL OFL 1.1 (rappel)

Avant toute intégration de `BeriyaArabicProto-Regular.ttf`, corriger dans `build_proto_font.py` le champ **`nameID=3`** (`2.009;GOOG;NotoSansArabic-Regular` → `2.009;BERIYA;BeriyaArabicProto-Regular`) et livrer la notice de modification avec `Noto-OFL.txt`.

---

## 6. Architecture recommandée & Décision

- **Architecture recommandée :** **Option A (extension ciblée de `package:pdf 3.12.0` sans fork)** si l'exigence prioritaire est la **réversibilité Unicode exacte, la conservation de `BeriyaPdfService` / `erfe_pdf_text.dart`, 0 Mo de surcoût APK et le fonctionnement 100 % hors ligne multiplateforme**.
  - *Alternative si des paragraphes arabes longs multi-lignes deviennent requis :* **Option C1 (`Printing.convertHtml` sur Android WebView)** pour le rendu visuel RTL, en acceptant les limites d'extraction BiDi de Skia PDF.
- **Preuves techniques :** `ar_pdf_04_option_a.pdf` (`17,4 Ko`, `16/16` visuel + `ToUnicode` nominal) vs `ar_pdf_04_option_c.pdf` (`114 Ko`, `16/16` visuel mais `14–16/16` inversés à l'extraction).
- **Limitations connues :**
  1. Le prototype Option A utilise 2 `drawString` (causant 1 espace sur `ۆ ̀`) : l'implémentation finale devra émettre `base + mark` dans un seul bloc `BT..ET` (ou `ActualText`) et gérer le retour à la ligne RTL par ligne.
  2. Validation physique sur **Samsung SM-A336E** toujours requise (non testée à ce stade).
- **Estimation de l'effort (Option A complète) :** **3 à 5 jours-homme** (générateur de table `GPOS`/`GSUB` pour l'alphabet arabe complet + émission `BT..ET` unique + découpe RTL multi-lignes + tests unitaires et QA physique Samsung).
- **Décision :** **GO conditionnel pour Option A** (sous réserve de validation linguistique de la convention A et de la passe physique sur Samsung SM-A336E). **NO-GO** pour toute intégration immédiate en production.
