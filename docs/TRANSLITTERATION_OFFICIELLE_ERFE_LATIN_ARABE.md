# Moteur officiel Erfe ↔ Latin ↔ Arabe — 12 novembre 2026

## Résultat et périmètre

Implémentation locale sur `codex/official-erfe-transliteration`, issue de `48a2783` (`integrate/historical-tools-final`). Le dépôt était propre avant cette intervention. Aucune reprise des anciens lots commerciaux : leur code reste inchangé. Aucun déploiement, publication, migration, paiement ni SDK publicitaire.

La source fournie est conservée, sans changement de correspondances, dans `shared/linguistics/beriya_erfe_transliteration_mapping.json`. Les tables des trois plateformes sont générées par `scripts/generate_transliteration.py`, et non maintenues séparément à la main. `.gitattributes` préserve les octets du JSON entre les systèmes.

## Source linguistique vérifiée

Le classeur a été retrouvé au chemin communiqué par l’utilisateur : `C:\Users\MONSTER\Desktop\Beriya\ABH\erfe.xlsx`. Son nom diffère du nom `erfe(1).xlsx` déclaré dans le JSON, mais son contenu binaire correspond exactement à l’empreinte déclarée :

`82b1993b9a6b79422b909e2e8b5a90ba918a980566da49a65051a670905f711e`.

Lecture des XML internes du XLSX en lecture seule : **25 lignes canoniques et 25 variantes minuscules concordantes**. Aucun réenregistrement du classeur. Preuve : `transliteration/source_verification.json`. Vérification reproductible :

```powershell
backend/venv/Scripts/python.exe scripts/verify_transliteration_source.py 'C:/Users/MONSTER/Desktop/Beriya/ABH/erfe.xlsx'
backend/venv/Scripts/python.exe scripts/generate_transliteration.py --check
```

Les cas sensibles restent stricts : `A → ا`, `E → آ`, `G → ق`, `I → ی` (U+06CC), `Y → ي` (U+064A), ainsi que Ɲ, Ŋ, Ř et Š. Aucune normalisation arabe approximative, aucun ajout de lettre ou traduction.

## Contrat du moteur

| Opération | Python | Web JavaScript | Flutter/Dart |
|---|---|---|---|
| Normalisation | `normalize_erfe(text)` | `BKTransliteration.normalize_erfe(text)` | `normalizeErfe(text)` |
| Conversion explicite | `transliterate(text, source_script, target_script, latin_lowercase=False)` | `transliterate(text, source, target, latinLowercase=false)` | `transliterate(text, WritingScript.source, WritingScript.target, latinLowercase: false)` |

Scripts autorisés : `erfe`, `latin`, `arabic`. Aucune détection automatique. Latin ↔ arabe passe par la table Erfe canonique. Les variantes minuscules Erfe sont normalisées dans toutes les directions. Le latin est produit en majuscules, ou dans les minuscules exactes du référentiel sur demande.

Une conversion renvoie `{text, unmapped}` ; Dart expose un `TransliterationResult`. Chaque élément non couvert indique `character`, `codepoint`, `index`. L’index compte les points de code de l’entrée après NFC et normalisation Erfe, pas les unités UTF-16 ni les graphèmes. Les espaces, nombres et ponctuations restent présents sans avertissement ; les autres caractères non couverts restent présents et sont signalés. La classification non linguistique de ces caractères est elle aussi générée pour éviter les différences entre plateformes.

Exemples testés :

```text
normalize_erfe("𖺻𖺼𖺽")                  → 𖺠𖺡𖺢
transliterate("ABD", latin, erfe).text     → 𖺠𖺡𖺢
transliterate("ابد", arabic, erfe).text    → 𖺠𖺡𖺢
transliterate("𖺠𖺡𖺢", erfe, latin).text   → ABD
transliterate("𖺠𖺡𖺢", erfe, arabic).text  → ابد
transliterate("یي", arabic, latin).text   → IY
```

API **additive**, sans changement des endpoints existants : `POST /api/core/transliterate/`, avec `text`, `source_script`, `target_script`, et `latin_lowercase` facultatif. Elle ne sauvegarde rien, accepte le texte vide et les espaces, limite l’entrée à 100 000 caractères et refuse les scripts invalides par HTTP 400. Les éditeurs utilisent le moteur local, donc ne dépendent pas de cet endpoint ni d’une connexion.

## Intégrations et conservation

