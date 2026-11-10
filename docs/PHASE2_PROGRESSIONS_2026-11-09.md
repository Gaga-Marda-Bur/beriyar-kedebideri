# Phase 2 — Propriété des progressions utilisateur

9 novembre 2026. Correctif local ciblé, après Phase 1 audio. Aucun déploiement, aucune migration de la copie SQLite existante ou de Render, aucun seed, changement de corpus/Unicode/translittération, ni modification d’interface. La Phase 1 et les travaux présents à l’ouverture ont été conservés.

## Investigation et périmètre réel

Le modèle serveur des données d’apprentissage personnelles est `progress.UnitProgress` : propriétaire compte optionnel, installation invitée, unité, compteurs d’exercices/quiz, scores/version de calcul, statut et dates. Deux routes : GET `/api/progress/unit-progress/` et POST `/api/progress/unit-progress/sync/`. Il n’existe pas de route détail ni de PUT/PATCH/DELETE public pour ces données. La création et la mise à jour passent par la synchronisation ; la suppression autorisée existe dans l’administration Django.

Les unités, thèmes, leçons et questions de quiz sont des contenus pédagogiques partagés, pas les réponses personnelles d’autres utilisateurs. Leurs sérialiseurs publics inspectés n’incluent pas `progress_records`. Aucun autre modèle serveur de résultat par réponse ou endpoint de statistiques personnelles indépendant identifié : les statistiques personnelles actuellement disponibles sont les compteurs de UnitProgress. Cela ne signifie pas absence d’historique local.

Flutter : `UnitProgressLocalStorage` et `LearningSession` conservent progression, réponses et checkpoints dans SharedPreferences ; les brouillons de l’éditeur sont également locaux. `SyncManager.syncAll()` envoie les progressions, pas ces brouillons ni l’intégralité de l’historique des réponses. `DeviceIdService` conserve UUID et jeton d’installation ; le service sync les transmet dans le corps et les en-têtes. L’application actuelle ne possède pas de parcours de connexion/gestion de plusieurs comptes utilisateurs ; ses données locales sont celles d’une installation, pas de profils authentifiés séparés sur un téléphone partagé.

Authentification serveur : sessions et authentification DRF existantes ; `request.user` décide du propriétaire authentifié. Les identifiants fournis dans le JSON ne doivent jamais choisir ce propriétaire. L’administration utilise ses permissions Django habituelles ; le seul statut staff ne suffit plus à ouvrir la liste API globale.

## Vulnérabilités et reproductions avant correction

Toutes les reproductions utilisent des utilisateurs, unités et progressions synthétiques sur base mémoire. Aucun test d’attaque distant.

| Constat confirmé | Reproduction avant correctif | Cause racine |
|---|---|---|
| N01 — Historique sans preuve revendicable | Créer une ligne sans jeton ; GET avec device_id et jeton inventé → 200 ; sync avec ce jeton → ligne attribuée/modifiée | Un jeton seulement non vide était accepté ; première attribution automatique sur historique existant |
| N02 — Accès croisé entre unités | Enregistrer un autre jeton pour une nouvelle unité du même device_id ; GET avec ce jeton retourne aussi l’unité protégée par le premier | Contrôle d’écriture limité à `(device_id, unit)` ; contrôle de lecture acceptant n’importe quel jeton du groupe puis retournant tout le groupe |
| Données de compte accessibles à un invité détenant un ancien jeton | Une ligne appartient au compte B et porte un jeton d’installation ; GET invité avec ce jeton → 200 ; sync invitée → compteurs de B modifiés | La vérification du propriétaire de compte n’était effectuée à l’écriture que si le demandeur était lui-même authentifié ; lecture invitée sans exclusion des comptes |
| Staff sans permission métier : lecture globale | `is_staff=True`, aucune permission progress ; GET → toutes les lignes | Autorisation basée uniquement sur le drapeau staff |
| Invité sans jeton enregistré | Sync d’un nouvel identifiant avec jeton vide → création acceptée | Aucune preuve exigée lors de création |
| N03 — Identifiants mal typés | `device_token: 42` ou booléen → HTTP 500 | `.strip()` sur le JSON brut, champ jeton absent du sérialiseur d’entrée |
| Identités en-tête/corps contradictoires | En-tête device A, corps device B avec jeton de B → écriture acceptée | Aucune cohérence imposée entre les deux représentations |

Autres défauts de compatibilité confirmés : propriétaire de compte légitime empêché de synchroniser sans ancien jeton ; création authentifiée sans device sous l’identifiant partagé vide. Le propriétaire était déjà choisi depuis `request.user` et non le JSON, mais le champ vide pouvait provoquer des collisions entre comptes pour une même unité.

## Correctifs

### Frontière compte / invité

