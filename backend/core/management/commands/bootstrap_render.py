# backend/core/management/commands/bootstrap_render.py

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError


class Command(BaseCommand):
    help = "Bootstrap Render database: create superuser only."

    def handle(self, *args, **options):
        User = get_user_model()
        if os.environ.get('BOOTSTRAP_SUPERUSER', '').lower() != 'true':
            self.stdout.write('Superuser bootstrap disabled (explicit opt-in required).')
            return

        username = os.environ.get("DJANGO_SUPERUSER_USERNAME", "")
        email = os.environ.get("DJANGO_SUPERUSER_EMAIL", "")
        password = os.environ.get("DJANGO_SUPERUSER_PASSWORD", "")

        if not username or not password:
            raise CommandError('Bootstrap explicite : identifiant et mot de passe requis.')

        if User.objects.filter(username=username).exists():
            self.stdout.write(
                self.style.SUCCESS(f"Superuser '{username}' already exists.")
            )
            return

        try:
            validate_password(password, User(username=username, email=email))
        except ValidationError as error:
            raise CommandError('Mot de passe bootstrap refusé par les validateurs.') from error

        User.objects.create_superuser(
            username=username,
            email=email,
            password=password,
        )

        self.stdout.write(
            self.style.SUCCESS(f"Superuser '{username}' created.")
        )
