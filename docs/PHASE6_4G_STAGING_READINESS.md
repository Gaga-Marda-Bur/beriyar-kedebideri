# Lot 6.4G — Qualification RC1 et dossier staging

11 novembre 2026. **NO-GO pour un déploiement staging immédiat.** Les vérifications
locales et Samsung sont concluantes sur plusieurs fonctions, mais elles ne lèvent
ni les prérequis de la cible distante ni les réserves pédagogiques constatées.
Aucun déploiement distant/public, paiement, publicité ou modification linguistique.

## 1. Référence exacte et préservation

Référence reçue : `codex/phase6-4f-release-candidate`, commit
**964b73d5c884d9dc9a115e18c7c87b37f1cc28fb**. Branche de qualification :
`codex/phase6-4g-staging-readiness`. Le dossier distingue :

- **RC1 originale** : arbre Git mobile archivé, APK éducatif reconstruit deux fois.
- **Correctifs 6.4G** : fermeture des simulations en staging et garde de route Flutter.
- **Harnais QA** : simulation activée uniquement dans les tests isolés sur comptes
  fictifs ; jamais assimilé au build éducatif livré.

Six bytecodes Python étaient déjà modifiés à l'arrivée. Leurs empreintes sont dans
[INITIAL_STATE.json](phase6_4g/INITIAL_STATE.json) ; ils sont conservés hors commit.
La base source `backend/db.sqlite3` est ouverte en lecture seule pour l'inventaire.
Son empreinte reste `8c1d4b1cf3a9415b17510fe5ce0b80c080ed056d7ca884730352214eadc65aef`.
Les migrations des tests concernent exclusivement des bases mémoire/jetables ou
une copie de recette. Aucune migration sur la base existante ou sur Render.

## 2. Résultats réellement exécutés

| Contrôle | Avant correction, rejoué ici | Après correction |
|---|---|---|
| Django global, SQLite mémoire | 155, dont 153 réussis et 2 réservés à PostgreSQL | **158, dont 156 réussis et 2 réservés à PostgreSQL** |
| Module commercial, PostgreSQL local isolé | 38 réussis, périmètre plus large que les 20 cités en F | **41 réussis**, concurrence comprise |
| Flutter global | 151 réussis | **152 réussis** |
| Analyse Flutter | — | **Aucune anomalie** |
| JavaScript audio/typographie, Node | **5 réussis**, pas « N/A » | Sources JS inchangées |
| Reproduction garde staging | 3 tests : **2 échecs attendus**, 1 réussi | **3 réussis** |
| Chrome réel headless | Ancien reçu HTTP insuffisant | **12 sondes : 10 réussies, 2 réserves observées** |
| Samsung physique | Réinstallations QA distinctes | **9 scénarios réussis**, plus contrôle de route du candidat corrigé |
| `check --deploy`, profil staging synthétique | Modèle F : production et preload activé | **2 avertissements HSTS conservés**, aucune erreur |

Résultats et empreintes : [RESULTS.json](phase6_4g/RESULTS.json).
Les logs bruts sont conservés sous `phase6_4g/runtime/`, ignorés par Git.
Les tests PostgreSQL ne sont pas additionnés comme autant de tests Django uniques.

## 3. Preuves navigateur et portée de l'ancien reçu

`docs/phase6_4e/e2e_web_receipt.py` utilise `urllib`, un CookieJar et des recherches
de sous-chaînes HTML. Il produit **19 clés de résultat**, contient **zéro assert**,
suit les redirections et imprime aussi les booléens faux sans échouer.
Il ne lance aucun moteur navigateur, n'exécute ni JavaScript, ni clavier, ni
décodage audio, ni contrôle de mise en page. Son serveur de fixtures ne prouve
pas la couverture pédagogique de la vraie base.
Voir [LEGACY_RECEIPT_AUDIT.json](phase6_4g/LEGACY_RECEIPT_AUDIT.json).

La nouvelle recette utilise **Chrome 157.0.8103.50**, piloté par Playwright en
headless, sur loopback et copie du corpus local. Les comptes de la copie sont
neutralisés, les tables privées nettoyées, les médias privés non servis ; seul
un compte fictif permet la vérification de session.

