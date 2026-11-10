# Publicités administrables — livrable 4

Tous les flags globaux, plateformes, fournisseurs, formats et emplacements sont
**False/inactifs par défaut**. Pas de SDK, script tiers, identifiant publicitaire
ou requête réseau Ads tant qu’une décision complète ne l’autorise pas.

## Formats et emplacements

| Format | Emplacement candidat | Garde-fous | Position proposée |
|---|---|---|---|
| Bannière | Accueil ou liste culturelle, sans déplacer les contrôles | Identification « Publicité », pas près du bouton audio/validation ni du clavier | Option de faible complexité, après consentement et recette |
| Native | Carte culturelle séparée visuellement du contenu éditorial | Libellé explicite, pas une fausse leçon/mot du dictionnaire | Différée, nécessite contrôle de présentation fournisseur |
| Récompensée | Écran autonome facultatif hors séance | Choix explicite, jamais clic encouragé ni récompense pour cliquer ; aucun contenu essentiel conditionné | Différée ; récompense nouvelle à approuver, vérification serveur si droit durable |
| Interstitielle | Aucun emplacement approuvé initialement | Jamais en cours de leçon, écoute, saisie ou révision ; ni lancement imposé ni reprise réseau | Désactivée, hors premier périmètre même si le modèle connaît le format |
| Parrainage direct | Carte partenaire éditorialement approuvée | Visuel/lien contrôlés, dates et consentements ; pas de tracking tiers requis | Premier candidat sans SDK, toujours soumis à activation explicite |

Exclusions non modifiables par Admin : leçons, quiz, écoute/lecteur actif, clavier
Erfe, saisie/éditeur en cours, révision SRS, parcours interactif en séance,
authentification, paiements et données personnelles. Un emplacement autorisé sur
Accueil ne l’est plus lorsqu’un lecteur audio y est actif. Le contexte est
revérifié juste avant affichage, pas seulement au chargement de l’écran.

## Catégories et limites réelles

| Sujet à éviter | Contrôle fournisseur à vérifier | Rôle de Django / limite |
|---|---|---|
| Jeux d’argent/paris | Catégories sensibles et règles d’éligibilité du compte | Politique d’interdiction, état de vérification console, pas garantie de classement |
| Adultes et contenu sexuel | Catégories sensibles, classification de contenu | Interdiction + maximum de classification souhaité ; ne garantit pas toutes les créations |
| Rencontres | Blocage de catégorie/annonceur selon réseau | Désactivé dans la politique BK ; vérifier catégories qui se recoupent |
| Alcool | Paramètres/catégories restreintes ou sensibles du fournisseur | Aucun opt-in, particulièrement pour public jeune ; pas de blocage universel simulé |
| Tabac/drogues | Politique du réseau, restrictions produits, URL/annonceur | Ne pas inventer un bouton console « tabac » présent dans tous les réseaux |
| Finance risquée, prêts prédateurs, promesses de gains | Catégories générales/sensibles disponibles + examen annonces/URLs | Interdiction éditoriale et signalement ; pas de classificateur infaillible BK |
| Tromperie et contenu éducativement inadapté | Politiques fournisseur, centre de contrôle, blocage création/URL | Retrait, coupe-circuit et suivi humain ; liste Django ≠ filtre automatiquement appliqué au réseau |

AdMob propose blocage de catégories, URLs et autres contrôles ; sa classification
automatique n’est pas garantie et dépend de langues prises en charge. Une interface
en Beřiya ne prouve pas cette couverture. Consigner console, portée du réglage,
date, opérateur et preuve de vérification ; `desired_blocked_categories` est une
intention tant que l’adaptateur/console ne la confirme pas.
[Contrôles AdMob](https://support.google.com/admob/answer/3150176?hl=en),
[catégories sensibles](https://support.google.com/admob/answer/3150953?hl=en),
[catégories AdSense](https://support.google.com/adsense/answer/186376?hl=en).

## Décision d’éligibilité commune

```text
autorisé = configuration approuvée ET fraîche
           ET flags global/plateforme/fournisseur/format/emplacement
           ET absence de kill switch
           ET compte non Premium confirmé (sinon aucune annonce)
           ET consentement et audience compatibles
           ET contexte non sensible ET aucun audio actif
           ET plafond session/jour ET délai minimal respectés
```

Échec réseau, configuration périmée, consentement inconnu ou état Premium ambigu :
**aucune annonce**. Les données personnelles et droits ne vont pas dans un cache
public. Le compteur local réduit l’exposition, sans prétendre constituer un
contrôle antifraude inviolable. Une fréquence proposée ne vaut pas approbation :
aucune valeur commerciale n’est fixée dans cette conception.

Le kill switch interdit les nouveaux chargements et retire un emplacement dès
qu’une mise à jour est reçue. Une TTL courte et une revérification au premier plan
bornent le délai **en ligne** ; aucun arrêt instantané universel n’est promis.
Ne pas précharger en avance des annonces qui pourraient réapparaître après coupure.

### Consentement, enfants et confidentialité

Audience réelle et présence d’enfants à déterminer avant choix SDK. En l’absence
de cette décision, tiers désactivés ; une publicité classée G n’est pas à elle seule
une conformité enfant. Le retrait du consentement interdit les nouvelles requêtes,
détruit les annonces préchargées et donne accès aux options de confidentialité.
Les réglages enfant/âge et UMP sont ceux effectivement requis par l’audience/région.
[UMP Flutter](https://developers.google.com/admob/flutter/privacy),
[paramètres de ciblage](https://developers.google.com/admob/flutter/targeting).

Une annonce non personnalisée n’est pas automatiquement dispensée de consentement.
Aucun historique de mots appris, erreurs, dialecte ou enregistrement vocal n’est
transmis pour cibler une annonce. Séparer l’usage de sécurité d’une clé d’appareil
des identifiants publicitaires. Aucun SDK publicitaire n’est ajouté au premier lot.
