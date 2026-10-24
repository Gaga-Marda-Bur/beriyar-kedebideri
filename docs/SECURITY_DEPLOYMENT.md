# Préparer les réglages serveur — A14 / A15

Ces réglages sont implémentés et testés localement. Les variables et services de production n’ont pas été modifiés. Aucun secret ni fichier de signature n’a été remplacé.

## Environnement et secrets

Déclarer explicitement `DJANGO_ENV=production` et `DEBUG=False` chez l’hébergeur. Sans environnement explicite, un service Render ou `DEBUG=False` sont traités comme production. Le développement et les tests disposent de leurs profils distincts.

La production exige une `SECRET_KEY` existante non vide, non publique, d’au moins 50 caractères variés. Le code ne génère pas de clé de remplacement. Une clé existante est utilisée telle quelle, sans suppression de ses espaces. Si la clé actuelle est insuffisante, préparer une rotation distincte avec son impact sur les sessions et signatures ; ne pas déployer en remplaçant arbitrairement la valeur.

Renseigner `ALLOWED_HOSTS` avec les hôtes réellement servis, dont l’hôte API utilisé par le mobile, et `CSRF_TRUSTED_ORIGINS` avec des origines HTTPS sans chemin, paramètres ni identifiants. Les hôtes génériques `*`, la liste vide et les origines CSRF mal formées sont refusés en production. Les secrets R2 requis lorsque `USE_R2=True` restent obligatoires comme auparavant.

Un fichier `.env.production` présent sur disque n’est pas une preuve que ses valeurs sont chargées par le processus de l’hébergeur. Vérifier les variables effectives du service, sans les copier dans le dépôt ou les journaux.

## Vérifier le proxy avant de lui faire confiance

`TRUST_X_FORWARDED_PROTO` est désactivé par défaut. Pour Render, le démarrage en production demande une activation explicite après vérification du proxy TLS. Lorsque cette confiance est activée en production, `NUM_PROXIES` doit aussi être explicitement positif et correspondre au chemin réel des requêtes, y compris un éventuel CDN.

1. Vérifier que le proxy contrôlé écrase l’en-tête `X-Forwarded-Proto` fourni par le client et que le backend n’est pas exposé directement en contournant ce proxy.
2. Déterminer la chaîne `X-Forwarded-For` effective ; ne pas supposer que le nombre de proxys est toujours 1.
3. Configurer `TRUST_X_FORWARDED_PROTO=True` et le `NUM_PROXIES` mesuré dans l’environnement de test, puis vérifier les requêtes avant production.
4. Consulter `/api/core/diagnostics/https/` avec un compte staff authentifié. La réponse expose le schéma reconnu, les en-têtes de transport, l’identifiant client utilisé par les quotas et les réglages non secrets. Aucun cookie, mot de passe ou secret n’est retourné ; les adresses IP restent réservées au staff.
5. Contrôler une requête HTTPS et une requête HTTP : pas de boucle de redirection, HTTPS reconnu, cookies `Secure`, et identification correcte du client. Une valeur arbitraire envoyée par le navigateur ne doit pas suffire à contourner la politique.

