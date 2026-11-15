# BK-REMOTE-PILOT-03 — B2-A : Estimation budgétaire mensuelle (Pilote 5–10 apprenants)

**Avertissement :** L'accès facturation Render/Cloudflare n'étant pas disponible, **les coûts actuels déjà payés sont non vérifiables** et les montants ci-dessous sont des **estimations** basées sur les grilles publiques standards Render et Cloudflare R2.

---

## 1. Tableau comparatif (coût supplémentaire pour le pilote isolé)

| Poste | Option économique (minimale) | Option recommandée (stable, sans mise en veille) | Statut |
|---|---|---|---|
| **Service Django pilote (Render Web Service)** | Free (`0 $/mois`, mise en veille après 15 min d'inactivité) | Starter (`7 $/mois`, 512 Mo RAM, toujours actif) | **Estimé** |
| **PostgreSQL dédié (Render)** | Free (`0 $/mois`, expire après 30 jours, pas de backups auto) | Basic 256 Mo (`~6–7 $/mois`, persistant, snapshots) | **Estimé** |
| **Cache partagé (`DatabaseCache`)** | `0 $/mois` (inclus dans PostgreSQL via `createcachetable`) | `0 $/mois` (inclus dans PostgreSQL via `createcachetable`) | **Confirmé** (architecture dépôt) |
| **Stockage privé R2 (`R2_PRIVATE_BUCKET_NAME`)** | `0 $/mois` (palier gratuit R2 : 10 Go/mois, 0 $ egress) | `0 $/mois` (< 1 Go pour 5 leçons + packs pilotes) | **Estimé** |
| **Sauvegardes (`pg_dump` local/manuel + snapshots Render)** | `0 $/mois` (`pg_dump` manuel) | Inclus Basic DB (`0 $` supplémentaire) | **Estimé** |
| **Bande passante** | `0 $/mois` (R2 egress gratuit + Render inclus pour 5–10 testeurs) | `0 $/mois` (trafic pilote très faible) | **Estimé** |
| **Total supplémentaire estimé** | **0 $/mois** *(non recommandé : cold starts + DB éphémère)* | **~13–14 $/mois** *(durée limitée au pilote, ex. 1–2 mois)* | **Estimé** |

---

## 2. Recommandation budgétaire

- **Infrastructure déjà payée :** non vérifiable sans facture Render.
- **Surcoût recommandé pour le pilote (1 à 2 mois) :** **~13–14 $/mois** (Render Web Starter + PostgreSQL Basic dédiée), résiliable immédiatement après clôture du pilote, évitant les cold starts de 30–50 s sur Android et la perte de base Free à 30 jours.
- **Alternative 0 $/mois :** possible uniquement avec disque/DB Free éphémère, déconseillée pour la fiabilité des tests utilisateurs.
