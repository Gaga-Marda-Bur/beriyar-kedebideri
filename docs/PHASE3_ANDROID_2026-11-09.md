# Phase 3 — Validation Android, hors ligne et synchronisation

9 novembre 2026. **Décision : NO-GO pour engager une modernisation UX/UI globale sur un socle déclaré fiable.** La persistance de Learning Core et sa synchronisation fonctionnent dans les scénarios exécutés, mais quatre tests natifs révèlent des anomalies, dont l’audio hors ligne malgré un pack installé. Priorité à un petit lot de corrections et à sa nouvelle recette, sans refonte graphique.

Ce rapport distingue tests Android sur émulateur et Samsung physique, échanges HTTP réels locaux, observations du code et scénarios non exécutés. Le téléphone a finalement été autorisé dans ADB après activation du débogage USB.

## Environnement et isolation

| Élément | État observé/utilisé |
|---|---|
| Sources | Dépôt local avec correctifs des Phases 1/2 ; leurs modifications préexistantes conservées |
| Backend | Python du venv existant, Django 6.0.6 / DRF 3.17.1 ; serveur réel `127.0.0.1:8765` |
| Données QA | Nouvelle SQLite sur disque dans `docs/qa_android/runtime/`, sans comptes, sessions, feedback ou historiques privés source |
| Corpus QA | Copie en lecture seule du corpus publié local et de ses parents nécessaires ; statuts éditoriaux d’origine conservés ; noms de locuteurs/notes anonymisés dans la copie |
| Comptes de sécurité | A/B synthétiques, mots de passe aléatoires réservés au laboratoire ; aucun vrai compte utilisé |
| Android | AVD Medium_Phone, `sdk_gphone64_x86_64`, Android **16 / API 36**, RAM configurée **2 048 Mo**, affichage 1080×2400 / 420 dpi |
| Partition émulateur | Nouveau fichier userdata dans le laboratoire, AVD en lecture seule, sans chargement/enregistrement de snapshot existant |
| Audio émulateur | Sortie sonore hôte désactivée ; décodage, durée et événement de fin du lecteur Android natif vérifiés ; qualité perceptive non évaluée |
| Application | Clone debug `com.afrigama.beriyarkedebideri.qa`, label « BK QA Phase 3 », distinct de l’application habituelle |
| Accès réseau | Tunnel ADB vers l’API locale ; aucune connexion de test à Render/R2, aucune publication ni publicité |
| Téléphone physique | Samsung **SM-A336E**, Android **16 / API 36**, **arm64-v8a**, autorisé dans ADB ; clone QA installé sans toucher à l’application habituelle |

La détection initiale USB sans interface ADB a été résolue avec le propriétaire dans les options développeur. Le téléphone apparaissait en état `device` avant installation. Pour les tests hors ligne, le mode avion a été activé, le Wi-Fi désactivé et le tunnel USB retiré ; un bloc `finally` rétablit les réglages initiaux (mode avion 0, Wi-Fi 1, données mobiles 1). Aucun pilote ni protection système n’a été modifié.

Le clone ajoute `integration_test` fourni par le SDK uniquement dans son propre pubspec. Aucun fichier métier Flutter, dépendance/configuration de l’application d’origine ou contrat API public n’a été modifié par cette phase. Le harnais utilise de vraies préférences Android, des fichiers réels, les services existants, le lecteur audio natif et l’API HTTP réelle ; il ne simule pas ces composants avec des mocks.

## Migration, sauvegarde et retour arrière préparés

Migration en attente : `progress.0004_progressdevicecredential`, dépendant de `progress.0003_unitprogress_scoring_metadata` et du modèle utilisateur configuré ; les migrations antérieures de progress et ses dépendances sont conservées.

Dans QA : création du schéma précédent 0003, copie des contenus nécessaires, création des comptes/historiques synthétiques, sauvegarde SQLite avant 0004, restauration vers un autre fichier, comparaison des schémas et lignes des **37 tables**, contrôles `integrity_check=ok` et absence de violations FK. Puis application de 0004 et vérification `makemigrations --check --dry-run` sans écart. Aucune donnée linguistique n’est réparée ou inventée.

0004 crée le registre et ajoute le marqueur durable de confidentialité. Son initialisation concerne les lignes déjà liées à un compte : aucune revendication d’historique invité. Les écritures de test suivantes concernent uniquement QA.

