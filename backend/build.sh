#!/usr/bin/env bash
set -o errexit

# A21: Phase de build pure (installation des dépendances et compilation des assets).
# Les migrations de base de données sont intentionnellement séparées dans release.sh
# pour éviter de muter le schéma pendant que l'ancienne version dessert le trafic.

pip install -r requirements.txt
python manage.py collectstatic --noinput