Le diagnostic n’a pas été exécuté contre la production dans cette tranche. Le test local prouve le comportement du code selon la configuration, pas le comportement du proxy réel. Les conditions de confiance dans cet en-tête sont décrites par [Django](https://docs.djangoproject.com/en/6.0/ref/settings/#secure-proxy-ssl-header).

## HTTPS, HSTS et cookies

Le bloc `config/security.py` est désormais l’unique source des réglages de sécurité. En production : redirection HTTPS obligatoire et cookies de session/CSRF sécurisés. Le développement local reste utilisable en HTTP.

Sans politique explicitement configurée, HSTS commence à 300 secondes, sans extension aux sous-domaines ni préchargement. Les valeurs HSTS déjà fournies par l’environnement sont prises en compte ; il n’y a plus de second bloc qui les écrase.

Augmenter la durée seulement après vérification de la disponibilité TLS des domaines concernés. `SECURE_HSTS_INCLUDE_SUBDOMAINS=True` et `SECURE_HSTS_PRELOAD=True` demandent une décision explicite ; le préchargement exige une durée d’au moins un an et l’inclusion des sous-domaines. Le code n’effectue aucune inscription à une liste de préchargement. Un déploiement progressif peut encore faire apparaître les avertissements HSTS de `manage.py check --deploy` ; ils ne doivent pas être masqués ou présentés comme une certification de sécurité complète.

## Feedbacks : quotas et stockage du compteur

Les quotas par défaut sont :

| Variable | Défaut | Portée |
|---|---|---|
| `FEEDBACK_RATE_BURST` | `5/min` | Client anonyme par IP effective ou compte connecté |
| `FEEDBACK_RATE_SUSTAINED` | `30/hour` | Même portée, sur une durée plus longue |
| `FEEDBACK_RATE_DEVICE` | `20/hour` | Identifiant d’installation en complément pour l’API |

Le web et l’API partagent les quotas client. Les tentatives invalides peuvent aussi consommer ces quotas. Les comptes staff authentifiés sont exemptés des quotas, mais restent soumis à la validation des champs. Un identifiant de périphérique reste déclaratif et ne constitue pas une authentification.

Le cache de quotas est l’alias `feedback`. Par défaut, `LocMemCache` convient au développement, mais ses compteurs sont séparés par processus et disparaissent au redémarrage. Pour plusieurs workers/instances, configurer un cache partagé. Une possibilité sans nouveau paquet Python est :

```text
FEEDBACK_CACHE_BACKEND=django.core.cache.backends.db.DatabaseCache
FEEDBACK_CACHE_LOCATION=feedback_rate_limits
```

La table dédiée doit être préparée sur l’environnement cible, après vérification de ses sauvegardes et de ses permissions, avec la commande Django `createcachetable feedback_rate_limits`. Cette table n’a pas été créée sur la base de travail ou en production pendant cette tranche. Un cache partagé déjà exploité par l’équipe peut aussi être utilisé avec le backend et les dépendances appropriés.

Les limites DRF restent approximatives en concurrence et ne constituent pas une protection DDoS. Compléter avec une politique à la périphérie et une limite de taille de requête adaptée. Vérifier les usages légitimes derrière un NAT partagé avant de modifier les seuils. Les limites documentées par [DRF](https://www.django-rest-framework.org/api-guide/throttling/) s’appliquent à cette implémentation.

## Validation et reprise des signalements

- Type autorisé, titre de 255 caractères au maximum, message de 5000 caractères au maximum, message ou titre requis.
- Plateforme, langue, identifiant d’installation, version et date client contrôlés ; caractères de contrôle et surrogates Unicode isolés refusés.
- Cibles limitées à une liste de modèles pédagogiques existants avec identifiant entier ; aucune référence aux utilisateurs, sessions ou progressions. Les pistes audio UUID ne sont pas des cibles de ce champ entier ; un problème audio peut être décrit dans le message.
- Statut, priorité, utilisateur, note interne et lien `audio_feedback` ne sont pas des champs d’écriture publique.
- Capture JPEG/PNG/WebP de 2 Mo et 4096 pixels par côté au maximum, avec contenu vérifié. Les nouveaux fichiers valides reçoivent un nom serveur aléatoire et une extension correspondant au format ; les fichiers existants ne sont pas renommés.
- L’API refuse les requêtes déclarées de plus de 3 Mo. Ce contrôle ne remplace pas une limite d’entrée au niveau proxy, notamment pour les corps transmis en flux.
- Le formulaire web conserve le texte après erreur 400/429 et conserve sa protection CSRF. Le mobile affiche le délai `Retry-After` sur un 429 et garde la saisie pendant que l’écran reste ouvert. Il ne promet pas une sauvegarde du feedback sur le serveur après un refus ou après fermeture de l’application.

## Avant diffusion

Valider le profil de production sur un environnement séparé, vérifier le proxy et le cache partagé, exécuter les tests puis `manage.py check --deploy` avec les variables cibles. Revoir séparément les avertissements de politique HSTS. Aucun déploiement, aucune rotation de clé et aucune modification des archives R2/CDN n’est inclus dans ces opérations locales.
