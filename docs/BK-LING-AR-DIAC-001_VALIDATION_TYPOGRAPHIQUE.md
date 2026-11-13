# RAPPORT DE VALIDATION TYPOGRAPHIQUE ET UNICODE — BK-LING-AR-DIAC-001
## Convention candidate Arabe des 16 formes diacritiques du Beřiya

**Référence spécification :** `BK-LING-AR-DIAC-001` (v1.0 — Convention candidate)  
**Référence technique :** branche `dev`, commit `5836c63`  
**Date d'exécution :** 13 novembre 2026  
**Périmètre :** Qualification technique Unicode, typographique et d'export (sans modification de code, sans migration de données, sans fusion Git, sans déploiement).

---

## 1. Tableau de validation linguistique des 16 correspondances (statut)

> **Important :** Aucune correspondance n'est considérée comme officielle à ce stade. La validation linguistique humaine reste requise pour l'ensemble des 16 formes, en particulier `Ị / ị`.

| N° | Latin | Erfe canonique | Arabe candidat | Séquence Unicode | Collision (25 bases / 16 cand.) | NFC ↔ NFD stable | Validation linguistique |
|---|---|---|---|---|---|---|---|
| 1 | `Ị / ị` | `𖺧̇` | `ی̇` | `U+06CC U+0307` | Non | Oui | **En attente** (`U+0323` latin vs `U+0307` arabe) |
| 2 | `Î / î` | `𖺧̄` | `ی̄` | `U+06CC U+0304` | Non | Oui | **En attente** |
| 3 | `Û / û` | `𖺶̄` | `ۇ̄` | `U+06C7 U+0304` | Non | Oui | **En attente** |
| 4 | `Ô / ô` | `𖺯̄` | `ۆ̄` | `U+06C6 U+0304` | Non | Oui | **En attente** |
| 5 | `Â / â` | `𖺠̄` | `ا̄` | `U+0627 U+0304` | Non | Oui | **En attente** |
| 6 | `Ê / ê` | `𖺣̄` | `آ̄` | `U+0622 U+0304` | Non | Oui (`U+0627 U+0653 U+0304` en NFD) | **En attente** |
| 7 | `À / à` | `𖺠̀` | `ا̀` | `U+0627 U+0300` | Non | Oui | **En attente** |
| 8 | `Á / á` | `𖺠́` | `ا́` | `U+0627 U+0301` | Non | Oui | **En attente** |
| 9 | `È / è` | `𖺣̀` | `آ̀` | `U+0622 U+0300` | Non | Oui (`U+0627 U+0653 U+0300` en NFD) | **En attente** |
| 10 | `É / é` | `𖺣́` | `آ́` | `U+0622 U+0301` | Non | Oui (`U+0627 U+0653 U+0301` en NFD) | **En attente** |
| 11 | `Ì / ì` | `𖺧̀` | `ی̀` | `U+06CC U+0300` | Non | Oui | **En attente** |
| 12 | `Í / í` | `𖺧́` | `ی́` | `U+06CC U+0301` | Non | Oui | **En attente** |
| 13 | `Ù / ù` | `𖺶̀` | `ۇ̀` | `U+06C7 U+0300` | Non | Oui | **En attente** |
| 14 | `Ú / ú` | `𖺶́` | `ۇ́` | `U+06C7 U+0301` | Non | Oui | **En attente** |
| 15 | `Ò / ò` | `𖺯̀` | `ۆ̀` | `U+06C6 U+0300` | Non | Oui | **En attente** |
| 16 | `Ó / ó` | `𖺯́` | `ۆ́` | `U+06C6 U+0301` | Non | Oui | **En attente** |

---

## 2. Matrice des tests typographiques et Unicode (T01–T08)