`ownership.py` centralise l’autorisation serveur :

- Lecture authentifiée ordinaire : uniquement `user=request.user`, quels que soient `user` ou `device_id` forgés dans la requête.
- Lecture globale : staff **et** permission `progress.view_unitprogress` ; filtres de consultation conservés. Un staff sans cette permission ne voit que ses propres données. Les opérations Django admin restent régies par les permissions view/change/delete existantes.
- Lecture invitée : identifiant et jeton requis ; exclusion des lignes de compte ; correspondance du jeton sur chaque ligne retournée, jamais sur le seul ensemble de l’installation. Une ligne sans jeton n’est pas revendiquée. En cas d’historique ancien à plusieurs jetons, une lecture peut restituer uniquement le sous-ensemble invité correspondant exactement au jeton, jamais les autres lignes ; la création du registre/synchronisation refuse l’ambiguïté.
- Écriture : résolution d’un objet déjà possédé ou création attribuée par le serveur. Le compte propriétaire peut reprendre ses données sans ancien secret d’installation. Un compte A, même staff/superutilisateur, ne peut pas utiliser l’endpoint sync pour modifier B ; la gestion administrative autorisée se fait dans Django admin.
- Création authentifiée sans justificatif d’installation : identifiant serveur réservé `account:<pk>`, inaccessible aux invités, afin d’éviter les collisions sur device vide.
- Rattachement invité → compte : uniquement avec preuve valide, sans historique ambigu ; l’installation est alors liée au compte et n’est plus accessible par son ancien mode invité. L’indicateur de rattachement reste fermé même si ce compte est ensuite supprimé, pour les installations enregistrées ainsi.

`AllowAny` reste au niveau d’entrée des deux vues car l’apprentissage invité est conservé ; il n’autorise aucune donnée à lui seul. Les frontières de données sont appliquées au queryset de lecture et au résolveur d’objet de synchronisation avant sauvegarde, et non par Flutter.

### Registre d’installation additif

Nouveau modèle `ProgressDeviceCredential` : clé unique `device_id`, empreinte SHA-256 du secret aléatoire, compte optionnel et indicateur `account_bound`. Migration `0004_progressdevicecredential` : **table et indicateur de propriété additifs**, sans suppression de données ni réattribution d’historique invité. L’initialisation de l’indicateur des lignes déjà liées à un compte est décrite ci-dessous.

Le registre est créé à la première synchronisation valide : installation nouvelle ou historique dont tous les jetons existants concordent avec la preuve présentée. Historique sans jeton ou à plusieurs jetons : refus de revendication et conservation intégrale. Transactions, unicité en base et relecture avec `select_for_update()` contrôlent le gagnant d’une première inscription concurrente. Les tests sont exécutés sous SQLite ; la course réelle entre workers PostgreSQL n’a pas été exercée ici.

Un indicateur interne `UnitProgress.account_bound` conserve également le fait qu’une ligne appartient/a appartenu à un compte. Il est posé lors de la sauvegarde d’une ligne liée à un compte et reste vrai si `user` devient NULL après suppression du compte. La migration l’initialise seulement pour les lignes dont la FK prouve déjà ce rattachement ; ni scores, ni compteurs, ni propriétaire ne changent. Une ligne de compte détachée ne peut donc pas redevenir une ligne invitée accessible par ancien jeton, même sans registre préalable. Un test dédié couvre cette suppression.

Le registre n’est ni exposé dans l’API, ni ajouté à l’admin. Il conserve l’identité même après suppression de la dernière progression, empêchant le remplacement du secret par un autre demandeur. Le champ historique `UnitProgress.device_token` reste présent et stocké comme auparavant pour compatibilité : il ne faut pas prétendre que tous les jetons historiques sont désormais hachés.

### Validation et erreurs

Sérialisation stricte des identifiants : chaînes uniquement, tailles limitées à celles des modèles ; plus de `.strip()` sur des valeurs JSON arbitraires. Cohérence en-têtes/corps imposée. Les refus par élément utilisent l’enveloppe existante `synced_count/error_count/synced/errors`. La sync peut donc répondre 200 avec erreurs partielles, comme auparavant ; cela ne signifie pas que l’élément a été accepté. Les en-têtes surdimensionnés donnent 400. Les erreurs internes inattendues n’exposent plus directement leur chaîne d’exception.

La fusion des scores, les seuils pédagogiques, le format des contenus, les sessions et la logique audio restent inchangés.

## Contrat et opérations vérifiés

