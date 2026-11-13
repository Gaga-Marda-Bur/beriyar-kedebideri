# BERIYAR KEDEBIDERI — RAPPORT DE CLÔTURE TECHNIQUE (AR-CLOSE-10)
## Préparation de la fusion contrôlée du moteur PDF arabe expérimental

**Référence :** `AR-CLOSE-10`  
**Date :** 13 novembre 2026  
**Branche candidate :** `feature/arabic-pdf-experimental`  
**Branche cible (non fusionnée) :** `dev` (`5836c63fbb475b03e42e829a07fd4c0e20642dd3`)

---

## 1. Vérification des 25 lettres arabes fondamentales sur Samsung SM-A336E

Le harnais QA isolé (`mobile/integration_test/arabic_pdf_physical_test.dart`, `--dart-define=BK_TOOLS_QA=true`, package `com.afrigama.beriyarkedebideri.qa_tools`) a été mis à jour avec la liste exacte des **25 lettres arabes fondamentales** de `shared/linguistics/beriya_erfe_transliteration_mapping.json` et exécuté sur le **Samsung SM-A336E** (Android 16, SDK 36) :

- **Artefact généré sur appareil :** `docs/qa_arabic_diacritics/close_10/ar_device_09_samsung.pdf` (`23 338` octets, `2` pages).
- **Extraction Unicode (`pypdf` et `pdfminer.six`) :**
  - **25 / 25 lettres arabes fondamentales** extraites sans aucune lettre manquante (`missing_pypdf_ar: []`, `missing_miner_ar: []`).
  - **25 / 25 lettres Erfe fondamentales** extraites (`pypdf` & `pdfminer.six`).
  - **16 / 16 formes arabes accentuées** extraites (`pypdf` & `pdfminer.six`).

---

## 2. Confirmation du fonctionnement 100 % hors ligne sur Samsung SM-A336E

- Avant l'exécution du test sur `R6CT6003WRT`, le Wi-Fi et les données mobiles ont été désactivés via ADB (`svc wifi disable; svc data disable`).
- La sonde réseau (`ping -c 1 -W 2 1.1.1.1`) a retourné **`connect: Network is unreachable`**.
- Le harnais `arabic_pdf_physical_test.dart` s'est exécuté jusqu'à son terme (**`00:10 +1: All tests passed!`**), générant `ar_device_09_samsung.pdf` en **`1 797 ms`** et `ar_device_09_historical_erfe.pdf` (`10 990` octets) sans aucune connexion réseau.

---

## 3. Sélection et copier-coller : lecteur PDF Android vs structure du PDF

- **Garanties du PDF généré (vérifiées) :**
  - Flux `/ToUnicode` nominaux sans aucune forme de présentation (`0` code `FBxx`/`FExx` dans `/ToUnicode`).
  - `pypdf` et `pdfminer.six` restituent `16/16` formes accentuées, `25/25` Erfe et `25/25` Arabe dans l'ordre logique Unicode.
  - Dans l'application Flutter sur Samsung SM-A336E (`TextField` + `Clipboard`), le copier-coller des 16 formes et des chaînes RTL conserve 100 % des points de code et diacritiques combinants.
- **Limitations propres au lecteur PDF Android (à distinguer du PDF) :**
  - Le rendu visuel réel du PDF dans **Google Drive PDF Viewer** (`com.google.android.apps.docs`) sur Samsung SM-A336E est validé (`android_pdf_viewer_p1.png`, `android_pdf_viewer.png`).
  - La sélection tactile interactive directement dans Google Drive PDF Viewer n'a pas été exécutée manuellement ; les éventuelles variations de sélection de mots, de copie d'espaces inter-widgets sur lignes mixtes (`pw.Wrap`) ou de normalisation du presse-papier Android relèvent du moteur de sélection du lecteur PDF tiers et non des tables `/ToUnicode` du fichier PDF.

---

## 4. Vérification Unicode et variantes de *yeh* arabe

### Différences entre les variantes de *yeh* arabe
| Caractère | Point de code | Nom Unicode | Rôle dans Beriyar Kedebideri |
| :--- | :--- | :--- | :--- |
| `ی` | `U+06CC` | ARABIC LETTER FARSI YEH | **Lettre fondamentale `i` (`𖺧` `U+16EA7`)** et **base des 4 voyelles `ی̇`, `ی̄`, `ی̀`, `ی́`**. Sans points en isolée/finale (`FBFC`/`FBFD`), 2 points dessous en initiale/médiane (`FBFE`/`FBFF`). |
| `ي` | `U+064A` | ARABIC LETTER YEH | **Lettre fondamentale `y` (`𖺸` `U+16EB8`)**. Porte 2 points dessous dans toutes les formes (`064A`/`FEF2`/`FEF3`/`FEF4`). |
| `ى` | `U+0649` | ARABIC LETTER ALEF MAKSURA | Présente uniquement dans `arabicContextualForms` (support arabe général), **non utilisée** dans les 25 lettres Beřiya ni dans les 16 formes accentuées. |

