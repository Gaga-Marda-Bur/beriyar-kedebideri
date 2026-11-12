# Extension officielle des diacritiques — 12 novembre 2026

## État et validation linguistique

Branche : `codex/erfe-diacritics-extension`, créée depuis le commit validé `e827c7e`. L’arbre Git était propre. Les anciens rapports et preuves restent conservés ; les nouvelles preuves sont dans `docs/transliteration_diacritics/`.

Les trois points ambigus ont été soumis à l’utilisateur, qui a répondu **« Je confirme les trois conventions »** :

1. **Ị/ị** est précomposé en U+1ECA/U+1ECB. Sa décomposition NFD contient **U+0323, point dessous**. Sa correspondance Erfe est bien I Erfe + **U+0307, point dessus**, conformément à la convention confirmée. Ce n’est pas une équivalence Unicode, mais une correspondance linguistique explicite.
2. La saisie initiale « ÂÂ » signifie **Â/â**.
3. **Ó/ó → 𖺯́**, O Erfe majuscule U+16EAF + U+0301. L’entrée minuscule 𖻊́ est normalisée vers cette même forme canonique.

La source unique JSON passe au schéma **1.1**. Le bloc des **25 correspondances fondamentales est inchangé**, vérifié par comparaison structurelle avec `e827c7e`. Les 16 ajouts proviennent de la présente demande et de sa confirmation, pas du classeur précédent. Aucun équivalent arabe n’est inventé.

## Les 16 correspondances ajoutées

| Latin | Erfe canonique | Séquence Erfe | Latin NFD (majuscule) | Arabe |
|---|---|---|---|---|
| Ị / ị | 𖺧̇ | `U+16EA7 U+0307` | `U+0049 U+0323` | Non défini |
| Î / î | 𖺧̄ | `U+16EA7 U+0304` | `U+0049 U+0302` | Non défini |
| Û / û | 𖺶̄ | `U+16EB6 U+0304` | `U+0055 U+0302` | Non défini |
| Ô / ô | 𖺯̄ | `U+16EAF U+0304` | `U+004F U+0302` | Non défini |
| Â / â | 𖺠̄ | `U+16EA0 U+0304` | `U+0041 U+0302` | Non défini |
| Ê / ê | 𖺣̄ | `U+16EA3 U+0304` | `U+0045 U+0302` | Non défini |
| À / à | 𖺠̀ | `U+16EA0 U+0300` | `U+0041 U+0300` | Non défini |
| Á / á | 𖺠́ | `U+16EA0 U+0301` | `U+0041 U+0301` | Non défini |
| È / è | 𖺣̀ | `U+16EA3 U+0300` | `U+0045 U+0300` | Non défini |
| É / é | 𖺣́ | `U+16EA3 U+0301` | `U+0045 U+0301` | Non défini |
| Ì / ì | 𖺧̀ | `U+16EA7 U+0300` | `U+0049 U+0300` | Non défini |
| Í / í | 𖺧́ | `U+16EA7 U+0301` | `U+0049 U+0301` | Non défini |
| Ù / ù | 𖺶̀ | `U+16EB6 U+0300` | `U+0055 U+0300` | Non défini |
| Ú / ú | 𖺶́ | `U+16EB6 U+0301` | `U+0055 U+0301` | Non défini |
| Ò / ò | 𖺯̀ | `U+16EAF U+0300` | `U+004F U+0300` | Non défini |
| Ó / ó | 𖺯́ | `U+16EAF U+0301` | `U+004F U+0301` | Non défini |

Le tableau est aussi disponible dans `transliteration_diacritics/correspondances.md`. Le détail de chaque codepoint précomposé, décomposé, canonique et minuscule figure dans `unicode_report.json`.

## Traitement Unicode

Le moteur existant est étendu, sans second moteur. `scripts/generate_transliteration.py` produit les tables Python, Dart, JavaScript, les options accentuées du clavier et les vecteurs de référence depuis le même JSON.

