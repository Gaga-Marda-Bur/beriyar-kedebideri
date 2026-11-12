import json
from pathlib import Path
from django.test import TestCase, SimpleTestCase
from rest_framework.test import APIClient
from .transliteration import normalize_erfe, transliterate

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = json.loads((ROOT / 'shared/linguistics/beriya_erfe_transliteration_mapping.json').read_bytes())


class EngineTests(SimpleTestCase):
    def test_shared_vectors(self):
        vectors = json.loads((ROOT / 'shared/linguistics/transliteration_vectors.json').read_bytes())
        for v in vectors:
            with self.subTest(v['name']):
                self.assertEqual(transliterate(v['input'], v['source'], v['target'], latin_lowercase=v['lowercase']), v['expected'])

    def test_all_letters_and_directions(self):
        for r in REFERENCE['letters']:
            self.assertEqual(normalize_erfe(r['erfe_lower_alias']), r['erfe'])
            for source, key in [('erfe', 'erfe'), ('latin', 'latin_upper'), ('arabic', 'arabic')]:
                for target, target_key in [('erfe', 'erfe'), ('latin', 'latin_upper'), ('arabic', 'arabic')]:
                    self.assertEqual(transliterate(r[key], source, target), {'text': r[target_key], 'unmapped': []})
            self.assertEqual(transliterate(r['latin_lower'], 'latin', 'erfe')['text'], r['erfe'])
            self.assertEqual(transliterate(r['erfe'], 'erfe', 'latin', latin_lowercase=True)['text'], r['latin_lower'])

    def test_nfc_unknown_and_multiline(self):
        self.assertEqual(transliterate('aBd\n 123،!?', 'latin', 'arabic'), {'text': 'ابد\n 123،!?', 'unmapped': []})
        self.assertEqual(transliterate('R\u030cS\u030c', 'latin', 'arabic')['text'], 'ڕش')
        result = transliterate('A😀C\U00020000', 'latin', 'erfe')
        self.assertEqual(result['text'], '𖺠😀C\U00020000')
        self.assertEqual([i['index'] for i in result['unmapped']], [1, 2, 3])
        self.assertEqual(transliterate('یي', 'arabic', 'latin')['text'], 'IY')
        self.assertEqual(transliterate('AEG', 'latin', 'arabic')['text'], 'اآق')
        self.assertEqual(transliterate('𖺻𖺼𖺽', 'erfe', 'latin')['text'], 'ABD')
        with self.assertRaises(ValueError):
            transliterate('A', 'auto', 'erfe')


class WriteBoundaryTests(TestCase):
    def test_admin_transcription_conversion_is_explicit(self):
        from django.forms import modelform_factory
        from vocabulary.models import Word
        from .forms import CanonicalErfeModelForm
        form_type = modelform_factory(Word, form=CanonicalErfeModelForm,
                                     fields=['beriya_text', 'latin_transcription', 'arabic_transcription'])
        form = form_type(data={'beriya_text': '𖺻', 'latin_transcription': 'a', 'arabic_transcription': 'ا'})
        self.assertTrue(form.is_valid(), form.errors)
        word = form.save()
        self.assertEqual(word.beriya_text, '𖺠')
        self.assertEqual(word.latin_transcription, 'a')

    def test_search_finds_mixed_historical_case_without_rewrite(self):
        from vocabulary.models import Word
        from .erfe_search import erfe_search_expression
        word = Word.objects.create(beriya_text='𖺠𖺡', validation_status='published')
        Word.objects.filter(pk=word.pk).update(beriya_text='𖺻𖺡')
        found = Word.objects.alias(s=erfe_search_expression('beriya_text')).filter(s__icontains='𖺠𖺡')
        self.assertEqual(list(found.values_list('pk', flat=True)), [word.pk])
        self.assertEqual(Word.objects.get(pk=word.pk).beriya_text, '𖺻𖺡')

    def test_new_word_is_canonical_without_translating(self):
        from vocabulary.models import Word
        word = Word.objects.create(beriya_text='𖺻𖺼𖺽', latin_transcription='abd', arabic_transcription='ابد')
        word.refresh_from_db()
        self.assertEqual(word.beriya_text, '𖺠𖺡𖺢')
        self.assertEqual(word.latin_transcription, 'abd')
        self.assertEqual(word.arabic_transcription, 'ابد')
        self.assertEqual(word.validation_status, 'draft')

    def test_unchanged_history_and_partial_update_preserved(self):
        from vocabulary.models import Word
        word = Word.objects.create(beriya_text='𖺠')
        # Simulate an old record, never run this on historical project data.
        Word.objects.filter(pk=word.pk).update(beriya_text='𖺻')
        word.refresh_from_db()
        word.french_translation = 'test'
        word.save()
        word.refresh_from_db()
        self.assertEqual(word.beriya_text, '𖺻')
        word.beriya_text = '𖺼'
        word.save(update_fields=['beriya_text'])
        word.refresh_from_db()
        self.assertEqual(word.beriya_text, '𖺡')

    def test_api_exact_conversion_no_persistence(self):
        client = APIClient()
        response = client.post('/api/core/transliterate/', {'text': 'ABD', 'source_script': 'latin', 'target_script': 'erfe'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['text'], '𖺠𖺡𖺢')
        response = client.post('/api/core/transliterate/', {'text': 'A', 'source_script': 'auto', 'target_script': 'erfe'}, format='json')
        self.assertEqual(response.status_code, 400)
