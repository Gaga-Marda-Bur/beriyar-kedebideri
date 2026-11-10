# Gratuit / Premium — livrable 3

**Proposition à arbitrer, aucune fonction n’est rendue payante.** Le minimum
gratuit comprend aussi tout ce qui est déjà gratuit, au-delà de la liste essentielle.

| Fonction | Socle gratuit à conserver | Avantage Premium éventuellement nouveau | Décision |
|---|---|---|---|
| Alphabet Erfe, typographie, clavier, translittération | Toutes les fonctions existantes | Aucun retrait ou quota | Gratuit protégé |
| Dictionnaire essentiel et ressources validées existantes | Recherche, lecture et audio disponibles | Aucun verrouillage du corpus existant | Gratuit protégé |
| Parcours A/B, initiation, écoute et exercices de base | Accès actuel et fonctions fondamentales | Éventuels services supplémentaires distincts | Gratuit protégé |
| Progressions acquises, historique, sync et SRS existants | Consultation, conservation, révisions et comportement actuel | Aucune rançon pour retrouver sa progression | Gratuit protégé |
| Packs existants et mode hors ligne actuel | URLs, ZIP et droits actuels conservés | Aucun changement rétroactif de statut | Gratuit protégé |
| Éditeur, exports PDF/image et Sticker Studio actuels | Même périmètre, y compris style nommé `premium` | Nouveaux outils avancés ou créations **supplémentaires**, si utiles | Option future à définir |
| Suppression des futures annonces | Aucune annonce si Ads est désactivé ; jamais pendant apprentissage | Tout Premium actif serait sans publicité | Candidat initial, pas de prix choisi |
| Badge de soutien | Profil actuel inchangé | Badge facultatif associé à un plan approuvé, sans classement obligatoire | À valider ; pas un « don sans contrepartie » si vendu avec un avantage |
| Services d’accompagnement nouveaux | Apprentissage autonome gratuit | Service humain réellement disponible, périmètre distinct | À étudier ; aucune promesse de locuteurs/prestations non organisées |
| Nouveaux contenus/packs additionnels | Contenus gratuits actuels intacts | Éventuel catalogue nouveau, validé, livré en privé | **Différé**, pas éligible au premier lot |

### Invariants techniques

`FreeAccessPolicy` est appliquée côté serveur et client, avant la configuration
commerciale. L’Admin peut publier de nouvelles offres mais ne peut pas transformer
un code essentiel/existant gratuit en paywall. Pas de vies, de rupture de série,
de blocage de leçon ou d’exercice manuscrit pour monétiser une difficulté.

Un plan actif et ses fonctions ne sont pas codés par leur prix dans Flutter.
Le client affiche des offres reçues du serveur et n’active un avantage que selon
un droit effectif ; un code inconnu ne débloque pas arbitrairement une interface.
Le serveur protège toute opération privilégiée même si le client est modifié.

### Après expiration ou révocation

Conserver le corpus local, les packs téléchargés, les réponses, SRS et progressions.
Les fonctions actuelles restent utilisables. Recommandation pour de futurs packs
supplémentaires : conserver la lecture déjà acquise, arrêter seulement de nouvelles
acquisitions selon le contrat approuvé. Ne pas promettre simultanément une lecture
permanente et une révocation totale des fichiers téléchargés.

Un statut commercial inconnu n’est pas affiché comme une dette ou une perte de
maîtrise. Prévoir « À revérifier à la reconnexion », distinct d’expiré confirmé.
Annuler le renouvellement ne retire pas un droit payé encore dans sa période.

### Pourquoi les packs payants sont différés

Les packs publiés actuels ont des URLs publiques : les masquer dans Flutter ne les
protège pas. Une future ressource payante aurait son propre cycle approuvé, stockage
privé, contrôle serveur et endpoint de téléchargement, éventuellement URL signée
à durée courte. Réutiliser backend privé et validateurs de 6.3, **pas les endpoints
feedback**. Ne pas publier son URL via les serializers historiques ni réutiliser
un numéro de version/ZIP existant avec un autre contenu. L’authentification serveur
et les contrôles de corpus publié restent obligatoires. Ce chantier demande une
conception complémentaire et une recette avec anciens clients avant activation.
