# Livrable 6 — Validation et matrice de non-régression

9 novembre 2026. Les critères futurs ci-dessous sont des conditions proposées, pas des tests déjà réussis.

**Complément oralité :** les sondes [audio](AUDIT_ORALITE_2026-11-09.md) reproduisent N14/N15 sans modifier les médias. Avant enrichissement, valider qualité acoustique et linguistique, droits/consentements et couverture. Les tests futurs doivent distinguer compréhension orale, lecture et saisie ; aucune évaluation automatique de prononciation n’est présumée fiable. Exiger première écoute sans déchiffrage préalable, réécoute illimitée, variantes préservées, vidéo optionnelle, révisions avec sons téléchargés après redémarrage hors ligne. Le lot 1 inclut export de leçons avec items et rôle audio des quiz ; les suites antérieures ne prouvent pas ces cas. Aucun tracé manuscrit requis ou ajouté.

## Référence actuelle

59 tests backend réussis, 70 Flutter réussis, 3 JavaScript réussis ; analyse Flutter sans anomalie et pip cohérent. Migrations d’une base mémoire neuve réussies et modèles sans migration manquante. SQLite locale en lecture seule : intégrité `ok`, 0 violation FK. Les sondes complémentaires **reproduisent** N01/N02/N03 et ne constituent pas une validation de sécurité. Résultats détaillés dans `AUDIT_GENERAL_2026-11-09.md` et `audit_2026_11_09_results.json`.

| Domaine préservé | Référence / couverture exécutée | Non-régression à exiger ensuite |
|---|---|---|
| Corpus, Unicode, transcriptions | Agrégats lecture seule, UTF-16 Flutter | Empreintes export source avant/après ; pas de modification automatique ; accents/combinants/sélections et rendu Kedebideri réels |
| Translittération | Aucun moteur aller-retour identifié | Définir avec comité linguistique si nécessaire ; jeux validés réversibles/ambiguïtés, ne pas inventer de correspondances |
| Comptes et propriété | Tests progress existants + sondes révélant faille | Isolation comptes/appareils, historiques sans jeton, deux unités/deux jetons, concurrence et récupération contrôlée |
| API et publication éditoriale | Tests Django y compris filtres de brouillons | Snapshot des routes/champs utilisés, liste/détail/relations/pack publics, lecture ancienne app et migrations additives |
| Dictionnaire | Pagination Flutter testée, sonde HTML 101/1001 | Recherche Erfe/Latin/FR/EN/AR, filtres, changement langue, ordre stable, pas de perte/doublons entre pages |
| Leçons et maîtrise | LearningSession, seuil/reprise, clavier compact | Succès/échec, révision, interruption, version de flux modifiée, ancien succès conservé, zéro tracé accessible |
| Audio | 3 JS + tests lecteurs Flutter et backend | Sons publiés identiques API/web/ZIP, pas de superposition, appareil muet/erreur/absence réseau, écoute linguistique humaine |
| Images | Composants et résolveurs revus | HTTP 404, fichier absent, local/distant, taille mémoire décodée, droits et pertinence de l’image |
| Cache/packs | Tests corruption, pagination incomplète, téléchargement, audio local | Téléchargement interrompu, espace plein, reprise, mauvais checksum, chemins hostiles, ancien pack préservé, dépendances complètes |
| Synchronisation | Suite existante ; faille en sonde | 101 éléments, lot partiel, répétition, dates égales/anciennes/futures, device changé, réponse rejetée, repli hors ligne |
| Éditeur/PDF/studio/No Ena/feedback | Tests éditeur/PDF/feedback/No Ena existants | Brouillon restauré, partage/impression, polices exportées, feedback limité sans perte du message, liens existants |
| Déploiement/sauvegarde | Config et scripts revus ; aucune opération distante | PostgreSQL staging, restauration DB+médias+archives, permissions, proxy/cookies réels, ancienne version compatible |

## Acceptation et retour arrière par lot

