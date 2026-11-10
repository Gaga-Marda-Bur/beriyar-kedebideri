# Complément d’audit — Oralité et ressources authentiques

9 novembre 2026. **Priorité décidée par le propriétaire : Memrise pour l’inspiration pédagogique ; Duolingo en second pour l’UX, le parcours et la motivation.** BK doit partir des pratiques orales de sa communauté. Cette décision remplace toute lecture qui donnerait la priorité à un parcours principalement textuel.

## Périmètre et preuves

Inventaire de la copie SQLite locale en lecture seule, contrôle d’existence/empreintes des fichiers référencés, lecture technique de l’en-tête WAV, revue des lecteurs, modèles, relations et exporteurs. Deux sondes synthétiques en mémoire pour l’export. Aucune écoute perceptive, validation par locuteur, recherche de documents privés de consentement, inspection R2/Render ou modification des médias. Les nombres ne représentent pas la production.

Scripts reproductibles : `docs/audit_audio_2026_11_09.py` et `docs/audit_audio_contract_2026_11_09.py` ; résultats JSON de mêmes noms suffixés `_results`. La première sonde vérifie une empreinte de la base avant/après identique. Pas de framework, dépendance ou service nouveau installé. FFmpeg/ffprobe non trouvés dans le PATH interrogé ; aucun décodage MP3 complet ni diagnostic de bruit n’a été exécuté.

## Bibliothèque audio observée

| Indicateur local | Résultat |
|---|---|
| AudioAsset | 2, tous deux marqués `published` et disponibles hors ligne dans les métadonnées |
| Types | 1 `character`, 1 `quiz_prompt` |
| Vitesse déclarée | 2 `normal`, 0 `slow` |
| Fichier référencé présent | 2/2, WAV 791 192 octets et MP3 9 643 octets |
| Nom de locuteur renseigné | 2/2 ; noms non recopiés dans le rapport |
| Région/dialecte renseigné | 1/2 |
| Transcription renseignée | 1/2 ; justesse non évaluée |
| MIME renseigné | 2/2 ; ce champ seul ne certifie pas le codec |
| Durée en base | 0/2 |
| `recording_quality` renseignée | 0/2 |
| Notes renseignées | 0/2 |
| Champs dédiés licence/consentement dans AudioAsset | Aucun identifié |

Le WAV est lisible par `wave` : 4,485 s, deux canaux, 44 100 Hz, échantillons de 2 octets. Cela ne certifie ni intelligibilité, ni absence d’écrêtage, ni adéquation pédagogique. L’en-tête MP3 est relevé sans certification de décodage. Ne pas confondre statut `published`, qualité acoustique et autorisation d’exploitation.

Le dossier média contient également 18 petits fichiers `.mp3` de 16 octets, non référencés par AudioAsset, sous des noms `audio/test*.mp3`. Ils ne sont pas comptés comme prononciations disponibles. Leur caractère orphelin n’est pas prouvé : rechercher les usages ZIP/externes avant toute suppression. Aucun nettoyage effectué. Aucun fichier audio/vidéo trouvé dans `media_samples` par cette sonde.

### Couverture relationnelle

1 lien CharacterAudio (`normal`), 1 WordAudio (`normal`), 1 LessonItemAudio (`normal`), 3 QuizQuestionAudio (`question`). Ce sont des liens, pas autant d’enregistrements indépendants. Aucun lien phonème, nom de lettre, syllabe, consigne ou correction spécialisé recensé dans ces tables locales. Le code prévoit ces rôles ; leur existence dans le schéma ne suffit pas à constituer une bibliothèque.

| Unité locale | Statut | Caractères sélectionnés avec au moins un audio publié référencé | Mots sélectionnés/cible avec au moins un audio publié référencé |
|---|---|---|---|
| ID 1 | publié | 1/5 | 1/1 |
| ID 2 | publié | 0/2 | 0/1 |
| ID 3 | publié | 1/2 | 0/1 |
| ID 4 | publié | 0/2 | 0/1 |

Ces chiffres incluent les objets sélectionnés sans prétendre que chaque objet est lui-même publiable. Ils ne vérifient pas le rôle requis, le sens de l’audio ni la qualité. La couverture réellement exploitable peut donc être inférieure. Une leçon publiée comporte un item avec audio direct ou associé ; ce n’est pas une preuve de couverture de toutes les futures consignes. La seule publication No Ena locale a une référence audio, sans référence vidéo. Le modèle accepte `short_video` et un fichier vidéo : aucune conversation filmée validée n’est démontrée.

## Capacités déjà présentes et écarts

