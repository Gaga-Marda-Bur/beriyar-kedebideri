# API réellement implémentée — 6.4B

11 novembre 2026. Préfixe `/api/monetization/v1/`. Toutes les réponses commerciales
sont explicitement en mode `simulation`. Aucune vente, URL de paiement, coordonnée
bancaire, clé privée, API fournisseur ou SDK publicitaire.

| Méthode / route | Accès | Contrat |
|---|---|---|
| GET `public-config/` | Public sans authentification | Flags effectifs Ads/ventes/personnalisation/tracking/collecte AD_ID tous false, audience mixte, âge inconnu protégé, fonctions gratuites, limite hors ligne, aucun emplacement actif |
| GET `catalog/` | Compte actif | Plans marqués `simulation_available`, révision, durée, fonctions ; `purchasable=false`, `price=null`. Pas de tarif commercial inventé |
| GET `me/entitlements/` | Compte actif | `subject` opaque, epoch, mode, status `free/active`, `verification=server_verified`, server_now, features, free_features, grants et bornes UTC |
| GET `me/requests/` | Compte actif | Ses 100 demandes les plus récentes, champs minimaux sans justificatif ni coordonnées |
| GET `me/requests/<uuid>/` | Propriétaire | Même sous-ensemble ; objet tiers ou absent → 404 |
| POST `me/device-keys/challenge/` | Compte actif + CSRF pour session | Corps `purpose=enroll/lease` ; id, nonce aléatoire, expiration 2 min, message exact à signer |
| POST `me/device-keys/` | Compte actif + preuve P-256 | challenge_id, public_key (SPKI DER/base64), signature (ECDSA SHA-256 DER/base64) ; device_id, thumbprint et subject |
| POST `me/offline-lease/` | Compte actif + appareil possédé | challenge_id, device_id, signature ; enveloppe Ed25519 ou refus. Aucune clé privée cliente ou serveur dans la réponse |

Les routes personnelles portent `Cache-Control: private, no-store` et varient
sur Cookie/Authorization, y compris leurs erreurs. La configuration publique
est séparée (`max-age=60`). Le catalogue simulé est volontairement authentifié,
plus restrictif que le catalogue public envisagé en 6.4A ; il ne constitue pas
une vitrine commerciale accessible aux enfants/invités.

Authentification : mêmes sessions Django et Basic DRF existants ; session soumise
à CSRF, utilisateur inactif refusé. Pas de nouvel émetteur JWT, de mot de passe
persisté ou de connexion par UUID/secret de progression. En réseau réel, TLS reste
obligatoire. Le client Flutter reçoit explicitement son transport authentifié ;
il ne partage aucun cookie implicitement avec la synchronisation des progressions.

Erreurs : 400 validation/purpose/preuve mal formée, 401/403 selon authentification,
403 preuve invalide/rejeu/appareil tiers ou révoqué, 404 demande tierce,
405 mutation non offerte, 503 signataire non provisionné ou indisponible.
Une erreur de signature n'est pas convertie en succès. 503/401/403 ne suppriment
ni progrès ni ressources ; un lease encore prouvable reste borné à son expiration.
Au-delà, le client passe à `verificationRequired` ou `expired`, avec le gratuit.

## Protocole signé v1

Enveloppe : `version=1`, `kid=sim-*`, `payload_b64url`, `signature_b64url`.
Message exact : `BK-OFFLINE-GRANT/v1\n{kid}\n{payload_b64url}` en ASCII.
Algorithme fixé : Ed25519. JSON canonique limité aux valeurs ASCII, entiers et
tableaux produits par le serveur ; pas d'algorithme négocié, de doublon JSON ni
d'URL de clés. Flutter vérifie d'abord les octets reçus, puis les claims/canonicalité.

Claims : version, issuer `bk`, audience `bk-android-simulation`, environnement,
subject, lease_id, entitlement_epoch, device_id, device_key_thumbprint,
features, grant_ids, issued_at, starts_at, expires_at, offline_valid_until,
server_now, nonce, policy_version. Les dates sont des secondes UTC entières.
La fin est le minimum de la limite de politique (1 à 7 jours) et de la première
expiration des grants inclus : aucun avantage ne dépasse sa période. Rafraîchir
après cette première fin si d'autres grants restent valides.

Chaque POST de lease signe un nouveau challenge à usage unique, lié au compte et
à sa finalité. Le délai d'aller-retour accepté par le client est borné à 30 s.
Vingt challenges non expirés maximum par compte ; aucune empreinte publicitaire.
Un même reçu de lease ne réancre pas l'horloge ; l'epoch connu ne recule pas.

## Provisionnement de recette

`MONETIZATION_SIGNING_KEY_FILE` désigne une clé privée PEM **externe** Ed25519 ;
`MONETIZATION_SIGNING_KID` un identifiant `sim-[A-Za-z0-9_-]{1,64}`. Aucun défaut
secret et aucun fallback vers SECRET_KEY. Sans provisionnement : 503, sans perte
de données. Aucune clé privée persistante n'a été créée pour le serveur local.
Les tests créent des clés temporaires supprimées à la fin du test.

Les écritures commerciales/émissions sont refusées en `DJANGO_ENV=production`.
Le vérificateur Flutter refuse aussi les leases en production et dans un build
release ; sa liste de confiance par défaut est vide. Les clés publiques de test
ne sont injectées que par les tests. La rotation live reste hors de ce lot.

## API volontairement absentes

Aucun POST public de paiement/don, upload de reçu, webhook, paiement externe,
abonnement auto-renouvelé ou création d'offre commerciale. Les mutations de
simulation passent par l'Admin et les services à permissions. L'outbox reste
locale, sans email envoyé. Les anciens endpoints pédagogiques restent inchangés.
