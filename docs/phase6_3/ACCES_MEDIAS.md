# Matrice d’accès aux médias — Phase 6.3

Les colonnes API décrivent les contrôles exécutés localement. Les ACL du CDN/R2
ne sont pas inférées d’un contrôle API. Staff = utilisateur staff authentifié,
conformément aux permissions de modération existantes.

| Ressource / opération | Anonyme ou invité | Comptes A / B non staff | Staff | Preuve / limite |
|---|---|---|---|---|
| Audio pédagogique publié, métadonnées et URL | Public | Public | Public | Test 200 ; aucune authentification ajoutée |
| Images/vidéos de contenus volontairement publics | Public | Public | Public | Vues publiques conservées ; nouveaux uploads validés |
| Pack publié actif, métadonnées et URL | Public | Public | Public | Tests 200 + pack restauré SHA/CRC |
| Audio/pack brouillon dans API | Non visible | Non visible | Accessible | Politique staff actuelle conservée, sans imposer un nouveau flag preview |
| Audio `feedback`, même marqué publié | 404 | 404 | Métadonnées accessibles | Tests de reproduction avant/après |
| Nouvelle capture feedback, URL contrôlée | 403/404 | 403/404, même pour l’émetteur | Téléchargement authentifié, `no-store` | Tests fichier réel et flux ; ce n’est pas un espace personnel de lecture |
| Nouvel audio feedback, URL contrôlée | Refusé | Refusé | Téléchargement authentifié | Vrai WAV synthétique, stockage privé |
| Capture/audio feedback historiques via route contrôlée | Refusé | Refusé | Lecture legacy conservée | Pas de déplacement automatique des anciens octets |
| Ancien chemin `/media/feedback/...` via Django | 404 | 404 | 404, utiliser route contrôlée | Tests chemin normal, casse et `../` |
| URL historique sur bucket/CDN public externe | **NON PROUVÉ PRIVÉ** | Idem | Idem | Le middleware Django ne contrôle pas Cloudflare ; remédiation préalable requise |
| Modification des médias pédagogiques par API list/detail | Pas de création/modification | Idem | Pas de nouveau droit API d’écriture | Endpoints d’origine en lecture ; édition Admin selon permissions Django |
| Upload feedback public | Autorisé, contrôlé et limité | Idem, attribution serveur existante | Autorisé | Suites feedback/CSRF/throttles conservées |

Le token d’installation invité n’accorde aucun accès aux pièces de modération.
Une modification d’identifiant ou de chemin ne remplace pas une session/identité
staff. Les routes privées résolvent une **référence exacte en base**, jamais un
chemin arbitraire fourni directement au système de fichiers.

## Stockages et limites

- Nouveaux fichiers : images JPEG/PNG/WebP, 5 Mo et 4096 px ; feedback 2 Mo ;
  audio MP3/M4A/WAV 20 Mo ; vidéo MP4/WebM 50 Mo ; ZIP 200 Mo compressés,
  500 Mo décompressés et 5 000 entrées, alignés sur Flutter. Les signatures/conteneurs sont contrôlés,
  les images décodées, les ZIP CRC vérifiés ; ce n’est pas un antivirus ni une
  certification des codecs audio/vidéo.
- La sauvegarde ORM standard des nouveaux fichiers et les ModelForms passent
  par la validation partagée. Les références déjà stockées sont conservées sans
  relecture forcée ni réécriture. `bulk_create`, SQL direct ou `FieldFile.save`
  peuvent contourner un `Model.save` : ces voies restent réservées aux services
  de confiance, dont le générateur de ZIP testé. Aucun endpoint public n’offre
  ces accès d’écriture aux médias pédagogiques.
- Le bucket privé doit être distinct **et réellement non public** (`r2.dev` et
  domaine personnalisé désactivés). Un nom différent et des URLs signées ne
  suffisent pas si son accès public est activé. Les permissions IAM sont à vérifier.
- Les brouillons pédagogiques actuellement stockés sur un bucket public peuvent
  rester accessibles par une URL connue. Leur confidentialité au niveau stockage
  n’est pas garantie par la seule exclusion de l’API ; statuer sur la politique
  éditoriale et le cycle de publication avant production.

## Remédiation historique avant tout déploiement

1. Inventorier en environnement autorisé les pièces feedback et leurs références
   exactes (y compris objets orphelins et contenus présents dans d’anciens packs).
2. Sauvegarder DB, bucket public et bucket privé dans un même instantané cohérent.
3. Copier les objets privés vers le bucket privé sans écrasement ; vérifier taille,
   SHA-256 et lecture staff par la nouvelle route. Aucun changement linguistique.
4. Après validation explicite, retirer l’accès aux anciens objets publics et purger
   les caches ciblés ; vérifier qu’une requête anonyme sur l’ancienne URL échoue.
   Une ancienne copie téléchargée ne peut pas être révoquée.
5. Ne pas modifier silencieusement un ZIP publié : si un pack contient une pièce
   privée, décider du retrait et d’une nouvelle version avec nouveau checksum.

**Aucune de ces opérations distantes n’a été exécutée dans cette phase.**