| Besoin prioritaire | Existant observé | Écart à traiter après validation |
|---|---|---|
| Entendre dès l’entrée dans une leçon | `_applyUnit()` appelle `_playCurrentStepAudio()` dans Learning Core ; bouton global de réécoute et cartes audio | Dépend du son de l’étape courante ; sans URL le lecteur s’arrête. Ne garantit pas un mot audible pour toutes les unités, ni parité web |
| Réécouter | `AudioUrlPlayer.playUrl()` relance le son, arrêt du lecteur précédent, pause/états/erreurs | Recette tactile/TalkBack et son réel ; conserver une commande clairement identifiable |
| Vitesse adaptée | Rôles/variantes `slow` dans les modèles | Aucune variante lente locale ; pas de commande de vitesse identifiée dans le lecteur actuel. Vérifier plateforme/intelligibilité avant ajout, ne pas inventer de prononciation |
| Audio–caractère/mot | Relations et sélection d’audio publiés | Couverture très incomplète ; phonème pur distinct du nom de lettre à faire valider |
| Audio–phrase/contexte | Type `sentence`, transcript, No Ena, quiz et items | Pas de bibliothèque de phrases authentiques démontrée par les deux AudioAsset |
| Écoute et choix/reconstitution | Discrimination et clavier du Learning Core, quiz | Réutiliser mais concevoir consignes et items validés ; pas d’obligation de lire la réponse avant d’écouter |
| Production orale | Répétition conseillée par `repeat_count` et textes de consigne | Aucune reconnaissance ou notation vocale fiable démontrée ; pratique libre sans note automatique |
| Flashcards audio-visuelles / répétition espacée | Composants audio/image/session et statut review | Moteur de cartes/rappels par élément à concevoir, non développé |
| Révision hors ligne | Packs, résolveurs locaux, sessions/cache | Export leçons/quiz à corriger, couverture et scénario mode avion à prouver |
| Vidéos naturelles facultatives | Champs et type No Ena | Consentement/droits, format léger, lecteur/pack et alternative audio à valider ; pas d’activation ni téléchargement implicite |
| Variantes et locuteurs | `speaker_name`, `dialect_region`, `speed`, liens multiples | Identité stable de locuteur/variante, provenance et droits à définir ; ne pas fusionner des variantes automatiquement |

## N14 — P1 — Export d’une leçon bloqué

**Reproduit en mémoire**, `backend/offline_packs/services/offline_pack_generator.py:_serialize_lessons()` appelle `get_linked_audio_file(lesson, role='normal')`. Le helper accède à `obj.audio_links`, qui n’existe pas sur `Lesson` : `AttributeError: 'Lesson' object has no attribute 'audio_links'`. La sonde crée un thème, une unité, une leçon et un pack publiés, puis appelle cette sérialisation sans création de média.

La même méthode référence aussi `lesson.cover_image`, `short_description_*` et `item.writing_hint`, absents des modèles inspectés ; ces écarts supplémentaires sont observés dans le code, pas atteints par la première reproduction bloquante. Cause probable : exporteur resté aligné sur un ancien contrat de modèle. **Correction recommandée :** aligner l’export sur les champs et relations réels, en définissant explicitement l’audio d’introduction et les fallbacks utiles, sans ajouter de champs métier pour masquer le problème. Tester une leçon publiée avec item/caractère/mot/audio, puis générer et relire son ZIP hors ligne. Garder l’ancienne archive jusqu’à validation de la nouvelle.

Les tests backend précédemment réussis restent valables dans leur périmètre : leurs packs de génération n’incluent pas de leçon et ne couvrent pas ce chemin.

## N15 — P1 — Mauvais rôle pour l’audio des quiz exportés

**Reproduit en mémoire**, `_serialize_quizzes()` cherche `get_linked_audio_file(question, role='normal')`, alors que `QuizQuestionAudio` définit `question`, `slow_question`, `explanation`, `correction`. Avec un lien `question` publié : résolution `question` vraie, résolution `normal` fausse. Les trois liens de quiz locaux portent justement le rôle `question`.

Conséquence probable : prompt audio absent du quiz exporté malgré un lien utilisable. La sonde vérifie le sélecteur exact utilisé, pas un ZIP complet avec tous les champs. **Correction recommandée :** reprendre le contrat de sélection du sérialiseur API pour chaque rôle, et tester parité API/web/ZIP/mobile et sons manquants. Ne pas requalifier automatiquement les enregistrements en base.

## Qualité, authenticité et droits : validation encore nécessaire

