# A11 / A12 — validation pédagogique, reprise et audio

Corrections réalisées le 24 octobre 2026. Les modifications A01–A10 déjà présentes dans le dossier de travail ont été conservées. Aucun déploiement ni changement de statut éditorial n’a été effectué.

## A11 — une session terminée ne signifie plus automatiquement une unité maîtrisée

Le Learning Core utilise désormais `LearningSession`, avec la règle de calcul version 2 :

- Aucun point au démarrage ni pour le simple passage d’un écran.
- Les exercices évalués sont la discrimination, le tracé et l’encodage au clavier. Le score d’un exercice repose sur sa première réponse ; les nouvelles tentatives permettent de progresser sans effacer cette première réponse. Le tracé conserve les deux répétitions réussies demandées auparavant, comptées comme un seul exercice.
- Le clavier propose une validation explicite. Le bouton de navigation reste désactivé tant que l’exercice évalué n’est pas résolu. Une réponse répétée ou une navigation arrière ne donne pas de points supplémentaires.
- Les pondérations de l’unité sont normalisées sur les catégories effectivement évaluées ; une catégorie absente n’accorde aucun point. Aucun score minimum artificiel de 50 % n’est appliqué.
- La maîtrise exige les exercices résolus, les étapes de contenu parcourues et un score supérieur ou égal à `minScoreToPass`. Une session sans exercice évalué ne démontre pas la maîtrise. Une session insuffisante se termine avec l’état « À réviser ».
- L’ancien écran `UnitPracticeScreen`, qui sert de consultation, ne donne plus 100 % à la fin : il clôt une consultation et ne crée aucune nouvelle maîtrise.

Le seuil est aussi vérifié par l’API pour une nouvelle complétion ; une réussite déjà enregistrée reste préservée. Le statut serveur est normalisé pour éviter `status=completed` avec `completed=False`. Le score mobile reste déclaratif : il n’est pas une certification antifraude.

### Reprise et conservation

Un checkpoint distinct conserve l’étape, la saisie en cours, les premières réponses, les tentatives et les répétitions de tracé. Les écritures de l’écran sont ordonnées pour éviter qu’une sauvegarde ancienne écrase une plus récente. Une erreur d’écriture est signalée.

Le checkpoint est associé à une empreinte stable du flux, du seuil et des pondérations. Le passage d’URL réseau à des chemins de pack ne change pas cette identité. Si les exercices changent, une nouvelle session démarre ; le checkpoint de l’ancien flux reste stocké. Recommencer une session terminée archive d’abord son checkpoint. Il n’y a pas de purge automatique de ces historiques.

Les meilleurs scores, dates de complétion et réussites historiques restent préservés, y compris lors d’un nouvel essai moins bon. Leur version de calcul n’est pas remplacée tant qu’un nouveau meilleur score n’est pas effectivement obtenu dans une session terminée. Les anciens historiques sans checkpoint détaillé ne permettent pas de reconstruire leurs réponses : ils restent conservés, mais une nouvelle session évaluée commence au début.

Les compteurs envoyés à l’API utilisent des observations réelles, en remplacement des indicateurs artificiels 0/1 : exercices répondus, premières réponses correctes, caractères et mots parcourus. Ils conservent leur maximum observé et ne constituent pas une somme exhaustive des tentatives sur toute la vie du compte. Une fusion syllabique n’est pas comptée comme une leçon entière.

### Migration locale

La migration additive `progress.0003_unitprogress_scoring_metadata` ajoute :

- `scoring_version`, par défaut 1 pour les données historiques ;
- `last_session_score`, nullable, pour garder le résultat récent distinct du meilleur score.

Elle a été appliquée **uniquement à la base SQLite locale**, après sauvegarde via l’API SQLite. La sauvegarde est `backend/db_pre_a11_20261024_535750e1.sqlite3`, ignorée par Git. Son intégrité a été vérifiée. Après migration, comparaison de toutes les valeurs des colonnes préexistantes sur **36 tables**, hors journal des migrations : identiques. `integrity_check=ok` et aucune violation de clé étrangère.

La base de production n’a pas été migrée. Avant déploiement, sauvegarder et vérifier son propre plan de migration, appliquer la migration additive, puis déployer les clients compatibles. Les anciennes applications n’envoyant pas les nouveaux champs restent acceptées.

## A12 — même sélection métier et lecture contrôlée

Le filtre de template `published_audio` appelle `get_linked_audio_url`, déjà utilisé par les sérialiseurs API et les packs : rôle exact, piste publiée, fichier présent, priorité `is_primary`, ordre éditorial, puis identifiant pour départager.

