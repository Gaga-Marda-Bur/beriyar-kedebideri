from io import StringIO
from django.core.management import call_command
from django.test import TestCase

from alphabet.models import Character


class SeedInitialContentSecurityTests(TestCase):
    def test_seed_does_not_delete_characters_in_extended_range(self):
        """A08: seed_initial_content ne doit pas supprimer les caractères de la plage U+16EBB..U+16ED3."""
        # Créer un caractère dans la plage étendue
        char_ext = Character.objects.create(
            symbol=chr(0x16EBB),
            unicode_code='U+16EBB',
            name='Test Extended',
            is_active=True,
        )

        out = StringIO()
        call_command('seed_initial_content', stdout=out)

        # Vérifier que le caractère est TOUJOURS présent en base
        self.assertTrue(Character.objects.filter(id=char_ext.id).exists())

    def test_seed_dry_run_creates_no_records(self):
        """A08: En mode --dry-run, aucun enregistrement ne doit être créé."""
        initial_count = Character.objects.count()

        out = StringIO()
        call_command('seed_initial_content', '--dry-run', stdout=out)

        self.assertEqual(Character.objects.count(), initial_count)
        self.assertIn('MODE SIMULATION', out.getvalue())