La base source reste à son état initial : SHA-256 avant/après `0e92a4da3cd7736a6cc9d47f1d770efaf9586774ab3873aadec6eda54c76360b`. **La migration n’a été appliquée ni à cette copie existante, ni à la production.** Les deux audios copiés gardent leurs octets et empreintes d’origine. Les sauvegardes, comptes synthétiques et APK sont dans le dossier ignoré `runtime/`, pas dans les livrables à commiter.

## Scénarios exécutés

RÉUSSI = assertion exécutée dans le périmètre exact indiqué. ÉCHOUÉ = écart effectivement reproduit. NON EXÉCUTÉ/INDISPONIBLE = aucune preuve de réalisation, sans assimiler absence de test et absence de fonction.

| Scénario | Moyen | Résultat et preuve |
|---|---|---|
| Préparation et restauration QA avant migration | SQLite réelle sur disque | **RÉUSSI**, 37 tables comparées et intégrité contrôlée |
| Migration 0004 et concordance des modèles | Backend QA | **RÉUSSI**, aucune migration manquante détectée |
| Compilation debug et installation initiale | Émulateur | **RÉUSSI**, premier assembleDebug 162,9 s, installation 964 ms ; ce sont des temps d’outillage local |
| Premier démarrage invité | Application native QA | **RÉUSSI** pour affichage et accès aux données ; aucun écran de connexion de compte présent |
| Téléchargement et extraction du pack QA | Service Flutter réel + HTTP local | **RÉUSSI**, checksum/installation existants utilisés, pack exact 2 438 999 octets |
| Lecture d’un audio de leçon depuis le pack | Lecteur Android natif | **RÉUSSI**, WAV local, durée 4 485 ms, événement de fin reçu |
| Ouverture Mes téléchargements et Quiz | Écrans existants sur émulateur et Samsung | **RÉUSSI** dans les scénarios en ligne puis hors ligne ; pas une mesure de découvrabilité |
| Début de séance Learning Core | Interaction avec widgets réels | **RÉUSSI**, découverte, bonne réponse de reconnaissance, étape 2 sauvegardée |
| Arrêt du processus puis installation en mise à jour | ADB et nouveau lancement du harnais | **RÉUSSI**, même applicationId/signature debug, sans désinstallation/effacement |
| Reprise après fermeture en mode avion | Émulateur, Samsung et préférences natives | **RÉUSSI**, étape 2 et données de progression identiques au checkpoint précédent |
| Composition et fin de séance hors ligne | Clavier Erfe et moteur existants | **RÉUSSI** dans cette unité, statut terminé et score 100 conservés ; aucune épreuve manuscrite |
| Tentative de synchronisation sans serveur accessible | Tunnel API retiré, mode avion actif | **RÉUSSI** pour refus sans perte de progression locale |
| Audio disponible dans le pack mais lu par le chemin cache de l’écran | Test natif séparé | **ÉCHOUÉ**, référence distante conservée, timeout du lecteur après 30 s, état `failed` ; P3-01 |
| Unicité des quiz en cache hors ligne | Test natif séparé | **ÉCHOUÉ**, 4 entrées pour 2 identifiants uniques ; P3-02 |
| Accès aux téléchargements depuis le catalogue hors ligne | Écran catalogue réel | **ÉCHOUÉ**, 1 pack installé mais aucun lien Mes téléchargements rendu dans l’état d’erreur ; P3-03 |
| Retour réseau et synchronisation de la séance terminée | Nouveau processus Android + vrai serveur QA | **RÉUSSI**, progression reçue et propriétaire invité conservé |
| Jeton invité invalide, données locales puis réessai valide | Android + HTTP réel | **RÉUSSI**, refus, aucune perte locale, synchronisation valide suivante acceptée |
| Conflit de mise à jour ancienne | Android + serveur QA | **RÉUSSI**, ancien score 0/date 2000 n’abaisse pas la meilleure maîtrise ; compteurs également vérifiés dans la sonde HTTP |
| Bonne réponse dans le quiz autonome après mélange des options | Écran réel et score affiché | **ÉCHOUÉ** pour le feedback : score incrémenté correctement, mais message positif absent ; P3-04 |
| Réouverture du quiz autonome | Navigation réelle | **CONSTAT**, score provisoire remis à zéro ; aucune persistance de cette session identifiée. À distinguer de Learning Core |
| Compte A puis requête sans authentification puis compte B | HTTP réel, authentification Django/DRF | **RÉUSSI**, 14 contrôles HTTP dont séparation A/B, attribution serveur, refus invité et absence de revendication sans preuve |
| Connexion/déconnexion A/B dans l’interface Flutter | Téléphone/émulateur | **INDISPONIBLE** : fonction non implémentée dans l’application actuelle ; aucun ajout dans cette phase |
| Jeton de compte réellement expiré puis nouvelle authentification mobile | Android | **NON EXÉCUTÉ** : pas de mécanisme mobile d’authentification/expiration de jeton de compte. Un jeton invité invalide n’est pas présenté comme une expiration |
| Saturation réelle du stockage, interruption en cours de téléchargement | Android | **NON EXÉCUTÉ** ; aucun remplissage artificiel du téléphone ni de la partition de l’émulateur |
| Profil de fluidité release, chauffe/batterie, TalkBack, grands caractères | Appareil réel | **NON EXÉCUTÉ** |
| Installation, démarrage, pack, audio, reprise, fin de leçon et synchronisation sur téléphone physique | Samsung SM-A336E USB | **RÉUSSI**, scénarios natifs `online`, `offline` et `resync` ; installation QA sans effacement |
| Audibilité du son sur le téléphone | Confirmation explicite du propriétaire | **CONFIRMÉE** : « Oui, le son est audible » ; ne valide ni les licences ni l’exactitude linguistique |

