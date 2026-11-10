# Droits Premium hors ligne — livrable 5 / décision prioritaire

**Spécification proposée, non implémentée ni testée cryptographiquement ici.**
Le compte Django demeure l’autorité. SharedPreferences n’enregistre qu’un cache
non fiable ; aucun `isPremium=true` ne constitue un droit. Les données pédagogiques
ne sont jamais supprimées lors d’expiration, révocation, logout ou erreur commerciale.

## Menaces et frontière de confiance

Prévoir modification du cache, copie d’une attestation entre A/B et appareils,
rejeu, réponse réseau ancienne, recul de l’horloge, changement de compte et perte
d’appareil. Une app rootée/modifiée peut ignorer son propre vérificateur : **pas de
DRM absolu**. Le serveur protège toujours les nouvelles opérations connectées.
Un fichier déjà téléchargé ou une révocation sur téléphone totalement déconnecté
ne peuvent pas être rappelés instantanément.

## Profil de signature proposé

Attestation autonome à algorithme **Ed25519 fixé**, implémentée par bibliothèques
maintenues, jamais des primitives maison. La clé privée de signature reste côté
serveur, distincte de SECRET_KEY Django et des secrets de paiement. Flutter ne
contient que des clés publiques et leur `kid`. Évaluer les dépendances légères
Python/Dart et les vecteurs interlangage avant de les ajouter.
[RFC 8032](https://www.rfc-editor.org/rfc/rfc8032).

Enveloppe versionnée : `version`, `kid`, `payload_b64url`, `signature_b64url`.
Signer les octets exacts d’un message avec séparation de domaine
`BK-OFFLINE-GRANT/v1`, le kid et le payload encodé. Pas de négociation d’algorithme
depuis un champ client, de `alg=none`, ni d’URL arbitraire de clé. Génération JSON
canonique serveur, parsing strict sans doublons ; vérifier les octets reçus sans
les réencoder avant signature. [RFC 8785](https://www.rfc-editor.org/rfc/rfc8785).
Ce profil d’enveloppe est une proposition à réviser, **pas une affirmation de JWT
standard déjà interopérable**.

| Claim obligatoire | Contrôle |
|---|---|
| version, issuer, audience, environnement | Valeurs reconnues et attendues par ce build ; staging ≠ production |
| subject commercial opaque | Correspond au compte authentifié localement établi, jamais à un user_id choisi dans l’UI |
| lease_id, entitlement_epoch | Identifiant unique, version de droits non décroissante ; aucune substitution par un ancien état connu |
| device_key_thumbprint | Correspond à la clé enregistrée de cet appareil, pas au seul UUID d’installation |
| feature_codes / plan_revision | Ensemble autorisé et connu ; code inconnu non activé |
| starts_at, issued_at, expires_at, offline_valid_until | Entiers UTC bornés et ordre cohérent ; aucune prolongation locale |
| nonce de renouvellement / server_now | Fraîcheur de l’échange d’émission, pas une preuve renouvelable depuis un vieux fichier |

Validité proposée à arbitrer : **au plus sept jours**, et jamais après la fin du
grant. Ce n’est pas une grâce ajoutée à un abonnement expiré. Un plan permanent
reçoit aussi une attestation courte renouvelable. Authentification API, TLS et
signature sont complémentaires : une signature valide ne remplace pas la session
requise pour recevoir un nouveau droit.

## Identité d’appareil et copie

Créer une paire de clé de possession Android via Keystore (profil P-256 à évaluer
sur les appareils cibles), enregistrer sa clé publique via nonce serveur et session
authentifiée. La clé privée reste non exportable lorsque le dispositif le permet.
L’attestation de droits lie l’empreinte publique ; le client prouve qu’il détient
la clé correspondante. Ne pas supposer Ed25519 matériel partout, StrongBox ou une
attestation hardware disponible. [Android Keystore](https://developer.android.com/privacy-and-security/keystore).

`DeviceKey` conserve ces autorisations, sans devenir le registre des progressions.
L’UUID et le secret invité existants ne suffisent pas et ne sont pas transférés
au système commercial. Les sessions/attestations/ancres sont dans un stockage
sécurisé scoped compte + appareil + environnement, exclu des backups automatiques.
Le stockage chiffré seul n’empêche pas le rejeu d’une ancienne sauvegarde chiffrée.

Nouvel appareil/réinstallation/perte de clé : réauthentification et enregistrement
en ligne, émission d’une nouvelle attestation, sans nouvel achat si le droit serveur
est encore valide. Ne pas restaurer une ancienne attestation liée à une autre clé.
Nombre maximal d’appareils et procédure de remplacement sont des décisions à valider.

## Horloge : politique honnête et bornée

Recommandation stricte à valider sur le terrain : ancrer le temps signé du serveur
sur l’horloge monotone native Android incluant la veille (`elapsedRealtime`), avec
marqueur de boot fiable à tester. La même ancre survit à un redémarrage de **l’app**
pendant le même boot. Un `Stopwatch` Dart recréé n’est pas une telle ancre persistante.
Les changements d’heure civile n’allongent pas le droit.
[Référence SystemClock Android](https://developer.android.com/reference/android/os/SystemClock?authuser=00).

Renouvellement : nonce frais, instant monotone du début de requête, RTT borné,
signature et ordre des dates vérifiés. Refuser une réponse ancienne ou trop retardée ;
ne pas prendre son `issued_at` comme « maintenant » à chaque relecture du cache.
Les métadonnées d’ancre/dernier epoch sont authentifiées et leur absence impose une
nouvelle vérification réseau, pas une reconstruction depuis l’heure locale.

Après **reboot du téléphone**, perte d’ancre, incohérence de boot ou stockage
restauré, l’écoulement hors tension ne peut être prouvé par cette seule horloge.
Recommandation stricte : `NEEDS_ONLINE_VALIDATION` pour les avantages supplémentaires,
sans bloquer le gratuit ou les téléchargements acquis. Cela peut être contraignant
en zone peu connectée : valider explicitement ce compromis avant implémentation.
Une alternative tolérant l’heure civile après reboot est plus confortable mais
moins résistante au recul/réinitialisations ; ne pas annoncer la même garantie.

## Machine d’état et comportement

| Situation | Décision commerciale | Données et apprentissage |
|---|---|---|
| Compte invité / aucun lease | Gratuit | Fonctionnement actuel intact |
| Lease vérifié, même boot, temps restant | Avantages signés actifs | Progression habituelle |
| Fermeture/réouverture app, même compte/appareil/boot | Revalider signature et ancre persistées | Pas de perte ni reconnexion obligatoire si preuve encore valide |
| Lease expiré confirmé | Gratuit / renouvellement proposé plus tard | Aucun effacement de packs, réponses, SRS ou progrès |
| Serveur temporairement indisponible | Conserver le lease encore prouvable ; après sa limite, statut à revérifier | 503 n’est pas une révocation, gratuit toujours accessible |
| Révocation reçue avec epoch récent | Retirer immédiatement les avantages concernés en ligne | Conserver les données ; autres grants indépendants inchangés |
| Logout/changement A→B | Neutraliser leases/annonces préchargées/notifications A ; charger seulement contexte B | Pas de fusion ou suppression d’historique A ; contexte guest préservé |
| Reboot ou clé/ancre perdue | Vérification réseau requise pour les seuls avantages nouveaux | Pas de verrouillage des leçons gratuites |
| Signature/kid/audience/subject invalides | Aucun privilège ; récupération en ligne | Pas d’envoi de progression avec l’identité du mauvais compte |

Les annonces sont désactivées hors ligne et quand la configuration/droits sont
incertains. Une expiration ne déclenche aucune publicité au milieu d’un exercice.
Renouvellement et révocation vérifient le serveur ; la suppression d’un abonnement
par l’UI ne simule pas un remboursement bancaire.

## Rotation et récupération

Public keys initiales intégrées ; rotation par mise à jour approuvée ou keyset signé
par une racine distincte déjà approuvée, borné/versionné et sans downgrade. Aucune
clé fournie arbitrairement dans un reçu/API ne devient une autorité. Retirer une
clé compromise demande une distribution de confiance ; effet immédiat hors ligne
impossible. Ne pas allonger les leases pour masquer une panne de signature.

Tests futurs indispensables : vecteurs connus Python/Dart, claims modifiés,
signature tronquée, kid inconnu, clé test en prod, dates extrêmes, rejeu après
epoch/révocation, copie A/B et appareil, kill/restart/reboot, changement d’heure,
restauration d’état ancien, 401/403/503 et renouvellement perdu. **Aucun de ces
tests de nouveau module n’a été exécuté dans cette phase de conception.**
