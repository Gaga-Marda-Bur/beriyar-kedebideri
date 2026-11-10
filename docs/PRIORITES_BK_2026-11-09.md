# Livrable 4 — Matrice de priorisation

Proposition du 9 novembre 2026. H/M/F = haut/moyen/faible. Complexité relative pour ce dépôt, pas devis. Coût financier = coût récurrent supplémentaire envisagé ; le temps de développement et de validation humaine reste à financer. « 0 prévu » n’est pas une garantie de gratuité.

| Amélioration | Utilisateur | Pédagogie | Risque technique | Complexité | Coût récurrent additionnel | Dépendances | Priorité | Tests requis |
|---|---|---|---|---|---|---|---|---|
| Audit sons/droits/couverture avant enrichissement | H | H | F en lecture seule | M–H validation humaine | Temps locuteurs à chiffrer | Fichiers sources, preuves de droits, responsables du corpus | Prérequis | Existence, décodage, écoute humaine, provenance, autorisations et rôles |
| Export audio leçons/quiz N14/N15 | H | H | M | M | 0 prévu | Contrat des modèles et rôles existants | P1 | Leçon avec items dans ZIP, rôle question, parité API/pack, mode avion |
| Propriété installation et récupération historique N01/N02 | H | M | H, transition d’identité | H | 0 prévu | Décision récupération, sauvegarde | P0 | Historique sans jeton, jetons concurrents, isolation compte/appareil, course transactionnelle |
| Validation des entrées sync N03 | H | M | F | F | 0 prévu | Contrat d’erreur compatible mobile | P1 | Types malformés, bornes, aucun 500 |
| Catalogue local indépendant N06 | H | H | F | F | 0 prévu | Lecteur local existant | P1 | API indisponible + packs locaux, navigation Mes packs |
| Garde-fou sans tracé N07 | H | H | M | M | 0 prévu | Politique anciens packs et API | P1 | API true, ancien ZIP tracing, flux sans tracé, scores historiques préservés |
| Complétude audio et validation N10 | H | H | F code / H éditorial | M–H | Enregistrements/stockage à chiffrer | Locuteurs, comité linguistique | P1 | Validation humaine, liens/médias et publication |
| Lots et reprise sync N09 | H | M | M | M | Trafic à mesurer | Propriété corrigée | P1 | 0/1/100/101 items, reprise, rejet partiel, idempotence |
| Téléchargement borné/manifestes N08 | H | H | M | M–H | Trafic/CDN à mesurer | Contrat packs/version, appareil test | P1 | Coupure, disque plein, gros ZIP, checksum, chemins hostiles, mise à jour |
| Pagination web N04 | H à l’échelle | M | F–M | M | Potentiellement réduit le trafic | Ordre stable et URLs | P1 avant croissance | 0/1/51/1001 mots, filtres, performances avant/après |
| Langue/filtres N05 et consignes N11 | H | H | F–M | M | 0 prévu hors validation UI | Traductions UI, fallback explicite | P2 | FR/EN/AR, RTL, recherche préservée |
| Santé API distincte du contenu N12 | M | M | F–M | M | 0 prévu | Délais et comportement réseau définis | P2 | 200 vide, lenteur, 503, offline, reprise |
| Contrats entre flux et générateurs N13 | M | H | M | M | 0 prévu | Inventaire usages externes | P2 | Parité Python/Dart/API/ZIP, dépendances fermées |
| Navigation/reprise/titres accessibles | H | H | M | M | 0 prévu | Validation maquette + corpus | P2 | Routes, zoom, TalkBack, novice, clavier |
| Deux orientations pédagogiques | H | H | M | H éditorial | Contenu humain à chiffrer | Programme validé, composants existants | P2 après socle | Objectifs, séance complète, absence de faux contenu |
| Révision espacée par élément | H | H | H | H | 0 prévu au départ | Modèle additif, calendrier/fusion validés | P2 après parcours | Échéances, horloges, redémarrage, fusion, conservation historique |
| Publication Android | H | H | H opérationnel | H recette | Comptes/services à vérifier | Signature existante, politique vie privée, appareils | P1 avant diffusion | APK signé, mise à jour sans perte, mode avion, permissions |
| XP/badges/défis facultatifs | M | M à confirmer | M | M | 0 prévu | Mesure d’usage et définition maîtrise | P3 | Aucun blocage, pas de double attribution, offline |
| Publicité/sponsoring désactivés | F immédiat | F | M confidentialité | M | Fournisseur non choisi | Public d’âge, consentement, conformité future | P3 | Aucun appel pub par défaut, aucune interruption, désactivation |

Ordre conseillé : sécurité et préservation → accès fiable → corpus publiable → simplification → méthode/révision → enrichissements. Éviter de financer un redesign complet avant d’avoir rendu les unités existantes utilisables et vérifiées.

L’oralité est prioritaire dans chaque étape : première écoute accessible, réécoute, compréhension orale puis lecture/saisie progressive. Enrichissement vidéo uniquement si utile et consenti, avec alternative audio. Voir [le complément](AUDIT_ORALITE_2026-11-09.md).