| Point | Comportement ajouté | Conservation |
|---|---|---|
| Django, nouvelles écritures de contenu | Normalisation avant `save`, limitée aux champs texte contenant de l’Erfe dans alphabet, vocabulary, learning, lessons, quizzes, no_ena | Un champ historique inchangé n’est pas réécrit ; `update_fields` respecté ; fixtures brutes ignorées |
| Dictionnaire et alphabet, administration | Formulaire normalisant les champs modifiés avant validation ; outils de conversion des transcriptions | Pas de génération automatique de traduction/transcription, validation éditoriale inchangée |
| Alphabet | Cohérence du code Unicode lors d’un nouveau symbole normalisé ; refus des collisions canoniques | Pas de fusion ni suppression des anciennes fiches minuscules |
| Web, clavier et champs marqués Erfe | Normalisation frappe/collage ; sélection conservée ; transaction native pour les insertions du clavier | Dispositions et outils historiques conservés |
| Éditeur et Sticker web | Choix source/cible, résultat, copie, insertion explicite et annulation ; résultats arabes RTL | Contrôles repliables, exclus de l’impression ; export PNG/PDF lit du texte normalisé |
| Flutter, champs et clavier partagé | Formatter de saisie/collage, normalisation des insertions programmatiques, mapping des positions UTF-16 après NFC | Composition IME différée jusqu’à validation, sans conversion automatique latin/arabe |
| Flutter, éditeur et Sticker | Action `Erfe | Latin | Arabe`, conversion de la sélection ou du texte entier, copie, insertion et annulation | Les textes gratuits et styles existants restent accessibles |
| Brouillons et PDF Flutter | Normalisation des nouvelles sérialisations et du texte remis au service PDF | Lecture du stockage historique inchangée ; affichage du brouillon normalisé dans l’éditeur, sans réécriture automatique à la lecture |
| Apprentissages et quiz | Saisie canonique ; comparaison normalisée des deux côtés | Ancienne réponse attendue minuscule compatible, sans assouplir les accents ou accepter une autre lettre |
| Recherche du dictionnaire | Comparaison Erfe canonique côté serveur et hors ligne | Pas de réécriture des mots, API et cache conservés ; requêtes latines sans les 25 remplacements SQL |
| Import/export de textes UTF-8 | CLI `scripts/convert_erfe_text.py` ; normalisation par défaut, conversion seulement avec source/cible explicites | Refus d’écraser une sortie existante ; CRLF, espaces et caractères supplémentaires conservés |

La liste exhaustive des fichiers se trouve dans `transliteration/files_changed.json`.

## Reproductions et validations exécutées

| Contrôle | Avant intégration | Après |
|---|---|---|
| Suite Django | 161 tests, OK, 2 ignorés | 169 tests, OK, 2 ignorés |
| Création / modification de mot Erfe minuscule | Deux tests échouent : minuscules sauvegardées | Tests réussis, historique inchangé conservé |
| API de conversion | Test échoue : HTTP 404 | HTTP 200, conversion exacte ; script invalide HTTP 400 |
| Réponse canonique face à l’attendu historique minuscule | Test Flutter échoue | Test réussi ; réponse avec diacritique différent toujours refusée |
| Suite Flutter | 161 tests réussis | 167 tests réussis |
| JavaScript | Audio et typographie historiques inclus dans la non-régression | 7 tests réussis au total |
| Parité | Aucune infrastructure commune | **315 vecteurs partagés** vérifiés dans chacun des trois moteurs |
| Navigateur Chrome réel | Sans commandes de conversion | 7 scénarios réussis, aucune erreur JavaScript |
| Import/export CLI | Sans utilitaire central | Normalisation, CRLF, caractère supplémentaire et refus d’écrasement vérifiés |
| Analyse Flutter | 1 avertissement existant constaté avant intégration | Le même avertissement uniquement ; aucun nouveau diagnostic |

Les 315 vecteurs comprennent chaque lettre dans toutes les directions, les entrées minuscules, la sortie latine minuscule, les retours LF/CRLF, les nombres, la ponctuation, NFC, les caractères inconnus et supplémentaires. Des tests supplémentaires vérifient les allers-retours, le collage, la sélection UTF-16, la composition, l’insertion et l’annulation, la recherche hors ligne et la conservation du cache et des statuts pédagogiques.

L’avertissement préexistant concerne `mobile/integration_test/historical_tools_final_qa_test.dart:8` : import `path_provider` inutilisé. Il est déjà présent dans `48a2783`. Il n’a pas été supprimé dans ce lot pour ne pas modifier un test de recette sans rapport avec la translittération. L’analyse complète retourne donc un code non nul pour cet avertissement ; elle n’est pas annoncée comme entièrement sans anomalie.

