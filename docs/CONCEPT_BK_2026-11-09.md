# Livrable 3 — Concept de modernisation à valider

Propositions fonctionnelles du 9 novembre 2026. Aucune maquette ci-dessous n’est une fonctionnalité développée. Aucun contenu Beřiya nouveau, traduction, alphabet ou correspondance phonétique n’est créé.

**Priorité pédagogique précisée : Memrise est l’inspiration principale pour l’oralité et la mémorisation ; Duolingo est secondaire pour l’UX, le parcours et la motivation.** L’oral précède l’introduction progressive du texte. Voir [l’audit audio et le cadre oral révisé](AUDIT_ORALITE_2026-11-09.md), qui complète et précise ce concept.

## Trois niveaux

| Niveau | Périmètre proposé | Effort relatif / contraintes |
|---|---|---|
| Minimal | Corriger propriété/sync/packs, conserver filtres langue, paginer le web, améliorer consignes/états et hiérarchie | Risque limité si contrats conservés ; ne fournit pas une nouvelle méthode complète |
| Intermédiaire — recommandé après sécurisation | Réutiliser thèmes/unités/flux et sessions pour deux orientations, reprise claire, petites séances, espace révision et maîtrise par élément | Ajouts ciblés et migrations additives à valider ; nécessite corpus et tests appareil |
| Avancé | Adaptation fine selon erreurs, défis facultatifs, partenariats, éventuel compte multiappareil | Uniquement après usage réel ; coût éditorial, confidentialité et exploitation plus élevés |

Recommandation : commencer au niveau minimal, puis valider les éléments intermédiaires séparément. Aucune nouvelle plateforme, microservice, moteur IA ou dépendance publicitaire n’est nécessaire pour cette trajectoire.

## Identité et navigation

Conserver le logo et la police Kedebideri, vert profond `#1B4D3E`, nuit `#0F3227`, or `#D4AF37` déjà présents. Clarifier les surfaces, réserver l’or à l’action/progression, prévoir états texte/icône en plus des couleurs et animations courtes désactivables. Lisibilité Erfe validée humainement, sans supposer qu’une police latine de remplacement convient. Pas de copie de mascotte, illustration ou composant propriétaire.

Cinq sections maximum : **Accueil · Apprendre · Réviser · Dictionnaire · Mon espace**. Packs, réglages et outils dans Mon espace ; No Ena accessible aussi depuis Accueil/ressources. Conserver toutes les URL existantes et les routes mobiles utiles, avec entrées réorganisées. L’espace personnel doit pouvoir fonctionner localement ; ne pas promettre de compte cloud avant sa conception.

## Maquettes fonctionnelles textuelles

| Écran | Ordre et actions proposés | États indispensables |
|---|---|---|
| Accueil | Brève présentation BK ; « Reprendre [titre] » ou « Choisir mon parcours » ; objectif de séance ; dictionnaire ; ressources culturelles | Première visite, reprise existante, unité indisponible, sans connexion |
| Apprendre | Choix du public ; unités en liste/carte légère ; états disponible/en cours/terminé ; prochaine leçon et durée indicative | Rien publié, pack nécessaire, contenu mis à jour, progression historique |
| Leçon | Retour/quitter ; étape/total ; un objectif ; grand texte Erfe ; audio ; une interaction ; Valider ; retour immédiat ; Continuer | Audio absent/erreur/réessai, clavier ouvert, réponse erronée, sauvegarde impossible, reprise |
| Réviser | Nombre d’éléments dus ; « Réviser quelques minutes » ; difficultés ; historique de maîtrise | Rien dû, rien encore appris, tout local, activité en attente de synchronisation |
| Dictionnaire | Recherche Erfe/Latin/traduction ; filtres ; résultats progressifs ; détail avec audio/image/exemple validé | Aucun résultat, traduction absente, média non téléchargé, résultats locaux partiels |
| Mon espace | Progression, compétences observées, objectif personnel, historique ; packs/taille/suppression volontaire ; langue ; outils ; confidentialité | Identité locale, sync en attente/échec/réussie, espace insuffisant ; aucune fausse promesse de sauvegarde cloud |

