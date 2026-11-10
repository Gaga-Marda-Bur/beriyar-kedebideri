# Risques, tests et retour arrière — livrable 10

Tous les tests de nouveau module ci-dessous sont **à concevoir/exécuter après
autorisation**, pas réussis dans la Phase 6.4A. Les résultats 117 Django / 130
Flutter / 5 JS et analyse propre sont la référence Phase 6.3, non rejouée pour des
documents seuls. Aucun appel marchand/sandbox, annonce de test ou migration exécuté.

## Matrice de validation future

| Risque / scénario | Résultat attendu et preuve à obtenir |
|---|---|
| Accès de A aux droits/demandes/pièces de B | 404/403 serveur, aucun payload privé ; tests API et URLs directes, non simple filtre Flutter |
| UUID invité/devicetoken présenté comme compte Premium | Refus ; gratuit et historique invité conservés |
| Connexion A→B et retour invité | Contextes séparés, pas de grant/notification/annonce A réutilisé, pas de suppression de progrès |
| Migration des anciennes clés locales | Backup et migration idempotente avec consentement ; coupure au milieu, réessai et rollback sans perte |
| App modifiée prétendant Premium | Opérations serveur privilégiées refusées faute de grant ; limites de protection locale documentées |
| Faux reçu ou callback UI « succès » | Pas de grant ; réception rapprochée ou preuve fournisseur requise |
| Deux vérifications du même encaissement | Une affectation et un grant, même en concurrence PostgreSQL ; aucune garantie déduite de SQLite seul |
| Référence devinée réservée par un fraudeur | La déclaration ne prend pas possession d’un reçu ; triage du vrai payeur possible |
| Même idempotency-key, corps différent | 409 ; même corps retourne la même décision sans second grant |
| Devise/montant/plan changés côté client | Devis serveur fait foi ; négatif, fraction invalide, overflow et offre inactive refusés |
| Don converti en Premium, cash comme faux contournement | Contraintes/service refusent l’auto-grant ; revue de canal nécessaire |
| Permissions staff excessives | Staff sans capability ne peut configurer/payer/octroyer ; auto-approbation et bypass Admin/actions/jobs testés |
| Webhook simulé falsifié, dupliqué, hors ordre ou mauvais marchand | Refus/déduplication/réconciliation selon adaptateur ; test-mode ne produit pas de droits live |
| Renouvellement, annulation, remboursement et autre bourse active | Dates exactes ; annuler renouvellement ≠ perdre période ; remboursement révoque seulement les grants concernés |
| Signature/claim modifié, clé test en prod, kid inconnu, doublons JSON | Aucun privilège ; tests interlangage, parser borné et vecteurs cryptographiques connus |
| Copie de lease A→B ou vers autre appareil | Sujet/clé/audience vérifiés ; aucun privilège transféré |
| Rejeu de lease plus ancien après révocation | Epoch connu ne recule pas ; revalidation réseau, limites de rollback complet/root explicites |
| Recul/avance d’heure, veille, kill/restart app, reboot téléphone | TTL ne s’allonge pas ; même boot utilise ancre native ; reboot/perte d’ancre suit la politique approuvée |
| Serveur 401/403/503, réseau intermittent et réponse très retardée | Pas de prolongation locale ni effacement ; statut inconnu distinct de révocation ; gratuit accessible |
| Rotation/perte de clé, nouveau téléphone, restauration système | Réenregistrement en ligne, récupération des droits serveur sans rachat ; absence de clé ne récupère pas un lease étranger |
| SDK Ads initialisé alors que désactivé/inconnu | **Zéro requête tiers** mesurée, pas seulement un widget invisible |
| Exercice/audio/clavier/SRS ou compte Premium | Aucun chargement ni affichage Ads, y compris si une annonce était préchargée avant changement de contexte |
| Retrait consentement / audience enfant inconnue | Requêtes arrêtées et créatifs détruits ; règles d’âge revues ; pas de fallback NPA automatique prétendument exempt |
| Kill switch / config expirée / app en arrière-plan | Interdiction à réception/expiration, revérification au retour ; délai réel mesuré, pas promesse d’instantanéité hors ligne |
| Fréquence/banner près d’un contrôle | Plafonds et temporisation effectifs, tactile/accessibilité, pas de clic accidentel induit |
| Pièce jointe hostile ou URL de secret | Validation/stockage privé, accès scoped et no-store, pas de fetch arbitraire/secret env consultable par Admin |
| Notification relancée après crash | Audit/grant atomiques ; outbox dédupliquée, aucune seconde activation |
| Anciennes APIs, packs, SRS, Erfe et progressions | Contrats et checksums identiques, corpus inchangé ; suites historiques + recette Android offline |
| Migration additive et rollback code N-1 | Sauvegarde/restauration isolées, anciennes colonnes/valeurs préservées, clients non commerciaux restent fonctionnels |

