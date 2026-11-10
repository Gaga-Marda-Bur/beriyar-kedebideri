# Phase 6.2 — Rendu Erfe Django / Flutter

10 novembre 2026. Branche `codex/phase6-2-erfe-typography`.
Checkpoint documentaire : **4cb8708** (`docs(phase6.1): checkpoint audit valide et preuves typographiques`).
Les corrections ci-dessous sont locales et testées ; aucune publication ni activation commerciale.

## Résultat et périmètre

Le titre Django réel de l’unité 2 affiche désormais U+16EB5 avec Kedebideri chargée
par HTTP. Chrome confirme une police personnalisée Kedebideri pour le glyphe et
Segoe UI pour le latin. Sur le **Samsung SM-A336E, Android 16**, les captures
comparatives de composants réels montrent la disparition des rectangles pour
les deux titres, les 50 caractères, les cinq voyelles à macron et les textes mixtes.

Le choix retenu réutilise la cascade CSS, les deux thèmes Flutter et les styles
centraux existants. Aucun nouveau widget pédagogique ni moteur de segmentation
des réponses n’est ajouté. Les 50 caractères assignés sont ceux de **Unicode 17.0**.
La présence de glyphes et leur affichage ne valent pas validation linguistique
par des locuteurs ; aucun mot ni traduction n’a été inventé ou corrigé.

## Préservation et checkpoint

Au départ : seuls le rapport Phase 6 et `docs/phase6_reprise/` étaient non suivis.
Leur manifeste a été vérifié avant commit ; ces huit fichiers ont été commités
séparément. Aucun secret, SQLite, média utilisateur, APK temporaire ou clone de
recette n’y figure. `.gitattributes` protège ensuite les octets des preuves
documentaires contre la conversion automatique des fins de ligne ; les copies
d’audit de la copie de travail restent identiques à leurs empreintes initiales.

`phase6_2/verify_final.py` contrôle la stabilité des six binaires Kedebideri, du
manifeste validé et de la base source :
`2684f6ce3662fa7f3e771258887c3e48e76b72362a271598f25d1599f92b3543` avant/après.
Le serveur QA ouvre cette SQLite en **lecture seule** ; ses sessions utilisent
des cookies signés uniquement dans le processus de recette. Aucun réglage du
backend livré n’est changé pour la recette. Aucun accès à Render/R2 effectué.

## Défauts confirmés et corrections

| Défaut | Preuve avant | Correction | Validation après |
|---|---|---|---|
| Titres web sans sélection de Kedebideri | Capture locale réelle + Chrome CDP : uniquement Segoe UI pour le titre contenant 𖺵 | CSS Erfe partagée avec famille `BK Erfe` limitée aux plages Erfe et marques couvertes ; six graisses ; filtre `render_erfe` sur les textes mixtes principaux | HTTP 200, Kedebideri-Bold effectivement utilisée pour le glyphe, latin conservé ; capture réelle de la même route |
| Admin : aperçu en erreur | Test du vrai `LearningUnitAdmin.core_flow_preview` : TypeError de `format_html(html)` sans argument | `format_html` et `format_html_join` avec arguments ; chaque valeur dynamique échappée et balisage Erfe réutilisé | Test de rendu réussi, chaînes `<script>` et `<img>` échappées ; template Admin charge la CSS partagée |
| Styles Flutter latins sans fallback | 2 tests en échec ; captures Samsung avec rectangles dans titres, label d’option, grille et texte mixte | `fontFamilyFallback` sur les deux thèmes et styles `latin*`, six graisses déclarées dans pubspec ; saisie partagée en Roboto avec fallback Erfe | Captures Samsung clair/sombre sans rectangles sur cette planche ; 4 tests ciblés de styles et petite taille |
| Détection JS limitée aux majuscules | Deux tests exécutés sur les fonctions du checkpoint échouent pour les minuscules | Ajout de la plage assignée U+16EBB..U+16ED3 dans clavier et Sticker Studio | Deux tests des fonctions actuelles réussissent sur les 50 caractères et rejettent le point réservé ; table de clavier inchangée |
| PDF Flutter sans ř | Export natif avant : avertissement « Unable to find a font to draw ř » ; PDF conservé | Fontes Noto Latin/Arabic en fallback PDF, Kedebideri inchangée | Export natif après sans cet avertissement ; PDF rendu avec Poppler et inspecté : ř, Erfe et macrons visibles |
| PDF web : caractères mixtes manquants / marques déplacées | Choix de police unique identifié ; décalage des marques constaté sur le premier export de recette après fallback | Sélection par grappe de caractères, priorité Noto hors Erfe ; positions GPOS de Kedebideri appliquées lors du dessin Erfe | Export depuis le vrai bouton de l’éditeur, téléchargement réussi, PDF régénéré et inspecté avec macrons attachés |