| Interaction Chrome | Résultat et preuve |
|---|---|
| Navigation ordinateur → alphabet | Clic réel et URL finale vérifiée, capture `alphabet_desktop.png` |
| Recherche dictionnaire | Saisie d'un terme déjà présent, soumission, résultat retrouvé ; un seul mot publié visible |
| Clavier Erfe | Ouverture, clic caractère puis suppression ; valeur réelle de l'input contrôlée |
| Parcours public | **Réserve : aucun lien d'unité**, les deux thèmes sont draft |
| Unité/leçon directe | Unité publiée ouverte directement, contenu de leçon rendu ; ne résout pas sa découverte |
| Quiz JavaScript | Sélection changeant l'état puis validation et feedback affiché |
| Audio | Bouton réel, état playing, horloge du lecteur avançant, durée et fichier HTTP 200 ; aucune écoute humaine revendiquée |
| Authentification | Fetch exécuté dans Chrome : CSRF, login 200, état 200, logout 200, puis 401 |
| Responsive mobile | Vue 390×844, menu réellement ouvert (`aria-expanded`), pas de débordement horizontal sur l'accueil testé |
| Typographie | Chrome/CDP confirme Kedebideri utilisé dans le titre mixte ; six graisses HTTP 200 et octets identiques aux sources |
| Préférence clair/sombre web | **Réserve : aucun thème distinct observé**, les deux préférences sont exercées mais le rendu reste fixe |

[BROWSER.json](phase6_4g/BROWSER.json) conserve succès **et échecs**, erreurs JS et
requêtes HTTP. Le 401 final est attendu. Aucune origine tierce observée sur ces
pages ; cela n'est pas une certification de tout parcours possible. Captures dans
[captures](phase6_4g/captures/), notamment
[clavier](phase6_4g/captures/keyboard_erfe.png),
[parcours vide](phase6_4g/captures/learning_path.png),
[leçon directe](phase6_4g/captures/direct_unit_lesson.png).

Le serveur HTTP de recette n'est pas du staging : son DEBUG et ses cookies locaux
ne qualifient ni HTTPS ni les cookies Secure d'une cible distante. Exports PDF,
tests manuels d'accessibilité et audio entendu par une personne restent non rejoués.

## 4. Android reproductible et preuves Samsung

Téléphone réellement utilisé : **Samsung SM-A336E, Android 16, API 36**, version
relevée pendant ce lot ; ne pas reprendre Android 13 du rapport F.
Package QA : `com.afrigama.beriyarkedebideri.qa64c`, version **1.0.0 / build 1**.
Flutter **3.44.1**, Android build-tools **36.0.0**, minSdk **24**, targetSdk **36**.

L'APK éducatif original est compilé depuis l'archive de 964b73d avec :

```text
flutter build apk --debug --no-pub
  --dart-define=BK_IDENTITY_QA=true
  --dart-define=BK_PREMIUM_SIMULATION=false
  --dart-define=API_FLAVOR=local
  --dart-define=API_BASE_URL=http://127.0.0.1:18778/api
```

SHA-256 **edc228af2ce1d50ecb222e980b331562d479aba1b42cc35271ff41b62b155a31**,
168 823 574 octets. Après `flutter clean`, résolution hors ligne des mêmes
dépendances et reconstruction, **SHA-256 identique**, mêmes entrées ZIP.
Preuve : [REPRODUCIBILITY.json](phase6_4g/REPRODUCIBILITY.json).
Cette égalité vaut sur la machine/toolchain mesurée, pas sur toute machine.

Les sources Android/Dart originales sont inchangées dans l'archive de travail ;
`pub get` régénère sept registrants desktop non utilisés par l'APK Android.
Les 316 fichiers d'origine ont été comparés ; voir
[MOBILE_SOURCE_CHECK.json](phase6_4g/MOBILE_SOURCE_CHECK.json).
Le harnais de persistance ajouté par 6.4G est une surcouche de test explicite.

Le build est **debug QA**, pas une release signée/publicable ni une mesure de
taille finale. La commande release F omet API_FLAVOR et les prérequis de signature ;
elle ne constitue pas une procédure de release validée. Aucune nouvelle clé de
signature de publication n'est créée. Artefact et flags détaillés dans
[ANDROID_ARTIFACT.json](phase6_4g/ANDROID_ARTIFACT.json).

| Scénario physique | Vérification |
|---|---|
| Initialisation A | Connexion par les vrais champs, droits signés et clés natives |
| A → logout → B | B gratuit, aucun avantage A actif |
| Réouverture B | Contexte B conservé, pas d'avantage A |
| Reconnexion A | Droit simulé récupéré auprès du serveur |
| A hors ligne | Mode avion système à 1, accès USB au backend retiré, lecture locale valide |
| Logout invité hors ligne | Nouveau contrôleur sans identité ni droit précédent |
| Erfe clair/sombre | 50 glyphes, chaînes mixtes et diacritiques rendus et captures inspectées |
| Vrai pack et progression | ZIP téléchargé avec checksum via les services existants ; progression locale enregistrée |
| Réouverture pédagogique hors ligne | Progression comparée sans la réécrire, pack lu localement et checksum inchangé ; effacement des seules clés commerciales sans perte pédagogique |

