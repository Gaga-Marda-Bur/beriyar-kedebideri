import io
import json
import zipfile
from django.core.files.base import ContentFile
from django.test import TestCase

from alphabet.models import Character, CharacterAudio
from audio_assets.models import AudioAsset
from learning.models import LearningTheme, LearningUnit
from offline_packs.models import LessonPack
from offline_packs.services.offline_pack_generator import OfflinePackGenerator


class OfflinePackModelTests(TestCase):
    def test_update_file_metadata_streaming(self):
        """A04: update_file_metadata doit calculer taille et SHA-256 sans faire pack.file.path."""
        content = b"TEST_STREAMING_CONTENT_FOR_A04"
        pack = LessonPack.objects.create(
            slug='test-streaming-pack',
            title_fr='Pack Test Streaming',
            version=1,
            file=ContentFile(content, name='test_pack.zip'),
        )

        pack.update_file_metadata()

        import hashlib
        expected_sha = hashlib.sha256(content).hexdigest()

        self.assertEqual(pack.size_mb, round(len(content) / (1024 * 1024), 2))
        self.assertEqual(pack.checksum, expected_sha)


class OfflinePackGeneratorTests(TestCase):
    def setUp(self):
        self.theme = LearningTheme.objects.create(
            slug='theme-test',
            title_fr='Theme Test',
            status=LearningTheme.PUBLISHED,
        )
        self.unit = LearningUnit.objects.create(
            theme=self.theme,
            slug='unit-test',
            title_fr='Unit Test',
            status=LearningUnit.PUBLISHED,
        )

        self.audio = AudioAsset.objects.create(
            title="Audio Test",
            file=ContentFile(b"FAKE_MP3_CONTENT", name="audio/test.mp3"),
            validation_status="published",
        )

        self.character = Character.objects.create(
            symbol="𖺀",
            unicode_code="U+16EA0",
            validation_status="published",
        )
        CharacterAudio.objects.create(
            character=self.character,
            audio_asset=self.audio,
            role="normal",
        )
        self.unit.characters.add(self.character)

        self.pack = LessonPack.objects.create(
            slug='pack-test',
            title_fr='Pack Test',
            version=1,
            status=LessonPack.PUBLISHED,
        )
        self.pack.themes.add(self.theme)
        self.pack.units.add(self.unit)
        self.pack.characters.add(self.character)

    def test_generation_rewrites_core_flow_media_references(self):
        """A06: Le core_flow exporté dans le pack doit réécrire les références audio vers des chemins locaux."""
        generator = OfflinePackGenerator(self.pack)
        pack = generator.generate()

        self.assertIsNotNone(pack.file)
        self.assertEqual(len(pack.checksum), 64)  # SHA-256 valide

        # Lire le units.json embarqué dans le ZIP
        with zipfile.ZipFile(pack.file.path, 'r') as z:
            namelist = z.namelist()
            units_entry = 'units.json' if 'units.json' in namelist else f"{pack.slug}/units.json"
            units_json = json.loads(z.read(units_entry).decode('utf-8'))
            self.assertEqual(len(units_json), 1)
            core_flow = units_json[0]['core_flow']
            self.assertGreater(len(core_flow), 0)

            # Vérifier qu'aucune étape discovery n'expose d'URL distante ou /media/...
            for step in core_flow:
                if step.get('audio_url'):
                    self.assertFalse(step['audio_url'].startswith('http://'))
                    self.assertFalse(step['audio_url'].startswith('/media/'))
                    self.assertTrue(step['audio_url'].startswith('audio/'))

    def test_published_pack_excludes_draft_items(self):
        """A07: Un pack au statut 'published' ne doit jamais embarquer d'éléments au statut 'draft' ou 'review'."""
        draft_unit = LearningUnit.objects.create(
            theme=self.theme,
            slug='draft-unit',
            title_fr='Draft Unit',
            status='draft',
        )
        draft_char = Character.objects.create(
            symbol="𖺁",
            unicode_code="U+16EA1",
            validation_status="review",
        )
        self.pack.units.add(draft_unit)
        self.pack.characters.add(draft_char)

        generator = OfflinePackGenerator(self.pack)
        pack = generator.generate()

        with zipfile.ZipFile(pack.file.path, 'r') as z:
            namelist = z.namelist()
            units_entry = 'units.json' if 'units.json' in namelist else f"{pack.slug}/units.json"
            units_json = json.loads(z.read(units_entry).decode('utf-8'))
            unit_slugs = [u['slug'] for u in units_json]
            self.assertIn('unit-test', unit_slugs)
            self.assertNotIn('draft-unit', unit_slugs)

            chars_entry = 'characters.json' if 'characters.json' in namelist else f"{pack.slug}/characters.json"
            chars_json = json.loads(z.read(chars_entry).decode('utf-8'))
            char_symbols = [c['symbol'] for c in chars_json]
            self.assertIn('𖺀', char_symbols)
            self.assertNotIn('𖺁', char_symbols)
