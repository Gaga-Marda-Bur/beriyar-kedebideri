# A13 / A14 / A15 — reprise et finalisation

Travail repris après interruption, le 24 octobre 2026. Les changements amorcés ont été vérifiés et complétés ; aucune clé ni donnée existante n’a été remplacée.

## A13 — configuration release

`ApiConfig` et Gradle exigent `production` ou `staging` explicitement pour une release. HTTP, hôtes locaux/privés connus, identifiants dans l’URL, paramètres et fragments sont refusés. Le garde-fou Dart au démarrage bloque aussi les services réseau si une configuration invalide a contourné le build Android. Le développement local debug/profile continue de fonctionner.

Le manifeste principal interdit HTTP en clair. Les fichiers et paramètres de signature existants restent utilisés ; aucun keystore de remplacement n’est généré. Le script `mobile/tool/build_release.ps1` permet de choisir le profil, APK/AAB, l’URL et, facultativement, un numéro de build explicite.

Trois contrôles Gradle réels ont été effectués sur `:app:preReleaseBuild` : absence de profil refusée, API HTTP locale refusée, profil production avec cible HTTPS par défaut accepté. Aucun APK/AAB final n’a été produit ou signé. La tâche vérifie la présence de la configuration de signature, pas la validité finale du certificat ou du mot de passe.

Voir [RELEASE_MOBILE.md](RELEASE_MOBILE.md) pour la cible API, la signature et la recette de mise à jour à vérifier avant distribution.

## A14 — réglages serveur explicites

Le nouveau module testable `config/security.py` centralise les secrets, DEBUG, hôtes, origines CSRF, HTTPS, HSTS, cookies et confiance dans le proxy. La production refuse les secrets manquants/publics/faibles, `DEBUG=True` et la désactivation de la redirection HTTPS. Une clé existante est utilisée sans transformation et n’est jamais régénérée.

La confiance dans `X-Forwarded-Proto` et le nombre de proxys ne sont plus implicites. Un diagnostic HTTPS réservé au staff permet d’examiner les valeurs effectives après préparation du déploiement. HSTS dispose d’une politique progressive par défaut, sans imposer le préchargement ou les sous-domaines ; les valeurs explicitement configurées ne sont plus écrasées par un bloc ultérieur.

La vérification du proxy réel reste à faire sur l’environnement cible. Ce travail local ne confirme ni ses en-têtes ni son isolation réseau.

## A15 — validation commune et limites sur les feedbacks

Le nouveau sérialiseur de création est maintenant utilisé par l’API. Le formulaire Django et l’API appliquent les mêmes règles de texte, catégories et métadonnées. Les champs internes ne sont pas modifiables publiquement ; les cibles sont limitées ; les images ont des limites de format, taille et dimensions. Les requêtes déclarées trop volumineuses sont refusées et les entrées mal formées sont testées sans erreur 500.

Les limites courtes et longues par client sont communes au web et à l’API, avec une limite supplémentaire par identifiant d’installation. Les clés de cache d’installation sont hachées. Un 429 fournit `Retry-After`. Le web réaffiche la saisie ; Flutter conserve le texte et indique le délai. Aucun contenu refusé n’est présenté comme sauvegardé sur le serveur.

Un cache partagé doit être configuré pour agréger les quotas de plusieurs workers/instances. Le cache mémoire par défaut est local au processus. Les compteurs DRF sont approximatifs en concurrence ; une protection réseau et une limite d’entrée restent nécessaires. Voir [SECURITY_DEPLOYMENT.md](SECURITY_DEPLOYMENT.md).

## Validation

| Vérification | Résultat |
|---|---|
| Suite Django isolée | 52 tests réussis |
| Suite Flutter avec sonde de cache | 63 tests réussis |
| Analyse Flutter | Aucun problème signalé |
| Modèles / migrations | Aucun changement détecté |
| Prévalidation Gradle sans profil | Refus attendu A13 |
| Prévalidation Gradle avec API HTTP locale | Refus attendu A13 |
| Prévalidation Gradle production / HTTPS | Réussite |

Les nouveaux tests couvrent les réglages de production, les en-têtes et permissions du diagnostic, les limites courtes/longues/périphérique, la reprise après expiration d’une limite, les signalements staff légitimes, les champs interdits, CSRF, les pièces jointes, les payloads mal formés et Unicode, ainsi que la saisie Flutter après 429.

Les tests Django utilisent une base en mémoire et des médias temporaires. Les tests Flutter utilisent des préférences et des réponses HTTP simulées. Aucune migration supplémentaire n’est nécessaire pour cette tranche. La base de travail, les variables et services de production, les secrets, les signatures et les archives R2/CDN n’ont pas été modifiés. Les changements antérieurs du dossier de travail ont été conservés.

Le motif d’exclusion Git couvre aussi les sauvegardes `backend/*.sqlite3.bak*`, dont la sauvegarde locale antérieure à A01. Les fichiers restent sur disque ; ils ne doivent pas être publiés avec le code.

Commandes, depuis la racine :

```text
backend/venv/Scripts/python.exe docs/run_backend_checks.py
```

Depuis `mobile/` :

```text
flutter test --no-pub test ../docs/audit_cache_probe.dart
flutter analyze --no-pub
```

Ces résultats valident l’implémentation locale. Ils ne remplacent pas un build APK complet, la comparaison des certificats, l’installation sur appareil, la vérification de la cible API, la recette du proxy et du cache partagé, ou un audit de sécurité exhaustif de production. Gradle signale aussi des avertissements de compatibilité Kotlin/plugins/Gradle à traiter séparément, sans mise à niveau implicite de cette tranche.
