# Conformité par canal et fournisseur — livrable 8

Sources officielles consultées le **10 novembre 2026**. Cette étude ne constate
aucune inscription BK, autorisation Store, compte marchand ou conformité juridique
validée. Recontrôler les règles à chaque publication ; la politique doit être
versionnée par canal/storefront, pas figée dans une règle pays arbitraire Flutter.

## Canaux et achats numériques

| Canal | Analyse et position proposée |
|---|---|
| Site web Django | Paiements manuels ou PSP possibles après vérification du porteur/pays/contrats et obligations ; aucun encaissement préparé ici |
| Android APK direct hors Google Play | Canal distinct à étudier ; les exigences de facturation Play ne s’appliquent pas automatiquement à une distribution web ; les autres lois/contrats demeurent |
| Android Google Play | Biens et fonctionnalités numériques achetés dans l’app relèvent normalement de Play Billing. Mode consommation seule possible ; reconnaître des droits existants sans proposer une vente externe non autorisée. Exceptions/programmes territoriaux à vérifier avant chaque build, pas activés par un simple header |
| iOS App Store | IAP est la règle générale pour le numérique. Ne pas qualifier automatiquement BK de Reader. Services multiplateformes et exceptions storefront ont leurs conditions propres ; une stratégie Android consommation seule n’est pas une autorisation Apple |

Ces principes proviennent de la [politique Payments Google Play](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
et des [App Review Guidelines Apple, §3.1.1/3.1.3](https://developer.apple.com/app-store/review/guidelines/).
Les pages publiques ne remplacent pas la validation du cas BK ni l’adhésion aux
programmes applicables. Ne pas annoncer « conforme 100 % ».

Un paiement espèces/mobile money reste un achat numérique s’il débloque Premium.
Un « code d’activation », QR, WebView, lien de support, bannière ou page distante
ne doit pas servir à déguiser un tunnel externe interdit. Les règles peuvent
différer selon storefront et programme approuvé ; ne pas présumer l’exception.

Pour une véritable contribution sans contrepartie, distinguer don, pourboire et
achat. Éligibilité nonprofit, collecte, reçu fiscal et règles Store doivent être
vérifiés ; aucun statut fiscal BK n’est établi. Donner un badge/avantage en échange
change la qualification à examiner. [Apple, §3.2](https://developer.apple.com/app-store/review/guidelines/).

## Fournisseurs candidats, sans sélection commerciale

| Candidat | Usage envisagé | Conditions et inconnues BK |
|---|---|---|
| Parrainage interne | Créatif culturel contrôlé, sans SDK réseau | Contrat, droits des visuels, identification de l’annonce et contenu revus ; pas une garantie légale absolue |
| AdMob | Android puis éventuellement iOS | Compte/app éligibles, SDK et règles audience à vérifier, consentement, contrôles console et qualification des annonces ; aucune garantie de revenu |
| AdSense | Web uniquement | Éligibilité du site et emplacement, confidentialité et règles de contenu ; pas un SDK mobile de remplacement |
| Banque/mobile money/espèces | Instructions administrées et rapprochement manuel | Banque/opérateur et pays réellement disponibles, compte du bénéficiaire autorisé, reçus et obligations locales à confirmer ; pas d’opérateur inventé pour un pays |
| Stripe | Éventuel paiement web hébergé | Pays de l’entité marchande, KYC, compte de règlement, devises et méthodes ; clientèle diaspora ne prouve pas l’éligibilité du marchand |
| CinetPay | Éventuel PSP régional après étude | Pays d’établissement et services accessibles, devise/moyen réellement proposés, contrat, rapprochement et sandbox ; aucune couverture universelle Tchad/Soudan/Libye présumée |
| Play Billing / Apple IAP | Futures ventes Store si retenues | Produits créés dans consoles, receipt/token vérifié serveur, notifications, remboursements, périodes et restauration ; aucun produit ni SDK configuré ici |

Disponibilité marchande : [Stripe Global](https://stripe.com/global),
[conditions de service CinetPay](https://cinetpay.com/legal/cgu-services).
La page CGU CinetPay était disponible par extrait de recherche mais son ouverture
complète a renvoyé 403 : ce document ne prétend donc pas en valider toutes les
conditions. La page support pays/devise a également renvoyé 502 à l’ouverture ;
ses extraits ne valent pas accord marchand BK. Éligibilité web :
[AdSense](https://support.google.com/adsense/answer/9724?hl=en).
Les tarifs, commissions, fiscalité et disponibilité BK restent à chiffrer après
identification de l’entité et du pays. Pas de prix affiché ou de fournisseur final
retenu sur la base de cette seule étude.

## Publicité et données

AdMob classe automatiquement ses annonces ; ses blocages ne sont pas exhaustifs.
Les catégories/langues effectivement couvertes doivent être vérifiées dans la
console ; Django enregistre la politique et sa validation, pas une promesse de
filtrage sémantique. [Contrôles officiels](https://support.google.com/admob/answer/3150176?hl=en).

Les annonces non personnalisées peuvent encore utiliser identifiants/cookies et
nécessiter un consentement. `npa=1` ne justifie pas de charger un SDK malgré un refus.
[AdMob, personnalisé/non personnalisé](https://support.google.com/admob/answer/7676680?hl=en).

UMP actualise l’état de consentement et fournit un contrôle avant requête Ads ;
prévoir retrait et options de confidentialité. Le ciblage enfant et la classification
de contenu sont des réglages distincts. L’audience réelle BK doit être définie,
sans collecte de date de naissance complète par défaut.
[UMP Flutter](https://developers.google.com/admob/flutter/privacy),
[ciblage Flutter](https://developers.google.com/admob/flutter/targeting).

Sur iOS, la permission de suivi ATT, si l’usage prévu relève du suivi, est distincte
du consentement publicitaire ; ne pas contourner un refus par fingerprinting.
[Apple ATT](https://developer.apple.com/documentation/apptrackingtransparency).
Déclarations de confidentialité/App Privacy/Data Safety doivent décrire le SDK et
les traitements **réels**, pas seulement ceux du code BK. Pas d’analyse de voix,
mot appris, difficulté pédagogique ou dialecte pour cibler des annonces.

## Contrôle de canal et garde-fous backend

Le serveur expose seulement les offres approuvées pour la politique de canal,
mais un paramètre `channel=web` ou `DISTRIBUTION_CHANNEL` n’est pas une preuve
d’origine inviolable. La conformité Store repose aussi sur le build publié et
ses écrans : aucun lien externe interdit, même reçu par configuration distante.
Les droits sont accordés après preuve financière/administrative, jamais parce
que le client affirme venir d’un canal plus permissif.

Un paiement Store futur doit vérifier produit, application/bundle, environnement,
transaction, statut autoritatif et liaison au compte ; événements de renouvellement,
remboursement et révocation dédupliqués. Ne pas envoyer les secrets PSP dans le
binaire : page hébergée approuvée ou adaptateur serveur, avec simulation d’abord.

**NO-GO activation** sans revue du pays marchand, audience, canal et produit exacts,
ainsi que levée des blocages de production de Phase 6.3.
