import json
from pathlib import Path
import unicodedata as ud
from django.test import SimpleTestCase
from rest_framework.test import APIClient
from .transliteration import normalize_erfe, transliterate

SOURCE = json.loads((Path(__file__).resolve().parents[2] / 'shared/linguistics/beriya_erfe_transliteration_mapping.json').read_bytes())


class DiacriticsTests(SimpleTestCase):
    def test_api_converts_homologated_arabic_without_unmapped(self):
        response = APIClient().post('/api/core/transliterate/',
            {'text': 'ÁÈÎÔ', 'source_script': 'latin', 'target_script': 'arabic'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.json()), {'text', 'unmapped'})
        self.assertEqual(response.json()['text'], '\u0627\u0301\u0622\u0300\u06CC\u0304\u06C6\u0304')
        self.assertEqual(response.json()['unmapped'], [])

    def test_all_16_forms_in_all_directions_nfc_nfd_and_roundtrip(self):
        self.assertEqual(len(SOURCE['diacritic_letters']), 16)
        for r in SOURCE['diacritic_letters']:
            with self.subTest(r['latin_upper']):
                for key in ('latin_upper', 'latin_lower'):
                    for form in ('NFC', 'NFD'):
                        self.assertEqual(transliterate(ud.normalize(form, r[key]), 'latin', 'erfe'), {'text': r['erfe'], 'unmapped': []})
                        self.assertEqual(transliterate(ud.normalize(form, r[key]), 'latin', 'arabic'), {'text': r['arabic'], 'unmapped': []})
                for key in ('erfe', 'erfe_lower_alias'):
                    for form in ('NFC', 'NFD'):
                        erfe_val = ud.normalize(form, r[key])
                        self.assertEqual(transliterate(erfe_val, 'erfe', 'latin')['text'], r['latin_upper'])
                        ar_res = transliterate(erfe_val, 'erfe', 'arabic')
                        self.assertEqual(ar_res, {'text': r['arabic'], 'unmapped': []})
                        self.assertEqual(transliterate(ar_res['text'], 'arabic', 'erfe'), {'text': r['erfe'], 'unmapped': []})
                        self.assertEqual(normalize_erfe(erfe_val), r['erfe'])
                for form in ('NFC', 'NFD'):
                    ar_val = ud.normalize(form, r['arabic'])
                    self.assertEqual(transliterate(ar_val, 'arabic', 'erfe'), {'text': r['erfe'], 'unmapped': []})
                    self.assertEqual(transliterate(ar_val, 'arabic', 'latin'), {'text': r['latin_upper'], 'unmapped': []})

    def test_regression_eight_numbered_items_erfe_to_arabic_no_erfe_left(self):
        sample = (
            "𖺯̄𖺩𖺩𖺧𖺸𖺠 𖺡𖺣𖺲𖺧𖺸𖺠𖺱 𖺩𖺣𖺢𖺣𖺡𖺧𖺢𖺣𖺲𖺧 𖺩𖺧̄𖺸𖺧𖺱 𖺩𖺧𖺸𖺣 𖺢𖺧𖺢𖺧 𖺩𖺧̄ 𖺣𖺱 𖺨𖺧𖺸𖺧 𖺣𖺥𖺯 𖺬𖺠𖺢𖺠𖺬𖺢𖺣𖺣 𖺣𖺢𖺧.\n\n"
            "1. 𖺢𖺧𖺡𖺯 𖺥𖺥𖺠𖺱𖺢𖺧\n"
            "2. 𖺫𖺯̄𖺥𖺯𖺷\n"
            "3. 𖺫𖺠𖺦𖺠\n"
            "4. 𖺦𖺠𖺥𖺠\n"
            "5. 𖺠𖺱𖺥𖺠𖺬𖺠\n"
            "6. 𖺦𖺣𖺸𖺥𖺯\n"
            "7. 𖺵𖺧𖺩𖺵𖺯𖺩\n"
            "8. 𖺥𖺠𖺱𖺢𖺧"
        )
        expected = (
            "ۆ̄ككیيا بآڕیيار كآدآبیدآڕی كی̄يیر كیيآ دیدی كی̄ آر جیيی آقۆ ناداندآآ آدی.\n\n"
            "1. دیبۆ ققاردی\n"
            "2. مۆ̄قۆو\n"
            "3. ماها\n"
            "4. هاقا\n"
            "5. ارقانا\n"
            "6. هآيقۆ\n"
            "7. تیكتۆك\n"
            "8. قاردی"
        )
        res = transliterate(sample, 'erfe', 'arabic')
        self.assertEqual(res['text'], expected)
        self.assertEqual(res['unmapped'], [])
        self.assertFalse(any(0x16EA0 <= ord(c) <= 0x16EDF for c in res['text']))
        back = transliterate(expected, 'arabic', 'erfe')
        self.assertEqual(back['text'], sample)
        self.assertEqual(back['unmapped'], [])

    def test_examples_and_no_inferred_marks(self):
        self.assertEqual(normalize_erfe('𖺻́𖺾̀𖻂̄'), '𖺠́𖺣̀𖺧̄')
        self.assertEqual(transliterate('𖺠́𖺣̀𖺧̄', 'erfe', 'latin')['text'], 'ÁÈÎ')
        self.assertEqual(transliterate('ÁÈÎ', 'latin', 'erfe')['text'], '𖺠́𖺣̀𖺧̄')
        self.assertEqual(transliterate('𖺯̄', 'erfe', 'arabic')['text'], '\u06C6\u0304')
        self.assertEqual(transliterate('𖺧̄', 'erfe', 'arabic')['text'], '\u06CC\u0304')
        # Erfe circumflex is NOT the supplied Erfe macron; no invented alias.
        result = transliterate('𖺧\u0302', 'erfe', 'latin')
        self.assertEqual(result['text'], '𖺧\u0302')
        self.assertTrue(result['unmapped'])
        self.assertEqual(transliterate('𖺧\u0307', 'erfe', 'latin')['text'], 'Ị')
        self.assertEqual(transliterate('I\u0323', 'latin', 'erfe')['text'], '𖺧\u0307')