- **41 unités connues** : 25 lettres simples et 16 lettres accentuées.
- NFC et NFD latins sont acceptés, en majuscules et minuscules. La sortie latine reste NFC, en majuscules par défaut ou en minuscules sur demande.
- Les 25 minuscules Erfe continuent d’être converties vers les majuscules, sans supprimer ni remplacer le signe combinant.
- Chaque forme Erfe accentuée contient **2 points de code**, **3 unités UTF-16**, et forme une unité de translittération. Une unité est une base suivie de ses signes combinants ; le moteur ne convertit pas seulement la base lorsque l’unité entière est inconnue.
- Grave U+0300, aigu U+0301, macron U+0304 et point dessus U+0307 sont employés par les formes Erfe fournies. Le circonflexe U+0302 apparaît dans les entrées latines NFD : par exemple `A + U+0302` devient Â puis se convertit en Erfe A + U+0304, selon la table validée.
- **Ne pas confondre** Latin Â et Ā : le Latin A + macron n’a pas de correspondance fournie. De même, Latin İ (I + point dessus) n’est pas un alias de Ị ; Erfe I + point dessous et Erfe I + circonflexe ne sont pas inventés comme variantes. Ces unités sont conservées et signalées.
- Les signes supplémentaires ou empilés non définis sont conservés avec leur base et signalés. Aucun retrait d’accent ni simplification arabe approximative.
- Les indices de diagnostic restent des offsets en points de code dans l’entrée normalisée NFC, au début de l’unité. Les positions des éditeurs restent en UTF-16, avec les adaptations de sélection existantes.

Les catégories de signes combinants sont générées pour les trois moteurs depuis la même classification Unicode Python ; les exemples du référentiel et cas limites sont couverts par les tests de parité. Cela ne constitue pas une preuve sur toutes les combinaisons Unicode possibles hors référentiel.

Exemples exécutés :

```text
normalize_erfe("𖺻́𖺾̀𖻂̄")                 → 𖺠́𖺣̀𖺧̄
transliterate("𖺠́𖺣̀𖺧̄", erfe, latin)     → ÁÈÎ
transliterate("ÁÈÎ", latin, erfe)           → 𖺠́𖺣̀𖺧̄
transliterate("I\u0323", latin, erfe)       → 𖺧̇
transliterate("BÁ D", latin, arabic).text   → بÁ د
```

## Correspondances arabes non définies

**Les 16 lignes du tableau ont `arabic: null`.** Cela concerne Ị, Î, Û, Ô, Â, Ê, À, Á, È, É, Ì, Í, Ù, Ú, Ò et Ó, ainsi que leurs minuscules et formes décomposées équivalentes.

Pour une conversion vers l’arabe :

- une unité reconnue mais sans équivalent arabe reste dans son écriture source, après NFC et normalisation obligatoire des minuscules Erfe ;
- son diagnostic contient `reason: "missing_arabic_mapping"` ;
- l’interface affiche **« Conversion incomplète — correspondances arabes non définies »**, avec les formes conservées ; cet avertissement reste présent après copie ;
- les lettres simples voisines peuvent être converties, mais l’accent n’est jamais déplacé vers une lettre arabe supposée.

Le contrat API reste `{text, unmapped}`. Les clés existantes sont conservées. `unmapped.character` peut maintenant contenir une unité avec plusieurs points de code ; `codepoint` énumère sa séquence. `reason` est ajouté pour l’absence d’équivalent arabe. La présence de diagnostics indique une conversion incomplète ; aucun endpoint ni script existant n’est supprimé.

Une future prise en charge complète de l’arabe exige une décision linguistique explicite pour chacune des 16 formes, puis des tests de réversibilité et d’absence de collisions. La normalisation d’une écriture arabe supposée équivalente ne sert pas à combler ces lacunes.

## Intégrations