## Risques résiduels et garde-fous

- **Élevé — identité mobile absente et cache non cloisonné :** bloque l’activation
  de droits personnels tant que le lot identité/local n’est pas validé.
- **Élevé — hors ligne/root/horloge :** signature ne rend pas le téléphone inviolable ;
  TTL, ancre et politique reboot réduisent les risques sans révocation instantanée.
- **Élevé — paiement et pouvoirs administratifs :** contrôle du reçu réel,
  séparation des actions, contraintes DB et revue des accès ; UI seule insuffisante.
- **Élevé — publicités inadaptées/enfants :** filtrage non exhaustif ; audience,
  consentement, tests réseau et arrêt d’urgence avant toute exposition réelle.
- **Élevé — Store/PSP inéligible :** pays/canal/contrat inconnus ; pas de vente
  externe ni de « donation » déguisée pour contourner les règles.
- **Élevé — production 6.3 non levée :** private bucket, anciens objets publics,
  proxy, PostgreSQL restauré et migrations à vérifier sur la cible réelle.
- **Moyen — charge/coût/stockage :** taille SDK, réseau et clés natives à mesurer
  sur téléphones modestes ; aucun benchmark ni revenu inventé.
- **Moyen — données privées/audit :** reçus et tokens hors logs/API publics,
  rétention justifiée et accès restreint ; journal applicatif ≠ indestructibilité DB.

## Modes et arrêt d’urgence

Séparer `ads_enabled`, autorisation par placement, pause des ventes et droits
existants. Désactiver les nouvelles offres ne révoque pas les grants déjà acquis.
Un mode live nécessiterait à la fois approbation métier et garde d’environnement
opérationnelle distincte, inaccessible à un simple changement Admin. En phase de
test, seuls adaptateurs/IDs/test keys synthétiques peuvent être utilisés.

En incident : couper annonces et nouvelles opérations commerciales, conserver
gratuit et données. Une erreur de monétisation n’arrête pas la synchronisation
pédagogique. Ne pas retirer des droits valides pour dissimuler un problème d’offre.

## Retour arrière proposé

1. Désactiver annonces et nouvelles ventes/approbations ; laisser les anciens droits
   prouvables et les fonctions gratuites, avec message d’état non accusateur.
2. Revenir à un artefact compatible avec les tables additives et le protocole de
   signature existant ; ne pas remettre un lecteur qui ignore la séparation A/B.
3. Conserver ledger, grants, audit, demandes et fichiers privés. **Pas de migration
   `monetization zero`** en rollback standard : elle supprimerait des preuves.
4. Reconciler les encaissements et callbacks arrivés durant l’incident avant reprise.
   Ne pas restaurer une ancienne DB par-dessus des paiements plus récents sans plan
   de rejeu/déduplication et validation.
5. Rotation de clés approuvée si compromise ; ne pas confondre restore du serveur
   et reset du compteur de droits/epoch qui permettrait un downgrade.
6. Après tests isolés, restaurer les services commerciaux par étapes, sous décision
   humaine distincte. Aucun remboursement, email, purge cloud ou déploiement lancé ici.

## Critères d’approbation du Lot 6.4A

Les dix documents sont complets et reliés ; gratuit protégé, rôle du serveur,
limites hors ligne, workflow idempotent et périmètre de canal sont explicites.
Restent à valider par le porteur : avantages, prix futurs, entité/pays, audience,
durée/reboot/appareils, choix d’identité et cumul de permissions.

**GO proposé pour revue de conception seulement.** Aucun résultat documentaire
ne vaut validation des futures fonctions. NO-GO pour déploiement, paiements, Ads
réels ou implémentation globale avant approbation explicite.