Le filtre Django échappe même les entrées préalablement marquées sûres. Les
chaînes stockées et les valeurs de formulaire restent inchangées. Les `<title>`
HTML et attributs de données ne reçoivent pas de `<span>`. Les runs Erfe ont
`dir="ltr"` et `unicode-bidi: isolate` ; le latin et l’arabe conservent leur police.

Les définitions `@font-face` utilisent les fichiers TTF existants ; `BK Erfe`
possède un `unicode-range` restreint. Kedebideri ne devient donc pas la police
latine/arabe globale. L’Admin garde sa famille primaire habituelle hors Erfe.
Les six URLs ont été demandées avec succès dans Chrome ; le serveur statique QA
Windows annonce `application/octet-stream`, accepté ici par le navigateur qui
utilise effectivement les glyphes. Le MIME/CSP/CDN de production n’a pas été testé.

## Écrans Flutter inspectés et portée de la centralisation

- Leçons et parcours : textes héritant du thème, `BkLearningNode`, styles purs
  Erfe dans `learning_core_unit_screen`, `syllable_fusion_widget` et parcours.
- Alphabet et dictionnaire : styles `AppTextStyles.beriya*` déjà dédiés aux glyphes ;
  descriptions/éléments mixtes bénéficient du fallback du thème.
- Quiz et SRS : styles Erfe existants et labels/options héritant du thème,
  `BkOptionCard`, `srs_review_session_screen` ; aucune logique de score modifiée.
- Clavier : données, touches et suppression inchangées ; seul le style du champ
  partagé permet au latin/arabe de rester dans la police système et à l’Erfe de
  sélectionner Kedebideri.
- Packs hors ligne et feedback : leurs titres/instructions héritent du thème ;
  aucun format de pack, stockage, progression, feedback métier ou synchronisation
  modifié. Les fontes supplémentaires sont embarquées dans les assets existants.

Cette inspection et les tests globaux ne constituent pas une nouvelle recette
humaine de chacun de ces écrans. Les captures physiques utilisent une **planche
QA**, avec les vrais `AppTheme`, `AppTextStyles`, `BkLearningNode`, `BkOptionCard`
et le vrai exporteur PDF ; elles ne sont pas présentées comme des captures de
tous les parcours complets de l’application.

## Diacritiques, mélange des scripts et petites tailles

Les cinq séquences de voyelles longues testées proviennent des tables de clavier
existantes web et Flutter : U+16EA0/U+16EA3/U+16EA7/U+16EAF/U+16EB6 + U+0304.
Aucune séquence n’est ajoutée aux données. Le relevé limité des colonnes SQLite
inspectées n’a trouvé aucune combinaison Erfe + marque ; cela ne prouve pas leur
absence de tous les médias ou fichiers. `RESULTS.json` distingue ce relevé des
séquences réellement définies par le clavier.

Les tests du filtre vérifient aussi le transport intact des 50 caractères avec
marque ; il s’agit d’un stress test typographique, pas de 50 formes linguistiques
validées. Le code couvre les marques présentes dans Kedebideri : U+0300, U+0301,
U+0304, U+0307, pas les marques U+0302/U+0303 absentes de la police.

Recette : Chrome à **390×844**, grille des 50 caractères sur six graisses ; Samsung
en clair/sombre, textes `Beřiya`, arabe de contrôle et Erfe en contexte LTR/RTL ;
tests widgets **320×568**, deux thèmes et deux directions, sans exception de layout.
La sortie physique ne montre pas de rectangles ni de macrons coupés dans la
planche inspectée. Aucun ajout de contrôles bidi aux réponses ou aux données.

## Tests exécutés

