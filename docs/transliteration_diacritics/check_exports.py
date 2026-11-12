"""Run with the bundled Python (pypdf, Pillow). All test assets are synthetic QA."""
import json
from pathlib import Path
from pypdf import PdfReader
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
forms = json.loads((ROOT / 'shared/linguistics/beriya_erfe_transliteration_mapping.json').read_bytes())['diacritic_letters']
results = {}
for name in ('web_diacritics.pdf', 'flutter_diacritics.pdf'):
    reader = PdfReader(OUT / name)
    text = '\n'.join(p.extract_text() for p in reader.pages)
    missing = [r['erfe'] for r in forms if r['erfe'] not in text]
    missing_latin = [r['latin_upper'] for r in forms if r['latin_upper'] not in text]
    # Require valid UTF-16BE ToUnicode destinations (supplementary Erfe included).
    maps = []
    for page in reader.pages:
        for font in page['/Resources'].get('/Font', {}).values():
            obj = font.get_object()
            if '/ToUnicode' in obj:
                maps.append(obj['/ToUnicode'].get_object().get_data().decode('ascii'))
    valid_supplementary = any('D81BDEA' in m.upper() or 'D81BDEB' in m.upper() for m in maps)
    results[name] = {'pages': len(reader.pages), 'missing_erfe_units': missing,
                     'missing_latin_units': missing_latin, 'all_16_units_extractable': not missing and not missing_latin,
                     'supplementary_UTF16BE_cmap': valid_supplementary}
for name in ('web_diacritics.png', 'flutter_diacritics.png', 'sticker_16_forms.png'):
    with Image.open(OUT / name) as image:
        image.verify()
    with Image.open(OUT / name) as image:
        results[name] = {'format': image.format, 'size': list(image.size), 'valid_png': image.format == 'PNG'}
(OUT / 'export_checks.json').write_text(json.dumps(results, ensure_ascii=True, indent=2) + '\n')
print(json.dumps(results, ensure_ascii=True))
assert all(r.get('all_16_units_extractable', True) and r.get('supplementary_UTF16BE_cmap', True) for r in results.values())
