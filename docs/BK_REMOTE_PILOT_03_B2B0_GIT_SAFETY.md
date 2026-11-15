# BK-REMOTE-PILOT-03 — B2-B.0 : Sécurisation Git et audit CI/CD

**Date :** 2026-11-15  
**Périmètre :** Lecture seule locale + création de la branche locale `pilot/erfe-v1` depuis `f662f6e`. **Aucun push, aucune fusion, aucun déploiement.**

---

## 1. Remotes et branches Git observés

- **`git remote -v` :** `origin https://github.com/Gaga-Marda-Bur/beriyar-kedebideri.git` (fetch/push, aucun jeton ni identifiant sensible dans l'URL).
- **Branches distantes visibles sur `origin` :**
  - `remotes/origin/dev` (`72ffb0d`)
  - `remotes/origin/fix/a07-editorial-draft-protection` (`3081aff`)
  - *(Aucune branche `main` présente localement ou sur `origin`.)*
- **Branche locale actuelle :** `dev` sur `f662f6e` (`ahead 57` par rapport à `origin/dev`).
- **Branche pilote créée localement :** `pilot/erfe-v1` sur `f662f6e` (non poussée, non fusionnée).

### Graphe Git vérifié (`f662f6e` -> `bd99a16`)
```text
* f662f6e (HEAD -> dev, pilot/erfe-v1) BK-REMOTE-PILOT-03 (B2-A/B2-A.1): on_commit storage sync, idempotent reconciliation and B2-B runbook
* c29d5ea BK-REMOTE-PILOT-03 (B1/B1.1): private pack storage, auth download, status sync and redirect hardening
* c1df76b chore(pilot): prepare BK-REMOTE-PILOT-02 remote pilot config, Android pilot variant and docs
* 75cf4f4 fix(editor): prevent AppBar horizontal overflow in BeriyaEditorScreen
* c0c49ae feat(auth): implement BK-AUTH-PILOT-01 learner authentication for Erfe V1 private pilot
* dcc48a4 security(pilot): restrict pilot_erfe_v1 to allowlisted units and document NO-GO
* 226af88 feat(pilot): BK-ERFE-V1 private pilot access, SRS audio-free fix & pilot docs
* 72927e2 test(learning): BK-LEARN user qualification & release readiness Erfe V1
* fb6f623 feat(learning): BK-LEARN finalize Erfe Alphabet V1 audio-free candidate
* bca9716 test(bk-ling): add exact user regression case, bump webapp cache-buster, and close BK-LING
```

---

## 2. Audit CI/CD, Blueprints et scripts de déploiement

| Élément | Constat vérifié | Impact / Risque |
|---|---|---|
| `.github/workflows/ci.yml` | Déclenché sur `push` (`main`, `master`, `fix/**`) et `pull_request` (`main`, `master`). Exécute uniquement les tests Django, Node et Flutter. | Aucun job de déploiement, aucun appel à Render. |
| `render.yaml` / Blueprints | Absent du dépôt. | Aucune infra déclarative susceptible d'être appliquée automatiquement. |
| Deploy hooks (`api.render.com/deploy`, etc.) | Aucune référence trouvée dans le dépôt (`git grep`). | Aucun déclenchement caché par script. |
| `backend/build.sh` | `pip install -r requirements.txt` + `python manage.py collectstatic --noinput`. | Build pur, aucune mutation DB. |
| `backend/release.sh` | `migrate --noinput`, `createcachetable`, `bootstrap_render` (`BOOTSTRAP_SUPERUSER=true` opt-in uniquement). | Aucun import automatique de données pédagogiques ni publication de leçons. |

---

## 3. Risque CI/CD et condition bloquante pour tout push distant

- **Condition bloquante :** le service de production `beriyar-kedebideri` a **Auto-Deploy activé** sur une branche autre que `main` et `dev`, dont le nom exact n'est pas vérifiable depuis Git local (potentiellement `fix/a07-editorial-draft-protection` ou une autre branche distante).
- **Mesure de sécurité :**
  - Ne pousser sur aucune branche existante tant que le nom exact de la branche configurée dans Render n'est pas confirmé.
  - Lors de B2-B (après autorisation), pousser uniquement la nouvelle branche dédiée `pilot/erfe-v1` et configurer `beriyar-pilot-api` avec **`Auto-Deploy: Off`**.
