# Checklist de préproduction — à valider avant toute mise en ligne

Ce document n’autorise aucun déploiement. « Local validé » ne signifie pas
« configuration Render/Cloudflare vérifiée ».

| Contrôle | État Phase 6.3 | Condition avant production |
|---|---|---|
| Branche et référence de retour | Branche dédiée, base 7998177 | Relire le commit final et conserver les artefacts N-1 |
| Suites automatiques | Résultats structurés `RESULTS.json` | Réexécuter sur l’environnement de recette réellement provisionné |
| Django patché | 6.0.10 local, pin requirements corrigé | Même version installée sur staging puis production |
| Staging distinct | Support testé avec valeurs synthétiques | Domaine, PostgreSQL, médias publics/privés et credentials distincts |
| Secrets | Inventaire des noms uniquement, fichiers ignorés | Secrets uniques forts, hors Git ; rotation planifiée si compromis |
| DEBUG / hosts / CSRF / CORS | Refus des configurations dangereuses testé | Vérifier les variables effectives sans exporter leurs valeurs sensibles |
| Proxy | Refus de confiance implicite conservé | Vérifier la chaîne réelle, écrasement X-Forwarded-Proto, NUM_PROXIES exact |
| HTTPS / HSTS | HTTPS, cookies secure, HSTS 300 s | Tester TLS et redirections ; sous-domaines/preload seulement après décision dédiée |
| Base | PostgreSQL explicite exigé en environnement déployé | TLS externe ; exception privée seulement sur réseau réellement vérifié |
| Médias publics | Accès public légitime conservé | Domaine de contenu isolé, MIME correct, nosniff, limites de requête en bordure |
| Médias privés | Nouveau routage + permissions testés localement | Bucket distinct réellement privé, IAM minimal, aucune URL publique résiduelle |
| Pièces historiques | Lecture staff legacy conservée | Inventaire/copie privée/vérification/retrait public/purge ciblée validés |
| Packs historiques | Pack local SHA/CRC validé | Vérifier contenu privé absent ; aucune réécriture en place des versions publiées |
| Cache partagé feedback | DatabaseCache démontré entre deux processus | Table créée sur cible ; limites DRF approximatives, compléter en bordure |
| Statiques Kedebideri | 6 graisses collectées et servies par WhiteNoise | Tester les vraies URLs HTTP/CDN après déploiement autorisé |
| Sauvegarde DB/médias | SQLite + fichiers locaux restaurés réellement | pg_dump/pg_restore sur cible neuve isolée, buckets cohérents et sauvegardes chiffrées |
| Migrations | Copie restaurée migrée ; 0002 médias sans SQL de schéma | Contrôler état réel et sauvegarde ; 0004 progress encore en attente dans la source locale |
| Comptes/progressions | Comparaison des anciennes valeurs et suites vertes | Recette A/B et invités contre le vrai staging avec comptes synthétiques |
| Superuser | Opt-in explicite et password validators | Bootstrap one-shot puis retirer ses variables ; ne pas changer un compte existant |
| Journalisation | Aucun secret ni contenu utilisateur dans les livrables | Logs sans corps/tokens, accès restreint, rétention et alertes à vérifier |
| Android réel | Aucun appareil détecté en Phase 6.3 | Reconnecter un appareil pour la recette staging authentification/médias/sync |
| Ads / Premium / paiement | Non activés, non développés | Validation distincte ultérieure |

Les avertissements `security.W005` et `security.W021` restent documentés :
`SECURE_HSTS_INCLUDE_SUBDOMAINS=False`, `SECURE_HSTS_PRELOAD=False`.
Ils ne sont pas masqués et ne doivent pas être « corrigés » mécaniquement sans
vérifier tous les domaines concernés. Le cache partagé ne garantit pas un quota
strict sous concurrence : la démonstration locale porte sur la visibilité des
compteurs entre processus séquentiels.

## Sauvegarde / restauration et rollback

- Geler les écritures ou employer un mécanisme cohérent/versionné DB + objets.
- Utiliser une destination neuve et distincte ; refuser toute restauration sur la
  source. Ne jamais exécuter `pg_restore --clean` sur une URL de production par
  simple copier/coller. Les outils PostgreSQL et les ACL cloud ne sont pas validés ici.
- Comparer schémas/lignes avant migration, toutes les anciennes valeurs après,
  comptes/progressions, médias audio et checksums/CRC des packs.
- Conserver les tables et credentials de progression ; ne pas revenir à une
  migration antérieure supprimant leur registre.
- Les migrations médias 0002 sont des changements d’état Django, sans opération
  SQL de schéma. Ne pas déplacer automatiquement les anciens fichiers.
- Un retour intégral à 7998177 rétablirait le stockage public des nouveaux feedbacks
  et Django 6.0.6 : ce n’est pas un rollback de sécurité acceptable en production.
  Privilégier un correctif en avant ou maintenir le routage privé ; si nécessaire,
  suspendre explicitement les seuls uploads de pièces pendant intervention, en
  conservant les feedbacks texte et les données locales.
- Pas de durée RTO/RPO promise : ces objectifs doivent être mesurés sur le volume
  PostgreSQL/R2 réel. Les copies locales de recette contiennent des données privées
  et restent dans `runtime/` ignoré ; protéger leurs accès et leur rétention.
