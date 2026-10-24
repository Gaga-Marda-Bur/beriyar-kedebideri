#!/usr/bin/env bash
set -o errexit

# A21: Phase de release distincte (Render preDeployCommand / commande de pré-déploiement).
# Exécutée APRÈS la réussite du build (build.sh) et AVANT la mise en ligne des nouvelles instances.
# En cas d'erreur ici, le déploiement est annulé et l'ancienne version reste en ligne.

python manage.py migrate --noinput
python manage.py bootstrap_render
