# Phase 6.3 — Sécurité, staging et préparation opérationnelle

10 novembre 2026 — branche `codex/phase6-3-security-staging`, base **7998177**.
Référence documentaire précédente **4cb8708**. Intervention locale uniquement.

**Décision : GO pour soumettre les corrections et la préparation de recette à
validation ; NO-GO pour un déploiement réel à ce stade.** Les contrôles locaux
réussissent, mais PostgreSQL/R2/proxy réels, pièces historiques et recette Android
staging restent des prérequis ouverts. Aucune Phase 6.4 engagée.

## Préservation et état de référence

Le dépôt était propre sur `codex/phase6-2-erfe-typography`, HEAD 7998177.
La branche dédiée a été créée avant correction. Les preuves, captures, rapports
et polices de Phase 6.2 restent conservés ; leur intégrité est vérifiée dans les
résultats de consolidation. Les tests de référence ont été **réexécutés** :
99 Django sous 6.0.6, 130 Flutter et 5 JavaScript réussis.

La base locale courante diffère de l’empreinte archivée en Phase 6.2 : elle porte
`8c1d4b1cf3a9415b17510fe5ce0b80c080ed056d7ca884730352214eadc65aef`.
La cause et la chronologie exacte de cet écart antérieur/concurrent ne sont pas
établies ; le serveur local préexistant sur 8000 est conservé. Cette empreinte est
stable pendant les sauvegardes/restaurations RO et au contrôle final. Ne pas
présenter le hash 2684… de Phase 6.2 comme celui de l’état courant, ni affirmer une
preuve de stabilité de toute la phase avant le premier relevé présent.

Aucune migration ou écriture de données applicatives n’a été effectuée sur la
base source. Les copies restaurées, bases de tests, médias synthétiques et arbres
de staticfiles sont des cibles distinctes dans le dossier ignoré `phase6_3/runtime/`
ou dans des dossiers temporaires. Les credentials réels n’ont été ni imprimés ni
copiés dans les livrables ; `CONFIG_RESULTS.json` contient les **noms** des variables.

## Lot A — Environnements et déploiement préparé

| Constat | Reproduction / preuve | Correction ciblée |
|---|---|---|
| `DJANGO_ENV=staging` rejeté | Test d’acceptation staging en erreur avant correction | Staging distinct mais mêmes garde-fous secrets, DEBUG, HTTPS, cookies, HSTS et proxy que production |
| CORS non contrôlé par le constructeur de sécurité | Test wildcard production échoué avant correction | Origines explicites validées, HTTPS en environnement déployé, wildcard interdit, credentials désactivés par défaut |
| Hôtes mal formés / absence de séparation staging | Tests valeurs dangereuses | Staging exige sa liste explicite ; validation des noms ; ajout du domaine API de production déjà utilisé par Flutter aux défauts production |
| SQLite implicite possible si DATABASE_URL manquait | Lecture settings et nouvelles sondes de démarrage | URL PostgreSQL explicite exigée en staging/prod ; TLS par défaut, exception seulement sur réseau privé explicitement déclaré |
| LocMem pour quotas par processus | Lecture settings ; différence de configuration démontrée | En environnement déployé, cache partagé requis ; DatabaseCache sans service Redis supplémentaire possible ; createcachetable ajouté à release.sh |
| Médias sur disque éphémère non signalés | Audit settings | R2 ou déclaration explicite de stockage persistant ; aucune ressource cloud créée |
| Bootstrap superuser automatique si mot de passe présent | Audit de la commande ; tests opt-in/refus password faible | Activation one-shot explicite, username explicite, validateurs Django ; aucun compte existant modifié |
| Django 6.0.6 antérieur au patch sécurité | Version locale/pin vérifiés ; bulletin officiel consulté | **Django 6.0.10**, même branche mineure, installé localement et épinglé dans requirements.txt ; pip check réussi |