Le mode avion seul ne coupe pas un tunnel USB localhost. Le retrait du tunnel a rendu le serveur réellement inaccessible au clone pendant la phase hors ligne. Le rétablissement du tunnel et du réseau initial a permis la synchronisation ; cela ne valide ni un débit mobile réel ni la disponibilité de Render.

### Confirmation sur Samsung physique

Les sept scénarios natifs ont également été exécutés sur le SM-A336E : **3 réussites** (`online`, `offline`, `resync`) et **4 échecs reproduisant les défauts**. L’audio du cache échoue après 30 s malgré le WAV local lisible ; le cache contient **6 quiz pour 2 IDs** après deux rafraîchissements explicites ; un pack est installé mais le lien du catalogue est absent ; la bonne réponse augmente le score sans feedback positif. Le quiz autonome repart également à zéro après réouverture. Les réglages réseau après recette sont identiques aux valeurs initiales et vérifiés par le collecteur.

Le harnais ouvre les écrans par leurs routes et choisit les réponses depuis les contenus existants pour tester le moteur ; il ne mesure pas un parcours humain complet depuis le menu. Les données natives ont réellement traversé des arrêts de processus et des installations en mise à jour. La reprise n’est pas seulement une recréation de service dans un test hôte.

## Anomalies confirmées et corrections minimales proposées

### P3-01 — P1 — Le cache prive l’écran de ses audios téléchargés

`mobile/lib/core/cache/cached_content_service.dart:283` : en l’absence de backend, `loadUnits()` privilégie le cache JSON avant le pack. Les unités conservées depuis l’API ont encore des URL HTTP. Le même média est pourtant disponible et décodable dans le pack installé. `LearningCoreUnitScreen` reçoit ce flux distant par son chargeur normal ; la réussite d’une lecture directe de pack ne prouve donc pas la réussite de la lecture dans cet écran.

Reproduction native : charger les unités en ligne, télécharger le pack, arrêter le processus, couper réseau/tunnel, ouvrir le flux depuis CachedContentService puis rejouer le premier son disponible. Résultat : référence distante, délai de préparation 30 s, `AudioPlaybackStatus.failed`. Le WAV local correspondant atteint normalement sa fin en 4,485 s.

**Proposition :** résoudre les médias téléchargés avant la lecture, en associant identité et version du contenu/flux ; utiliser le pack compatible pour les médias présents et un état indisponible explicite pour les autres. Ne pas préférer aveuglément un ancien pack à une version de contenu différente ou réintroduire un brouillon/élément retiré. Garder le fallback distant uniquement lorsque le réseau et le média sont réellement disponibles. Tester cache chaud/froid, redémarrage, versions divergentes et absence de média. Aucun changement linguistique requis.

### P3-02 — P1 — Le cache de quiz grossit avec des doublons