| Composant | Mise à jour |
|---|---|
| Django/Python, Dart, JavaScript | Même segmentation base + signes et mêmes 41 correspondances générées ; entrées NFC/NFD |
| Claviers Web, Flutter et mini-clavier Sticker | 16 formes accessibles par les options générées ; le macron reste le premier choix existant ; ponctuations et dispositions conservées |
| Éditeurs et outils | Conversion explicite de la sélection ou du texte entier ; avertissement arabe incomplet ; copie, insertion et annulation conservées |
| Collage et saisie | Normalisation Erfe avec diacritiques ; sélection et retours à la ligne conservés ; composition IME inchangée |
| Sticker et exports PNG | Texte canonique avant rendu ; vraie génération de PNG de recette |
| Exports PDF | Placement des accents selon Kedebideri et conservation de leurs unités Unicode à l’extraction |
| Import/export CLI et nouvelles écritures Django | Réutilisation du moteur existant, sans transformation automatique latin/arabe ni réécriture historique |
| Chargement Web | Révision des URLs des scripts concernés pour éviter un mélange des anciennes et nouvelles tables dans le cache navigateur |

## Corrections PDF découvertes par la recette

La vérification n’a pas été limitée à l’en-tête `%PDF-`.

1. **Flutter PDF : accents décalés à droite.** La bibliothèque PDF ne réapplique pas les ancrages GPOS de Kedebideri. `scripts/generate_erfe_pdf_layout.cjs` dérive les positions exactes depuis les polices Regular/Bold existantes et les 16 unités du JSON. Il génère des **métriques graphiques**, pas une seconde table linguistique. Le rendu utilise ces positions, sans nouvelle police, contour vectorisé substitué au texte ni centrage approximatif.
2. **Flutter PDF : encodage ToUnicode hors BMP incorrect dans `pdf 3.12.0`.** La bibliothèque écrit notamment une destination `<16EA7>` au lieu de sa paire UTF-16BE. Un adaptateur local `pdf_unicode_cmap.dart` corrige les destinations pendant la préparation du CMap, puis restaure la liste de scalaires utilisée pour les glyphes. Aucun fichier du SDK ou du cache n’est modifié.
3. **PDF Web : base et accent séparés lors de l’extraction.** Pour les 16 unités validées, une opération texte unique conserve la paire ensemble, tout en appliquant l’offset GPOS exact. Les autres tracés existants gardent leur traitement antérieur.

Les PDF finaux Web et Flutter ont chacun été rouverts : **les 16 unités Erfe et leurs équivalents latins sont extractibles**, et les CMap hors BMP sont en UTF-16BE. Les deux pages de chaque PDF ont été rendues puis inspectées. Le titre Flutter comporte également des formes accentuées en gras. Les exports PNG et le Sticker ont été inspectés.

Les six graisses Kedebideri couvrent les 50 lettres Erfe et les quatre marques Erfe effectivement utilisées, soit 54 codepoints testés. Le fallback Noto Sans couvre les 32 formes latines précomposées. **Aucun fichier de police modifié.**

## Tests et preuves

| Contrôle exécuté | Résultat |
|---|---|
| Reproduction avant correction | 3 tests, 33 sous-tests en échec et 16 erreurs, notamment absence du diagnostic arabe attendu |
| Django complet | **173 tests, OK, dont 2 ignorés** |
| Flutter complet | **172 tests réussis** |
| JavaScript audio, typographie et translittération | **7 tests réussis** |
| Parité Python/Dart/JavaScript | **627 vecteurs communs** exécutés dans chaque moteur |
| Chrome, scénarios historiques | **7 scénarios réussis** |
| Chrome, extension et exports réels | **6 scénarios réussis**, aucune erreur JavaScript |
| PDF Web et Flutter | 16 unités Erfe et 16 formes latines présentes à l’extraction ; CMap hors BMP correct |
| PNG Web, Flutter, Sticker | Fichiers valides, rendus inspectés |
| Analyse Flutter | Aucun nouveau diagnostic ; 1 avertissement préexistant d’import inutilisé dans `integration_test/historical_tools_final_qa_test.dart:8` |

Les 16 formes sont testées en NFC/NFD, majuscules/minuscules latines, Erfe canonique/minuscule, conversion aller-retour et absence d’arabe. Les tests couvrent le point dessous/dessus distinct, le circonflexe/macron distinct, les accents empilés inconnus, les textes mixtes, le collage, les positions UTF-16, les retours à la ligne et l’annulation.

**314 des 315 anciens vecteurs sont strictement identiques.** Le dernier ancien cas change intentionnellement : Erfe A + macron, auparavant non couvert avec sortie Ā, correspond maintenant à **Â** selon l’ajout expressément validé. Le Latin Ā reste non défini et conservé, sans nouvelle convention déduite.