| Test | Environnement | Résultat observé | Statut |
|---|---|---|---|
| **T01 — Formes isolées** | Chrome 157 (Windows, 200% DPR) | Signes combinants latins (`U+0300..U+0307`) absents de `NotoSansArabic-Regular.ttf` → repli multi-police cassant le centrage GPOS (`ا̄` ressemble à `7`/`┐`, accents décalés à gauche). `Segoe UI` rend `ا̀`/`ا́`/`آ̀`/`آ́` quasi invisibles. | **ÉCHEC** |
| **T02 — Tailles (12, 16, 24, 36 px)** | Chrome 157 (Windows, 200% DPR) | À 12 px et 16 px, les combinaisons sur `آ` (`آ̀`, `آ́`, `آ̄`) et `ۇ`/`ۆ` s'écrasent ou se confondent avec la madda / le signe `v` natif. | **ÉCHEC** |
| **T03 — Combinaisons en contexte** | Chrome 157 (`Noto Sans Arabic` & `Tahoma`) | La liaison arabe (`ب` + voyelle) fonctionne, mais les diacritiques combinants dérivent à gauche entre les lettres. Dans `Mixte Latin/Arabe`, l'ordre BiDi général reste cohérent mais le positionnement des marques est décalé. | **ÉCHEC** |
| **T04 — Saisie et édition RTL** | Chrome 157 (`<textarea dir="rtl">`) | Saisie, collage logique et `Backspace` (suppression du combinant seul `ۇ̄ → ۇ`) fonctionnent au niveau Unicode (`t04_input`), mais le rendu visuel subit les mêmes décalages que T01/T03. | **PARTIEL** |
| **T05 — Conversions aller-retour (6 sens)** | Prototype Python en mémoire (`verify_t05_roundtrips.py`) | 16/16 formes bijectives et réversibles dans les 6 directions ; stabilité NFC/NFD vérifiée pour les 16 séquences (note : `آ` + marque devient 3 points de code `U+0627 U+0653 U+03xx` en NFD). | **PASSÉ** (Unicode pur) |
| **T06 — Export PNG (style Sticker)** | Chrome 157 (`chrome_t06_sticker_arabic.png`) | Le point `U+0307` de `ی̇` est rendu par la police de repli comme un carré flottant en haut à gauche hors de la lettre ; le macron de `ی̄` flotte à gauche au-dessus de l'espace. | **ÉCHEC** |
| **T07 — Export PDF & extraction** | Chrome PDF (`chrome_t07_arabic_diacritics.pdf`) + `pypdf` | L'extraction `pypdf` inverse visuellement l'ordre de `12 / 16` séquences (`̄ی`, `́ا`, `̀آ`). De plus, dans `BeriyaPdfService` (Flutter `pdf`), `NotoSansArabic-Regular.ttf` ne contient pas `U+0300/0301/0304/0307`. | **ÉCHEC** |
| **T08 — Compatibilité des polices** | Analyse `cmap` TTF + Chrome (`Noto Sans Arabic`, `Segoe UI`, `Tahoma`, `Arial`) | Aucune des polices testées ne fournit un ancrage GPOS propre pour les 4 signes combinants latins sur des bases arabes. | **ÉCHEC** |
| **Samsung SM-A336E / Flutter Android** | ADB (`adb devices`) | **Non exécuté** : appareil Samsung non connecté lors de cette session (`List of devices attached` vide). | **NON TESTÉ** |

---

## 3. Comparaison des polices (T08)

| Police | Source / Version | 5 bases arabes (`ا`, `آ`, `ی`, `ۆ`, `ۇ`) | 4 combinants (`U+0300/0301/0304/0307`) | Défauts de positionnement observés | Export PDF |
|---|---|---|---|---|---|
| **NotoSansArabic-Regular.ttf** | Dépôt (`mobile/assets/fonts/` & `backend/static/webapp/fonts/`) | **Oui** (`5/5` dans `cmap`) | **Non (`0/4` absents du `cmap`)** | Décalage à gauche via police de repli ; `ا̄` forme un `7`/`┐` ; `ی̇` décalé hors glyphe. | **Bloquant** (glyphes absents dans le TTF) |
| **NotoSans-Regular.ttf** | Dépôt | Non (`0/5`) | Oui (`4/4`) | Ne couvre pas l'alphabet arabe (sert uniquement de repli pour les combinants). | N/A pour l'arabe |
| **Kedebideri-Regular.ttf** | Dépôt | Non (`0/5`) | Oui (`4/4`) | Police Erfe uniquement. | N/A pour l'arabe |
| **Segoe UI** | Windows 11 / Chrome | Oui | Oui (ou repli partiel) | **Critique** : `ا̀`, `ا́`, `آ̀`, `آ́` rendent les accents invisibles/écrasés ; collision sur `ۇ`/`ۆ`. | Non homologable |
| **Tahoma** | Windows 11 / Chrome | Oui | Oui | Décalage systématique vers la gauche (`'ا`, `'آ`, `┐` sur `ا̄`). | Non homologable |
| **Arial** | Windows 11 / Chrome | Oui | Oui | Décalage vers la gauche (`ا̄` ressemble à `7`/`┐`, chevauchement sur `آ`). | Non homologable |

---

## 4. Rapport des anomalies