| Contrôle | Avant | Après final |
|---|---|---|
| Django typographie | 4 méthodes en erreur, dont aperçu réel ; les 50 sous-tests du nouveau filtre signalaient son absence | **5 tests réussis**, y compris template Admin et échappement |
| Flutter typographie | **2 tests échoués** (fallback absent) | **4 tests réussis**, dont petite taille clair/sombre LTR/RTL |
| Suite backend globale | Référence historique, non rejouée avant cette correction | **99 tests réussis**, 21,060 s du runner, SQLite de test en mémoire détruite à la fin |
| Suite Flutter globale | Référence historique, non rejouée avant cette correction | **130 tests réussis**, dont tests packs, cache, sessions, synchronisation et SRS existants |
| JavaScript audio et détection Erfe | 2 tests de détection échoués sur les fonctions extraites du checkpoint | **5 tests réussis**, dont 3 audio et 2 de détection (`tests_audio_player.cjs`, `tests_typography.cjs`) |
| Analyse Flutter finale | Première passe : import inutilisé et accolade manquante de style, corrigés | **No issues found**, 11,0 s |
| Android physique | 1 test natif de planche réussi mais défauts visuels et avertissement PDF observés | 1 test natif réussi, deux captures et PDF collectés ; aucun avertissement ř après correction |
| Web | HTTP 200 sur snapshot des templates/CSS au checkpoint ; défaut observé | HTTP 200 sur source corrigée, polices réelles inspectées par CDP ; export PDF téléchargé |
| Intégrité | Manifeste et empreintes initiaux relevés | Base, six polices Kedebideri et huit livrables de reprise inchangés |

Commandes et scripts : `docs/run_backend_checks.py`,
`flutter test --no-pub`, `flutter analyze --no-pub`,
`node --test backend/webapp/tests_audio_player.cjs backend/webapp/tests_typography.cjs`,
`phase6_2/capture_web.cjs`, `phase6_2/typography_android_test.dart`,
`phase6_2/collect_phone.py`, `phase6_2/verify_final.py`.
Les logs bruts restent dans `phase6_2/runtime/` ignoré, sans intégration au commit.
Les preuves partageables et leurs empreintes sont dans `phase6_2/captures/` et
`phase6_2/RESULTS.json`.

La première tentative HTTP a échoué parce que la session Django essayait
d’écrire dans la base RO. Le serveur QA utilise ensuite des sessions signées sans
écriture SQLite ; l’échec de préparation est conservé uniquement dans runtime,
pas comme capture avant valide. Les captures avant valides utilisent les vrais
templates/CSS du checkpoint extraits par `git archive`, avec le même corpus RO.

## Captures et exports consultables

| Plateforme | Avant | Après |
|---|---|---|
| Django, vraie unité 2 | [Page avant](phase6_2/captures/django_before.png) | [Page après](phase6_2/captures/django_after.png) |
| Samsung, planche claire | [Avant](phase6_2/captures/phase62_before_light.png) | [Après](phase6_2/captures/phase62_after_light.png) |
| Samsung, planche sombre | [Avant](phase6_2/captures/phase62_before_dark.png) | [Après](phase6_2/captures/phase62_after_dark.png) |
| PDF export Flutter natif | [Avant](phase6_2/captures/phase62_before.pdf) | [Après](phase6_2/captures/phase62_after.pdf) |

[Grille web six graisses](phase6_2/captures/web_grid_after.png),
[export web après](phase6_2/captures/web_export_after.pdf),
[rendu PDF web](phase6_2/captures/pdf_web_after.png),
[rendu PDF Flutter](phase6_2/captures/pdf_flutter_after.png).
[Éditeur mixte après](phase6_2/captures/editor_mixed_after.png) et
[export PNG réel](phase6_2/captures/web_image_export_after.png) : le bouton
d’export image a aussi été exécuté et le résultat inspecté, avec latin, arabe,
Erfe et les cinq macrons.
Ces images sont des sorties réelles de recette, pas des maquettes.

## Fichiers modifiés, ressources et compatibilité

Liste exhaustive : `phase6_2/FILES_CHANGED.txt` (chemins relatifs au dépôt).
Groupes métier modifiés :