Le harnais historique réécrit sa sentinelle à chaque lancement : ce seul marqueur
ne prouve pas la persistance. La surcouche 6.4G teste donc un vrai enregistrement
UnitProgressLocalStorage et le pack réel, séparément.
[SAMSUNG_SCENARIOS.json](phase6_4g/SAMSUNG_SCENARIOS.json),
[SAMSUNG_LEARNING.json](phase6_4g/SAMSUNG_LEARNING.json),
[Erfe clair](phase6_4g/captures/samsung_erfe_light.png),
[Erfe sombre](phase6_4g/captures/samsung_erfe_dark.png).

Le candidat corrigé a son propre hash dans
[ANDROID_CANDIDATE.json](phase6_4g/ANDROID_CANDIDATE.json). Installé sous le même
package QA, un lancement direct `/premium` atteint l'accueil gratuit, sans UI
Premium. La lecture d'accessibilité prend en compte `content-desc` Flutter.
Les empreintes/UID/version/date de mise à jour du package principal sont identiques
avant et après ; aucune désinstallation ni lecture de ses données utilisateur.

Pas de reboot système Samsung dans ce lot : réouvertures d'application seulement.
Pas de notation de prononciation, nouvelle traduction ou nouvel enregistrement.
Le réseau du téléphone est rétabli à son état initial après les tests.

## 5. Inventaire pédagogique local réel

Portée : SQLite locale du dépôt et fichiers locaux ; **pas la base Render**.
Publication technique et validation linguistique humaine sont distinguées.
[INVENTORY.json](phase6_4g/INVENTORY.json), [PACK_CHECKS.json](phase6_4g/PACK_CHECKS.json).

| Élément | Observé | Préparation du pilote |
|---|---|---|
| Caractères | 50 actifs ; **2 published, 48 review** | Couverture typographique prouvée ; alphabet pédagogiquement complet non qualifié |
| Dictionnaire | 4 actifs ; **1 published, 3 draft** | L'entrée publiée porte le libellé français « exemple test » ; révision humaine nécessaire, pas un lexique prêt démontré |
| Leçons | 1 publiée, 1 item publié, 1 association audio | Prototype réduit ; pas un cursus complet |
| Unités | 4 actives/publiées | Accès direct possible, découverte publique bloquée par les thèmes |
| Thèmes | **2 draft** | Aucun thème public ; décision éditoriale humaine requise |
| Exercices | 2 quiz publiés, audio_to_character ; 8 options ; 3 liens audio | Interaction testée ; couverture pédagogique limitée |
| Audio | 2 assets publiés réellement présents : WAV 791 192 octets, MP3 9 643 octets | Octets/checksums et lecture navigateur vérifiés ; authenticité, licences, locuteurs et qualité perceptuelle non revalidés |
| Packs | 1 publié ; ZIP 1 951 973 octets, 12 entrées, CRC et checksum valides | Techniquement fonctionnel sur Samsung ; 5 caractères liés dont **3 encore review**, 1 mot, 1 leçon et 1 quiz |
| Parcours A | Choix et moteur audio-first Flutter présents | Contenus alimentés par le petit corpus ci-dessus, pas de parcours oral complet qualifié |
| Parcours B | Choix/catalogue thématique Flutter présents | Thèmes draft ; parcours public non prêt démontré |

Les titres des unités et leurs véritables états sont dans l'inventaire. Le rapport F
ne constitue pas une preuve des descriptions de consonnes/voyelles ni d'un exercice
de tracé ; aucun exercice manuscrit n'est ajouté. Aucun statut ni contenu n'a été
automatiquement promu ou « corrigé » pour faire passer la recette.

## 6. Désactivation commerciale et correctifs minimaux

| Frontière | Référence 964b73d | Qualification/correction 6.4G |
|---|---|---|
| Paramètres Flutter | Bouton masqué si flag absent | Conservé ; le masquage ne suffit pas à qualifier la route |
| Route `/premium` | Routage inconditionnel vers la page, contrôleur inactif sans flag | **Route elle-même gardée**, repli accueil gratuit sans simulation ou en release ; test widget et Samsung |
| Liens profonds Android | Pas de filtre VIEW/BROWSABLE/data déclaré | Audit du manifeste ; route initiale directe testée séparément |
| Contrôleur et leases | Flags/debug/origine et vérification cryptographique | Conservés, aucun booléen local n'octroie un droit |
| Publicités/ventes | False par contrainte SQL, zéro SDK/adaptateur réel | Conservé ; aucun réglage Admin ne rend la vente réelle active |
| API/Admin simulation | Services bloquent production mais **autorisaient staging** | **Mutations et clés/challenges de simulation limitées à development/test**, même pour un superuser |
| Données gratuites | Aucune dépendance à Premium | Préservées, y compris le style historique `StickerStyleType.premium` |

