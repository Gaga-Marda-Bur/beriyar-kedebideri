"""Test de vérification de sauvegarde et restauration physique (audit préproduction).

Ce script effectue une vraie sauvegarde et restauration sur fichier physique
(pas en mémoire) :
1. Sauvegarde de la base SQLite physique et de l'arborescence des médias.
2. Restauration vers une cible séparée (test_backup_scratch/restored.sqlite3 et dossier test_backup_scratch/restored_media).
3. Contrôle d'intégrité SQLite (PRAGMA integrity_check, PRAGMA foreign_key_check).
4. COMPARAISON EXHAUSTIVE table par table et ligne par ligne entre la source et la base restaurée :
   - Schémas identiques (CREATE TABLE DDL).
   - Nombre de lignes identique sur chacune des tables.
   - Contenu intégral des lignes identique (comparaison des enregistrements).
5. Vérification d'intégrité binaire (SHA-256) de 100% des fichiers médias restaurés.
"""
import hashlib
import os
import shutil
import sqlite3
import sys
import tarfile

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend'))
SOURCE_DB = os.path.join(BACKEND_DIR, 'db.sqlite3')
SOURCE_MEDIA = os.path.join(BACKEND_DIR, 'media')

WORK_DIR = os.path.join(BACKEND_DIR, 'test_backup_scratch')
BACKUP_ARCHIVE_DB = os.path.join(WORK_DIR, 'backup_db.sqlite3')
BACKUP_ARCHIVE_MEDIA = os.path.join(WORK_DIR, 'backup_media.tar.gz')