| ID | Caractère(s) | Police & Environnement | Attendu | Observé | Preuve | Gravité | Correction envisagée |
|---|---|---|---|---|---|---|---|
| **ANOM-AR-01** | `U+0300`, `U+0301`, `U+0304`, `U+0307` sur les 16 formes | `NotoSansArabic-Regular.ttf` (dépôt) | Présence des 4 combinants et ancrage GPOS centré sur les 5 bases arabes | Les 4 points de code sont **absents du `cmap`** de `NotoSansArabic-Regular.ttf`. Le navigateur bascule sur une police latine de repli, supprimant tout ancrage GPOS arabe ; en PDF Flutter, les combinants ne peuvent pas être dessinés par cette police. | [arabic_unicode_font_analysis.json](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/arabic_unicode_font_analysis.json) | **Bloquante** | Évaluer une police arabe intégrant ces combinants + GPOS (ex. `Scheherazade New` / `Amiri` / `Noto Naskh Arabic` complet) ou une fonte personnalisée, ou réviser le choix des signes combinants. |
| **ANOM-AR-02** | `ا̄`, `ا̀`, `ا́`, `ی̇`, `ی̄` | Chrome 157 (`Noto Sans Arabic` + repli, `Tahoma`, `Arial`) | Diacritique centré au-dessus de la base | Le macron sur `ا̄` se colle en haut à gauche (`7` / `┐`) ; l'aigu/grave sur `ا` flotte à gauche ; dans le Sticker T06, le point `ی̇` est un carré flottant hors de `ی`. | [chrome_t01_t08_matrix.png](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t01_t08_matrix.png), [chrome_t06_sticker_arabic.png](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t06_sticker_arabic.png) | **Majeure** | Dépend d'ANOM-AR-01 (police unique gérant base arabe + combinant via GPOS). |
| **ANOM-AR-03** | `ا̀`, `ا́`, `آ̀`, `آ́` | `Segoe UI` (Windows / Chrome) | Accent grave et aigu nettement distincts et visibles | Les accents grave et aigu sur `ا` et `آ` sont invisibles / indiscernables de `ا` et `آ` nus. | [chrome_t01_t08_matrix.png](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t01_t08_matrix.png) | **Bloquante** | Exclure `Segoe UI` des polices cibles et embarquer une police arabe validée. |
| **ANOM-AR-04** | `آ̄`, `آ̀`, `آ́` (`Ê`, `È`, `É`) | Toutes polices testées (`12px`–`36px`) | Double marque lisible au-dessus de l'Alif | `آ` (`U+0622`) porte déjà une madda (`U+0653`, classe 230) : l'ajout d'une seconde marque de classe 230 (`U+0300`/`0301`/`0304`) provoque un empilement/chevauchement difficile à lire aux petites tailles (`12px`–`16px`). | [chrome_t01_t08_matrix.png](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t01_t08_matrix.png) | **Majeure** | Vérifier l'acceptabilité visuelle avec le responsable linguistique sur une police à empilement vertical (`mark-to-mark` GPOS). |
| **ANOM-AR-05** | `12 / 16` séquences en extraction PDF | Chrome PDF + `pypdf` (`chrome_t07_arabic_diacritics.pdf`) | Extraction conservant l'ordre logique `base + combinant` | `pypdf` extrait `̄ی`, `́ا`, `̀آ` (ordre inversé) sur `12/16` formes. | [browser_typographic_results.json](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/browser_typographic_results.json), [chrome_t07_arabic_diacritics.pdf](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t07_arabic_diacritics.pdf) | **Majeure** | Tester l'extraction avec une police arabe unifiée et valider le flux `ToUnicode` PDF dédié. |

---

## 5. Preuves générées (lecture seule, aucun code applicatif modifié)

- Analyse Unicode & tables `cmap` TTF : [analyze_arabic_candidates.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/analyze_arabic_candidates.py) → [arabic_unicode_font_analysis.json](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/arabic_unicode_font_analysis.json)
- Tests T05 (6 sens × 16 formes en mémoire) : [verify_t05_roundtrips.py](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/verify_t05_roundtrips.py) → [t05_roundtrip_results.json](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/t05_roundtrip_results.json)
- Matrice Chrome T01–T08 & captures : [chrome_t01_t08_matrix.png](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t01_t08_matrix.png), [chrome_t06_sticker_arabic.png](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t06_sticker_arabic.png), [chrome_t07_arabic_diacritics.pdf](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/chrome_t07_arabic_diacritics.pdf), [browser_typographic_results.json](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/qa_arabic_diacritics/browser_typographic_results.json)

---

## 6. Décision GO / NO-GO argumentée

### Décision : **NO-GO en l'état (activation bloquée)**

1. **Plan linguistique :** En attente de confirmation explicite du responsable linguistique Beřiya pour les 16 formes candidates (notamment `Ị / ị` → `ی̇` et l'empilement sur `آ` pour `Ê / È / É`).
2. **Plan typographique (bloquant technique majeur) :**
   - La police arabe embarquée du projet (`NotoSansArabic-Regular.ttf`) **ne contient aucun des 4 signes combinants** (`U+0300`, `U+0301`, `U+0304`, `U+0307`).
   - Sur Chrome/Web, le repli vers une police latine casse le positionnement GPOS (décalages à gauche, `ا̄` lu comme `7`, point flottant sur `ی̇` dans le Sticker).
   - Sur `Segoe UI`, les accents grave et aigu sur `ا` et `آ` disparaissent visuellement.
   - L'export PDF présente des inversions d'extraction (`12/16`) et la police embarquée ne couvre pas les combinants pour `BeriyaPdfService`.
   - Le test sur Samsung SM-A336E reste à exécuter une fois l'appareil reconnecté et une police candidate compatible sélectionnée.

**Action recommandée avant toute nouvelle tentative d'homologation :** obtenir la validation linguistique des 16 formes et identifier/tester une police arabe unifiée prenant en charge les 5 lettres de base, les 4 signes combinants et leur ancrage GPOS (`mark` et `mkmk` sur `آ`).
