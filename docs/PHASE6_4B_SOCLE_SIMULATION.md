# Lot 6.4B — Socle Ads, Premium et paiements simulés

11 novembre 2026. Base : **c59808e**, conservée comme checkpoint documentaire.
Branche dédiée : `codex/phase6-4b-simulation-foundation`.
**Implémentation de recette uniquement : aucun déploiement, paiement ou Ads réel.**

## Bilan

Un module Django unique, ses modèles/additions de schéma, son administration à
permissions distinctes et son API personnelle sont implémentés. Flutter dispose
d'un transport commercial isolé, d'un vérificateur Ed25519 et d'un coffre natif
Android pour les attestations. Le mode commercial est fermé à plusieurs niveaux ;
aucune interface éducative n'est modifiée ni conditionnée à ces droits.

Les décisions utilisateur sont appliquées : web + Android, public adultes/mineurs,
âge inconnu protégé, sept jours au plus hors ligne, aucun pays marchand présumé,
gratuit préservé. Le client ne reçoit aucune clé privée et les tests utilisent
uniquement comptes, transactions et clés synthétiques.

## Livrables et preuves

| # | Demande | Emplacement |
|---|---|---|
| 1 | Rapport d'implémentation | Ce document |
| 2 | Architecture réellement implémentée et différences de périmètre | [ARCHITECTURE_IMPLEMENTEE.md](phase6_4b/ARCHITECTURE_IMPLEMENTEE.md) |
| 3 | Modèles et migrations | `backend/monetization/models.py`, `migrations/0001_initial.py` et `0002_alter_commercialrequest_feature_snapshot.py` ; [SCHEMA_CHECKS.json](phase6_4b/SCHEMA_CHECKS.json) |
| 4 | Contrats des API | [API.md](phase6_4b/API.md) |
| 5 | Matrice des permissions | [PERMISSIONS_ET_MINEURS.md](phase6_4b/PERMISSIONS_ET_MINEURS.md) |
| 6 | Protection des mineurs et limites de conformité | Même document, sources officielles et politique effective fermée |
| 7 | Droits hors ligne et recette Android | Tests Python/Dart/intégration ; [ANDROID_ENVIRONMENT.json](phase6_4b/ANDROID_ENVIRONMENT.json), [NATIVE_PROOF_VERIFICATION.json](phase6_4b/NATIVE_PROOF_VERIFICATION.json) |
| 8 | Simulations de paiement | [SIMULATIONS.json](phase6_4b/SIMULATIONS.json) |
| 9 | Non-régression et résultats structurés | [RESULTS.json](phase6_4b/RESULTS.json), section suivante |
| 10 | Migration isolée et retour arrière | [MIGRATION_ROLLBACK.md](phase6_4b/MIGRATION_ROLLBACK.md) |
| 11 | Fichiers et commit identifiable | [FILES_CHANGED.txt](phase6_4b/FILES_CHANGED.txt), commit livré sur la branche dédiée |
| 12 | Décision pour la suite | Dernière section |

## Validation exécutée

| Contrôle | Référence avant | Résultat du lot |
|---|---|---|
| Django global, SQLite mémoire et médias temporaires | 117 réussis | **147 exécutés, 145 réussis et 2 réservés à PostgreSQL** |
| Nouveau module sur PostgreSQL 17.5 isolé | Absent | **30 tests réussis**, dont 2 de concurrence réelle |
| Flutter global | 130 réussis | **145 tests réussis** |
| JavaScript audio/typographie | 5 réussis | **5 tests réussis** |
| Analyse Flutter | Référence propre | Résultat final consigné dans RESULTS.json |
| Schéma Django | Pas d'app commerciale | Migrations additives appliquées en bases jetables ; makemigrations sans différence ; check Django sans anomalie |
| Signature interlangage | Non implémentée | Enveloppe signée Python vérifiée Dart ; preuve native P-256 vérifiée indépendamment Python |
| Android debug | Aucun appareil physique connecté | Compilation réussie ; recette sur **émulateur Android 16/API 36**, package QA distinct |

Les chiffres historiques sont séparés des nouvelles exécutions. Les deux tests
ignorés sous SQLite ont été exécutés et réussis sur PostgreSQL : approbation
simultanée et création idempotente simultanée. Le corpus Erfe, l'audio, les packs,
progressions et SRS sont couverts par leurs tests historiques rejoués ; aucune
nouvelle validation visuelle ou écoute humaine n'est revendiquée.

Les tests ont été écrits avant ou pendant l'implémentation. Le premier lancement
ciblé constatait l'absence du module (ImportError attendu), **pas une vulnérabilité
des anciennes APIs**. Les tests supplémentaires ont ensuite révélé/corrigé :
validation de don sans snapshot, collision d'un code dans la fixture multi-méthodes,
fermeture des connexions de threads de recette et reprise du cache native par le
runner. Les vérifications finales font autorité, pas ces essais intermédiaires.

## Scénarios hors ligne

| Scénario | Niveau et preuve |
|---|---|
| Fermeture et redémarrage, même boot | **Exécuté sur émulateur** : arrêt du package QA, relance, cache Keystore conservé |
| Mode avion | **Exécuté sur émulateur** : paramètre système confirmé à 1 ; lecture de l'attestation existante sans réseau |
| Reboot du système Android | **Exécuté sur émulateur** : ancien lease conservé mais avantages nécessitant revalidation ; fonctions gratuites disponibles |
| Expiration, recul d'horloge | Tests Dart avec horloge monotone injectée, borne exacte et incohérences ; pas de mesure physique d'horloge sécurisée |
| Changement A/B et logout | Tests Dart ; absence de privilège transféré, suppression du seul cache commercial lors du logout |
| Réinstallation/perte de clé | Simulation Dart de changement de clé native ; refus. La séquence Android multi-lancements conserve volontairement le package |
| Révocation après reconnexion | Tests serveur + enveloppe révoquée Python vérifiée Dart ; retrait des seuls extras |
| Suppression de compte / invité usurpateur | Tests Django : clé serveur supprimée, grant orphelin non réattribué, jeton invité non authentifiant |
| Refus 401/403/503, jeton/session invalide | Tests transport Flutter et authentification Django ; cache encore valide conservé, aucune perte pédagogique |
| Conservation des contenus gratuits | Invariants Dart + suites existantes ; aucun nouveau service n'efface/modifie de progression, pack ou audio |