Une validation humaine doit vérifier ce qui est effectivement prononcé, la variante, l’association au texte/à l’image, le naturel, l’intelligibilité, la pertinence de vitesse et les éventuelles ambiguïtés. Une vérification technique doit ensuite couvrir décodage complet, durée, silences/bruit/écrêtage, niveau d’écoute comparable, taille et lecture sur Android modeste. Aucune note de qualité n’est attribuée ici.

Les champs existants ne consignent pas explicitement licence, provenance, périmètre d’autorisation, preuve de consentement, autorisation d’usage hors ligne ou possibilité de retrait. Des preuves peuvent exister ailleurs : **droits non vérifiables dans les sources inspectées**, pas « absence de droits ». Avant nouvel usage ou diffusion, relier chaque média à une preuve vérifiée par le responsable ; garder la preuve et les coordonnées privées hors de l’API publique et des packs.

Métadonnées proposées à valider, sans migration maintenant : identifiant du média et de sa version ; locuteur pseudonymisé/identifiant stable ; variante déclarée et validée ; contenu correspondant ; source/date ; langue ; rôle ; vitesse ; durée/format/taille/empreinte ; validations linguistique et technique ; référence de preuve de droits et usages autorisés. Pour vidéo, participants/consentements et alternative audio distincte. Le statut éditorial ne doit pas déclencher automatiquement une autorisation de diffusion.

## Cadre pédagogique révisé

**Parcours A : Je parle Beřiya, j’apprends l’Erfe.** Point de départ : un son, mot ou énoncé familier. Écouter → reconnaître le sens/son → découvrir le caractère ou mot typographique → associer → composer au clavier → relire et réviser. La lecture s’appuie sur une compétence orale préexistante ; elle n’est pas présentée comme apprentissage d’une langue étrangère.

**Parcours B : J’apprends à parler Beřiya et à utiliser l’Erfe.** Point de départ : une situation et un enregistrement naturel. Comprendre/écouter → choisir une image ou réponse → répéter oralement librement → reconnaître → introduire progressivement lecture et saisie Erfe → utiliser en contexte validé. Aucune synthèse vocale, reconnaissance vocale ou évaluation automatique de prononciation présumée disponible.

Les six actions BK **VOIR, ÉCOUTER, RECONNAÎTRE, COMPOSER, RÉVISER, UTILISER** restent possibles, mais leur ordre est souple et **l’oral est la porte d’entrée**. Une première écoute ne doit pas dépendre de la capacité à déchiffrer un texte Erfe. Mini-séances 3–5 minutes comme cible à tester. Pas de tracé manuscrit. Pas de contenu Beřiya généré.

Maquette fonctionnelle proposée : entrée « Écouter » immédiatement visible et son d’ouverture local disponible selon préférence ; contexte/image facultatifs ; réécoute illimitée ; consigne simple ; choix ou clavier après écoute ; feedback explicite ; pratique orale libre optionnelle. Séparer compréhension orale et lecture dans les évaluations ; ne pas utiliser la réussite de frappe comme note de prononciation. Un son manquant exige un état honnête et une autre activité adaptée, jamais une fausse validation d’écoute.

## Ordre de réalisation révisé — aucun changement métier autorisé par ce document

0. Audit audio, droits, qualité et couverture ; finaliser avec responsables du corpus et locuteurs. L’inventaire technique local est fourni ; la validation humaine et distante reste ouverte.
1. Corriger l’existant : propriété des progressions, export leçons/quiz, accès packs et erreurs ; aucun enrichissement ne doit masquer les blocages.
2. Moderniser les écrans autour de l’écoute immédiate, réécoute, contexte, lecture progressive et clavier accessible.
3. Construire les exercices audio-visuels en réutilisant objets et médias validés ; critères distincts compréhension/lecture/saisie.
4. Introduire répétition espacée basée sur les performances, avec rappels et médias téléchargés utilisables hors ligne ; pratique orale non automatiquement notée.
5. Enrichir progressivement l’audio puis les vidéos naturelles justifiées et consenties ; téléchargement vidéo explicite, taille annoncée, audio seul suffisant pour le parcours essentiel.
6. Valider l’expérience complète auprès de locuteurs réels des deux publics ; associer aussi des locuteurs à la validation des contenus dès le départ.

Avant acceptation : première écoute sans lecture préalable, bouton audio accessible et répétable, variantes conservées, compréhension testable sans vidéo, exercice/reprise/révision en mode avion, aucun dessin requis, aucune notation vocale artificiellement annoncée, aucune perte des données existantes. Ces critères sont proposés, non annoncés réussis.
