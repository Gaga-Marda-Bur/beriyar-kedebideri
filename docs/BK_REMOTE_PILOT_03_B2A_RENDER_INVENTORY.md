# BK-REMOTE-PILOT-03 — B2-A : Inventaire Render (lecture seule)

**Statut d'accès :** Aucune session authentifiée Render (plugin, CLI `render` ou jeton console) n'est disponible dans cet environnement. Aucune ressource n'a été créée ou modifiée.

---

## 1. État des contrôles

| Élément | Statut | Détail observé / requis |
|---|---|---|
| Service Web production existant (`beriyar-kedebideri.onrender.com`) | **Confirmé** (sondes publiques) | CNAME `gcp-us-west1-1.origin.onrender.com` -> `216.24.57.16` / `.18` ; répond `HTTP/1.1 200 OK` via `x-render-origin-server: gunicorn`. |
| Scripts Build / Release | **Confirmé** (dépôt) | `backend/build.sh` (`pip install`, `collectstatic`), `backend/release.sh` (`migrate`, `createcachetable`, `bootstrap_render`). Aucun `render.yaml` dans le dépôt. |
| Liste complète des services Web et Workers | **Non vérifiable** | Nécessite la consultation du tableau de bord Render par le responsable. |
| Plans actuellement utilisés & coûts mensuels | **Non vérifiable** | Nécessite la consultation de l'onglet Billing / Plan Render. |
| Région exacte de l'instance Render | **Estimé / Partiel** | Le CNAME public indique `gcp-us-west1-1` (US West / Oregon), à confirmer dans les paramètres du service Render. |
| Instances PostgreSQL, versions et sauvegardes | **Non vérifiable** | Nécessite la consultation de la section PostgreSQL dans Render (version PG, plan, rétention des sauvegardes). |
| Branches et commits réellement déployés | **Non vérifiable** | Nécessite la vérification de l'historique Events / Deploys du service Render. |
| Domaines personnalisés configurés sur Render | **Confirmé (partiel)** | `beriyarkedebideri.com` et `www.beriyarkedebideri.com` pointent vers Render ; `pilot-api.beriyarkedebideri.com` est absent. |
| Politiques de déploiement automatique (Auto-Deploy) | **Non vérifiable** | Nécessite la vérification de Settings -> Build & Deploy sur Render. |
| Possibilité d'ajouter un environnement pilote isolé | **Confirmé (architecture)** | Le dépôt supporte un service Web + PostgreSQL + stockage privé distincts sans `render.yaml` bloquant. |

---

## 2. Informations à fournir par le responsable (sans mot de passe ni clé API)

1. Captures ou relevé du **plan actuel** du service Web et de la base PostgreSQL (ex. Free, Starter, Standard) et de la **région** affichée.
2. **Branche** suivie par la production (ex. `main` vs `dev`) et **commit** actuellement en ligne.
3. État de l'**Auto-Deploy** et présence éventuelle de Workers / Cron Jobs.
4. État des **sauvegardes automatiques PostgreSQL** et date d'expiration éventuelle d'une base Free.