Les pages alphabet, vocabulaire, unité et quiz utilisent cette politique. Le quiz peut sélectionner une piste publiée non primaire si aucune primaire n’existe. Les audios de publication No Ena non publiés sont masqués sur le web et dans l’API. Aucun enregistrement n’a été supprimé ou republié.

Le web possède un contrôleur commun pour les boutons audio : chargement, lecture, pause, erreur et nouvelle tentative. Le libellé et les attributs accessibles suivent cet état. La lecture d’un autre audio ou d’une vidéo arrête les autres lecteurs. Les anciens gestionnaires qui créaient une nouvelle instance par clic ont été retirés.

Le lecteur Flutter expose les mêmes états, permet la pause et arrête le lecteur actif lorsqu’un autre écran lance un son. Le Learning Core affiche chargement, pause, nouvelle écoute ou erreur réessayable ; les autres écrans continuent d’utiliser le service commun, sans refonte de tous leurs composants. La fin d’un écran arrête son lecteur. Les références audio spécialisées et les références imbriquées de `core_flow` sont désormais résolues vers le dossier local du pack par le lecteur de contenu hors connexion.

Les couleurs, la police Beriya et les composants de marque sont conservés. Les étapes peuvent défiler et la barre de navigation s’adapte aux petits écrans ; une recette de widget couvre 390 × 640 pixels.

## Complément A10 — protection du cache complet

Une erreur sur une page suivante, une URL `next` non autorisée, un résultat mal formé ou l’atteinte de la limite des pages ne renvoie plus une liste partielle comme si elle était complète. `IncompleteListException` conserve les éléments acquis et indique la suite non chargée. Les services de cache existants passent alors à leur cache/packs de repli au lieu de remplacer un cache complet par cette collection tronquée.

Le schéma et l’autorité des URL suivantes sont vérifiés ; les URL relatives sont résolues par rapport à la page courante. Le cas d’un cache de vocabulaire existant est testé de bout en bout, avec vérification que sa valeur persistée reste identique après une interruption réseau. Une refonte générale de l’affichage de fraîcheur et du traitement des réponses vides (A16) reste distincte.

## Vérifications réalisées

| Contrôle | Résultat |
|---|---|
| Suite Flutter et sonde de cache | **55 tests réussis**, dont 54 tests dans `mobile/test/` et la sonde |
| Analyse statique Flutter | **Aucun problème signalé** |
| Suite Django isolée | **30 tests réussis** |
| Contrôleur audio JavaScript | **3 tests réussis** |
| Cohérence modèles / migrations | `makemigrations --check --dry-run` : aucun changement détecté |
| Migration SQLite locale | Une seule migration prévue/appliquée ; données préexistantes comparées et préservées |

Les tests supplémentaires couvrent notamment : absence de score par navigation, seuil inclusif, pondérations, deux répétitions de tracé, absence de crédit supplémentaire sur rejeu, reprise après recréation de l’écran et du stockage, changement de contenu, préservation des succès historiques, métadonnées synchronisées, lecture audio concurrente et réessayable, parité web/API/fichier de pack, et résolution des chemins audio imbriqués.

Commandes de validation, depuis la racine :

```text
backend/venv/Scripts/python.exe docs/run_backend_checks.py
node --test backend/webapp/tests_audio_player.cjs
```

Depuis `mobile/` :

```text
flutter test --no-pub test ../docs/audit_cache_probe.dart
flutter analyze --no-pub
```

Le lanceur Django utilise une base en mémoire et un stockage média temporaire, pour que les tests ne touchent pas au corpus ou aux médias de travail. Les tests Flutter utilisent des préférences simulées. Les tests JavaScript utilisent un DOM simulé, sans trafic réseau.

## Limites et recette avant diffusion

Pas d’installation de l’APK sur appareil réel, pas de validation acoustique des enregistrements, pas de déploiement. Les règles de notation et la qualité des tracés doivent être relues par les responsables pédagogiques. Les tests de lecture utilisent un lecteur simulé et ne prouvent pas la disponibilité d’un fichier distant réel.

Les archives déjà publiées sur **R2/CDN n’ont été ni inventoriées à distance ni modifiées**. L’analyse locale antérieure ne constitue pas ce contrôle. Avant diffusion, inventorier les ZIP et leurs statuts sur le stockage réellement utilisé, puis appliquer une éventuelle dépublication contrôlée après validation des responsables ; conserver les fichiers et leurs références pour récupération.

La recette restante sur appareil est : télécharger un pack validé, redémarrer en mode avion, reprendre et terminer une unité, vérifier les audios et la distinction « à réviser / maîtrisée », reconnecter puis synchroniser. Tester aussi l’échec d’une mise à jour de pack avec conservation de la version précédente. Ces opérations n’ont pas été déclarées réalisées dans ce compte rendu.