`cached_content_service.dart:423`, en particulier le filtre vers la ligne 454 : pour un chargement global, `unitSlug` vaut null. Le filtre `quiz.unitSlug != unitSlug` conserve les anciens quiz, puis les résultats complets sont ajoutés. En ligne l’écran utilise souvent les nouveaux résultats seuls, ce qui masque le défaut jusqu’au mode hors ligne.

Reproduction : 2 questions récupérées, préchargement puis ouverture/rechargement global, coupure du réseau et nouveau processus. Le test natif trouve 4 entrées pour 2 IDs ; les lancements ultérieurs ont fait croître ce même cache à 6, 8 puis 10 entrées dans les journaux. Il ne s’agit pas de doublons créés dans la base linguistique.

**Proposition :** remplacer la collection complète lors d’une récupération globale réussie ; pour un filtre d’unité, remplacer ce sous-ensemble et dédupliquer par ID. Préserver un cache complet si la pagination échoue, conformément aux tests existants. Vérifier aussi le chemin analogue des leçons, sans annoncer qu’un doublon de leçon a été reproduit ici. Tester récupération répétée, changement de filtre, cache ancien déjà dupliqué et mode avion.

### P3-03 — P1 — Le catalogue échoue avant de montrer les packs locaux

`mobile/lib/features/offline_packs/screens/offline_packs_screen.dart:36` : `_load()` attend `fetchPacks()` avant `listInstalledPacks()`. L’état d’erreur remplace ensuite toute la zone contenant le bouton Mes téléchargements.

Reproduction native : 1 pack installé, mode avion et tunnel retiré, ouverture `/offline-packs`. Le pack reste sur disque, la route séparée `/my-packs` fonctionne, mais le lien vers celle-ci n’est pas rendu dans le catalogue en erreur. Test natif en échec, sans perte de fichier.

**Proposition :** charger la liste locale indépendamment de l’API et conserver toujours l’accès Mes téléchargements ; l’indisponibilité du catalogue distant doit être une erreur secondaire. Aucun endpoint ou schéma à changer. Recetter avec API 503, absence de réseau, pack présent/absent et première visite.

### P3-04 — P1 pédagogique — Le score et le feedback du quiz divergent

`mobile/lib/features/quiz/screens/quiz_screen.dart` : `_selectAnswer()` utilise correctement `optionOrder[displayIndex]`, alors que le feedback vers les lignes 483/491 compare directement `selectedIndex` au `question.correctIndex` d’origine. Après mélange, l’index affiché et l’index original ne coïncident pas toujours.

Reproduction native : sélectionner la bonne option existante ; le score provisoire devient 1/2, mais le texte « Correct, très bien ! » n’apparaît pas. Le test consigne `answer_scored_correct=true` et `correct_feedback_displayed=false`. Le défaut ne provient pas du calcul de maîtrise Learning Core validé séparément.

**Proposition :** calculer une seule correspondance d’index affiché et l’utiliser pour toutes les indications après réponse. Tester plusieurs permutations, bonne/mauvaise réponse, couleur/icône/texte et score. Ce correctif ne nécessite pas une refonte visuelle.

### Autres constats à traiter sans inventer de fonctionnalité

- **Quiz autonome non persistant :** son score repart à zéro à la réouverture ; `_correctCount`, `_currentIndex` et `_finished` sont des états de widget sans écriture d’historique identifiée. Définir s’il s’agit d’une pratique libre éphémère ou d’une évaluation persistante avant toute extension. Ne pas annoncer que tous les résultats de quiz sont sauvegardés parce que Learning Core l’est.
- **Découverte du parcours sur la copie locale :** les deux thèmes parents sont `draft` et l’API publique retourne 0 thème, bien que 4 unités soient publiées. Les journaux natifs confirment le préchargement de 0 thème. Un jeu éditorial cohérent doit être validé pour recetter le bouton de première leçon ; aucun statut n’a été modifié pour masquer cette limite. L’état de Render n’en est pas déduit.
- **Poids du pack :** 5 références média contiennent exactement les mêmes octets WAV : 3 955 960 octets décompressés pour 791 192 octets uniques. `_copy_media()` écrit un fichier par préfixe d’entité ; proposer la réutilisation d’une même copie avec références compatibles. Aucun gain réseau après optimisation n’est annoncé : aucune optimisation n’a été appliquée.
- **Chaîne Android :** avertissements Kotlin de compatibilité future de plugins et niveaux Java 8 obsolètes, sans blocage de la compilation actuelle. Ne pas mettre à niveau toutes les dépendances pour corriger les quatre défauts fonctionnels ci-dessus.

