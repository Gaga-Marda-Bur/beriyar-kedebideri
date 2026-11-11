# Migrations et retour arrière — 6.4B

Référence préservée : `c59808e`, branche documentaire 6.4A. Branche de travail :
`codex/phase6-4b-simulation-foundation`. Les anciens livrables sont conservés.

## Ce qui a été exécuté

- Génération des seules migrations `monetization.0001` et `0002`.
- Application automatique par les runners Django à des **bases de test** :
  SQLite mémoire et PostgreSQL local temporaire sur port 55464.
- Le cluster PostgreSQL a été initialisé séparément sous `runtime/pgdata`,
  sans copie de données réelles. `run_postgres_tests.py` fige explicitement son
  hôte local, port et nom `bk64b_recette` ; il n'utilise pas DATABASE_URL externe.
  Les bases de test créées sont détruites par Django ; le cluster est ensuite arrêté.
- Vérification `makemigrations --check --dry-run`, contrôle Django et structure
  des opérations. Les migrations de progression en attente ne sont appliquées
  que dans ces bases jetables avec le reste du schéma de test.
- Contrôle SHA-256 de `backend/db.sqlite3` :
  `8c1d4b1cf3a9415b17510fe5ce0b80c080ed056d7ca884730352214eadc65aef`,
  identique à la preuve finale de Phase 6.3.

**Aucune migration exécutée sur la base locale existante ou la production.**
Les migrations de ce lot ne touchent ni les tables linguistiques, ni les polices,
ni les données pédagogiques. Voir SCHEMA_CHECKS.json.

## Reproduire sans toucher aux bases existantes

SQLite : `backend/venv/Scripts/python.exe docs/run_backend_checks.py`.
Le script force `sqlite:///:memory:` et des médias temporaires. Si Windows bloque
le répertoire temporaire, l'exécution nécessite l'autorisation d'accès à ces
répertoires ; ne pas remplacer leur chemin par le stockage des médias existants.

PostgreSQL : initialiser **un nouveau cluster** dans un répertoire runtime vide,
compte de test `bk_simulation`, écoute 127.0.0.1:55464, base `bk64b_recette`, puis
exécuter `docs/phase6_4b/run_postgres_tests.py`. Si port/répertoire occupé par un
autre service, arrêter la procédure et adapter explicitement le runner ; ne pas
réutiliser une base existante ou interrompre un serveur par son nom de processus.
L'authentification trust de ce cluster est limitée à des données fictives locales ;
ce n'est **jamais** une configuration de staging/production à recopier.
La version PostgreSQL préinstallée 17.5 décrit la recette, pas une recommandation
de version de production. Arrêter ce seul cluster avec son chemin `pg_ctl -D`.

## Rollback du code, pas suppression du ledger

1. Conserver l'arrêt Ads/ventes et la séparation de l'authentification pédagogique.
   Rien n'a été activé sur un environnement réel par ce lot.
2. Sauvegarder les éventuelles bases et fichiers de simulation qu'on souhaite
   conserver. Sur un futur environnement, vérifier dump/restauration isolés,
   cohérence médias/DB et états des callbacks **avant** d'autoriser la migration.
   Les procédures Phase 6.3 restent applicables et leurs limites restent ouvertes.
3. Revenir au code validé `c59808e` dans une branche de rollback ou révoquer le
   commit du lot. Ne pas forcer le reset d'un travail utilisateur en cours.
   L'ancien code n'a pas besoin des nouvelles tables ; les laisser intactes.
4. Ne pas exécuter `migrate monetization zero` sur une base utilisée : cela détruit
   les demandes, les droits et le journal. Aucun effacement de progression,
   restauration de vieux packs ou remplacement d'un secret n'est nécessaire.
5. Le package `.qa64b` est distinct du package pédagogique. Il ne contient que des
   données synthétiques ; sa désinstallation de recette ne concerne pas l'app
   principale. Une future application commerciale devra préserver les droits
   valides et données pendant un retour arrière, sans rejouer des encaissements.

## Conditions avant toute connexion réelle

Autorisation distincte, pays marchand/canaux/audience vérifiés, modèle de consentement
adapté, identité mobile et isolation des anciens caches recettées, secret de
signature provisionné/rotation et clés de confiance approuvées, revue sécurité,
recette sur téléphones modestes, sauvegarde/restauration cible et levée des blocages
6.3. Un commit ou un test vert n'autorise ni migration réelle ni publication.
