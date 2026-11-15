# BK-REMOTE-PILOT-03 — B2-A : Recommandation d'architecture & décision

**Commit de référence local :** `c29d5ea` (+ durcissement `transaction.on_commit` B2-A)  
**Statut :** Lecture seule terminée — **Aucune ressource créée, aucun déploiement effectué.**

---

## 1. Architecture recommandée pour B2-B

1. **Isolation totale par rapport à la production :**
   - Nouveau Web Service Render dédié (`pilot-api.beriyarkedebideri.com`).
   - Nouvelle base PostgreSQL Render dédiée (avec `DatabaseCache` pour le throttling, sans Redis payant supplémentaire).
   - Nouveau bucket Cloudflare R2 privé (`R2_PRIVATE_BUCKET_NAME`), **Public Access désactivé**, distinct du bucket public `media.beriyarkedebideri.com`.
2. **Sécurité & périmètre :**
   - `DJANGO_ENV=staging`, `SECRET_KEY` dédiée, `ADMIN_URL` dédié, `NUM_PROXIES` calibré via `/api/core/diagnostics/https/`.
   - Groupe `pilot_erfe_v1` limité aux 5 unités `bk-preprod-erf-01`..`05` ; packs pilotes en statut `validated` uniquement (jamais `published`).

---

## 2. Budget estimé

- **Surcoût mensuel recommandé :** **~13–14 $/mois** (Web Starter + PostgreSQL Basic, R2 et `DatabaseCache` à `0 $/mois` sous les seuils gratuits).
- **Coût actuel déjà payé :** **non vérifiable** sans accès console Render.

---

## 3. Risques résiduels avant B2-B

1. **Accès consoles Render / Cloudflare non vérifié :** plans réels, sauvegardes de prod et règles d'accès R2 doivent être confirmés par le responsable.
2. **Orphelins R2 en cas d'échec `on_commit` :** un rollback DB ne supprime plus le fichier actif, mais une erreur R2 post-commit peut laisser un objet orphelin à nettoyer manuellement.
3. **Cache hors ligne appareil :** un pack déjà téléchargé sur Android reste lisible hors ligne jusqu'à déconnexion/révocation lors d'une reconnexion réseau.

---

## 4. Décision

**PRÊT POUR B2-B SOUS RÉSERVE DE :**
1. Validation du budget (~13–14 $/mois) et fourniture des informations Render/Cloudflare par le responsable.
2. Autorisation explicite du responsable pour créer le commit local B2-A, provisionner les ressources isolées et déployer le pilote.