| Acteur / opération | Comportement attendu et testé |
|---|---|
| A authentifié, lecture avec IDs de B | Données de A seulement |
| A authentifié, sync sur B avec son ancien jeton | Refus, B inchangé |
| Invité, lecture/écriture d’une ligne de compte avec ancien jeton | Refus |
| Invité propriétaire, création puis sync de deux unités | Succès avec le même jeton |
| Invité, nouvelle unité d’un device connu avec un autre jeton | Refus, aucune ligne créée |
| Historique sans preuve | Conservé, aucune nouvelle attribution par premier demandeur |
| Propriétaire du compte, reprise sans jeton | Succès |
| Création avec `user` forgé | Compte de la requête ou invité, jamais propriétaire choisi par JSON |
| Changement d’identifiant/en-tête | Refus en cas de contradiction ; aucun accès indu |
| CRUD non exposé | POST/PUT/PATCH/DELETE de collection → 405 ; routes détail → 404 ; GET sur sync → 405 |
| Admin autorisé | Liste et suppression via Django admin fonctionnent |
| Staff sans permission | Pas de liste globale ni de suppression admin |
| Session sans jeton CSRF | POST sync rejeté 403 |
| Lot partiellement refusé | Succès autorisé conservé et erreur distincte pour l’autre élément |
| Refus de propriété reçu par Flutter | Échec signalé, historique local et mêmes identifiants conservés ; nouvelle tentative possible |

Les tests de suppression portent sur les routes réellement disponibles et sur l’administration. Aucun endpoint public DELETE ou CRUD supplémentaire n’a été ajouté.

## Tests réellement exécutés

| Étape | Résultat |
|---|---|
| Avant correction : `docs/run_backend_checks.py progress.tests_ownership` | 20 tests exécutés ; `FAILED (failures=16)`, incluant sous-cas ; preuves des contournements et défauts ci-dessus |
| Première validation ciblée après correction | 30/30 tests de propriété + progression existante réussis |
| Validation renforcée avec test de migration | 38 exécutés, une erreur dans la fixture historique de migration : état de LearningUnit pas aligné sur ses migrations déjà installées ; corrigé dans le test, sans changement métier supplémentaire |
| Test de migration corrigé, isolé | 1/1 réussi : table ajoutée puis retirée sur base mémoire, lignes de progression identiques ; `makemigrations --check --dry-run` sans écart |
| Suite Django complète avant le renforcement sur suppression de compte | **93/93 réussis**, 16,514 s ; contrôle système sans anomalie |
| Suite Django complète finale avec marqueur durable de propriété | **94/94 réussis**, 15,260 s ; migration et non-régression incluses |
| Flutter ciblé sync + sessions | **16/16 réussis** |
| Suite Flutter complète | **73/73 réussis**, compteur final ~7 s |
| Analyse Flutter finale | **Aucune anomalie**, 6,0 s ; un avertissement de style dans le nouveau test a été corrigé avant cette réussite |
| Lecteur audio web JavaScript | **3/3 réussis** |

Les tests backend ajoutés comprennent désormais 28 tests de propriété et un test de migration, en plus des 65 tests de Phase 1. Flutter ajoute un test de refus/reprise aux 72 tests de Phase 1. Les échecs simulés audio/cache dans les journaux Flutter ne sont pas des échecs du verdict de suite.

Le test de migration applique le schéma précédent, insère trois historiques synthétiques (avec/sans jeton et lié à un compte), compare toutes leurs colonnes historiques après migration, vérifie l’indicateur ajouté (faux/faux/vrai), puis compare à nouveau après retour au schéma précédent ; il restaure enfin le schéma de test actuel. **Ce retour arrière de test ne constitue pas une autorisation de supprimer un registre peuplé en production.**

## Fichiers de cette phase

| Fichier | Changement |
|---|---|
| `backend/progress/models.py` | Registre et marqueur durable de confidentialité des lignes de compte |
| `backend/progress/migrations/0004_progressdevicecredential.py` | Table et indicateur additifs ; initialisation de métadonnée pour les rattachements de compte déjà prouvés |
| `backend/progress/ownership.py` | Autorisation compte/invité, verrouillage et correspondance de chaque objet |
| `backend/progress/views.py` | Filtrage serveur, résolution sécurisée, permission staff explicite, cohérence des identifiants |
| `backend/progress/serializers.py` | Validation stricte et bornée des identifiants ; jeton write-only |
| `backend/progress/tests_ownership.py` | Matrice sécurité, CRUD réellement exposé, comptes/invités/admin/CSRF |
| `backend/progress/tests_migrations.py` | Migration sur historique synthétique peuplé et concordance modèle/migration |
| `mobile/test/unit_progress_sync_service_test.dart` | Refus serveur, conservation des données locales et identité stable pour réessai |
| `docs/PHASE2_PROGRESSIONS_2026-11-09.md` | Ce rapport et protocole opérationnel |