## Mesures disponibles

Échantillons uniques, **debug**, sur émulateur accéléré et Samsung. Ils ne représentent ni une médiane/p95, ni un budget release, ni un réseau mobile coûteux. Aucune optimisation réalisée et aucun gain avant/après revendiqué. Les mesures du premier tableau concernent l’émulateur.

| Mesure | Valeur et portée |
|---|---|
| Pack téléchargé | **2 438 999 octets** exacts, checksum vérifié par le service existant |
| Téléchargement + vérification + extraction | **1 006 ms**, serveur localhost via ADB, un essai |
| Documents avant/après installation du pack | 105 042 737 → 111 460 178 octets ; **delta 6 417 441 octets**. Le volume initial contient notamment des artefacts de debug, ce n’est pas une taille de données apprenant en release |
| Entrée main → premier écran stabilisé, harnais | En ligne **4 450 ms**, hors ligne **2 512 ms**, reconnexion **2 597 ms** ; conditions différentes, pas une comparaison d’optimisation |
| Ouverture de la leçon → écran stabilisé | En ligne **6 119 ms**, hors ligne **1 131 ms**, depuis route de test ; le son hors ligne provenant du cache reste défectueux |
| Durée du WAV donnée par Android | **4 485 ms**, fin de lecture native reçue ; pas une validation phonétique/perceptive |
| APK QA debug avec entrée normale | **160 981 936 octets**, version 1.0.0+1, minSdk **24**, target/compile **36** ; pas l’APK release final |
| Démarrage du clone normal après force-stop | `am start -W`, **COLD**, TotalTime **5 136 ms**, WaitTime 5 159 ms ; ne mesure pas à lui seul l’utilisabilité complète |
| Mémoire ponctuelle du clone normal | `dumpsys meminfo` : TOTAL PSS **335 633 Ko**, RSS 397 268 Ko. Snapshot debug, ni pic mesuré ni budget release |
| Espace de la partition /data de l’émulateur | 6 082 144 Kio au total, 3 798 044 Kio disponibles au relevé ; pas un test de faible espace |
| Fluidité et disque saturé | Pas de profil de frames ni de test ENOSPC exécuté. Les ouvertures testées ne certifient pas la fluidité sur un appareil modeste |

Mesures physiques Samsung, mêmes services et serveur localhost via USB :

| Mesure | Valeur et portée |
|---|---|
| Installation initiale du clone de test | **22,3 s** ; temps d’outillage, pas temps de démarrage |
| Entrée main → premier écran stabilisé | En ligne **3 287 ms**, hors ligne **2 965 ms**, reconnexion **2 678 ms** |
| Téléchargement, vérification et extraction | **679 ms**, même pack de 2 438 999 octets ; aucun débit mobile déduit |
| Documents avant/après pack | 105 052 497 → 111 469 938 octets ; delta **6 417 441 octets**, artefacts debug inclus |
| Ouverture de leçon | En ligne **5 510 ms**, hors ligne **679 ms**, route du harnais |
| Audio local | **4 485 ms**, lecture native terminée ; son confirmé audible par le propriétaire |
| Reprise et fin de séance | Étape **2** retrouvée après arrêt ; séance terminée, score **100**, conservés puis synchronisés |

## Compatibilité Django–Flutter et sécurité

Les exports Phase 1 sont téléchargés et lus par Android natif. Le format de progression Phase 2 est envoyé au vrai serveur QA après une fin de séance hors ligne, puis relu avec le justificatif invité : la meilleure maîtrise et l’identité restent correctes. Une preuve invalide est refusée et une nouvelle tentative valide fonctionne. Les 14 contrôles HTTP utilisent les mêmes endpoints avec A/B synthétiques et vérifient les frontières compte/invité.

En revanche, le chargeur de cache et l’écran de quiz présentent les écarts P3-01/02/04 ; « compatible au niveau JSON/API » ne signifie pas « parcours utilisateur entièrement fiable ». L’expiration d’un jeton de compte et l’alternance de comptes dans Flutter ne peuvent pas être validées comme fonctionnalités existantes. Avant ajout de connexion mobile, il faudra une séparation locale par propriétaire et une gestion de transition explicite, sans attribuer les données de A à B ni effacer les historiques pour contourner un refus.

