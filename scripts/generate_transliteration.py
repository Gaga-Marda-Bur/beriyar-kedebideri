"""Generate platform tables from the unchanged, user-approved JSON. --check for CI."""
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
    # Identical non-linguistic passthrough classification on every runtime.
    ranges = []
    for cp in range(0x110000):
        c = chr(cp)
        if c.isspace() or unicodedata.category(c)[0] in 'PNZ':
            if ranges and cp == ranges[-1][1] + 1:
                ranges[-1][1] = cp
            else:
                ranges.append([cp, cp])
    payload = {'source_sha256': hashlib.sha256(raw).hexdigest(),
               'unicode_version': unicodedata.unidata_version,
               'rows': [[r[k] for k in columns] for r in letters],
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
    add('unmapped-erfe-mark', '𖺠\u0304', 'erfe', 'latin', 'Ā',
        unmapped=[{'character': '\u0304', 'codepoint': 'U+0304', 'index': 1}])
    add('arabic-presentation-form-not-inferred', 'ﺍ', 'arabic', 'erfe', 'ﺍ',
        unmapped=[{'character': 'ﺍ', 'codepoint': 'U+FE8D', 'index': 0}])
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
