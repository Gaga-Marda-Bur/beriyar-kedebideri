"""Verify physical Samsung SM-A336E test proofs (PDF and PNGs) for Erfe Diacritics."""
import json
from pathlib import Path
from PIL import Image
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
CAPTURES_DIR = ROOT / 'docs' / 'qa_diacritics' / 'captures'
MAPPING_FILE = ROOT / 'shared' / 'linguistics' / 'beriya_erfe_transliteration_mapping.json'

mapping_data = json.loads(MAPPING_FILE.read_bytes())
forms = mapping_data['diacritic_letters']

results = {
    'device': 'Samsung SM-A336E (Galaxy A33 5G)',
    'android_version': 'Android 16 (API 36)',
    'serial': 'R6CT6003WRT',
    'package_isolated': 'com.afrigama.beriyarkedebideri.qa_tools',
    'pdf_verification': {},
    'png_verifications': {},
}

# 1. Vérification du PDF généré par l'éditeur sur Samsung
pdf_path = CAPTURES_DIR / 'samsung_erfe_diacritics.pdf'
assert pdf_path.exists(), f"PDF not found: {pdf_path}"

reader = PdfReader(pdf_path)
full_text = '\n'.join(p.extract_text() or '' for p in reader.pages)

missing_erfe = [f['erfe'] for f in forms if f['erfe'] not in full_text]
missing_latin = [f['latin_upper'] for f in forms if f['latin_upper'] not in full_text]

maps = []
for page in reader.pages:
    for font in page.get('/Resources', {}).get('/Font', {}).values():
        obj = font.get_object()
        if '/ToUnicode' in obj:
            maps.append(obj['/ToUnicode'].get_object().get_data().decode('ascii', errors='ignore'))

valid_supplementary_cmap = any('D81BDEA' in m.upper() or 'D81BDEB' in m.upper() for m in maps)

results['pdf_verification'] = {
    'file': pdf_path.name,
    'size_bytes': pdf_path.stat().st_size,
    'page_count': len(reader.pages),
    'missing_erfe_units': missing_erfe,
    'missing_latin_units': missing_latin,
    'all_16_erfe_extractable': len(missing_erfe) == 0,
    'all_16_latin_extractable': len(missing_latin) == 0,
    'supplementary_utf16be_cmap': valid_supplementary_cmap,
    'preview_text_snippet': full_text[:350].strip(),
}

# 2. Vérification des 6 captures et images PNG générées sur Samsung
png_files = [
    'samsung_transliteration_arabic_warning.png',
    'samsung_sticker_diacritics_composed.png',
    'samsung_sticker_diacritics.png',
    'samsung_editor_diacritics.png',
    'samsung_font_16_forms.png',
    'samsung_no_ena_check.png',
]

for png_name in png_files:
    png_path = CAPTURES_DIR / png_name
    assert png_path.exists(), f"PNG missing: {png_path}"
    with Image.open(png_path) as img:
        img.verify()
    with Image.open(png_path) as img:
        results['png_verifications'][png_name] = {
            'format': img.format,
            'size': list(img.size),
            'mode': img.mode,
            'size_bytes': png_path.stat().st_size,
            'valid_png': img.format == 'PNG',
        }

analysis_out = ROOT / 'docs' / 'qa_diacritics' / 'samsung_proofs_analysis.json'
analysis_out.write_text(json.dumps(results, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

print(json.dumps(results, indent=2, ensure_ascii=False))

# Assertions strictes
assert results['pdf_verification']['all_16_erfe_extractable'], f"Erfe units missing: {missing_erfe}"
assert results['pdf_verification']['all_16_latin_extractable'], f"Latin units missing: {missing_latin}"
assert results['pdf_verification']['supplementary_utf16be_cmap'], "Supplementary UTF-16BE CMap missing in PDF"
assert all(v['valid_png'] for v in results['png_verifications'].values()), "Invalid PNG found"
print("\n>>> ALL PHYSICAL SAMSUNG PROOF CHECKS PASSED SUCCESSFULLY! <<<")