Wireframe proposé pour la leçon :

```text
Fermer                          Étape 2 / 6
Objectif de l’exercice
[Caractère ou mot validé en police Kedebideri]
[Écouter] [Réécouter]
[Choix OU clavier Erfe — une interaction]
[Valider]
Feedback explicite puis [Continuer]
```

Ne pas substituer une autre unité quand le contenu manque. Une session doit pouvoir se terminer sans être déclarée maîtrisée ; conserver les anciens succès et leur version de calcul.

## Méthode BK proposée

**ÉCOUTER d’abord**, puis mobiliser VOIR, RECONNAÎTRE, COMPOSER, RÉVISER et UTILISER selon le public et les performances : un répertoire d’actions, pas six écrans obligatoires à chaque séance. Séances de 3–5 minutes comme cible à mesurer. Réutiliser les exercices existants ; ralentir ou répéter les difficultés sans bloquer l’apprenant. Aucun dessin manuscrit, tracé au doigt ou reconnaissance de gestes.

**Parcours A : Je parle Beřiya, j’apprends l’Erfe.** Partir de l’oral familier, associer les sons authentiques aux caractères typographiques, former des syllabes validées, composer des mots au clavier, lire/saisir des phrases validées, puis évaluations et révisions. **Parcours B : J’apprends à parler Beřiya et à utiliser l’Erfe.** Commencer par compréhension et pratique orale en contexte validé, puis introduire progressivement lecture et saisie. Pratique de prononciation libre sans notation automatique ; aucune reconnaissance ni synthèse vocale fiable présumée. Partager les mêmes objets de contenu quand ils sont adaptés ; ne pas dupliquer le corpus pour matérialiser les parcours. Les données locales ne suffisent pas à annoncer ces programmes complets.

Pour chaque activité, un responsable humain valide texte, sens, transcription, son, image et distracteurs. Ne pas déduire automatiquement une syllabe du simple assemblage de deux caractères : le générateur actuel utilise les deux premiers caractères et le mot cible, ce qui nécessite une vérification éditoriale de cohérence.

Première écoute disponible dès l’entrée, réécoute illimitée et bouton identifiable. Variantes/locuteurs conservés avec provenance et droits documentés. Vidéo naturelle facultative avec consentements vérifiés, téléchargement explicite et alternative audio ; ne jamais l’imposer quand l’audio suffit. Auditer qualité, licences et couverture **avant** construction d’exercices et enrichissement des médias.

Répétition espacée proposée : états nouveau/appris/à revoir par élément, échéance locale, rappel actif, réponse/erreur enregistrée et version de règle. Commencer par des intervalles simples configurables et validés pédagogiquement ; aucun algorithme n’est présenté comme déjà développé. Calendrier utilisable hors ligne, fusion différée par événements identifiés à concevoir, horloges erronées testées.

Gamification : progression de maîtrise, objectif hebdomadaire volontaire, célébration courte et badge explicite ; XP éventuels liés à l’activité sans confondre XP et compétence. Pas de vies bloquantes, pénalité de série, classement forcé ou sanction du mode hors ligne. Défis facultatifs seulement après retours utilisateurs.

## Hors ligne, coût et financement

Priorité à la lecture locale, téléchargement explicite avec taille/état, reprise après interruption et synchronisation différée. Réutiliser les services existants et le stockage actuel avant d’ajouter une base locale ou un service. Compresser seulement des copies dérivées après mesures et écoute humaine ; préserver les originaux et le corpus. Évaluer taille APK et mémoire avant suppression de dépendances/polices.

Monétisation ultérieure : interface indépendante de fournisseur, état désactivé par défaut, emplacements éventuellement sur accueil/fin de séance, aucun au milieu d’un exercice, aucune lecture sonore ou clic encouragé. Sponsoring identifié et séparé du contenu linguistique. Aucun SDK, publicité réelle ni traçage ajouté. Avant activation, vérifier les règles Google Play/AdMob alors en vigueur, public d’âge, consentement, confidentialité et déclarations ; conformité actuelle non certifiée ici. Fonctions éducatives essentielles accessibles et option de désactivation à étudier.
