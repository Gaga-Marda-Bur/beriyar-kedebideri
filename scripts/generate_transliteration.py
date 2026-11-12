"""Generate base + confirmed diacritic tables from the unique JSON. --check for CI."""
import argparse
import hashlib
import json
from pathlib import Path
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'shared/linguistics/beriya_erfe_transliteration_mapping.json'


def outputs():
    raw = SOURCE.read_bytes()
    data = json.loads(raw)
    letters = data['letters']
    diacritics = data.get('diacritic_letters', [])
    assert len(letters) == 25
    columns = ['erfe', 'erfe_lower_alias', 'latin_upper', 'latin_lower', 'arabic']
    for key in columns:
        assert len({r[key] for r in letters}) == 25
        assert all(len(r[key]) == 1 for r in letters)
    for i, row in enumerate(letters):
        assert ord(row['erfe']) == 0x16EA0 + i
        assert ord(row['erfe_lower_alias']) == 0x16EBB + i
        for char, code in [('erfe', 'erfe_codepoint'), ('arabic', 'arabic_codepoint'),
                           ('erfe_lower_alias', 'erfe_lower_codepoint')]:
            assert ord(row[char]) == int(row[code][2:], 16)
    assert len(diacritics) == 16
    assert data['diacritics_validation']['status'] == 'confirmed_by_user'
    for row in diacritics:
        assert row['arabic'] is None  # No Arabic convention has been supplied.
        assert len(row['erfe']) == len(row['erfe_lower_alias']) == 2
        assert ord(row['erfe'][0]) - 0x16EA0 == ord(row['erfe_lower_alias'][0]) - 0x16EBB
        assert row['erfe'][1] == row['erfe_lower_alias'][1]
        for key in ('latin_upper', 'latin_lower', 'erfe'):
            assert unicodedata.normalize('NFC', row[key]) == row[key]
    all_letters = letters + diacritics
    for key in ('erfe', 'latin_upper', 'latin_lower'):
        assert len({r[key] for r in all_letters}) == 41
    # Identical non-linguistic passthrough classification on every runtime.
    ranges, combining_ranges = [], []
    for cp in range(0x110000):
        c = chr(cp)
        if c.isspace() or unicodedata.category(c)[0] in 'PNZ':
            if ranges and cp == ranges[-1][1] + 1:
                ranges[-1][1] = cp
            else:
                ranges.append([cp, cp])
        if unicodedata.category(c)[0] == 'M':
            if combining_ranges and cp == combining_ranges[-1][1] + 1:
                combining_ranges[-1][1] = cp
            else:
                combining_ranges.append([cp, cp])
    options = {}
    # Preserve the existing first long-press choice (macron); no manual letter table.
    for row in sorted(diacritics, key=lambda r: (r['erfe'][1] != '\u0304', r['erfe'][1])):
        options.setdefault(row['erfe'][0], []).append(row['erfe'])
    payload = {'source_sha256': hashlib.sha256(raw).hexdigest(),
               'unicode_version': unicodedata.unidata_version,
               'rows': [[r[k] for k in columns] for r in all_letters],
               'combining_ranges': combining_ranges,
               'diacritic_options': options,
               'passthrough_ranges': ranges}
    encoded = json.dumps(payload, ensure_ascii=True, separators=(',', ':'))
    fixtures = []
    def add(name, text, source, target, expected, lower=False, unmapped=None):
        fixtures.append(dict(name=name, input=text, source=source, target=target,
                             lowercase=lower, expected={'text': expected, 'unmapped': unmapped or []}))
    for i, row in enumerate(letters):
        for source, source_key in [('erfe', 'erfe'), ('latin', 'latin_upper'), ('arabic', 'arabic')]:
            for target, target_key in [('erfe', 'erfe'), ('latin', 'latin_upper'), ('arabic', 'arabic')]:
                add(f'{i}:{source}-{target}', row[source_key], source, target, row[target_key])
        add(f'{i}:latin-input-lower', row['latin_lower'], 'latin', 'erfe', row['erfe'])
        add(f'{i}:erfe-input-lower', row['erfe_lower_alias'], 'erfe', 'arabic', row['arabic'])
        add(f'{i}:latin-output-lower', row['arabic'], 'arabic', 'latin', row['latin_lower'], True)
    for source, key in [('erfe', 'erfe'), ('latin', 'latin_upper'), ('arabic', 'arabic')]:
        for target, target_key in [('erfe', 'erfe'), ('latin', 'latin_upper'), ('arabic', 'arabic')]:
            text = '  ' + '\n ١٢3،!?—'.join(r[key] for r in letters) + '\t'
            expected = '  ' + '\n ١٢3،!?—'.join(r[target_key] for r in letters) + '\t'
            add(f'multiline:{source}-{target}', text, source, target, expected)
    add('nfc-sensitive', 'R\u030cS\u030c', 'latin', 'arabic', 'ڕش')
    add('CRLF', 'ABD\r\nABD\rABD', 'latin', 'arabic', 'ابد\r\nابد\rابد')
    add('unknown-supplementary', 'A😀C\U00020000', 'latin', 'erfe', '𖺠😀C\U00020000', unmapped=[
        {'character': c, 'codepoint': f'U+{ord(c):04X}', 'index': i}
        for i, c in enumerate('A😀C\U00020000') if i])
    add('unmapped-composed-vowel', 'A\u0304', 'latin', 'erfe', 'Ā',
        unmapped=[{'character': 'Ā', 'codepoint': 'U+0100', 'index': 0}])
    # This previously unsupported sequence now has an explicitly validated mapping.
    add('validated-erfe-macron', '𖺠\u0304', 'erfe', 'latin', 'Â')
    add('arabic-presentation-form-not-inferred', 'ﺍ', 'arabic', 'erfe', 'ﺍ',
        unmapped=[{'character': 'ﺍ', 'codepoint': 'U+FE8D', 'index': 0}])
    def missing(unit, index=0, reason=None):
        item = {'character': unit, 'codepoint': ' '.join(f'U+{ord(c):04X}' for c in unit), 'index': index}
        if reason:
            item['reason'] = reason
        return [item]
    for i, row in enumerate(diacritics):
        for source, inputs in [('latin', [row['latin_upper'], row['latin_lower'],
                                         unicodedata.normalize('NFD', row['latin_upper']),
                                         unicodedata.normalize('NFD', row['latin_lower'])]),
                               ('erfe', [row['erfe'], row['erfe_lower_alias']])]:
            for j, text in enumerate(inputs):
                for target, value in [('erfe', row['erfe']), ('latin', row['latin_upper'])]:
                    add(f'diacritic:{i}:{source}:{j}-{target}', text, source, target, value)
                preserved = row['erfe'] if source == 'erfe' else unicodedata.normalize('NFC', text)
                add(f'diacritic:{i}:{source}:{j}-arabic', text, source, 'arabic', preserved,
                    unmapped=missing(preserved, reason='missing_arabic_mapping'))
        add(f'diacritic:{i}:lower-output', row['erfe'], 'erfe', 'latin', row['latin_lower'], True)
    for source, text, expected in [('latin', 'ÁÈÎ', '𖺠́𖺣̀𖺧̄'), ('erfe', '𖺻́𖺾̀𖻂̄', 'ÁÈÎ')]:
        add('example:' + source, text, source, 'erfe' if source == 'latin' else 'latin', expected)
    add('mixed-incomplete-arabic', 'BÁ D', 'latin', 'arabic', 'بÁ د',
        unmapped=missing('Á', index=1, reason='missing_arabic_mapping'))
    for i, unit in enumerate(['𖺧\u0302', '𖺠\u0301\u0304', 'ا\u064E', '𖺧\u0323', 'İ']):
        add(f'unsupported-whole-unit:{i}', unit, 'arabic' if i == 2 else 'latin' if i == 4 else 'erfe', 'latin', unit,
            unmapped=missing(unit))
    return {
        'shared/linguistics/transliteration_vectors.json': json.dumps(fixtures, ensure_ascii=True, indent=2) + '\n',
        'backend/core/transliteration_data.py': '# Generated; do not edit.\nimport json\nDATA = json.loads(' + repr(encoded) + ')\n',
        'backend/static/webapp/js/transliteration_data.js': '// Generated; do not edit.\n(function(g){const data=' + encoded + ';if(typeof module!=="undefined")module.exports=data;else g.BKTransliterationData=data;})(globalThis);\n',
        'mobile/lib/shared/beriya/transliteration_data.dart': "// Generated; do not edit.\nimport 'dart:convert';\nfinal Map<String, dynamic> transliterationData = jsonDecode(r'''" + encoded + "''') as Map<String, dynamic>;\n",
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for relative, text in outputs().items():
        path = ROOT / relative
        if args.check:
            assert path.read_text(encoding='utf-8') == text, f'Outdated generated table: {relative}'
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8', newline='\n')