### Points de code exacts des 25 lettres fondamentales (`beriya_erfe_transliteration_mapping.json`)
`U+0627` (`ا` `a`), `U+0628` (`ب` `b`), `U+062F` (`د` `d`), `U+0622` (`آ` `e`), `U+0641` (`ف` `f`), `U+0642` (`ق` `g`), `U+0647` (`ه` `h`), `U+06CC` (`ی` `i`), `U+062C` (`ج` `j`), `U+0643` (`ك` `k`), `U+0644` (`ل` `l`), `U+0645` (`م` `m`), `U+0646` (`ن` `n`), `U+06BD` (`ڽ` `ɲ`), `U+06A0` (`ڠ` `ŋ`), `U+06C6` (`ۆ` `o`), `U+067E` (`پ` `p`), `U+0631` (`ر` `r`), `U+0695` (`ڕ` `ř`), `U+0633` (`س` `s`), `U+0634` (`ش` `š`), `U+062A` (`ت` `t`), `U+06C7` (`ۇ` `u`), `U+0648` (`و` `w`), `U+064A` (`ي` `y`).

---

## 5. Tableau d'homologation des 16 correspondances (candidat `BK-LING-AR-DIAC-001`)

| N° | Latin | Erfe canonique | Erfe Unicode | Arabe candidat | Arabe Unicode (NFC) | Statut linguistique |
|---:|---|---|---|---|---|---|
| 1 | `Ị / ị` | `𖺧̇` | `U+16EA7 U+0307` | `ی̇` | `U+06CC U+0307` | **À valider** |
| 2 | `Î / î` | `𖺧̄` | `U+16EA7 U+0304` | `ی̄` | `U+06CC U+0304` | **À valider** |
| 3 | `Û / û` | `𖺶̄` | `U+16EB6 U+0304` | `ۇ̄` | `U+06C7 U+0304` | **À valider** |
| 4 | `Ô / ô` | `𖺯̄` | `U+16EAF U+0304` | `ۆ̄` | `U+06C6 U+0304` | **À valider** |
| 5 | `Â / â` | `𖺠̄` | `U+16EA0 U+0304` | `ا̄` | `U+0627 U+0304` | **À valider** |
| 6 | `Ê / ê` | `𖺣̄` | `U+16EA3 U+0304` | `آ̄` | `U+0622 U+0304` | **À valider** |
| 7 | `À / à` | `𖺠̀` | `U+16EA0 U+0300` | `ا̀` | `U+0627 U+0300` | **À valider** |
| 8 | `Á / á` | `𖺠́` | `U+16EA0 U+0301` | `ا́` | `U+0627 U+0301` | **À valider** |
| 9 | `È / è` | `𖺣̀` | `U+16EA3 U+0300` | `آ̀` | `U+0622 U+0300` | **À valider** |
| 10 | `É / é` | `𖺣́` | `U+16EA3 U+0301` | `آ́` | `U+0622 U+0301` | **À valider** |
| 11 | `Ì / ì` | `𖺧̀` | `U+16EA7 U+0300` | `ی̀` | `U+06CC U+0300` | **À valider** |
| 12 | `Í / í` | `𖺧́` | `U+16EA7 U+0301` | `ی́` | `U+06CC U+0301` | **À valider** |
| 13 | `Ù / ù` | `𖺶̀` | `U+16EB6 U+0300` | `ۇ̀` | `U+06C7 U+0300` | **À valider** |
| 14 | `Ú / ú` | `𖺶́` | `U+16EB6 U+0301` | `ۇ́` | `U+06C7 U+0301` | **À valider** |
| 15 | `Ò / ò` | `𖺯̀` | `U+16EAF U+0300` | `ۆ̀` | `U+06C6 U+0300` | **À valider** |
| 16 | `Ó / ó` | `𖺯́` | `U+16EAF U+0301` | `ۆ́` | `U+06C6 U+0301` | **À valider** |

---

## 6. Inventaire final des fichiers, ressources et licences

- **Fichiers suivis modifiés (`5836c63..HEAD`, `+111 / -23`) :**
  - `mobile/lib/features/editor/services/beriya_pdf_service.dart`
  - `mobile/lib/features/editor/services/pdf_unicode_cmap.dart`
  - `mobile/pubspec.yaml`
