# backend/core/management/commands/bootstrap_render.py

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.core.management import call_command


class Command(BaseCommand):
    help = "Bootstrap Render database: create superuser and seed initial data."

    def handle(self, *args, **options):
        User = get_user_model()

        username = os.environ.get("DJANGO_SUPERUSER_USERNAME", "admin")
        email = os.environ.get("DJANGO_SUPERUSER_EMAIL", "gagapetitfils@gmail.com")
        password = os.environ.get("DJANGO_SUPERUSER_PASSWORD", "Marda..05BKa")

        if not password:
            self.stdout.write(self.style.WARNING("DJANGO_SUPERUSER_PASSWORD is not set. Superuser skipped."))
        elif User.objects.filter(username=username).exists():
            self.stdout.write(self.style.SUCCESS(f"Superuser '{username}' already exists."))
        else:
            User.objects.create_superuser(
                username=username,
                email=email,
                password=password,
            )
            self.stdout.write(self.style.SUCCESS(f"Superuser '{username}' created."))

        # Seed alphabet si la commande existe
        try:
            call_command("seed_alphabet")
            self.stdout.write(self.style.SUCCESS("Alphabet seed completed."))
        except Exception as exc:
            self.stdout.write(self.style.WARNING(f"seed_alphabet skipped: {exc}"))

        # Si tu as d'autres seed commands plus tard, on les ajoutera ici.