Preuves structurées : `transliteration_diacritics/unicode_report.json`, `test_results.json`, `font_coverage.json`, `export_checks.json`, `browser_results.json`, `browser_extensions.json`. La preuve initiale d’extraction incorrecte est conservée séparément dans `pdf_text_checks_before_fix.json` ; elle décrit l’état **avant** les correctifs PDF.

Captures et rendus : `editor_16_forms.png`, `arabic_incomplete.png`, `flutter_diacritics.png`, `sticker_16_forms.png`, `web_diacritics.png`, `web_pdf-1.png`, `web_pdf-2.png`, `flutter_pdf-1.png`, `flutter_pdf-2.png` dans ce même dossier. Les PDF sont des fichiers de recette contenant uniquement les formes fournies et des intitulés QA français.

## Reproductibilité

```powershell
backend/venv/Scripts/python.exe scripts/generate_transliteration.py --check
node scripts/generate_erfe_pdf_layout.cjs --check
backend/venv/Scripts/python.exe docs/run_backend_checks.py
node --test backend/webapp/tests_audio_player.cjs backend/webapp/tests_typography.cjs backend/webapp/tests_transliteration.cjs
# Depuis mobile/ :
flutter test --reporter expanded
flutter analyze --no-pub
```

La recette navigateur utilise `docs/transliteration/web_server.py`, strictement sur une copie SQLite anonymisée locale. Le script historique accepte désormais un dossier de sortie distinct pour préserver ses anciennes preuves. Les exports Flutter de recette sont produits par `flutter test test/transliteration_diacritics_test.dart --dart-define=BK_CAPTURE_DIACRITICS=true`. Le contrôle PDF/PNG utilise `docs/transliteration_diacritics/check_exports.py` avec le Python fourni par l’environnement, contenant pypdf et Pillow. Aucune dépendance applicative ajoutée ou mise à niveau.

## Conservation, limites et retour arrière

- **Base historique inchangée**, SHA-256 avant/après : `7fe288b82f0539166d8008b89725f27db490805d9b07542f469c816f5c219d03`. Aucun statut pédagogique, traduction historique, progression, pack ou police modifié. Aucun changement commercial, migration ni déploiement.
- Les imports SQL bruts et opérations bulk gardent la limite documentée au lot précédent : appeler explicitement la normalisation ; aucune conversion massive n’est lancée.
- Pas de recette Android physique dans ce lot. Le PNG Flutter est issu d’un vrai rendu de widgets avec les polices chargées sous `flutter test`, **pas d’une capture Samsung**.
- La correction CMap dépend de l’API interne de `pdf 3.12.0`, version actuelle verrouillée par le lockfile. L’import interne est isolé et documenté. Rejouer l’extraction et vérifier l’adaptateur lors d’une mise à jour du paquet. Les ancrages Regular/Bold sont contrôlés par le générateur ; toute modification future des polices exige régénération et recette visuelle.
- Poppler a émis deux avertissements de police système (`Symbol`, `ArialUnicode`) lors du rendu Web. Les formes contrôlées sont présentes, extractibles et visibles sur les pages inspectées ; ces avertissements ne sont pas comptés comme une validation générale de toutes les polices possibles.
- Les signes hors des 16 combinaisons validées restent signalés. Les autres navigateurs, les IME Android et les documents très longs n’ont pas fait l’objet d’une nouvelle recette physique exhaustive.
- Retour arrière : `git revert <commit-de-cette-extension>` sur un arbre propre, puis les tests. Aucune migration inverse ni restauration de base nécessaire pour ce lot local. Ne pas tenter de convertir automatiquement les nouveaux textes accentués légitimes en données anciennes.

Liste exhaustive des fichiers : `transliteration_diacritics/files_changed.json`.

**GO technique local pour les 16 formes Erfe ↔ Latin confirmées. Conversion arabe accentuée explicitement incomplète tant que ses 16 équivalents ne sont pas validés. Aucune distribution ni mise en production effectuée ; attendre l’approbation pour une étape de diffusion.**