Le bulletin Django du 3 novembre 2026 décrit notamment un problème de mémoire
lors d’uploads multipart encodés en base64 ; c’est pertinent pour les formulaires
acceptant des fichiers. La présence de la version concernée est confirmée, **pas
un exploit mémoire exécuté**. Aucun test destructif de déni de service. Les sujets
GIS du bulletin ne sont pas présentés comme des fonctions exposées de BK.
[Bulletin officiel Django](https://www.djangoproject.com/weblog/2026/nov/03/security-releases/).

Les domaines/API Flutter restent inchangés : staging et production HTTPS existent
dans `ApiConfig`, avec tests de refus release des URLs locales/HTTP. Aucun SDK,
contrat API pédagogique, police, traduction ou moteur mobile n’a été modifié.
`staging.env.example` est un modèle à compléter, pas une configuration active.

Les sondes utilisent exclusivement des valeurs synthétiques : trois configurations
sûres acceptées et neuf configurations dangereuses refusées, dont séparation des
buckets R2, refus d’un bucket privé manquant/identique et d’une origine HTTP.
Cela valide les réglages, pas l’état d’un bucket réel. `check --deploy`
via les checks Django retourne seulement **W005/W021**, non masqués : sous-domaines
HSTS et preload restent soumis à décision, pas activés pour faire taire un warning.
La chaîne de proxy Render/CDN et ses valeurs effectives n’a pas été interrogée.

## Lot B — Médias publics et privés

| Défaut confirmé | Gravité | Correction et limites |
|---|---|---|
| Capture feedback enregistrée sur le stockage public et URL anonyme | Élevée pour des pièces potentiellement personnelles | Nouveau stockage privé séparé et routes staff authentifiées, `no-store`, `nosniff` ; lecture legacy staff conservée |
| Audio de type feedback visible dans l’API si marqué publié | Élevée | Exclusion des requêtes publiques, des sélections audio pédagogiques et de No Ena ; endpoint privé staff ; aucune authentification ajoutée aux audios pédagogiques publics |
| Nouveaux médias invalides acceptés par `save()` ORM | Moyenne à élevée selon exposition | Validation commune sur nouveaux uploads pour formulaires et sauvegarde standard ; anciennes références conservées |
| Signature ID3/ftyp seule insuffisante | Moyenne | Reproduction puis contrôle de trame MP3/conteneur ISO BMFF en plus de la signature ; WAV minimal lu réellement |
| Accès direct legacy contournable par chemin normalisé/casse | Élevée localement selon serveur | Test en échec puis normalisation avant refus des chemins feedback ; comparaison insensible à la casse pour audios historiques |
| ZIP dangereux ou flux DEFLATE invalide | Moyenne | Chemins absolus, parent, lecteurs Windows, backslashes, NUL, liens symboliques, archives chiffrées/volumes excessifs et CRC refusés ; erreurs de décompression transformées en ValidationError |
| ZIP importé manuellement sans checksum calculé | Moyenne, intégrité | Test en échec avant correction ; SHA-256 et taille calculés uniquement sur nouveau fichier à l’enregistrement, sans réécrire les archives existantes |

La matrice complète et les limites sont dans [ACCES_MEDIAS.md](phase6_3/ACCES_MEDIAS.md).
Les comptes synthétiques A/B, l’anonyme/jeton invité forgé et le staff sont testés.
Les lectures publiques légitimes des audios et packs publiés restent à 200 ; les
brouillons restent invisibles aux non-staff. La politique staff existante est
conservée, sans imposer le flag preview annoncé à tort dans un ancien audit.

Les validations ne modifient ni les octets audio/image ni les données linguistiques.
Elles contrôlent formats, dimensions, tailles, chemins et structures ; elles ne
constituent pas un antivirus ni une certification de décodage de tous les codecs.
Les limites du parseur/proxy en amont restent nécessaires pour protéger le serveur
avant que la validation de formulaire ne s’exécute.

**Important : un contrôle Django ne privatise pas un bucket public externe.**
Le nouveau bucket privé doit être distinct et son accès public réellement désactivé.
Les objets historiques déjà publics, caches et anciens packs demandent inventaire,
sauvegarde, copie vérifiée et retrait public autorisé, sans réécriture silencieuse.
Aucune suppression, copie distante ou purge CDN n’a été faite.
[Accès public des buckets R2](https://developers.cloudflare.com/r2/buckets/public-buckets/).

Les modèles de contenu héritent d’un mixin de validation sans ajouter de colonne.
Deux migrations **d’état uniquement** enregistrent les nouveaux stockages/routages
des FileFields : `audio_assets.0002` et `feedback.0002`. `sqlmigrate` montre no-op
pour les opérations SQL de schéma. Aucun chemin stocké n’est réécrit automatiquement.
Une première génération AlterField aurait reconstruit les tables SQLite : elle a
été remplacée par SeparateDatabaseAndState avant toute application à la source.

## Lot C — Sauvegarde et restauration réellement vérifiées

`phase6_3/restore_isolated.py` crée une destination neuve, ouvre la source en RO,
utilise l’API SQLite backup, restaure vers un autre fichier puis compare toutes les
tables avant migration. Il refuse les liens symboliques dans la copie des médias.

Résultats dans [RESTORE_RESULTS.json](phase6_3/RESTORE_RESULTS.json) :

- **37 tables / 344 lignes**, schémas et valeurs identiques avant migrations.
- Migrations appliquées **à la copie seulement** : audio_assets.0002,
  feedback.0002 et progress.0004. Toutes les valeurs préexistantes conservées après
  migration ; seules les nouvelles entrées de django_migrations sont ajoutées.
- `integrity_check=ok`, aucune violation de clé étrangère.
- **146 médias publics / 70 511 945 octets**, dont 110 fichiers audio, copiés avec
  SHA-256 identiques ; un fichier privé local de 68 octets également comparé.
- **4 références fichier** en base : aucune référence absente sur cette copie ;
  deux références audio rouvertes. Cela ne signifie pas 110 audios référencés par
  les quatre champs : le nombre de fichiers et celui des références sont distincts.
- Un pack présent, son checksum stocké correspond au fichier restauré et son CRC
  ZIP est valide ; aucun pack existant régénéré ou modifié.
- DatabaseCache sur la copie : deux processus indépendants séquentiels observent
  les valeurs **1 puis 2**. Cela prouve le partage, pas l’atomicité sous concurrence.

La première vérification rejetait l’ajout attendu des nouvelles lignes dans
django_migrations ; la comparaison a été corrigée pour exiger la préservation de
toutes les anciennes lignes et permettre les nouvelles. Les anciennes destinations
de recette ne sont pas écrasées. Le runner de tests place désormais aussi les
médias privés dans son dossier temporaire pour éviter des fichiers synthétiques
hors de la recette.

**Non exécuté :** restauration PostgreSQL, téléchargement/snapshot R2, chiffrement
effectif des sauvegardes, gel des écritures réelles ou procédure de maintenance.
Les outils PostgreSQL n’étaient pas disponibles dans cette session. Les procédures
de `BACKUP_AND_RESTORE.md` sont précisées : instantanés neufs, `copy` plutôt que
`sync` destructeur pour une rétention, cible PostgreSQL isolée, pas de `--clean`
sur une URL source. RTO/RPO et cohérence cloud restent à mesurer.

## Lot D — Validation et typographie

| Contrôle | Résultat exécuté |
|---|---|
| Référence avant changements | 99 Django, 130 Flutter, 5 JS réussis |
| Reproduction principale | 10 tests : 5 échecs et 1 erreur avant corrections, autres assertions déjà conformes |
| Cas supplémentaires | Reproductions ciblées de chemin normalisé, conteneur falsifié et DEFLATE invalide, puis corrections |
| Suite Django finale | **117 tests réussis** sous Django 6.0.10 |
| Suite Flutter finale | **130 tests réussis** |
| Suite JavaScript finale | **5 tests réussis** |
| Analyse Flutter | **No issues found** |
| Configuration déployée synthétique | **12 scénarios attendus vérifiés**, W005/W021 documentés |
| Dépendances | `pip check` sans conflit ; pas de scan exhaustif CVE de tous les paquets |
| Statiques | `collectstatic` isolé réussi : 178 fichiers copiés, 514 post-traités |
| WhiteNoise | Six fichiers hashés servis localement avec octets identiques aux empreintes des polices validées |
| Navigateur réel | Chrome, vraie page locale Django RO : HTTP 200 et Kedebideri personnalisée réellement utilisée, capture conservée |
| Android physique Phase 6.3 | **NON EXÉCUTÉ** : ADB ne détecte aucun appareil ; les captures physiques 6.2 ne sont pas présentées comme rejouées |

L’ajout de validations a fait échouer trois tests utilisant deux fixtures anciennes
simulant un MP3 et un ZIP par des chaînes arbitraires ; ces fixtures ont été remplacées par du silence WAV et un ZIP
réel, sans affaiblir les contrôles ni modifier le but des tests d’export/checksum.
Les erreurs intermédiaires ne sont pas comptées comme des réussites.

La police et les assets Flutter sont inchangés. [TYPOGRAPHY_HTTP_RESULTS.json](phase6_3/TYPOGRAPHY_HTTP_RESULTS.json),
[STATIC_RESULTS.json](phase6_3/STATIC_RESULTS.json) et la
[capture locale](phase6_3/typography_http.png) complètent les tests typographiques
existants des 50 caractères/macrons, thèmes et petits écrans. Les tests WhiteNoise
emploient un Client Django local, pas une requête vers Render. Les requêtes Chrome
utilisent réellement HTTP localhost. Aucun mélange entre ces niveaux de preuve.
Un test supplémentaire utilise l’authentification Basic réelle sur une requête
Django HTTPS synthétique : lecture staff acceptée puis refus après désactivation
du compte. Il complète les contrôles de rôles par identités forcées, sans être
présenté comme une connexion mobile ou une requête réseau vers staging.

Le code de l’extracteur Flutter a également été consulté : contrôle SHA-256 quand
présent, chemins anti-ZipSlip, dossier de staging, limites 5 000 fichiers et 500 Mo.
Les nouveaux plafonds serveur sont alignés. La validation ZIP serveur porte sur la
sûreté du conteneur ; la conformité complète du metadata.json pédagogique reste
contrôlée par le client et les tests de génération, pas déduite d’un simple ZIP
valide. Les anciens packs sans checksum restent compatibles avec le comportement
historique du client ; aucun ancien checksum n’a été changé.

## Livrables, paramètres et limites

- [RESULTS.json](phase6_3/RESULTS.json) : synthèse structurée, empreintes et résultats.
- [CONFIG_RESULTS.json](phase6_3/CONFIG_RESULTS.json) : inventaire des noms de variables,
  sans valeurs sensibles, plus sondes synthétiques.
- [ACCES_MEDIAS.md](phase6_3/ACCES_MEDIAS.md) : matrice et procédure de remédiation historique.
- [CHECKLIST_PREPRODUCTION.md](phase6_3/CHECKLIST_PREPRODUCTION.md) : prérequis et rollback.
- [FILES_CHANGED.txt](phase6_3/FILES_CHANGED.txt) : liste exhaustive des fichiers du lot.
- Scripts reproductibles dans `phase6_3/`, logs et copies privés dans `runtime/` ignoré.

Les familles de modifications sont : sécurité/configuration Django ; routage privé
et contrôle des médias ; modèles/validations et migrations d’état ; patch Django ;
commande release/bootstrap ; tests, runner isolé et documentation. Le fichier
requirements conserve son encodage UTF-16 d’origine, seul le pin Django change.

| Fichiers / groupes | Justification du changement |
|---|---|
| `backend/config/security.py`, `settings.py` | Staging protégé, origines, base explicite, cache partagé et séparation des stockages |
| `backend/core/media_validation.py` et modèles des apps médias | Validation centralisée des seuls nouveaux fichiers, sans transformer les valeurs existantes |
| `backend/core/media_storage.py`, `media_access.py`, `feedback/private_media.py`, `feedback/urls.py` | Routage privé, autorisation staff et protection des anciens chemins servis par Django |
| `audio_assets/views.py`, `serializers.py`, `utils.py`, `no_ena/serializers.py` | Empêcher l’exposition publique du type feedback tout en conservant l’accès pédagogique |
| `audio_assets/migrations/0002*`, `feedback/migrations/0002*` | État des FileFields seulement, sans SQL de schéma |
| `offline_packs/models.py` | Calcul automatique du checksum des nouveaux ZIP importés ; anciens fichiers/checksums préservés |
| `core/management/commands/bootstrap_render.py`, `release.sh` | Bootstrap explicite et initialisation idempotente du cache configuré |
| `backend/requirements.txt` | Patch de sécurité Django 6.0.10 |
| `core/tests_phase63.py`, `offline_packs/tests.py`, `docs/run_backend_checks.py` | Reproductions, fixtures réellement valides et isolation des médias privés de test |
| `.gitignore`, scripts/JSON/rapports `docs/phase6_3/`, `docs/BACKUP_AND_RESTORE.md` | Exclusion des données privées, preuves reproductibles et procédures sûres |

Le compte staff de modération conserve ses droits existants ; les comptes A/B et
invités ne peuvent accéder aux pièces privées. Les routes additionnelles ne
changent pas les champs JSON pédagogiques. Les clients staff doivent transmettre
leur authentification pour lire une pièce privée ; une ancienne URL anonyme ne
constitue plus une méthode de lecture autorisée. Les liens publics éducatifs et
les contrats de progression/synchronisation restent inchangés.

L’état effectif des secrets/ACL/proxy sur Render et Cloudflare n’est pas vérifié.
Les logs réels, leur rétention et les alertes restent une recette opérationnelle,
pas une fonctionnalité développée. Aucun nouveau service payant, aucune publicité,
aucun Premium, paiement ou déploiement. Les limites résiduelles des validateurs,
des anciens objets publics, des uploads en bordure et des sauvegardes non chiffrées
locales sont explicitement conservées dans la checklist.

## Décision et retour arrière

**GO technique local** pour valider les corrections et planifier la prochaine
recette. **NO-GO production** avant la checklist externe, en particulier : bucket
privé effectif, remédiation des pièces historiques, vraie restauration PostgreSQL,
configuration du proxy et application contrôlée des migrations encore en attente.
La migration progress.0004 est toujours absente de la source locale observée ;
l’état réel de production ne doit pas en être déduit.

Le retour arrière des fichiers se fait depuis un commit identifiable sur une
branche de retour, sans restauration de la base source qui n’a pas été modifiée
par la recette. Ne pas supprimer le registre de propriété/progression et ne pas
réexposer les pièces privées en revenant aveuglément à 7998177. Préférer un
correctif en avant et garder le routage privé lors d’un rollback applicatif.
Les sauvegardes de recette restent conservées, exclues de Git et non partagées.
La Phase 6.4 attend une validation explicite distincte.
