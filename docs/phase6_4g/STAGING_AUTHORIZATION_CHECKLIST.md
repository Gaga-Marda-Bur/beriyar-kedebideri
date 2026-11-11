# Conditions d'autorisation staging — non exécutées à distance

La réussite des tests locaux n'est pas une autorisation de déploiement.
Le modèle `staging.env.example` est volontairement incomplet et ne contient aucun
secret réutilisable. Le modèle 6.4F reste archivé ; ne pas le recopier tel quel.

| Condition | Preuve nécessaire avant autorisation | État 6.4G |
|---|---|---|
| Périmètre | Staging privé technique ou pilote pédagogique public, audience et responsable nommés | À décider |
| Version | Commit 6.4G et artefacts approuvés ; distinguer RC1 originale et correctifs | Dossier local fourni |
| Domaine/TLS | Domaine réellement possédé, certificat, redirection HTTP→HTTPS, hôtes indésirables refusés | Non vérifié à distance |
| Proxy | Écrasement de X-Forwarded-Proto/For, nombre de proxys établi puis variables explicites | Non vérifié |
| Secrets | Nouvelles clés propres au staging, gestionnaire de secrets et rotation ; aucune reprise de développement | Non provisionné |
| PostgreSQL | Base distincte, rôle non-superuser, accès réseau restreint, TLS ou réseau privé attesté | Cible non auditée |
| Médias publics | Montage persistant effectif ou bucket staging dédié ; checksum des fichiers | Cible non auditée |
| Pièces privées | Stockage physiquement séparé, ACL sans URL publique, anciens objets privés remédiés | Cible non auditée |
| Fichiers | Permissions OS/stockage minimales ; pas de lecture publique du code, dumps, .env, clés | Cible non auditée |
| Journaux | Tests réels de redaction Cookie/Authorization/mots de passe, accès et rétention | Cible non auditée |
| Sauvegarde | Dump + médias cohérents, chiffrés, hors service ; restauration BK complète dans une base neuve | Probe locale limitée seulement |
| Migrations | Revue du plan et sauvegarde préalable ; aucune exécution à l'aveugle sur une base existante | Aucune appliquée à la source/cible |
| Commercial | Garde staging 6.4G, flags effectifs false, pas de clés/fournisseurs, contrôle direct des endpoints/Admin | Testé localement |
| Pédagogie | Validation humaine des thèmes/caractères/mots et cohérence du pack avant pilote | Bloquant pour pilote général |
| Recette | Chrome et Samsung avec réserves explicites, validation finale humaine | Dossier local fourni |

## HSTS et cookies

Commencer avec HTTPS obligatoire, cookies Secure/HttpOnly/SameSite et HSTS court
(300 secondes dans la proposition), **sans preload ni inclusion de sous-domaines**
non qualifiés. Les avertissements Django W005/W021 correspondants sont conservés,
pas masqués. Les hôtes locaux du modèle 6.4F sont retirés par le code de configuration :
leur présence dans ce modèle n'établit pas une autorisation effective.

Les paramètres sont testés avec un domaine `.invalid` et une clé éphémère ; cela
ne vérifie pas le DNS, les ACL, les certificats ni les cookies délivrés par un
vrai proxy. Les noms R2 réellement lus sont `R2_ACCESS_KEY_ID`,
`R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_ENDPOINT_URL`, `R2_PUBLIC_BASE_URL`
et `R2_PRIVATE_BUCKET_NAME`. Les exemples AWS/R2 du rapport 6.4F ne constituent
pas un provisionnement. `MEDIA_STORAGE_PERSISTENT=True` est une déclaration,
pas la preuve d'un disque persistant.

Références officielles : [checklist Django 6.0](https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/),
[précautions HSTS](https://docs.djangoproject.com/en/6.0/ref/middleware/#http-strict-transport-security).

## Retour arrière à prévoir avant déploiement

1. Stopper l'ouverture aux testeurs et les nouvelles écritures si incident.
2. Conserver les données et les journaux ; revenir à un artefact compatible
   approuvé, sans supprimer les registres de propriété ni réexposer les médias privés.
3. Aucun nouveau schéma en 6.4G : ne pas utiliser une migration inverse pour
   annuler ces gardes. Revenir à 964b73d réintroduirait les deux réserves corrigées ;
   préférer un correctif en avant ou un artefact conservant les gardes.
4. Ne pas reprendre le `pg_restore -c` du rapport F sur une base utilisée.
   Restaurer dans **une base neuve**, vérifier données/médias et changements survenus
   depuis la sauvegarde, puis soumettre une bascule distincte à autorisation.
5. Ne jamais désinstaller l'application principale Android. Le package QA distinct
   peut être remplacé après vérification de son identifiant, en préservant le principal.

Les dumps de la probe 6.4G portent sur deux lignes synthétiques et une copie
d'audio : ils prouvent les utilitaires locaux, pas une restauration du projet BK
complet ni de son stockage distant. Le RPO/RTO cible et les responsabilités
restent à définir. Aucun test local n'accorde implicitement un accès public.
