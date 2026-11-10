# Proposition de pilote A — De l’oral à l’Erfe

Proposition fonctionnelle après validation locale de N14/N15, le 9 novembre 2026. **Pas d’unité créée en base, de pack pédagogique publié ou de nouveau contenu Beřiya produit.** Le ZIP des tests contient uniquement du silence synthétique et n’appartient pas au corpus pédagogique.

Public : **« Je parle Beřiya, j’apprends l’Erfe. »** Ce pilote ne remplace pas le parcours B, destiné à l’acquisition orale puis à l’Erfe progressif. La méthode est inspirée principalement de Memrise ; l’UX pourra suivre les principes de clarté et de reprise de Duolingo sans copie graphique.

## Ressources locales réellement mobilisables

Lecture SQLite `mode=ro` pendant ce lot : deux caractères actifs publiés, ID 1 (`U+16EA0`, `𖺠`) et ID 2 (`U+16EA1`, `𖺡`). Le caractère ID 1 possède un lien audio publié vers `audio_assets/files/arkap.wav`. Le caractère ID 2 n’en possède pas.

Le seul mot actif publié, ID 1, contient également `𖺠` et utilise le même WAV. Ce sont deux enregistrements de données, **pas deux formes audio distinctes**. La pertinence de son classement comme mot, son sens, sa valeur phonétique et son usage dans un exercice sont à confirmer par le responsable linguistique. Aucun nom de son, traduction ou rapprochement phonétique n’est déduit du fichier.

Le second AudioAsset local est un prompt de quiz, pas une preuve de prononciation supplémentaire couvrant le pilote. Les autres caractères/mots ne sont pas considérés validés pour le pilote sur la seule base de leur existence. Le statut `published` est une piste éditoriale, pas une nouvelle attestation d’authenticité ou de droits faite par cet agent.

## Cible : 12 éléments, sans remplir artificiellement les manques

| Emplacements | Type envisagé | Ressources et décision attendues |
|---|---|---|
| C1 | Caractère familier | Candidat existant ID 1 ; confirmer valeur/son, licence et consentement du WAV |
| C2 | Caractère contrastif | Candidat existant ID 2 ; enregistrement authentique et validation d’association nécessaires |
| C3–C4 | Deux autres caractères | Choix et validation par locuteurs/enseignants ; sons à fournir ou retrouver dans sources autorisées |
| M1–M6 | Six mots familiers réellement employés | Sélection humaine de six formes distinctes et pertinentes ; forme Erfe exacte, sens/transcription validés et audios correspondants. Le mot ID 1 reste candidat à qualifier, pas une place réputée prête |
| P1–P2 | Deux énoncés courts en contexte | Choix et enregistrement par locuteurs ; lecture/saisie adaptées aux acquis, sans fabriquer de phrase à partir des caractères sélectionnés |

Répartition 4 + 6 + 2 proposée, à ajuster par le responsable pédagogique si elle ne correspond pas à une progression linguistique naturelle. Les mots doivent être compatibles avec les graphèmes enseignés ; cette cohérence ne se déduit pas automatiquement du nombre de caractères. Aucun emplacement vide ne doit devenir un mot de démonstration dans l’application.

## Déroulement proposé

Trois mini-séances de quatre éléments, environ 3–5 minutes chacune comme cible à valider, avec reprise locale. Ordre de sélection établi avec les locuteurs ; aucune obligation de présenter caractères puis mots dans un ordre rigide.

1. **ÉCOUTER** : prononciation authentique disponible dès l’entrée, bouton explicite de réécoute ; contexte oral/image si utile. L’utilisateur n’a pas à déchiffrer pour lancer le son. Répéter à voix haute reste facultatif et sans note automatique.
2. **RECONNAÎTRE** : écouter puis choisir entre distracteurs validés ; ne pas compter deux variantes authentiques comme une erreur. Éviter des réponses visuellement triviales qui masqueraient la compréhension du son.
3. **LIRE** : révéler le caractère ou mot en police Kedebideri et Unicode exacts, écouter de nouveau, associer oral et écrit. Pas de traduction nouvelle générée.
4. **COMPOSER** : entendre puis reconstruire au clavier Erfe avec des touches issues du corpus validé. Aide progressive et réponse erronée réessayable ; aucun dessin ou tracé.
5. **RÉVISER** : rappel actif des associations difficiles, audio rejouable et courte reprise. Pour ce pilote, révision de séance possible avec les briques existantes ; un échéancier de répétition espacée performant reste une étape future, pas une fonction annoncée livrée dans cette phase.

Évaluation : compréhension orale et lecture enregistrées comme compétences distinctes ; la réussite de saisie n’est pas une note de prononciation. Pas de reconnaissance vocale ni de synthèse Beřiya présumée. Aucune vidéo nécessaire pour ce pilote ; audio et images validées suffisent, avec taille du pack visible avant téléchargement.

## Conditions avant création du contenu

Chaque élément doit avoir un identifiant source stable, une validation humaine du texte Erfe et du lien au son, sa variante/son locuteur renseignés si utiles, et des droits/consentements vérifiés pour usage dans l’application et hors ligne. Les informations privées ne doivent pas entrer dans le ZIP public. Conserver les variantes, les originaux et les anciennes versions.

Valider le parcours avec des locuteurs réels : première écoute sans aide, compréhension des choix, lecture lisible, saisie accessible et réécoute. Télécharger, couper Internet, arrêter/réouvrir l’application, réviser puis reconnecter ; ce scénario physique reste à exécuter. Les corrections d’export permettent la vérification technique, elles ne comblent pas les ressources linguistiques manquantes.
