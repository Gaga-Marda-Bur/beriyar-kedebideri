# BK-REMOTE-PILOT-03 — Comparaison des architectures d'hébergement

| Critère | Scénario A — Réutiliser `beriyar-kedebideri.onrender.com` | Scénario B — Nouveau service pilote dans le compte Render existant *(Recommandé)* | Scénario C — Environnement temporaire entièrement séparé |
|---|---|---|---|
| **Sécurité** | **Faible pour un pilote** : partage la `SECRET_KEY`, l'`ADMIN_URL` et le bucket R2 public avec la prod. | **Élevée** : `SECRET_KEY`, `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS` et BDD isolés ; même gouvernance TLS/Cloudflare. | **Élevée** : isolation totale même au niveau du compte hébergeur. |
| **Isolation** | **Nulle** : BDD, sessions, comptes et migrations mélangés avec la production active (`HTTP 200`). | **Complète** : service Web + PostgreSQL + stockage média dédiés au pilote. | **Totale**, mais gestion de clés/facturation dispersée. |
| **Coût mensuel** | **0 € supplémentaire** (non vérifié : dépend du plan Render actuel, non accessible sans login Render). | **Estimé : coût d'un service Web + petite base PostgreSQL Render** *(tarifs exacts non vérifiables sans accès au compte Render ; plans gratuits Render sujets à mise en veille et expiration de BDD)*. | **Estimé : équivalent ou supérieur au Scénario B** selon l'hébergeur tiers choisi. |
| **Complexité** | Faible à court terme, risquée lors des migrations. | **Faible à modérée** : réutilise `build.sh`, `release.sh` et Cloudflare DNS existant (`pilot-api.beriyarkedebideri.com`). | **Plus élevée** : nouveau compte, nouveau DNS/TLS, nouvelle chaîne CI/CD. |
| **Maintenance** | Risque de régression sur le site public `beriyarkedebideri.com`. | **Simple** : un seul compte Render + un seul DNS Cloudflare à administrer. | Double administration. |
| **Sauvegardes** | Risque de mélange PII pilote/prod dans `pg_dump`. | **Propres** : snapshots PostgreSQL dédiés au pilote, purge facile en fin de pilote. | Propres mais isolées hors procédure équipe. |
| **Compatibilité Android** | Identique (`https://`), mais impose de pointer l'APK pilote sur la prod. | **Optimale** : APK `com.afrigama.beriyarkedebideri.pilot` pointe sur `https://pilot-api.beriyarkedebideri.com/api`. | Optimale si domaine HTTPS public valide. |
| **Retour arrière** | **Difficile** si migrations BDD ou comptes créés en prod. | **Immédiat** : suspension/suppression du service pilote sans aucun impact sur la prod. | Immédiat. |
| **Connexion depuis le Tchad** | Cloudflare CDN + Render `gcp-us-west1` (latence US-West ~200–350 ms, TLS 1.3 via Cloudflare Edge). | **Identique** (Cloudflare Edge + Render ; privilégier un plan sans mise en veille « cold start » de 30–50 s sur réseau mobile lent). | Variable selon région (une région Europe/Francfort réduit la latence depuis le Tchad vs US-West si un hébergeur EU est choisi). |

### Recommandation d'architecture
**Retenir le Scénario B** (nouveau service Web + base PostgreSQL dédiée dans le compte Render existant, sous `https://pilot-api.beriyarkedebideri.com`), en veillant à **ne pas** exposer les packs pilote sur le bucket R2 public historique et en vérifiant que le plan choisi ne subit pas d'expiration de base de données avant la fin du pilote.