Aucun fichier métier Flutter, réglage de production ou fichier de la Phase 1 audio n’a été modifié par cette phase. Les trois `.pyc` et les documents d’audit déjà modifiés/non suivis à l’ouverture restent distincts.

## Préservation et compatibilité opérationnelle

La base locale existante est inchangée : SHA-256 `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b`, identique à la référence des phases précédentes. Son inventaire agrégé lecture seule comporte 4 progressions, toutes sans jeton et sans compte, aucune installation à plusieurs jetons. Ce sont des chiffres locaux, pas Render.

**Restriction de compatibilité volontaire :** les historiques sans preuve ne peuvent plus être repris à distance en présentant simplement leur identifiant et un nouveau jeton. Le client conserve l’apprentissage local, mais la synchronisation de ces identités peut rester refusée jusqu’à récupération contrôlée. Aucune rotation automatique de device_id/token, fusion ou suppression destinée à contourner ce refus n’est implémentée. Les installations possédant déjà un jeton valide gardent leur protocole actuel ; aucun changement de forme du payload Flutter requis.

Récupération contrôlée proposée, non exécutée : inventorier les lignes avec accès administratif restreint ; sauvegarder et conserver les valeurs d’origine ; recueillir une preuve de propriété indépendante du seul device_id ; faire valider précisément les lignes et le compte/installation cible ; attribuer le rattachement et le justificatif via une opération administrative auditée ; vérifier ensuite que l’ancien accès invité/tiers est refusé. Sans preuve suffisante, conserver l’historique en accès administratif, sans le transférer. Ni script de réattribution globale ni bouton de revendication publique.

Avant une future mise en service : sauvegarde et restauration vérifiées ; migration 0004 en préproduction avec version précédente compatible ; application de la migration avant activation du code qui utilise le registre ; recette du payload Flutter réel et des refus ; contrôle des permissions staff ; puis décision distincte de déploiement. Aucun de ces changements distants n’est effectué ici.

## Risques résiduels et limites

- Un invité est identifié par un secret d’installation : qui copie ce secret peut agir comme cette installation. SharedPreferences n’est pas un coffre de secrets ; pas de refonte du stockage local ou d’authentification multi-compte dans ce lot.
- Le paramètre GET historique `device_token` reste accepté pour compatibilité. Préférer `X-Device-Token` et éviter les secrets dans les URL/journaux ; aucune configuration de journalisation distante n’a été inspectée/modifiée.
- Les anciennes lignes gardent leur champ jeton en clair. La nouvelle table d’empreintes ne remplace pas une protection du stockage serveur et des sauvegardes.
- Les lignes déjà orphelines avant cette phase (`user=NULL`) ne permettent pas de reconstituer automatiquement un ancien propriétaire supprimé. Les historiques sans jeton restent verrouillés ; toute autre ambiguïté historique nécessite inventaire et validation contrôlée, sans attribution automatique. Le nouveau marqueur protège les rattachements connus lors de la migration et les suppressions ultérieures.
- La concurrence réelle PostgreSQL/multi-worker, les sauvegardes Render, la configuration HTTPS/proxy et un téléphone physique n’ont pas été testés. L’unicité et les verrous sont présents ; ils ne sont pas annoncés comme un benchmark de concurrence exécuté.
- Les scores restent déclaratifs côté client ; cette phase protège la propriété, pas une certification antifraude. Quotas/anti-abus de synchronisation et découpage de plus de 100 éléments restent des sujets séparés.
- Une installation locale partagée entre plusieurs personnes n’offre pas d’isolation entre profils en l’absence d’une connexion/gestion de comptes dans Flutter. Aucun résultat de cette phase ne doit être présenté comme une telle fonctionnalité.

## Retour arrière

Avant intégration, isoler ce lot de la Phase 1 dans un commit/diff et sauvegarder base, médias et registre si utilisé. La migration est additive : l’ancienne version ignore la nouvelle table, mais elle contient des vulnérabilités et **ne doit pas être remise en service avec les endpoints progressions ouverts**.

En cas d’incident futur : mettre temporairement les deux endpoints de progression en maintenance/refus contrôlé, préserver les données locales des applications, conserver le registre et ses indicateurs de rattachement ; revenir à une version sécurisée connue ou corriger en avant. Ne pas effacer les jetons ni réattribuer les historiques pour rétablir artificiellement une synchronisation.

Le schéma précédent a été testé sur données synthétiques, mais retirer une table de justificatifs peuplée ferait perdre les décisions de propriété/révocation. Ne pas inverser 0004 sur une production utilisée sans sauvegarde, examen des dépendances et plan explicite de conservation/reprise du registre. Une restauration de sauvegarde doit également tenir compte des écritures depuis cette sauvegarde. Aucun reset global, purge du corpus, ni désinstallation Flutter n’est une procédure de retour arrière acceptable.