| Lot | Critères d’acceptation | Épreuves requises | Déclencheur et procédure de retour arrière |
|---|---|---|---|
| 0 | Inventaire daté et restauration indépendante DB/médias/archives démontrée | Comparaison tables/lignes/FK et SHA-256 médias ; accès au backup contrôlé | Si restauration impossible : aucun déploiement ; garder référence existante et résoudre la sauvegarde |
| 1 | Aucun accès/revendication sans propriété, aucun 500 pour mauvais token, packs locaux visibles hors réseau, aucun tracé affichable | Cas N01/N02/N03, tests widget packs, API/ancien ZIP avec tracing, contrat ancien mobile | Revenir au code précédent uniquement si cela ne réexpose pas les historiques ; sinon limiter/suspendre endpoint vulnérable. Schéma additif conservé, récupération manuelle auditée |
| 2 | Fonctions/liens conservés, filtres persistants, 5 sections max, titres compréhensibles, pagination complète | Widget/web, FR/EN/AR/RTL, zoom, clavier, lecteur écran, novice | Si navigation casse ou régression performance : restaurer templates/widgets précédents ; conserver URL/paramètres rétrocompatibles |
| 3 | Contenu humain validé, séance sans dessin, un objectif clair, seuil fidèle, reprise rapide | Test pédagogique par public, flux partagé API/ZIP/mobile, tests sessions et absent audio | Réactiver parcours précédent par configuration/version ; garder slugs, sessions et notes de validation |
| 4 | Calendrier déterministe hors ligne, historique intact, pas de punition, fusion sans double attribution | Horloges, jours/frontières, redémarrage, erreurs, événements rejoués, migration peuplée | Désactiver nouveau planificateur ; garder événements/révisions en lecture, ne pas effacer les scores historiques |
| 5 | Ancien pack utilisable jusqu’à remplacement validé, pas de téléchargement redondant, mesures améliorées ou justifiées | Réseau faible/coupure/disque plein, profil CPU/RAM, 20 échantillons avant/après même corpus et appareil | Réactiver version précédente du pack/cache/lecteur ; conserver originales et schémas anciens, aucune purge globale |
| 6 | Build release cible HTTPS autorisée, signature existante, installation en mise à jour sans perte, confidentialité prête | APK final, `adb install -r`, mode avion/redémarrage/reconnexion, permissions, Android modeste et TalkBack | Stopper diffusion ; mise à jour corrective signée avec même clé et versionCode supérieur. Ne pas demander désinstallation qui perdrait des données |
| 7 | Aucun trafic pub par défaut, aucune interruption d’exercice, consentement adapté avant tout appel éventuel | Mode enfant si applicable, refus/retrait consentement, SDK absent ou inactif, offline et non-blocage | Désactiver fournisseur/emplacement via mécanisme indépendant, revenir à version sans activation ; données éducatives conservées |

Le rollback de schéma n’est pas un `migrate` inverse aveugle : une sauvegarde peut devenir ancienne dès les premières écritures. Préférer changement compatible, désactivation ciblée ou correction en avant ; toute restauration doit prévoir les écritures survenues depuis le backup et une fenêtre contrôlée.

## Mesures de performance à établir avant optimisation

Référence disponible : rendu Django synthétique dictionnaire 101/1001 mots, 7 requêtes, 93 956/823 856 octets HTML, respectivement 31,9/69,0 ms au second passage d’audit. Échantillons uniques, non comparables à un Android réel ; aucune optimisation appliquée, donc aucun gain avant/après annoncé.

Mesurer ensuite sur le même commit, corpus, téléphone modeste identifié et réseau : démarrage à froid/chaud, temps jusqu’à première action utile, latence recherche, frames lentes, pic mémoire téléchargement/extraction/audio/image, taille APK installée, taille packs, stockage restant, octets réseau pour seconde consultation et reconnect. Conserver médiane/p95 sur au moins 20 répétitions lorsque pertinent, distinguer démarrage Render et temps applicatif. Fixer les seuils après référence réelle et budget d’appareil. Ne pas confondre taille du dossier médias avec taille téléchargée par utilisateur.

## Jalons non exécutés dans cette session

Restauration physique nouvelle, tests de charge, scan CVE, PostgreSQL/Render/R2, CI distante, navigateur interactif et captures, vérification contrastes, lecteur écran réel, son authentique, appareil Android/iOS, build et signature finale, mise à jour installée et mode avion de bout en bout. Les rapports d’octobre ne remplacent pas ces vérifications pour la version à publier.

La validation du plan et du lot suivant est nécessaire avant changement structurel. Aucun statut « réussi » ne doit être attribué à ces jalons sans exécution et preuve associée.