- **Fichiers applicatifs & tests ajoutés :**
  - `mobile/assets/fonts/experimental/BeriyaArabicProto-Regular.ttf` (`239 864` octets, SHA-256 `ff976ce200192dcafae66271d6db28d8980cc1f190ee3361b3cbfa8f7361baa8`)
  - `mobile/assets/fonts/experimental/OFL.txt` (`SIL OFL 1.1`, `nameID=1` = `Beriya Arabic Proto`, aucun nom réservé `Noto` dans la famille)
  - `mobile/lib/features/editor/services/arabic_pdf_layout_data.dart`
  - `mobile/lib/features/editor/services/arabic_pdf_text.dart`
  - `mobile/test/arabic_pdf_experimental_test.dart`
  - `mobile/integration_test/arabic_pdf_physical_test.dart`
- **Livrables QA :** `docs/AR_*`, `docs/BK-LING-AR-DIAC-001_VALIDATION_TYPOGRAPHIQUE.md`, `docs/qa_arabic_diacritics/`.
- **Intégrité :** aucun changement involontaire dans `backend/`, `shared/`, `erfe_pdf_text.dart`, les données pédagogiques, No Ena ou Studio Sticker.

---

## 7. Synthèse des vérifications exécutées

| Contrôle | Résultat | Date / Contexte |
| :--- | :--- | :--- |
| **`flutter analyze` (`mobile/`)** | **PASS (`0` anomalie)** | `No issues found! (ran in 9.1s)` après le dernier edit |
| **`flutter test test/arabic_pdf_experimental_test.dart`** | **4 / 4 PASS** | Après le dernier edit |
| **Harnais Samsung SM-A336E hors ligne (`arabic_pdf_physical_test.dart`)** | **1 / 1 PASS** | Wi-Fi & données coupés (`Network is unreachable`), `25/25` Arabe + `25/25` Erfe + `16/16` formes extraites |
| **Suite Flutter complète (`flutter test`)** | **176 / 176 PASS** | Validée en `AR-QA-08` (aucune modification de `mobile/lib/` depuis) |
| **Suite Django complète (`manage.py test`)** | **173 exécutés, OK (`skipped=2`)** | Validée en `AR-QA-08` (`backend/` intact) |

---

## 8. Plan de fusion contrôlée dans `dev` (à exécuter uniquement après accord)

1. **Avant fusion :** valider les éventuels choix de périmètre (inclure ou non `docs/qa_arabic_diacritics/` dans `dev`, ou n'intégrer que le code applicatif + tests + rapports de synthèse).
2. **Créer un tag/branche de sauvegarde** sur `dev` (`5836c63`).
3. **Committer proprement** sur `feature/arabic-pdf-experimental` en vérifiant que `BeriyaPdfService.experimentalArabicPdfEnabled` reste **`false`** par défaut.
4. **Fusionner dans `dev`** (`git checkout dev && git merge --no-ff feature/arabic-pdf-experimental`), sans push automatique ni déploiement.
5. **Post-fusion immédiate :** ré-exécuter `flutter analyze`, `flutter test` et `manage.py test` sur `dev`.

---

## 9. Limitations restantes et critères de retour arrière

### Limitations documentées
1. **4 lettres Beřiya étendues (`U+067E` پ, `U+0695` ڕ, `U+06A0` ڠ, `U+06BD` ڽ) :** absentes de `arabicContextualForms` dans `arabic_pdf_layout_data.dart` ; elles sont rendues en forme isolée et consignées dans `unsupportedCharacters` (extraction Unicode `25/25` OK, mais liaison contextuelle à ajouter dans un lot ultérieur avant activation publique).
2. **Paragraphe arabe unique > 1 page sans `\n` :** `LogicalRtlArabicBlock` ne implémente pas `SpanningWidget` (`MultiPage` découpe uniquement entre paragraphes).
3. **Empilement > 1 marque combinante sur une base (`cl.length > 2`) :** seule `cl[1]` est rendue.
4. **Sélection tactile interactive dans le lecteur PDF Android tiers :** non testée manuellement dans Google Drive PDF Viewer.

### Critères de retour arrière (rollback)
- **Désactivation immédiate sans rollback Git :** `BeriyaPdfService.experimentalArabicPdfEnabled` est déjà `false` par défaut ; aucun parcours utilisateur n'est affecté.
- **Rollback Git :** `git revert -m 1 <merge_commit_dev>` si une régression survenait après fusion dans `dev`.

---

## 10. Recommandation finale : **PRÊT SOUS CONDITIONS**

- **Statut technique :** **Prêt pour fusion contrôlée dans `dev` avec drapeau désactivé par défaut (`experimentalArabicPdfEnabled = false`)**, dès votre autorisation explicite.
- **Conditions avant activation utilisateur :**
  1. Homologation linguistique formelle des **16 correspondances** du tableau section 5.
  2. Ajout du support contextuel (isolée/finale/initiale/médiane) pour les 4 lettres Beřiya étendues (`U+067E`, `U+0695`, `U+06A0`, `U+06BD`).
