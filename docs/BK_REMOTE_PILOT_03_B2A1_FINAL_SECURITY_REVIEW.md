# BK-REMOTE-PILOT-03 — B2-A.1 : Revue finale de sécurité du stockage privé

**Périmètre :** Vérification des cas limites de transition, reprise idempotente, concurrence et non-publication automatique sur le code local depuis le commit `c29d5ea`.

---

## 1. Matrice des cas limites de transition et d'échec

| Cas analysé | Mécanisme en place | Résultat / Comportement |
|---|---|---|
| **Copie réussie puis rollback PostgreSQL** | `super().save(update_fields=['file', 'private_file'])` dans `try/except`, suppression de l'ancien objet différée via `transaction.on_commit(...)`. | L'ancien objet physique n'est **pas** supprimé ; si `super().save` lève une exception, la copie nouvellement écrite est nettoyée immédiatement (`_safe_delete_storage_object`). |
| **Échec de la copie (`open` / `save`)** | L'exception interrompt `_sync_storage_for_status()` avant `super().save()` et avant `on_commit`. | La base et l'ancien objet restent intacts. |
| **Commit réussi puis suppression R2 échouée** | `_safe_delete_storage_object()` capture l'exception et journalise un avertissement (`logger.warning`). | La transaction déjà commitée reste saine (aucune erreur fatale côté client) ; l'ancien objet devient un orphelin récupérable. |
| **Interruption du processus avant `on_commit`** | Même comportement qu'un échec post-commit : DB pointe vers le nouvel objet valide, l'ancien objet reste orphelin. | Aucune perte de données ; nettoyable par `reconcile_pack_storage --apply`. |
| **Ancien objet public restant accessible** | Si un pack `published` repasse en `draft` et que `on_commit` échoue, l'objet public reste dans `default` jusqu'à réconciliation. | Détecté et supprimé par `reconcile_pack_storage --apply` (ou purge manuelle R2). |
| **Régénération concurrente d'un pack** | `OfflinePackGenerator.generate()` acquiert un verrou ligne `LessonPack.objects.select_for_update().get(pk=self.pack.pk)` dans `transaction.atomic()`. | Les régénérations concurrentes s'exécutent séquentiellement en relisant le `status` verrouillé. |
| **Suppression répétée / relance interrompue** | `_safe_delete_storage_object()` vérifie `storage.exists(name)` ; `reconcile_pack_storage` est idempotent (`--dry-run` par défaut, `--apply` pour exécuter). | Relance sûre autant de fois que nécessaire sans erreur ni suppression d'objet actif. |

---

## 2. Non-publication automatique

- **Vérifié dans le code :** aucune commande de gestion, migration, vue API ou signal Django ne modifie `LessonPack.status` vers `LessonPack.PUBLISHED`.
- Le passage à `published` ne peut résulter que d'une action explicite d'administration/gestionnaire.

---

## 3. Ce qui reste à vérifier sur les consoles (non vérifiable localement)

- Absence de règles d'accès public (`r2.dev`, custom domain, politique de bucket) sur le futur bucket R2 privé.
- Comportement effectif d'un rollback/suppression sur l'API S3 Cloudflare R2 réelle.

---

## 4. Concurrence, rollback extérieur et protections `--apply` sur R2

- **Rollback d'une transaction extérieure :** si une transaction englobante échoue après l'écriture du nouveau fichier dans le stockage cible, `transaction.on_commit` ne s'exécute pas (l'ancien fichier actif est préservé sans perte de données), mais le nouveau fichier écrit reste un orphelin récupérable via `reconcile_pack_storage --apply`.
- **Concurrence et réutilisation des clés :**
  - `AWS_S3_FILE_OVERWRITE = False` sur R2 (et suffixation automatique `FileSystemStorage`) évite l'écrasement silencieux d'une clé existante.
  - `OfflinePackGenerator.generate()` verrouille la ligne `LessonPack` via `select_for_update()`.
  - `reconcile_pack_storage` liste les objets R2/disque **avant** d'interroger la base, vérifie l'union `file ∪ private_file`, applique un délai de grâce `--min-age-seconds=300` (5 min par défaut) pour épargner les créations en cours, et re-vérifie `LessonPack.objects.filter(Q(file=name) | Q(private_file=name)).exists()` juste avant toute suppression.
- **Mode `--dry-run` :** comportement par défaut, strictement en lecture seule (aucune écriture ni suppression).
- **Protections requises avant `--apply` sur R2 :**
  1. Exécuter d'abord `python manage.py reconcile_pack_storage --dry-run` et relire la liste exacte des orphelins.
  2. Effectuer une sauvegarde `pg_dump` préalable (`docs/BACKUP_AND_RESTORE.md`).
  3. Vérifier l'absence de génération de pack ou d'upload admin en cours.
  4. Conserver `--min-age-seconds >= 300` et vérifier que `R2_PRIVATE_BUCKET_NAME != R2_BUCKET_NAME`.