Environnement : Windows, Python 3.13.5, Django 6.0.10, Flutter 3.44.1, Dart 3.12.1, Node avec Unicode 16.0. Bibliothèque ajoutée : `unorm_dart 0.3.3`, nécessaire pour NFC non fourni par les chaînes Dart ; bibliothèque pure Dart, sans SDK commercial ni service distant. [Documentation du paquet](https://pub.dev/packages/unorm_dart).

Journaux : `transliteration/django_after.log`, `flutter_before.log`, `flutter_reproduction.log`, `flutter_after.log`, `flutter_targeted_final.log`, `flutter_analyze.log`, `javascript_after.log`. Résultats structurés : `test_results.json`, `browser_results.json`, `import_export_results.json`, `source_verification.json`, dans le même dossier.

## Preuves visuelles et limites de recette

Chrome headless exécute de vraies interactions DOM contre Django local et une copie SQLite anonymisée. Le script `transliteration/browser.cjs` vérifie : lecture d’un brouillon historique sans réécriture, chargement de la police et des scripts, collage multiligne, annulation native, conversion de sélection, insertion et annulation explicite, clavier Erfe, arabe strict RTL, signalement d’un emoji, presse-papiers, écran 390 px sans débordement, Sticker. Captures :

- `transliteration/web_erfe_conversion.png` : résultat Erfe avec sélection CSS Kedebideri vérifiée.
- `transliteration/web_converter_desktop.png` et `web_converter_mobile.png` : conversion arabe.
- `transliteration/web_sticker.png` : saisie canonique dans le Studio.

Ces captures ont été inspectées. Les tests widgets Flutter valident le dialogue et son comportement ; **ce ne sont pas des tests Android physiques**. `adb devices -l` ne détecte aucun appareil. Aucune nouvelle installation APK ni distribution. La recette du clavier système/IME Android, du presse-papiers et des polices sur téléphone reste à effectuer après disponibilité de l’appareil. Pas de nouvelle validation visuelle PDF physique dans ce lot ; le service PDF existant fait partie de la suite Flutter et reçoit désormais le texte canonique.

## Cas non couverts et risques résiduels

1. Le référentiel décrit 25 lettres, pas toutes les voyelles accentuées ni tous les signes phonétiques. `A` + macron devient `Ā` sous NFC ; `Ā` n’a pas de correspondance fournie et reste signalé. Erfe A + macron reste conservé, le signe non couvert est signalé ; la sortie latine NFC peut se composer en `Ā`. **Ne pas promettre l’aller-retour de ces séquences hors référentiel.**
2. C, Q, V, X, Z et les formes arabes de présentation non fournies ne sont pas déduits. Un texte mixte ne convertit que les lettres du script source choisi ; les autres lettres sont conservées et signalées.
3. Les tables de classification communes sont générées avec Unicode Python 15.1. Les bibliothèques NFC des moteurs utilisent des versions différentes (Python 15.1, Node 16, paquet Dart annonçant Unicode 18). La parité est prouvée pour les vecteurs du référentiel et cas testés, pas pour chaque séquence Unicode possible hors référentiel.
4. `bulk_create`, `bulk_update`, `QuerySet.update`, SQL brut et `loaddata` ne déclenchent pas la normalisation du signal. Les imports de textes doivent utiliser l’utilitaire ou appeler `normalize_erfe` avant ces opérations. Aucun import brut existant n’est réécrit à l’aveugle ; les nouveaux imports devront respecter ce contrat.
5. La composition IME active est préservée et NFC est différé jusqu’à sa validation. Chrome et tests Flutter vérifiés ; autres navigateurs et claviers Android restent à recetter. L’insertion native emploie `execCommand` avec fallback ; les navigateurs qui ne le prennent plus en charge conservent l’annulation explicite de conversion, mais l’annulation native doit y être vérifiée.
6. Une annulation explicite ne doit pas écraser des modifications effectuées après insertion : elle est protégée par comparaison du texte courant. Le navigateur signale une modification ultérieure ; utiliser alors l’historique d’édition.
7. La recherche historique Erfe utilise 25 remplacements SQL sans modifier les données. Sa correction est testée sur SQLite ; aucune mesure de charge PostgreSQL ni migration de production n’a été réalisée dans ce lot.

## Données, compatibilité et retour arrière

SHA-256 de `backend/db.sqlite3` observé avant/après :
`7fe288b82f0539166d8008b89725f27db490805d9b07542f469c816f5c219d03`.

La base est inchangée. Aucun pack ni police modifié, aucune modification de progression ou de monétisation, aucune traduction générée et aucun statut de validation modifié. Django a été testé sur base mémoire et médias temporaires ; le navigateur sur une copie anonymisée ignorée par Git, jamais sur une base de production. La table `files_changed.json` permet de contrôler ce périmètre.

Retour arrière : utiliser `git revert <commit-de-ce-lot>` sur un arbre propre, puis `flutter pub get` et les suites de tests. Pas de migration inverse ni restauration de données nécessaire pour cette intervention locale. Des nouveaux textes qui auraient ensuite été saisis en majuscules resteraient des données linguistiques légitimes : aucun script de décapitalisation automatique n’est fourni. La base historique n’ayant pas été convertie en masse, ses variantes restent présentes.

**GO pour revue de cette implémentation locale. Distribution suspendue à l’approbation de l’utilisateur.** La recette Android physique et les limites hors référentiel ci-dessus restent explicites ; aucun déploiement ni distribution ne découle de ce rapport.
