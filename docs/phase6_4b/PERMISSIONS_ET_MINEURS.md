# Permissions et audience mixte — état implémenté

11 novembre 2026. `is_staff` seul ne permet aucune transition commerciale.
Les permissions standard `view_*` donnent séparément accès aux écrans de lecture
Admin. Aucun groupe ni privilège utilisateur existant n'est changé par migration.

| Opération | Permission explicite supplémentaire | Contrôle |
|---|---|---|
| Configuration politique/plans/fonctions/méthodes/placements | `configure_commerce` | Validation modèle, simulation seulement, audit Admin ; caractéristiques utilisées figées, arrêt des nouvelles simulations toujours possible |
| Modifier classification déclarative d'un compte | `configure_commerce` + `review_protected_account` | subject, propriétaire et epoch non éditables ; audit ; aucune preuve juridique présumée |
| Arrêt d'urgence | `disable_ads_emergency` | Action spécifique, version incrémentée ; ne révoque pas les droits |
| Créer demande achat/don simulée, vérifier | `verify_payment` | Demande pending, référence SIM-* unique, pas d'avantage pour un don |
| Créer geste / bourse | `grant_complimentary` / `grant_scholarship` | Pas de méthode ni transaction financière artificielle |
| Activer achat simulé | `approve_payment` + `grant_entitlement` | Demande verified, approbateur distinct du créateur, du vérificateur et du bénéficiaire |
| Activer geste / bourse | Permissions d'activation + permission de geste/bourse correspondante | Demande pending ; décision indépendante et tracée |
| Activation concernant âge minor/unknown | En plus `review_protected_account` | Contrôle serveur, motif requis ; reste une simulation, pas un consentement parental |
| Refuser / annuler pending | `approve_payment` | État vérifié, opérations idempotentes |
| Remboursement simulé | `record_refund` | Seulement achat/don vérifié ou activé ; retire les seuls grants de la demande |
| Révoquer droit / appareil | `revoke_entitlement` | Action spécifique ; epoch de droits incrémenté pour une révocation de grant |
| Modifier/supprimer directement ledger/grants/audit/outbox | Interdit via Admin | Même les permissions CRUD standard ne permettent pas de contourner les transitions |

Tout service de mutation contrôle aussi acteur actif, permission, motif, état,
propriété du bénéfice et environnement. Verrous PostgreSQL et contraintes uniques
complètent l'interface. Audit/grant/epoch/outbox sont transactionnels. La répétition
d'une transition valide ne crée pas une deuxième activation. L'Admin demande de
sélectionner une seule demande par action ; pas d'octroi groupé implicite.

Pour la recette : attribuer explicitement `view_commercialrequest` au vérificateur
et à l'approbateur pour accéder à la liste ; leurs capacités métier restent celles
ci-dessus. L'approbateur ne peut pas être le maker/checker du même dossier, même
en cumulant les permissions. Les rôles sont des comptes distincts, sans compte
partagé. Les superusers/administrateurs DB restent des autorités irréductibles ;
le journal n'est pas annoncé inviolable contre un propriétaire de base.

## Protection des mineurs appliquée

- Un seul champ de classification `unknown/minor/adult`, **unknown par défaut** ;
  aucune date de naissance, identité parentale ou donnée d'âge dans les API publiques.
- Pas d'écran incitant à se déclarer adulte, pas de route client pour relever son
  âge, aucun compteur publicitaire ni profilage d'erreurs/mots/dialectes pour Ads.
- Ads, suivi, personnalisation et collecte d'identifiant publicitaire **interdits
  pour tous**, y compris adult. Les paramètres stockés préparent une configuration,
  mais ne peuvent pas initier de requête réseau publicitaire : aucun adaptateur/SDK.
- Mineur ou âge inconnu : permission de revue renforcée pour une activation fictive,
  approbateur indépendant, motif et audit. Une déclaration adult n'est pas une
  certification d'âge ; elle n'autorise ni publicité ni paiement réel.
- Aucun indicateur « consentement parental obtenu » artificiel. L'API déclare
  explicitement le dispositif non implémenté et n'en présume aucun consentement.
- L'identifiant de clé d'installation sert uniquement à la possession des droits,
  jamais au ciblage. L'identité de boot reste locale. Le registre est supprimé
  à la suppression du compte ; les preuves financières simulées restent orphelines
  sous subject opaque, à traiter selon la future politique de rétention.

## Conditions futures, non activées

Avant un réseau publicitaire ou une vente, définir pays d'établissement et pays
de distribution, âges locaux applicables, déclaration d'audience Play, politique
de confidentialité/rétention, éventuelle classification neutre et procédure
appropriée de consentement/représentation. États proposés pour ce futur dispositif :
non demandé, revue requise, vérifié par procédure approuvée, retiré/expiré ; aucun
n'est simulé comme une validation réelle dans ce lot.

Pour une audience mixte, la [politique Google Play Families](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
impose notamment des exigences relatives à l'âge, aux données et aux SDK autorisés
pour enfants/âge inconnu. Référence officielle relue le 11 novembre 2026 ; la
certification concerne les versions de SDK approuvées, pas une garantie générale
BK. L'absence actuelle de publicité réduit l'exposition mais ne certifie pas toute
la conformité légale des fonctionnalités pédagogiques existantes. Les seuils et
obligations varient ; aucune juridiction marchande n'est inventée.

La [déclaration d'audience Play](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en-GB)
doit correspondre au public réel. Une simple case Admin ne remplace ni cette
déclaration ni un consentement applicable. Toute connexion future exige une
validation distincte ; aucun contournement par espèces, WebView ou QR paiement.
