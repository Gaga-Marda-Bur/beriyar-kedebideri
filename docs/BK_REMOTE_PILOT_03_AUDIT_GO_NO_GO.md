# BK-REMOTE-PILOT-03 — Décision d'audit GO / NO-GO (Phase A)

**Décision :** **GO CONDITIONNEL POUR LE SCÉNARIO B** — **NO-GO POUR LE SCÉNARIO A (réutilisation directe du service de production)**

---

## Synthèse des constats

| Domaine | État | Conclusion |
|---|---|---|
| Dépôt Django & sécurité (`settings.py`, `security.py`, `auth_views.py`, `permissions.py`) | **Confirmé** | Prêt pour un déploiement `staging`/pilote HTTPS strict avec isolation `pilot_erfe_v1` sur `ERF-01`..`ERF-05`. |
| Application Android pilote (`BK_PILOT=true`, A13, Keystore, `allowBackup=false`) | **Confirmé** | Prête pour pointer vers un domaine HTTPS distant dédié (`com.afrigama.beriyarkedebideri.pilot`), sans écraser la version publique. |
| Service Render historique (`beriyar-kedebideri.onrender.com` / `beriyarkedebideri.com`) | **Confirmé en ligne (`200 OK`)** | Sert actuellement l'application publique. Réutiliser ce service/BDD pour le pilote (Scénario A) créerait un risque inutile sur la production. |
| Tableau de bord Render / Cloudflare / R2 privé | **Non confirmé** | Plans, coûts exacts, dates d'expiration PostgreSQL, configuration d'auto-déploiement et règles exactes du bucket `beriyar-kedebideri-media` non vérifiables sans accès authentifié aux consoles. |
| Stockage des `LessonPack` (`offline_packs/models.py`) | **Bloquant si R2 public utilisé** | `LessonPack.file` utilise `STORAGES['default']` (public si `USE_R2=True`). Un pack pilote ne doit pas être déposé dans le bucket R2 public sans stockage privé ou endpoint authentifié. |
| Sous-domaine pilote (`pilot-api.beriyarkedebideri.com`) | **Confirmé (absent en DNS)** | À créer dans Cloudflare DNS lors de la Phase B après autorisation. |

---

## Décisions attendues du responsable avant Phase B

1. **Valider le Scénario B** : création d'un service Web Render dédié + base PostgreSQL dédiée dans le compte Render existant.
2. **Confirmer l'état du compte Render & Cloudflare** : vérifier plan/facturation/absence d'expiration PostgreSQL et accès DNS pour `pilot-api.beriyarkedebideri.com`.
3. **Choisir le stockage média du pilote** : disque persistant Render isolé (`MEDIA_STORAGE_PERSISTENT=True`) ou bucket R2 privé dédié (pour éviter toute exposition de packs pilote sur `media.beriyarkedebideri.com`).
4. **Autoriser explicitement le lancement de BK-REMOTE-PILOT-03 Phase B** (provisionnement, déploiement, tests HTTPS distants Phase 6, puis création des 5–10 comptes `pilot_erfe_v1`).
