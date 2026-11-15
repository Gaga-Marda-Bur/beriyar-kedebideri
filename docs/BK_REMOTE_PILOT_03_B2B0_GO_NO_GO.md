# BK-REMOTE-PILOT-03 — B2-B.0 : Décision GO / NO-GO

**Branche pilote locale :** `pilot/erfe-v1` (commit `f662f6e`, identique à `dev`, non poussée)  
**Décision :** **PRÊT LOCALEMENT — EN ATTENTE D'AUTORISATION ET DE CONFIRMATION RENDER POUR B2-B**

---

## 1. État de préparation

- **Audit Git & CI/CD :** aucune automatisation GitHub Actions ou deploy hook ne déploie automatiquement.
- **Branche pilote `pilot/erfe-v1` :** créée localement depuis `f662f6e` sans modifier `dev`, `fix/a07-editorial-draft-protection` ni aucune autre branche.
- **Paramètres Render/Cloudflare isolés :** définis (`beriyar-pilot-api`, `Auto-Deploy: Off`, `beriyar-pilot-postgres`, `bk-pilot-private`, `pilot-api.beriyarkedebideri.com`).

---

## 2. Condition bloquante et autorisations requises

1. **Condition bloquante pour tout push sur une branche existante :** le nom exact de la branche sur laquelle `beriyar-kedebideri` a `Auto-Deploy` activé dans Render n'est pas confirmé (à vérifier dans la console Render avant tout push autre que `pilot/erfe-v1`).
2. **Autorisations explicites requises avant B2-B :**
   - Validation du budget provisoire (**13–14 USD/mois**).
   - Autorisation de créer le bucket privé `bk-pilot-private` et le DNS `pilot-api.beriyarkedebideri.com` sur Cloudflare.
   - Autorisation de créer `beriyar-pilot-postgres` et `beriyar-pilot-api` (`Auto-Deploy: Off`) sur Render et de pousser la branche dédiée `pilot/erfe-v1`.
