# BK-REMOTE-PILOT-03 — B2-B.0 : Plan de provisionnement et contrôles de sécurité

**Statut :** Préparation locale terminée — **Aucune ressource créée, aucun déploiement effectué.**

---

## 1. Paramètres cibles du futur service Render pilote

| Paramètre | Valeur cible | Isolation production |
|---|---|---|
| **Nom du Web Service** | `beriyar-pilot-api` | Distinct de `beriyar-kedebideri` |
| **Branche Git** | `pilot/erfe-v1` | Distincte de la branche prod |
| **Auto-Deploy** | `Off` | Déploiement manuel contrôlé uniquement |
| **Root Directory** | `backend` | — |
| **Build Command** | `./build.sh` | `pip install` + `collectstatic` |
| **Release / Pre-Deploy Command** | `./release.sh` | `migrate`, `createcachetable`, `bootstrap_render` |
| **Start Command** | `gunicorn config.wsgi:application` | — |
| **Base PostgreSQL** | `beriyar-pilot-postgres` | Distincte de `beriyar-postgres` |
| **Domaine cible** | `pilot-api.beriyarkedebideri.com` | Distinct de `beriyarkedebideri.com` |
| **Stockage privé R2** | `bk-pilot-private` (`R2_PRIVATE_BUCKET_NAME`) | Distinct de `beriyar-kedebideri-media` |
| **Cache partagé** | `DatabaseCache` (`feedback_rate_limit_cache`) | Tables dédiées dans `beriyar-pilot-postgres` |
| **Secrets & sessions** | `SECRET_KEY` et `ADMIN_URL` dédiés | Zéro secret ou session partagés avec la prod |

**Commandes post-déploiement vérifiées :**
- Migrations : incluses dans `./release.sh` (`0002_lessonpack_private_file_alter_lessonpack_status` additive).
- Données pédagogiques : import manuel strict des 5 unités Erfe (`bk-preprod-erf-01`..`05`) et génération des packs en statut `validated` uniquement (jamais `published`). Aucune connexion aux bases ou buckets de production.

---

## 2. Contrôles de sécurité obligatoires avant ouverture aux apprenants

1. **HTTPS et certificat TLS :** vérifier `https://pilot-api.beriyarkedebideri.com` (TLS valide, redirection HTTP → HTTPS active).
2. **Configuration Django :** `DJANGO_ENV=staging`, `DEBUG=False`, démarrage refusé si `SECRET_KEY < 50` car. ou si `R2_PRIVATE_BUCKET_NAME` absent/identique au bucket public.
3. **`ALLOWED_HOSTS` et `CSRF_TRUSTED_ORIGINS` :** restreints à `pilot-api.beriyarkedebideri.com` / `https://pilot-api.beriyarkedebideri.com`.
4. **Cookies sécurisés :** `sessionid` et `csrftoken` avec `Secure`, `HttpOnly` (`sessionid`), `SameSite=Lax`.
5. **Proxy & `NUM_PROXIES` :** calibrer via `/api/core/diagnostics/https/` pour que le throttling (`LearnerLoginThrottle` 15/min) identifie l'IP client réelle.
6. **Permissions du bucket privé `bk-pilot-private` :** `r2.dev` et *Custom Domains* désactivés ; clés API R2 restreintes au périmètre pilote.
7. **Isolation utilisateurs et progressions :** comptes de test dédiés (`pilot_erfe_v1`), progressions isolées dans `beriyar-pilot-postgres`.
8. **Accès strict aux 5 unités Erfe :** `bk-preprod-erf-01`..`05` accessibles au groupe `pilot_erfe_v1`, toute autre unité `validated` ou `draft` retourne `404`.
9. **Téléchargements authentifiés :** `/api/offline-packs/<pk>/download/` retourne `404` pour anonyme/non-pilote et `200` (`Cache-Control: private, no-store`) pour `pilot_erfe_v1`.
10. **Fonctionnement hors ligne :** vérifier sur APK pilote (`BK_PILOT=true`, pointant vers `pilot-api.beriyarkedebideri.com`) le téléchargement, la fermeture complète et la reprise hors ligne.
11. **Sauvegardes et restauration :** snapshot initial + `pg_dump -Fc --no-acl --no-owner` avant et après import ; test de restauration documenté (`docs/BACKUP_AND_RESTORE.md`).

---

## 3. Budget provisoire (à confirmer)

- **Facturation production actuelle annoncée :** `6,30–12,60 $` (`beriyar-kedebideri` + `beriyar-postgres`).
- **Surcoût pilote provisoire estimé :** **`13–14 USD/mois`** (`beriyar-pilot-api` Starter ~`7 $/mois` + `beriyar-pilot-postgres` Basic ~`6–7 $/mois` ; `bk-pilot-private` R2 et `DatabaseCache` à `0 $/mois` sous les seuils gratuits).
- Les tarifs exacts affichés, limites et frais éventuels seront relevés et confirmés dans les consoles Render/Cloudflare avant validation financière (aucun achat effectué).