Les résultats 94 Django / 73 Flutter / 3 JavaScript des phases précédentes sont une référence historique récente, **pas des suites complètes réexécutées dans cette phase**. Cette phase ajoute **14 contrôles HTTP réussis** et **7 scénarios natifs sur chacune des deux cibles**, soit 14 exécutions : **6 réussites et 8 échecs** reproduisant les quatre anomalies. Les échecs natifs ne doivent pas être remplacés par une affirmation « tous les tests passent ». La syntaxe Python des scripts QA et la validité JSON de la synthèse ont également été contrôlées.

## Livrables et preuves

- `docs/qa_android/PHASE3_RESULTS.json` : résultats consolidés, sans secrets ni contenu privé du téléphone.
- `docs/qa_android/prepare_lab.py` : base QA, sauvegarde/restauration, migration isolée et clone mobile.
- `docs/qa_android/http_security_probe.py` : 14 contrôles HTTP réels.
- `docs/qa_android/phase3_android_test.dart` : harnais natif, y compris tests qui échouent actuellement.
- `docs/qa_android/collect_evidence.py`, `collect_phone.py`, `.gitignore` et `README.md` : collecte et reproduction sur les deux cibles.
- `docs/qa_android/runtime/online.png` : capture réelle du rendu sur émulateur ; aucune maquette.
- `runtime/artifacts/bk-qa-debug.apk` : clone normal pour recette seulement, non publié ; SHA-256 `f88c2ea8d6ee31a5438553deb3a20dfc0e44443c145b0a0c1bbbe341f4ad8967`.

La première préparation a révélé un filtrage trop strict des parents dans le script QA, corrigé en conservant leurs statuts originaux ; une autre tentative a été bloquée par les permissions du dossier temporaire Windows, puis relancée avec autorisation. Ce sont des incidents de préparation, pas des modifications éditoriales. Le premier nettoyage Flutter a tenté une désinstallation de l’identifiant sans suffixe, absent de notre émulateur neuf : aucune application habituelle n’a été supprimée. Le clone fixe désormais l’applicationId complet et toutes les commandes suivantes utilisent `--no-uninstall`.

## Décision et suite minimale

**NO-GO** pour une modernisation graphique/pédagogique complète qui supposerait le fonctionnement hors ligne acquis. **GO pour préparer un lot de stabilisation limité**, après validation : P3-01 audio/cache en premier, puis P3-02 unicité, P3-03 catalogue et P3-04 feedback. Conserver les tests natifs en échec et les faire réussir après chaque correctif, sans changer les traductions/caractères ni le contrat public.

Critères de levée : son téléchargé lu depuis le vrai écran après arrêt/mode avion, absence de doublons après préchargements répétés, téléchargements accessibles malgré serveur indisponible, feedback fidèle au score, puis nouvelle recette des sessions et de la propriété sur émulateur et Samsung. Compléter avec mesure release/profil adaptée et essai contrôlé d’espace insuffisant. La qualité linguistique des sons, les droits et la cohérence du corpus restent à valider humainement ; seule l’audibilité du son testé est confirmée par le propriétaire.

## Retour arrière et nettoyage

Les sources métier d’origine ne sont pas modifiées par cette phase. Le retour arrière de la recette consiste à arrêter seulement le serveur local et l’émulateur QA, restaurer l’état réseau initial de la cible, puis archiver les preuves et sauvegardes avant éventuel nettoyage du dossier runtime. Aucun `pm clear`, désinstallation de l’application habituelle, migration inverse de production ou suppression du registre de propriété n’est nécessaire.

Nettoyage effectivement réalisé après collecte : clone QA arrêté sur Samsung, seul tunnel USB 8765 retiré, émulateur de recette arrêté et serveur local identifié par sa commande `prepare_lab.py serve` arrêté. Les données du clone, les preuves et les sauvegardes sont conservées. Les trois réglages réseau du téléphone ont été vérifiés restaurés avant retrait du tunnel. L’empreinte de la base source a été revérifiée identique en fin de recette.

Une nouvelle recette peut repartir d’un laboratoire distinct. Ne pas écraser la base source ni transformer la sauvegarde QA en sauvegarde de production. Pour un futur déploiement, conserver les règles de Phase 2 : sauvegarde/restauration, migration additive validée, endpoints protégés et décision explicite de mise en service. Aucune opération distante de ce type n’a été exécutée.