- Django : CSS `erfe.css`, inclusion dans `base.html`, surcharge Admin
  `admin/base_site.html`, filtre `web_i18n.py`, templates parcours/unité/quiz/No Ena,
  aperçu `learning/admin.py`, détections JS clavier/Sticker Studio et PDF éditeur.
  Les champs de l’éditeur (`beriya_editor.css`), entrées `.beriya-input` et textes
  canvas de l’éditeur/Sticker Studio utilisent aussi la famille restreinte
  `BK Erfe` afin de conserver les fontes latines/arabes sur les chaînes mixtes.
- Flutter : thèmes/styles partagés, déclaration des graisses dans `pubspec.yaml`,
  style du champ `BeriyaTextField`, fallback de `BeriyaPdfService`.
- Tests : `webapp/tests_typography.py`, `mobile/test/erfe_typography_test.dart` ;
  scripts et preuves documentaires de recette.
- Fontes PDF : NotoSans-Regular **569 208 octets** et NotoSansArabic-Regular
  **240 456 octets**, mêmes octets web/mobile, licence **SIL OFL** conservée.
  Sources officielles : dépôt `notofonts/noto-fonts`, chemins
  `hinted/ttf/NotoSans/NotoSans-Regular.ttf`,
  `hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf`, licence racine `LICENSE`.
  Leur ajout représente **809 664 octets non compressés par plateforme**, et non
  une mesure de taille APK. Aucun package applicatif supplémentaire.

Aucun modèle, migration métier, serializer, endpoint, traduction, caractère,
table de clavier/translittération ou algorithme pédagogique n’est modifié.
Pas de modification des packs déjà générés ni de leurs checksums. Les migrations
du runner ne concernent que sa base jetable, pas les bases existantes.
`integration_test` n’est ajouté qu’au clone ignoré, identifiant Android distinct
`com.afrigama.beriyarkedebideri.qa62`, sans clé de signature de production.
Toutes les installations de test utilisent `--no-uninstall` ; aucune application
habituelle ni donnée existante n’a été effacée.

## Limites et risques résiduels

- La mise en forme arabe a été observée sur une courte chaîne UI et un court
  export web ; ce n’est pas une validation complète UAX#9, ni une recette de tous
  les paragraphes PDF arabes. Le PDF Flutter exporté ici teste Erfe/latin/ř/macrons,
  pas un long paragraphe arabe. Aucune garantie universelle de bidi/extraction PDF.
- Les exports web nécessitent un navigateur prenant en charge `Intl.Segmenter`,
  `fontkit` local et les fontes HTTP ; les très vieux navigateurs ne sont pas
  recettés. Les erreurs de téléchargement restent visibles, sans substitution
  linguistique ni remplacement par des images.
- L’Admin est validé par appel réel de l’aperçu et rendu de son template, pas par
  une navigation staff authentifiée complète avec capture avant/après de l’Admin.
- TalkBack, tailles de police extrêmes, plusieurs constructeurs Android, build
  release signé, performances mémoire et médias CDN ne sont pas recettés ici.
- Aucun nouveau scénario mode avion/téléchargement/synchronisation physique
  complet ; les fontes de la planche et du PDF natif proviennent des assets
  embarqués, les suites de non-régression hors ligne existantes sont vertes.
- Staging, uploads et autres risques de sécurité du rapport Phase 6 restent
  ouverts hors correctif Admin explicitement autorisé. Aucune publicité, aucun
  paiement, aucun déploiement ni migration sur production.

## Retour arrière et décision Phase 6.3

Revenir au checkpoint documentaire **4cb8708** pour le code, en conservant une
archive des preuves de cette phase. Après commit, préférer `git revert` du commit
de correction sur une branche de retour, puis tests et recette. Aucune migration
inverse ni restauration de données n’est nécessaire. Conserver l’APK QA et les
captures tant que la revue est en cours ; ne pas désinstaller l’application
habituelle. Le clone de test peut rester installé et ses données sont conservées.

**GO technique pour soumettre la Phase 6.3 à validation** : le blocage typographique
reproduit sur les titres web et les composants mobiles est corrigé dans le
périmètre testé et les suites de non-régression sont vertes. **Aucune autorisation
d’exécuter Phase 6.3 n’est déduite de cette décision. NO-GO pour production ou
activation commerciale** sans les lots distincts et leurs validations. La revue
humaine des captures et les limites PDF/RTL doivent accompagner la décision.
