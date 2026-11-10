# Phase 1 — Stabilisation de l’export audio

9 novembre 2026. Corrections ciblées N14/N15 autorisées par le propriétaire après audit général et complément oralité. Les six livrables et le complément audio ont servi de cadre : priorité à l’oral, Memrise comme inspiration pédagogique, Duolingo secondaire pour l’UX, deux publics distincts, aucun dessin manuscrit. Aucune refonte graphique, migration, modification du corpus, installation de dépendance ou opération de production.

## Causes racines et contrats

### N14 — Export des leçons

`backend/offline_packs/services/offline_pack_generator.py:_serialize_lessons()` était désaligné sur `Lesson` et `LessonItem` : appel de `get_linked_audio_file(lesson)` alors que `Lesson.audio_links` n’existe pas ; autres accès invalides à `cover_image`, `short_description_*` et `item.writing_hint`.

Contrat réel : introduction textuelle `oral_intro_fr/en/ar`, description, durée indicative ; sons rattachés aux **items**, via `LessonItemAudio` et ses rôles `normal`, `slow`, `prompt`, `explanation`. Les indices sont localisés `writing_hint_fr/en/ar`. `LessonSerializer`, `LessonItemSerializer` et les modèles Flutter consomment ces champs.

Correction minimale : retirer les accès aux attributs inexistants, exporter les champs réels et tous les rôles audio des items. Les anciennes clés du pack restent présentes : introduction audio/couverture nulles, descriptions courtes vides puisque sans champ source, `writing_hint` alias du champ français existant. Aucun son d’item n’est arbitrairement présenté comme une introduction de leçon. Les relations historiques numériques `character`/`word` sont conservées et complétées par `character_id`/`word_id` attendus par Flutter. Les objets liés imbriqués restent facultatifs, comme auparavant ; ce lot ne refond pas la fermeture des dépendances de packs.

### N15 — Export des quiz

`_serialize_quizzes()` cherchait `normal`, absent de `QuizQuestionAudio.ROLE_CHOICES`. Les sept types d’exercices utilisent la même relation de prompt `question` ; le type de quiz ne change pas le nom du rôle. `slow_question`, `explanation` et `correction` ont chacun leur enregistrement, sans substitution implicite.

L’ancien JSON utilisait aussi `audio_url` et `prompt_fr` alors que `QuizQuestionModel` lit `question_audio_url` et `prompt_text_fr`. Corriger seulement le rôle aurait donc encore laissé le son inaccessible dans ce lecteur Flutter.

Correction : rôle `question` pour le prompt ; copie séparée des trois autres rôles ; réutilisation de `QuizQuestionSerializer` pour les clés canoniques/textes/réponses déjà consommés par Flutter, puis remplacement des URL média par chemins de pack. Les images de question/options sont copiées pour ne pas introduire des URL réseau depuis le sérialiseur. Les anciennes clés et données d’options du pack sont conservées. `correction_audio_url` est conservé dans le ZIP mais n’a pas de commande dédiée dans le modèle/écran Flutter actuel : aucune nouvelle interface n’est annoncée.

### Dépendances et effets secondaires

Web/API : aucun template, vue, modèle, URL ou sérialiseur API modifié. Le filtre de publication et la priorité des sons restent ceux de `audio_assets.utils`; les brouillons audio ne sont pas exportés. Le web et l’API continuent de fonctionner avec leurs contrats existants.

Flutter : aucun fichier métier modifié. Le lecteur de packs et `OfflineMediaResolver` savent déjà résoudre les champs suffixés `_audio_url`, y compris les consignes/explications des items. Les champs ajoutés au ZIP sont additifs, schéma 2 conservé ; les alias historiques restent lisibles. Les anciens packs ne sont pas réécrits et doivent être régénérés séparément en version nouvelle si leur défaut doit être corrigé.

Effets possibles : ZIP plus volumineux lorsqu’une leçon/quiz possède des variantes lentes, consignes ou explications ; texte/score de quiz désormais présent sous les clés attendues ; absence de son représentée par `null` si non lié, non publié ou introuvable. Le helper existant retourne `null` en cas d’échec de copie, sans diagnostic détaillé dans le manifeste : ce comportement est conservé, pas présenté comme validation de complétude pédagogique.

## Tests avant/après réellement exécutés

Base **en mémoire**, fichiers médias **temporaires**, stockage local isolé. Les WAV de test sont des silences synthétiques avec durées distinctes par rôle : aucun contenu linguistique ni voix artificielle.

| Exécution | Résultat |
|---|---|
| Avant modification du générateur : nouveau module `offline_packs.tests_audio_export` | 5 tests exécutés, 5 erreurs : blocage Lesson.audio_links et clés canoniques absentes |
| Avant correction : reproduction ciblée du quiz, assertion sur `audio_url` | 1 test exécuté, échec `unexpectedly None` malgré enregistrements `question` présents |
| Après correction : module ciblé enrichi | 6/6 réussis, 0,673 s ; sept types de quiz et quatre rôles audio couverts |
| Suite Django complète `docs/run_backend_checks.py` | **65/65 réussis**, 15,407 s, contrôle système sans anomalie |
| Suite Flutter complète `flutter --no-version-check --suppress-analytics test --no-pub` | **72/72 réussis**, compteur final ~9 s |
| Analyse Flutter `flutter --no-version-check --suppress-analytics analyze --no-pub` | **Aucune anomalie**, 7,2 s |
| `node --test backend/webapp/tests_audio_player.cjs` | **3/3 réussis**, code 0 |