Le premier essai de séquence multi-lancements utilisait la désinstallation de fin
de test activée par défaut dans Flutter ; il ne validait pas une persistance
inter-exécutions. Les phases initiale puis fermeture/mode avion ont été rejouées
avec `--no-uninstall`, en attendant la fin complète du runner. Le reboot a ensuite
été testé sur ce même package conservé. Ne pas présenter cet émulateur comme le
Samsung physique utilisé dans une phase antérieure.

## Garde-fous réellement appliqués

- SQL empêche `ads_enabled` et `premium_sales_enabled` de devenir vrais.
  Réponses effectives et `CommerceAccess.adsAllowed` fermées pour tous les âges.
- Aucun SDK Ads/IAP, lien de paiement externe, compte bancaire ou PSP configuré.
  La configuration de catégories est une intention, pas un filtrage tiers certifié.
- Circuit pending → verified → activated, maker/checker indépendant, permissions
  de vérification/attribution séparées ; âge inconnu/mineur exige revue renforcée.
- Motif/audit transactionnels, unicité du reçu simulé, demande/grant/outbox
  idempotents ; pas d'édition CRUD du statut/grant pour contourner les services.
- Droits signés à durée bornée, sujet de compte + clé d'installation ; aucune
  confiance en un booléen local, heure civile, device_token invité ou user_id client.
- API personnelle filtrée par propriétaire, no-store et CSRF pour sessions.
  Les anciens contrats pédagogiques ne changent pas.
- Configuration, ledger et métadonnées commerciales ne transforment aucune
  fonction éducative existante en contenu payant, même si un droit expire.

## Préservation et fichiers

La base SQLite source a la même empreinte SHA-256 que la fin de Phase 6.3 ; aucune
migration n'y est appliquée. Les tests n'ont importé aucune donnée réelle dans le
cluster PostgreSQL de recette. Les rapports/proofs de 6.4A et des phases précédentes
sont conservés. Les seuls fichiers existants modifiés sont settings/urls pour le
nouveau module, requirements pour la bibliothèque, pubspec/lock pour le vérificateur
et les outils de tests, MainActivity et Gradle pour le pont et le package QA.
Le reste des modifications correspond à des ajouts, détaillés dans le manifeste.

Les bytecodes suivis historiques régénérés pendant les premières vérifications
ont été remis exactement aux octets Git de référence ; aucun temporaire, venv,
base, clé privée, APK ou log runtime ne fait partie du commit. Les logs bruts et
le cluster jetable sont ignorés sous `docs/phase6_4b/runtime/` ; leurs empreintes
et synthèses non sensibles sont dans RESULTS.json.

## Risques et limites avant la suite

1. Pas de connexion native de compte ni d'écran Premium branché : le contrôleur
   exige une session et un contexte sûrs fournis par l'appelant. L'isolation/migration
   des anciens caches guest/A/B doit précéder l'intégration d'un login global.
2. Révocation immédiate hors ligne impossible ; téléphones rootés, app modifiée et
   rollback intégral d'un état chiffré restent hors de la garantie locale absolue.
   Reboot requiert réseau pour les extras ; tester ce compromis auprès des usagers.
3. Aucun téléphone physique disponible le 11 novembre. Keystore ancien Android,
   panne disque, migration/restauration système réelle, performances et mémoire
   doivent être recettés sur appareils modestes. Aucune mesure inventée.
4. Pays marchand, prix, avantages, canaux de vente et exigences parentales/juridiques
   non finalisés. La classification d'âge Admin ne prouve ni majorité ni consentement.
5. Clé persistante/rotation opérationnelle et comptes fournisseurs non provisionnés.
   Outbox sans worker/envoi, reçus externes et abonnements récurrents non implémentés.
   Quotas durables de clés/appareils, nettoyage des challenges consommés et rétention
   sont à finaliser avant une exposition réelle ; la borne de 20 challenges en attente
   ne constitue pas à elle seule un dispositif anti-abus complet.
6. Avertissement de compilation existant sur l'évolution Kotlin de plugins audio/share ;
   build debug réussi, sans mise à niveau de ces dépendances pendant ce lot.
7. Les blocages de production 6.3 restent ouverts : stockage privé effectif et anciens
   objets publics, proxy, restauration PostgreSQL cible et migrations à valider.

## Décision

**GO technique pour le socle de simulation isolé**, sous réserve de revue du
commit et de ses limites. Les tests autorisent sa validation technique, pas son
activation commerciale. Prochain lot recommandé : identité mobile/session et
isolation explicite des contextes pédagogiques, avec recette physique dédiée,
avant tout branchement des écrans de compte.

**NO-GO pour fournisseur réel, publicité, paiement, publication ou production.**
Validation humaine distincte nécessaire pour les obligations enfants/pays/canal,
les clés de signature et la levée des blocages opérationnels. Retour arrière décrit
dans MIGRATION_ROLLBACK.md ; ne pas supprimer les tables comme procédure standard.

Travail arrêté après ce lot, en attente d'approbation avant la suite.
