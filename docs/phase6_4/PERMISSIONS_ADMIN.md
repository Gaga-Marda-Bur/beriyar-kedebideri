# Permissions et contrôle d’accès — livrable 7

Permissions nouvelles proposées sous `monetization.*`, absentes aujourd’hui.
Réutiliser groupes et `has_perm` Django, avec portée d’objet/organisation si nécessaire.
**`is_staff` donne accès à l’Admin, pas automatiquement aux pouvoirs commerciaux.**

| Opération | Configuration | Finance vérification | Approbation droits | Support | Audit |
|---|---|---|---|---|---|
| Lire politique non sensible | Oui | Oui | Oui | Oui | Oui |
| Préparer offre/placement/fréquence | `change_policy_draft` | Non | Non | Non | Lecture |
| Publier configuration/coordonnées | `approve_policy` distinct ; double contrôle recommandé | Consultation coordonnées autorisées | Non | Non | Lecture |
| Lire justificatif/relevé | Non par défaut | `view_payment_evidence` | Minimum nécessaire à la décision | Métadonnées masquées | Selon nécessité/mandat |
| Marquer encaissement vérifié | Non | `verify_payment` | Non par défaut | Non | Lecture |
| Approuver paiement et octroyer | Non | Pas avec seul verify | `approve_payment` + `grant_entitlement`, objet vérifié | Non | Lecture |
| Geste/bourse | Non | Non | `grant_complimentary` / `grant_scholarship`, motif et limites | Demande seulement | Lecture |
| Révocation | Non | Signaler litige | `revoke_entitlement` + motif | Signaler | Lecture |
| Confirmer remboursement financier | Non | `record_refund`, confirmation réelle | Pas avec seul grant | Non | Lecture |
| Lire état d’un compte tiers | Non | Scope financier nécessaire | Scope d’approbation | `view_support_summary`, masqué | `view_audit`, limité |
| Modifier/supprimer audit | Non | Non | Non | Non | Non |
| Arrêt d’urgence Ads | `disable_ads_emergency` | Rôle assigné explicitement si souhaité | Rôle assigné explicitement | Signalement ; pas activation | Lecture |

Les noms sont conceptuels : choisir les codenames définitifs avant migration.
Les permissions de création/modification Django standard ne doivent pas permettre
de contourner les transitions métier. Champs statut, approved_by, bénéficiaire,
montant vérifié et grant en lecture seule après soumission ; pas d’inline modifiable
ni d’action groupée générique pouvant activer plusieurs comptes sans service.

## Règles applicables à toutes les voies

- Chaque action vérifie permission, portée, état courant et acteur **dans le service**,
  puis verrou/contrainte DB ; ne pas se reposer seulement sur `ModelAdmin`.
- L’utilisateur ordinaire ne voit que `user=request.user`. UUID difficile à deviner
  ne remplace pas un filtre de propriété. Le client ne peut choisir bénéficiaire,
  source, prix effectif ou statut financier via un PATCH.
- Compte invité : aucune lecture personnelle financière. Le secret de progression
  ne donne pas accès aux demandes, reçus, notifications ou droits d’un compte.
- Auteur/bénéficiaire n’auto-approuve pas son propre avantage. La politique maker/
  checker et l’éventuel cumul de permissions pour petite équipe sont explicitement
  approuvés, audités et testés. Pas de compte partagé.
- Principal webhook/job : capacités techniques minimales, pas un superuser caché.
  Une signature valide ne dispense pas du contrôle marchand/environnement/produit.
- Authentification forte, timeout session et revue d’accès pour finance ; ne pas
  prétendre que la présence de MFA est déjà acquise dans le Django actuel.
- CSRF maintenu pour sessions/Admin ; aucune exemption globale « pour Flutter ».
  Seuls les futurs callbacks fournisseurs ont leur propre authentification dédiée.

## Audit et pouvoirs irréductibles

Événements avec acteur, motif, cible opaque, corrélation, dates et différences de
champs utiles ; masquer secrets et données personnelles excessives. Les événements
de décision sont écrits dans la même transaction que le grant. Les lectures de
pièces sensibles peuvent avoir une trace d’accès distincte à rétention limitée.

Lecture seule dans Admin et absence d’API DELETE protègent l’usage normal, pas un
propriétaire DB ou un superuser capable d’écrire du code. Restreindre les comptes
DB et accès système ; journal externe ou scellement envisageable après besoin
réel, sans annoncer une immutabilité absolue. Les suppressions légales/anonymisations
sont des procédures explicites et tracées, pas une cascade supprimant les paiements.
