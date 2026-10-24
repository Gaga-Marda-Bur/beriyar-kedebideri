# Procédures de Sauvegarde, Déploiement et Restauration (A21)

Ce document décrit les procédures opérationnelles de déploiement, sauvegarde et reprise après incident pour Beřiyar Kedebideři.

---

## 1. Séparation du cycle de déploiement (A21)

Auparavant, `build.sh` exécutait `python manage.py migrate` pendant la phase de compilation. Cela présentait un risque majeur :
- Le schéma de base était muté alors que l'ancienne version du code était encore en train de servir les utilisateurs.
- Si le build échouait par la suite (ex. erreur de staticfiles ou échec réseau), la base était déjà modifiée sans retour arrière automatique.

### Cycle séparé

1. **Phase de build (`backend/build.sh`) :**
   ```bash
   pip install -r requirements.txt
   python manage.py collectstatic --noinput
   ```
   *Rôle :* Installation des dépendances et compilation des assets statiques dans une sandbox isolée, sans toucher à la base de données.

2. **Phase de release (`backend/release.sh`) :**
   ```bash
   python manage.py migrate --noinput
   python manage.py bootstrap_render
   ```
   *Rôle :* Exécution des migrations additives de manière atomique avant le basculement du trafic. Sur Render, cette commande est configurée dans le champ **`preDeployCommand`** du service web. En cas d'échec, le déploiement s'interrompt immédiatement et l'ancienne instance continue de tourner.

---

## 2. Procédures de sauvegarde

Avant tout déploiement comportant une migration de données ou de schéma :

### A. Base de données PostgreSQL (Production Render / Cloud)

1. **Sauvegarde binaire complète :**
   ```bash
   # Utilisation de pg_dump avec compression et horodatage UTC
   export BACKUP_FILE="backup_bk_prod_$(date -u +%Y%m%d_%H%M%SZ).dump"
   pg_dump -Fc --no-acl --no-owner "$DATABASE_URL" > "$BACKUP_FILE"
   ```

2. **Vérification de l'intégrité de la sauvegarde :**
   ```bash
   # Vérifier que l'archive est lisible et lister les tables
   pg_restore --list "$BACKUP_FILE" | grep -E "TABLE DATA.*(alphabet_character|vocabulary_word|progress_unitprogress)"
   ```

3. **Chiffrement et archivage sécurisé :**
   - Stocker la sauvegarde sur un stockage froid chiffré distinct (ex. bucket S3 ou R2 de rétention avec verrouillage d'objet).
   - Ne **jamais** commiter une sauvegarde dans le dépôt Git.

### B. Base SQLite locale / test

1. **Sauvegarde à chaud via l'API SQLite :**
   ```python
   import sqlite3
   import shutil
   from datetime import datetime

   src = sqlite3.connect("backend/db.sqlite3")
   dst_path = f"backend/db_pre_deploy_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.sqlite3"
   dst = sqlite3.connect(dst_path)
   src.backup(dst)
   dst.close()
   src.close()
   ```

2. **Contrôle d'intégrité :**
   ```bash
   sqlite3 "$dst_path" "PRAGMA integrity_check;"
   sqlite3 "$dst_path" "PRAGMA foreign_key_check;"
   ```

### C. Médias et packs (Cloudflare R2)

1. **Synchronisation du bucket R2 :**
   ```bash
   # Synchroniser le bucket R2 vers un stockage miroir local/sécurisé
   rclone sync r2:beriyar-media/ /backups/r2_media/ \
       --checksum \
       --transfers=8 \
       --log-file=/backups/rclone_$(date -u +%Y%m%d).log
   ```

---

## 3. Procédure de restauration testée

En cas d'incident critique lors d'une migration ou d'un déploiement :

### Étape 1 : Passer le service en maintenance
Pour éviter des écritures partielles ou des corruptions concurrentes pendant la restauration :
- Activer la page de maintenance ou couper temporairement le trafic API au niveau du reverse proxy / CDN.

### Étape 2 : Restaurer la base de données

1. **Restauration PostgreSQL :**
   ```bash
   # Restauration propre avec nettoyage des objets existants
   pg_restore --clean --if-exists --no-acl --no-owner -d "$DATABASE_URL" "$BACKUP_FILE"
   ```

2. **Validation post-restauration :**
   ```sql
   -- Vérifier la présence et la cohérence des tables clés
   SELECT count(*) FROM alphabet_character;
   SELECT count(*) FROM vocabulary_word;
   SELECT count(*) FROM progress_unitprogress;
   SELECT app, name, applied FROM django_migrations ORDER BY applied DESC LIMIT 10;
   ```

### Étape 3 : Rollback applicatif
- Si le nouveau code est incompatible avec le schéma restauré, effectuer un rollback vers le commit ou la release précédente dans l'interface de l'hébergeur (Render / Git).

### Étape 4 : Vérification de santé et réouverture
- Appeler l'endpoint de diagnostic staff : `GET /api/core/diagnostics/https/`
- Effectuer un test de fumée sur l'application web (`/`, `/alphabet/`, `/vocabulaire/`).
- Rouvrir le trafic public.
