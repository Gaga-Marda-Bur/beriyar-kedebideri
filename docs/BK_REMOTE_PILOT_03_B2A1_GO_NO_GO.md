# BK-REMOTE-PILOT-03 — B2-A.1 : Décision GO / NO-GO pour le provisionnement (Phase B2-B)

**Base Git :** commit `c29d5ea` sur `dev` + modifications locales B2-A / B2-A.1 (non commitées, en attente d'autorisation).  
**Décision :** **GO POUR B2-B** (sous réserve d'autorisation explicite du responsable, validation du budget ~13–14 $/mois et accès aux consoles Render/Cloudflare).

---

## 1. Résultats vérifiés localement (après les dernières modifications)

- `makemigrations --check --dry-run` : `No changes detected`.
- `migrate --plan` : inclut `offline_packs.0002_lessonpack_private_file_alter_lessonpack_status` (migration additive).
- Tests ciblés (`core.tests_auth offline_packs`) : `Ran 16 tests in 25.182s`, `OK`, `System check identified no issues (0 silenced).`
- Suite Django complète (`manage.py test`) : `Ran 193 tests in 76.600s`, `OK (skipped=2)`, `System check identified no issues (0 silenced).`
- `flutter analyze` : `No issues found! (ran in 8.5s)` (aucun code mobile modifié depuis `c29d5ea`).

---

## 2. Périmètre Git depuis `c29d5ea` (non commité)

- `backend/offline_packs/models.py` (`_safe_delete_storage_object`, `_sync_storage_for_status` avec `transaction.on_commit` et nettoyage en cas d'échec `save()`)
- `backend/offline_packs/services/offline_pack_generator.py` (`select_for_update()` contre la régénération concurrente, suppression `on_commit` via `_safe_delete_storage_object`)
- `backend/offline_packs/management/commands/reconcile_pack_storage.py` (commande idempotente d'inventaire et de nettoyage des orphelins, `--dry-run` par défaut)
- `backend/core/tests_auth.py` (tests de rollback DB et de réconciliation idempotente)
- Livrables documentaires `docs/BK_REMOTE_PILOT_03_B2A_*.md` et `docs/BK_REMOTE_PILOT_03_B2A1_*.md`

---

## 3. Ce qui reste non vérifiable jusqu'à l'accès consoles (B2-B)

- Plans réels, facturation, région exacte et sauvegardes Render.
- Configuration réelle des buckets R2, désactivation de l'accès public du bucket privé et création du CNAME `pilot-api.beriyarkedebideri.com` dans Cloudflare.
- Calibration de `NUM_PROXIES` sur le service Render réel via `/api/core/diagnostics/https/`.