Fichiers métier modifiés : `mobile/lib/app/app.dart`,
`backend/monetization/services.py`, `backend/monetization/licensing.py`.
Tests ajoutés : `tests_staging_gate.py`, `educational_route_gate_test.dart`.
Pas de migration ni de changement du format des API pédagogiques. Les mutations
de simulation en staging deviennent volontairement refusées ; les lectures
personnelles/authentification ne constituent pas une activation commerciale.
Les fixtures QA en environnement test restent fonctionnelles, démontrées sur Samsung.

## 7. Configuration staging, sauvegardes et permissions

[STAGING_CHECKS.json](phase6_4g/STAGING_CHECKS.json) : profil staging synthétique,
DEBUG false, HTTPS/cookies Secure, session HttpOnly/SameSite, hôtes explicites,
CORS sans wildcard, six sondes de configurations dangereuses rejetées.
`check --deploy` garde **W005 et W021** : HSTS court sans sous-domaines ni preload.
Ils ne sont pas masqués pour obtenir artificiellement « zéro warning ».

Le modèle F utilisait `DJANGO_ENV=production`, preload HSTS annuel et noms de
variables R2 partiellement différents des paramètres réellement lus. Les hôtes
locaux mentionnés dans ce modèle sont cependant **retirés par le code** : aucune
autorisation effective d'un hôte local en staging n'est ainsi démontrée.
Le nouveau [staging.env.example](phase6_4g/staging.env.example) ne contient pas
de faux secret prêt à copier et reste volontairement non déployable sans saisie
des domaines, secrets dédiés et stockage vérifié.

Le stockage persistant ne se déduit pas d'un booléen. ACL/buckets privés, permissions
Linux, rôle PostgreSQL minimal, TLS DB et proxy, journaux/rétention, secrets de la
cible et certificats ne sont **pas vérifiés à distance**. Le cache feedback partagé
est exigé ; le cache général reste LocMem : aucune garantie universelle de quota
distribué ne découle de ce seul réglage.

Une probe `pg_dump/pg_restore` dans deux bases temporaires avec deux lignes fictives,
et une copie d'audio à checksum identique, réussit :
[BACKUP_PROBE.json](phase6_4g/BACKUP_PROBE.json). Ce n'est **pas** une restauration
BK complète base+objets distants, ni une mesure de RPO/RTO. Les tests de schéma
PostgreSQL appliquent bien les migrations du projet dans leur base jetable.

## 8. Réserves restantes et priorités

- **P0, avant staging distant** : domaine/TLS/proxy, nouveaux secrets propres au
  staging, base/role/réseau distincts, médias persistants/privés et sauvegarde cible
  restaurable, journaux et permissions effectifs à prouver.
- **P1, avant pilote éducatif ouvert** : thèmes draft, 48 caractères en revue,
  traduction publiée de test et trois caractères du pack encore review ; couverture
  orale très faible. Validation par locuteurs/éditeurs, sans génération approximative.
- **P2** : thème web clair non observé, exports PDF/manuels et accessibilité non
  requalifiés ; debug APK volumineux, aucune mesure de performance Android modeste.
- **Limites générales** : révocation immédiate hors ligne impossible, root/rollback
  intégral non inviolables ; prérequis existants de comptes/caches conservés.
- Les empreintes de deux builds **du même original** sont égales. Ne pas comparer
  ce résultat comme une égalité binaire avec le candidat corrigé ou le harnais QA.

## 9. Rollback et dossier d'autorisation

[STAGING_AUTHORIZATION_CHECKLIST.md](phase6_4g/STAGING_AUTHORIZATION_CHECKLIST.md)
définit les preuves et le retour arrière. Aucun nouveau schéma à annuler en 6.4G.
Préférer un correctif en avant conservant les gardes ; revenir aveuglément à
964b73d réintroduit les réserves commerciales corrigées.
Ne pas utiliser `pg_restore -c` sur une base utilisée, ni effacer de ledger ou de
progression. Restaurer d'abord sur une base neuve et vérifier médias/données avant
toute bascule autorisée. Les bytecodes préexistants ne sont ni écrasés ni inclus
dans le commit. Liste exacte : [FILES_CHANGED.txt](phase6_4g/FILES_CHANGED.txt).

## 10. Décision

**GO pour clôturer la qualification locale et examiner le dossier d'autorisation.**
**NO-GO pour déployer immédiatement le staging** : la cible n'est pas encore
provisionnée/auditée et la préparation pédagogique ne permet pas d'homologuer un
pilote général. Un staging privé de validation éditoriale pourra être considéré
après les prérequis P0 et une décision humaine explicite de périmètre ; il ne
vaudra pas publication du corpus en revue.

Les deux gardes techniques ont été corrigées et testées ; les lacunes linguistiques
et les preuves distantes restent des réserves explicites, pas des tests réussis.
Travail arrêté après le commit de qualification. **Aucune autorisation de
déploiement implicite : attendre la validation de l'utilisateur.**
