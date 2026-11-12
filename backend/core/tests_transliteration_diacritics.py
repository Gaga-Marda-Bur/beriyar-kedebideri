import json
from pathlib import Path
import unicodedata as ud
from django.test import SimpleTestCase
from rest_framework.test import APIClient
from .transliteration import normalize_erfe, transliterate

SOURCE = json.loads((Path(__file__).resolve().parents[2] / 'shared/linguistics/beriya_erfe_transliteration_mapping.json').read_bytes())


class DiacriticsTests(SimpleTestCase):
    def test_api_reports_incomplete_arabic_without_changing_contract(self):
        response = APIClient().post('/api/core/transliterate/',
            {'text': 'ÁÈÎ', 'source_script': 'latin', 'target_script': 'arabic'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.json()), {'text', 'unmapped'})
        self.assertEqual(response.json()['text'], 'ÁÈÎ')
        self.assertEqual(len(response.json()['unmapped']), 3)
        self.assertTrue(all(c['reason'] == 'missing_arabic_mapping' for c in response.json()['unmapped']))

    def test_all_16_forms_in_both_directions_nfc_nfd_and_lower_erfe(self):
        self.assertEqual(len(SOURCE['diacritic_letters']), 16)
        for r in SOURCE['diacritic_letters']:
            with self.subTest(r['latin_upper']):
                for key in ('latin_upper', 'latin_lower'):
                    for form in ('NFC', 'NFD'):
                        self.assertEqual(transliterate(ud.normalize(form, r[key]), 'latin', 'erfe'), {'text': r['erfe'], 'unmapped': []})
                for key in ('erfe', 'erfe_lower_alias'):
                    self.assertEqual(transliterate(r[key], 'erfe', 'latin')['text'], r['latin_upper'])
                    self.assertEqual(normalize_erfe(r[key]), r['erfe'])

    def test_missing_arabic_preserves_entire_source_unit(self):
        for r in SOURCE['diacritic_letters']:
            for source, value in [('erfe', r['erfe']), ('latin', r['latin_upper'])]:
                with self.subTest(value):
                    result = transliterate(value, source, 'arabic')
                    self.assertEqual(result['text'], value)
                    self.assertEqual(len(result['unmapped']), 1)
                    self.assertEqual(result['unmapped'][0]['character'], value)
                    self.assertEqual(result['unmapped'][0]['reason'], 'missing_arabic_mapping')

    def test_examples_and_no_inferred_marks(self):
        self.assertEqual(normalize_erfe('𖺻́𖺾̀𖻂̄'), '𖺠́𖺣̀𖺧̄')
        self.assertEqual(transliterate('𖺠́𖺣̀𖺧̄', 'erfe', 'latin')['text'], 'ÁÈÎ')
        self.assertEqual(transliterate('ÁÈÎ', 'latin', 'erfe')['text'], '𖺠́𖺣̀𖺧̄')
        # Erfe circumflex is NOT the supplied Erfe macron; no invented alias.
        result = transliterate('𖺧\u0302', 'erfe', 'latin')
        self.assertEqual(result['text'], '𖺧\u0302')
        self.assertTrue(result['unmapped'])
        self.assertEqual(transliterate('𖺧\u0307', 'erfe', 'latin')['text'], 'Ị')
        self.assertEqual(transliterate('I\u0323', 'latin', 'erfe')['text'], '𖺧\u0307')
