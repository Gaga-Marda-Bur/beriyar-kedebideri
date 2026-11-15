# BK-REMOTE-PILOT-03 — B2-A : Inventaire Cloudflare (lecture seule)

**Statut d'accès :** Aucune session authentifiée Cloudflare (`wrangler` ou console) n'est disponible dans cet environnement. Aucune modification DNS, R2 ou pare-feu n'a été effectuée.

---

## 1. État des contrôles

| Élément | Statut | Détail observé / requis |
|---|---|---|
| Statut du domaine `beriyarkedebideri.com` | **Confirmé (DNS public)** | Domaine actif ; `beriyarkedebideri.com` (`216.24.57.16`/`.18`) et `media.beriyarkedebideri.com` (`104.21.76.238`, `172.67.202.24`) résolvent publiquement. |
| Enregistrements DNS existants (exhaustivité) | **Non vérifiable** | Seuls les sous-domaines testés (`@`, `www`, `media` actifs ; `api`, `staging-api`, `pilot-api` absents) sont observables publiquement. La liste complète des enregistrements Cloudflare reste à inspecter. |
| Faisabilité de `pilot-api.beriyarkedebideri.com` | **Confirmé** | Sous-domaine actuellement libre (`NXDOMAIN`), prêt pour un CNAME proxifié vers le futur service Render pilote. |
| Buckets R2 disponibles & noms exacts | **Non vérifiable** | Nécessite l'accès au tableau de bord R2 Cloudflare. |
| Règles d'accès public des buckets (dont `media.beriyarkedebideri.com`) | **Non vérifiable** | Le domaine `media.beriyarkedebideri.com` répond via Cloudflare (`404` à la racine), mais les règles d'accès public (`r2.dev`, custom domains, WAF) restent **non vérifiées**. |
| Création ultérieure d'un bucket privé (`R2_PRIVATE_BUCKET_NAME`) | **Confirmé (architecture)** | `backend/config/settings.py` supporte nativement un bucket privé séparé via `R2_PRIVATE_BUCKET_NAME` lorsque `USE_R2=True`. |
| Coûts, quotas et limites applicables | **Estimé** | Offre R2 standard (10 Go/mois gratuits en stockage, 0 frais de sortie Internet/egress) ; la consommation réelle du compte reste **non vérifiable**. |
| Politiques de stockage, cycle de vie et suppression | **Non vérifiable** | Règles de rétention/lifecycle et versioning du bucket R2 à inspecter dans Cloudflare. |

---

## 2. Informations à fournir par le responsable (sans mot de passe ni clé API)

1. Confirmation que le DNS de `beriyarkedebideri.com` est bien géré dans le compte Cloudflare accessible.
2. Liste des buckets R2 existants et confirmation que le futur bucket pilote (ex. `bk-pilot-private`) aura **Public Access désactivé** (aucun domaine personnalisé ni `r2.dev`).
3. Vérification de l'activation du mode facturation R2 (carte liée requise au-delà du palier gratuit) et d'éventuelles règles WAF/Rate Limiting Cloudflare.