RESTORED_DB = os.path.join(WORK_DIR, 'restored.sqlite3')
RESTORED_MEDIA = os.path.join(WORK_DIR, 'restored_media')


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def run_physical_restore_test():
    print("=== TEST PHYSIQUE SAUVEGARDE & RESTAURATION (COMPARAISON EXHAUSTIVE) ===")
    print(f"Source DB: {SOURCE_DB}")
    print(f"Source Media: {SOURCE_MEDIA}")

    if not os.path.exists(SOURCE_DB):
        print(f"ERREUR: Source DB introuvable : {SOURCE_DB}")
        return False

    if os.path.exists(WORK_DIR):
        shutil.rmtree(WORK_DIR)
    os.makedirs(WORK_DIR, exist_ok=True)

    # 1. Sauvegarde physique
    print("\n1. Création de la sauvegarde...")
    src_conn = sqlite3.connect(SOURCE_DB)
    backup_conn = sqlite3.connect(BACKUP_ARCHIVE_DB)
    src_conn.backup(backup_conn)
    backup_conn.close()
    print(f"   [OK] DB sauvegardée : {os.path.getsize(BACKUP_ARCHIVE_DB)} octets")

    # Sauvegarde médias dans un tar.gz
    media_count_orig = 0
    orig_media_hashes = {}
    if os.path.exists(SOURCE_MEDIA):
        with tarfile.open(BACKUP_ARCHIVE_MEDIA, "w:gz") as tar:
            for root, _, files in os.walk(SOURCE_MEDIA):
                for file in files:
                    full_p = os.path.join(root, file)
                    rel_p = os.path.relpath(full_p, SOURCE_MEDIA)
                    tar.add(full_p, arcname=rel_p)
                    orig_media_hashes[rel_p] = sha256_file(full_p)
                    media_count_orig += 1
    print(f"   [OK] {media_count_orig} fichiers médias archivés dans tar.gz")

    # 2. Restauration physique sur cible distincte
    print("\n2. Restauration sur environnement cible...")
    shutil.copy2(BACKUP_ARCHIVE_DB, RESTORED_DB)
    print(f"   [OK] DB restaurée dans : {RESTORED_DB}")

    os.makedirs(RESTORED_MEDIA, exist_ok=True)
    if os.path.exists(BACKUP_ARCHIVE_MEDIA):
        with tarfile.open(BACKUP_ARCHIVE_MEDIA, "r:gz") as tar:
            try:
                tar.extractall(RESTORED_MEDIA, filter='data')
            except TypeError:
                tar.extractall(RESTORED_MEDIA)
    print(f"   [OK] Médias extraits dans : {RESTORED_MEDIA}")

    # 3. Contrôles d'intégrité SQLite sur la DB restaurée
    print("\n3. Contrôles d'intégrité SQLite DB restaurée...")
    restored_conn = sqlite3.connect(RESTORED_DB)
    cur_res = restored_conn.cursor()

    cur_res.execute("PRAGMA integrity_check;")
    integrity = cur_res.fetchone()[0]
    if integrity != "ok":
        print(f"   [FAIL] integrity_check: {integrity}")
        return False
    print("   [OK] PRAGMA integrity_check: ok")

    cur_res.execute("PRAGMA foreign_key_check;")
    fk_violations = cur_res.fetchall()
    if fk_violations:
        print(f"   [FAIL] foreign_key_check: {len(fk_violations)} violations")
        return False
    print("   [OK] PRAGMA foreign_key_check: 0 violation")

    # 4. COMPARAISON EXHAUSTIVE SOURCE vs RESTAURÉE (Table par table, ligne par ligne)
    print("\n4. Comparaison exhaustive de TOUTES les tables (Source vs Restaurée)...")
    cur_src = src_conn.cursor()

    cur_src.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
    src_tables = cur_src.fetchall()

    cur_res.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
    res_tables = cur_res.fetchall()

    if len(src_tables) != len(res_tables):
        print(f"   [FAIL] Nombre de tables différent : source={len(src_tables)}, restaurée={len(res_tables)}")
        return False

    print(f"   [OK] {len(src_tables)} tables utilisateur identifiées dans les deux bases.")

    total_rows_verified = 0
    table_mismatches = []

    for name, sql in src_tables:
        # Vérification du schéma DDL
        cur_res.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name = ?;", (name,))
        res_sql_row = cur_res.fetchone()
        if not res_sql_row or res_sql_row[0] != sql:
            table_mismatches.append(f"Schéma divergent pour la table {name}")
            continue

        # Vérification du nombre de lignes
        cur_src.execute(f"SELECT count(*) FROM \"{name}\";")
        src_cnt = cur_src.fetchone()[0]

        cur_res.execute(f"SELECT count(*) FROM \"{name}\";")
        res_cnt = cur_res.fetchone()[0]

        if src_cnt != res_cnt:
            table_mismatches.append(f"Nombre de lignes divergent pour {name} : source={src_cnt}, restaurée={res_cnt}")
            continue

        # Vérification ligne par ligne de l'intégralité des données
        cur_src.execute(f"SELECT * FROM \"{name}\";")
        src_rows = cur_src.fetchall()

        cur_res.execute(f"SELECT * FROM \"{name}\";")
        res_rows = cur_res.fetchall()

        # Tri canonique en mémoire pour garantir la concordance indépendamment de l'ordre physique
        src_rows_sorted = sorted(src_rows, key=lambda r: str(r))
        res_rows_sorted = sorted(res_rows, key=lambda r: str(r))

        if src_rows_sorted != res_rows_sorted:
            table_mismatches.append(f"Données divergentes dans la table {name}")
            continue

        total_rows_verified += src_cnt

    src_conn.close()
    restored_conn.close()

    if table_mismatches:
        for err in table_mismatches:
            print(f"   [FAIL] {err}")
        return False

    print(f"   [OK] 100% des {len(src_tables)} tables vérifiées : schémas et {total_rows_verified} enregistrements identiques au bit près.")

    # 5. Contrôles d'intégrité binaire des médias
    print("\n5. Contrôles d'intégrité binaire des médias restaurés...")
    restored_media_count = 0
    mismatches = []
    for rel_p, orig_hash in orig_media_hashes.items():
        restored_file = os.path.join(RESTORED_MEDIA, rel_p)
        if not os.path.exists(restored_file):
            mismatches.append(f"Fichier manquant : {rel_p}")
            continue
        restored_hash = sha256_file(restored_file)
        if restored_hash != orig_hash:
            mismatches.append(f"Empreinte altérée pour : {rel_p}")
            continue
        restored_media_count += 1

    if mismatches:
        print(f"   [FAIL] Anomalies médias détectées : {mismatches}")
        return False
    print(f"   [OK] {restored_media_count}/{media_count_orig} fichiers médias restaurés à l'identique (SHA-256 conforme)")

    # 6. Nettoyage
    shutil.rmtree(WORK_DIR)
    print("\n=== RÉSULTAT DU TEST : COMPARAISON EXHAUSTIVE RÉUSSIE ===")
    return True


if __name__ == '__main__':
    ok = run_physical_restore_test()
    sys.exit(0 if ok else 1)
