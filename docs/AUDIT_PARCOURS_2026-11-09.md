# Livrable 2 — Parcours actuels et audit UX/UI

**Cadrage précisé :** l’entrée pédagogique doit être orale, selon les parcours A (locuteur → Erfe) et B (oral débutant → Erfe progressif). Memrise est l’inspiration principale ; Duolingo reste secondaire pour l’UX. Les sons sont disponibles dès l’entrée et répétables, les vidéos facultatives. Voir [le complément audio](AUDIT_ORALITE_2026-11-09.md) pour les capacités effectivement observées et les limites de couverture.

9 novembre 2026. Revue des templates/CSS, widgets/routes, tests de composants et rendu HTML du client Django. Aucun parcours navigateur interactif ni application sur téléphone observé aujourd’hui. Les jugements visuels sont des hypothèses de conception à confronter à un rendu réel ; aucune capture ni certification WCAG n’est annoncée.

## Site web

Parcours actuel observé : accueil → parcours → détail d’unité → consultation de ressources ; quiz via une page distincte. `unit_detail.html` présente des leçons, caractères, mots et questions, sans reproduire la séance Learning Core Flutter. Mesurer le temps avant le premier exercice nécessite une recette humaine ; compter les liens ne donne pas une durée fiable.

| Axe | Éléments observés | Difficulté / vérification restante |
|---|---|---|
| Première impression et identité | Logo, vert/or, signature, mission, APK, ressources No Ena | Plusieurs appels concurrents à l’action ; compréhension à tester avec débutants |
| Navigation | Mission, Parcours, Alphabet, Vocabulaire, No Ena, Feedback, Quiz, Studio, Éditeur dans `base.html` | Plus de cinq destinations principales ; effort de découverte élevé probable |
| Hiérarchie et lisibilité | Polices Kedebideri, cartes, styles partagés `brand.css` | Contrastes des surfaces transparentes, lignes longues et taille réelle Erfe non mesurés |
| Adaptation mobile | Menu mobile avec état ARIA et bouton, CSS responsive | Zoom 200 %, petits écrans, RTL, focus et TalkBack à vérifier |
| Langues | FR/EN/AR et `dir=rtl`, préférence session | Liens langue suppriment recherche/filtres ; transcription ne doit pas changer avec traduction |
| Dictionnaire | Champ q, catégories, texte/transcription/traduction, audio et état sans son | Tout le résultat rendu ; illustration non intégrée dans ce template ; exemples à rendre si validés |
| Feedback de réponse | Quiz JavaScript avec correction immédiate et audio partagé | Vérifier annonce vocale, compréhension de l’erreur, absence de dépendance à la couleur |
| États vides et erreurs | États sans résultat/sans audio, formulaire feedback | Distinguer absence de corpus publié, absence réseau et filtre trop restrictif |
| Motivation | Présentation de thèmes/unités et ressources culturelles | Pas de reprise personnelle web ni file de révision identifiées |

Parcours dictionnaire : ouvrir Vocabulaire → saisir une recherche → filtrer → écouter. Le changement de langue réinitialise la recherche ; corriger ce point conserve un parcours existant utile. Préserver les liens et fournir une pagination avec URL partageable.

## Application Flutter

Parcours initial : accueil sans progression → « Commencer » → écran des thèmes/unités → ouverture d’une unité. Avec progression, l’accueil affiche une carte de reprise vers `/unit-practice`, routée vers `LearningCoreUnitScreen`. Il existe aussi un écran historique `unit_practice_screen.dart` : sa présence ne prouve pas qu’il est le parcours actuellement routé.

| Axe | Éléments observés | Difficulté / vérification restante |
|---|---|---|
| Accueil | Reprise, indicateur connexion, accès Contenus/Alphabet/Vocabulaire/Réglages | Carte de reprise affiche le slug ; préférer le titre localisé validé |
| Navigation | Routes nommées, hub de contenus, retour par pile | Packs et ressources répartis entre hub, catalogue et « Mes packs » ; tester leur découvrabilité |
| Première leçon | Thèmes puis unités, flux un exercice à la fois | Pas de choix explicite entre deux publics ; pas de durée réellement mesurée |
| Consignes | Audio accessible, discrimination, fusion, saisie clavier | Consignes Learning Core souvent en français, même si UI EN/AR |
| Réponses et reprise | Moteur LearningSession, seuil, score, historique, reprise persistante | Tests de maîtrise/reprise réussis ; réception pédagogique du feedback non évaluée |
| Motivation | Écran de bilan, progression visible, statut review | Pas de répétition espacée opérationnelle ni objectifs hebdomadaires identifiés |
| Chargements/erreurs | FutureBuilder, retry, badge source mémoire/cache/pack, messages d’indisponibilité | Un nom technique de source peut peu aider un débutant ; afficher plutôt disponibilité hors ligne et prochaine action |
| Dictionnaire | Recherche à chaque frappe, bouton recherche, liste, traduction avec fallback | Absence de debounce visible ; fréquence réseau et rendu sur gros corpus à profiler |
| Accessibilité | Tokens tactiles, test clavier compact, prise en compte RTL | Tokens ne prouvent pas conformité de chaque contrôle ; TalkBack/grandes polices manquants |
| Audio/images | Lecteur avec états, `SmartImage` distant/local, résolution de médias packs | Cache JSON ne télécharge pas automatiquement tous les médias ; mode avion réel requis |
| Hors ligne | Cache mémoire/persistant, packs locaux, Mes packs | Catalogue attend le réseau avant sa liste locale ; téléchargement en mémoire |
| Erfe | Police embarquée, clavier dédié, utilitaires UTF-16 | Caractères combinants, sélection partielle et clavier flottant réel à tester |

Parcours hors ligne attendu à recetter : télécharger → vérifier taille/fin → ouvrir unité → couper réseau → tuer application → reprendre → terminer → reconnecter → synchroniser. Les tests unitaires en couvrent des parties ; ils ne constituent pas cette recette complète.

## Protocole de recherche utilisateur proposé

Deux groupes distincts : locuteurs Beřiya non lecteurs Erfe ; débutants de la langue. Confier à chacun cinq tâches : commencer une leçon, reprendre après arrêt, chercher un mot, écouter un son, retrouver un pack en mode avion. Relever réussite autonome, hésitations, erreurs, nombre d’actions et temps jusqu’au premier exercice. Viser une première activité en moins d’une minute comme **objectif proposé**, pas comme mesure actuelle. Aucun enregistrement personnel ni télémétrie supplémentaire avant décision de confidentialité.

Conserver éditeur, PDF/partage, studio sticker, No Ena et feedback dans les ressources secondaires ; leur valeur culturelle ne doit pas être perdue lors du regroupement de navigation.
