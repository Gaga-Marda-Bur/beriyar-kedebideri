# BK-REMOTE-PILOT-03 — B2-A : Revue des risques du stockage privé (B1/B1.1)

**Périmètre :** Audit local du code (`backend/offline_packs/models.py`, `services/offline_pack_generator.py`, `views.py`, `serializers.py`, `core/media_storage.py`). Aucun fichier R2 réel manipulé.

---

## 1. Risque corrigé durant B2-A : ordre suppression / transaction DB

- **Anomalie identifiée à la relecture :** dans B1.1, `_sync_storage_for_status()` et `OfflinePackGenerator.generate()` appelaient `.delete(save=False)` sur l'ancien fichier **avant** le commit de la transaction PostgreSQL. En cas d'échec ou de rollback DB, la base revenait à l'ancien chemin alors que l'objet physique avait déjà été supprimé.
- **Correctif appliqué localement :**
  - Copie préalable vers la nouvelle destination (`private_file` ou `file`), mise à jour DB (`super().save(update_fields=['file', 'private_file'])`), et suppression de l'ancien objet différée via `transaction.on_commit(...)`.
  - En cas de rollback DB, l'ancien objet physique reste intact (`test_pack_status_transitions_and_pilot_content_scope` vérifie explicitement ce rollback simulé).

---

## 2. Analyse des scénarios de défaillance

| Scénario | Comportement vérifié | Risque résiduel |
|---|---|---|
| **Échec pendant la copie (`open` / `save`)** | Exception levée avant modification DB ; l'ancien objet reste intact et la transaction DB est annulée. | **Faible** (éventuel fichier partiel selon backend S3). |
| **Échec / rollback DB après écriture du nouveau fichier** | `transaction.on_commit` ne s'exécute pas : **aucune perte du fichier actif**. | **Orphelin possible** dans le nouveau stockage (sans impact sécurité ni intégrité). |
| **Échec réseau R2 lors de `on_commit` (suppression ancien fichier)** | La DB pointe déjà vers le nouveau fichier valide. L'ancien fichier devient un objet orphelin. | **Modéré si `published` → `draft`** (ancien fichier public à purger manuellement ou via script de réconciliation R2 si `on_commit` échoue). |
| **Restauration d'un fichier** | Possible depuis le backup PostgreSQL + le bucket R2 (tant que la suppression `on_commit` n'a pas eu lieu, ou via versioning R2 si activé en B2-B). | Dépend de l'activation du versioning/backup en B2-B. |
| **Publication automatique des packs pilotes** | Aucune commande, vue, migration ni signal ne passe un pack à `published`. La publication reste strictement manuelle. | **Nul** dans le code audité. |

---

## 3. Objets orphelins et recommandation d'exploitation

- Sur le bucket privé pilote (`R2_PRIVATE_BUCKET_NAME`), activer si possible une règle de cycle de vie ou conserver un inventaire simple des clés `offline_packs/files/` non référencées en base.
- Lors d'un passage exceptionnel `published` → `draft` sur un bucket R2 réel, vérifier ensuite que l'ancien objet public n'est plus accessible (purge manuelle en secours si `on_commit` a échoué).
