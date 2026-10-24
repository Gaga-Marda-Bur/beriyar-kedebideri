# Préparer une distribution mobile — A13

Le build Android release refuse une configuration d’API implicite, locale ou HTTP. Les versions de développement debug/profile peuvent continuer à utiliser l’API locale. Le manifeste principal interdit le trafic HTTP en clair ; seules les variantes debug/profile l’autorisent.

## Commande de build

Depuis `mobile/`, utiliser le script `tool/build_release.ps1` :

```powershell
./tool/build_release.ps1 -Flavor production
./tool/build_release.ps1 -Flavor staging
./tool/build_release.ps1 -Flavor production -Target appbundle
```

`-ApiBaseUrl` permet de préciser une URL HTTPS différente. L’environnement doit rester explicite : `production` ou `staging`. Les URL avec identifiants, paramètres ou fragments, ainsi que les adresses locales/privées détectables par leur écriture, sont refusées. Le script et les diagnostics ne doivent pas afficher d’identifiants éventuellement inclus dans une URL invalide.

Le numéro de build doit dépasser celui de la version réellement distribuée. Une fois ce numéro déterminé par le responsable de publication, le passer avec `-BuildNumber`. S’il est omis ou vaut 0, la version définie par le projet reste utilisée ; aucun incrément n’est inventé automatiquement.

Les commandes Flutter directes restent possibles :

```text
flutter build apk --release --dart-define=API_FLAVOR=production
flutter build appbundle --release --dart-define=API_FLAVOR=staging
```

Gradle vérifie aussi les paramètres fournis directement par Flutter. Si une release contourne Gradle, par exemple sur une autre plateforme, un garde-fou au démarrage empêche l’application de lancer ses services réseau avec une configuration invalide. L’écran utilisateur propose de mettre la version à jour ou de contacter le projet, sans exposer les détails techniques.

## Vérifier la cible réelle

Les valeurs actuelles sont `https://api.beriyarkedebideri.com/api` et `https://staging-api.beriyarkedebideri.com/api`. Elles sont des valeurs de configuration, **pas une preuve de disponibilité**. Confirmer DNS, certificat, routes, hôtes Django autorisés et accès réseau depuis le téléphone avant distribution. Une URL HTTPS publique dans sa syntaxe peut encore résoudre vers une mauvaise adresse : la validation du build ne remplace pas cette recette.

## Préserver la signature et les données

- Conserver `applicationId=com.afrigama.beriyarkedebideri`, la clé de signature et l’alias de la version déjà distribuée.
- Utiliser les fichiers de signature existants. Le build refuse une configuration absente/incomplète ; il ne génère ni nouvelle clé ni signature de remplacement.
- Ne pas ajouter `key.properties`, keystores ou mots de passe au dépôt ou aux journaux. Les garde-fous vérifient leur présence, pas la validité cryptographique du mot de passe ou du certificat.
- Comparer le certificat de signature de l’APK final à celui de la version distribuée, puis tester une installation **en mise à jour**, sans désinstallation, avec conservation des packs, brouillons et progressions.
- Publier uniquement après validation du numéro de version, du certificat et de la cible API.

## Vérifications de cette tranche

La tâche Gradle `:app:preReleaseBuild` a été exécutée en mode hors ligne avec la configuration de signature déjà présente :

| Paramètres | Résultat attendu et observé |
|---|---|
| Sans `API_FLAVOR` | Refus explicite A13 |
| `API_FLAVOR=production`, API HTTP locale | Refus explicite A13 |
| `API_FLAVOR=production`, cible HTTPS par défaut | Contrôle préparatoire réussi |

Cette tâche ne compile ni ne signe l’APK final. Aucun nouvel APK/AAB n’a été produit ou diffusé pendant cette tranche. Les avertissements de compatibilité Kotlin/Gradle affichés par la chaîne Android restent à examiner séparément ; aucune mise à niveau de dépendance n’a été effectuée implicitement.