Les suites complètes de référence avant ce lot, exécutées dans cette même session d’audit, comptaient 59 backend / 70 Flutter / 3 JS. Les cas de reproduction nouveaux démontrent précisément ce qui leur manquait ; ne pas interpréter leurs anciennes réussites comme une couverture de N14/N15.

Les tests ajoutés vérifient :

- Génération complète du ZIP avec leçons, items et quiz ; CRC ZIP, SHA-256 et taille du pack ; chaque chemin de manifeste présent et non vide.
- Parité des champs utiles avec les sérialiseurs existants, dont indices, introductions, répétitions, bonne réponse et index de correction.
- Correspondance des octets copiés avec les fichiers sources pour chaque rôle ; métadonnées AudioAsset inchangées après génération.
- Enregistrements absents, fichiers manquants, brouillons et fallback publié non primaire ; anciennes leçons vides et sans audio ; exclusion des leçons brouillon et items inactifs.
- Installation Flutter d’une archive réellement générée par Django, contrôle du checksum, fermeture du client HTTP simulé puis lecture via de **nouvelles instances** de lecteur/service local. Les chemins des sept sons exploités par les modèles conduisent à des fichiers WAV locaux accessibles.
- Ancienne leçon JSON dépourvue de médias toujours désérialisable ; tests existants du lecteur audio pour erreur et média local absent.

Le redémarrage de lecteurs de test n’est pas un redémarrage Android physique. Aucun test de décodage sur matériel, qualité perceptive, autorisations de diffusion, R2 réel, build APK ou déploiement exécuté. La portée « hors ligne » ici est l’installation simulée puis le chargement de données/fichiers locaux sans appel réseau supplémentaire.

## Fichiers de ce lot

| Fichier | Modification |
|---|---|
| `backend/offline_packs/services/offline_pack_generator.py` | Seul fichier métier modifié : corrections et compatibilité JSON/media |
| `backend/offline_packs/tests_audio_export.py` | 6 tests de contrat et export complet ; génération optionnelle de fixture |
| `mobile/test/audio_export_contract_test.dart` | 2 tests de lecture Flutter/ancienne leçon |
| `mobile/test/fixtures/audio_export.zip` | Archive de silence synthétique issue du générateur corrigé |
| `mobile/test/fixtures/README_AUDIO_EXPORT.md` | Provenance/régénération de la fixture |
| `docs/PHASE1_AUDIO_2026-11-09.md` | Ce rapport |
| `docs/PILOTE_A_AUDIO_2026-11-09.md` | Proposition pédagogique et ressources manquantes |

L’état initial comportait déjà trois `.pyc` modifiés et les livrables/sondes d’audit non suivis. Ils ne sont pas des changements métier de ce lot et ne doivent pas être annulés par un reset global.

Empreinte de `backend/db.sqlite3` à la fin identique à celle du complément audio précédent : `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b`. Aucun seed ni migration de cette base exécuté. Les fichiers réels du corpus ne sont pas utilisés comme destinations des tests. Aucune archive de production régénérée/remplacée.

## Risques et étapes restantes

N14/N15 sont corrigés et validés dans le périmètre local testé. La couverture audio, l’authenticité, les licences et consentements demandent encore validation humaine. Les historiques/propriétés de progression N01/N02 et la validation N03 restent hors de ce lot : ce résultat n’est pas un feu vert de publication générale.

Un son `null` est un état technique valide, pas une leçon orale prête. Le pilote doit attendre son corpus. Les anciens ZIP publiés ne deviennent pas corrigés par modification du générateur ; préparer des versions nouvelles, tester, puis activer séparément avec sauvegarde. Le générateur parallèle à la racine du dépôt reste intact ; le chemin corrigé est celui importé par Django sous `backend/`.

## Retour arrière

Avant intégration, conserver le diff de ce lot et son commit de départ `3081aff1b90fade719bc84e22efc1a3dc974523b` ; le générateur était sans modification locale à l’ouverture de cette phase. Restaurer **uniquement** sa version antérieure si nécessaire (ou révoquer le futur commit dédié). Garder les tests comme preuve des échecs attendus sur l’ancien code. Aucun rollback DB n’est nécessaire : schéma et données inchangés.

Si des packs sont publiés plus tard, conserver chaque ancienne archive et activer une nouvelle version plutôt que réécrire une archive installée. En cas d’incident, rétablir la version précédente du catalogue/pack sans supprimer les progressions ni les téléchargements utilisateurs. Cela ne corrige pas les défauts de l’ancien export : bloquer la publication du nouveau pack en échec jusqu’à correction. Ne pas utiliser `git reset --hard`, une purge de médias ou une désinstallation mobile comme procédure de retour arrière.
