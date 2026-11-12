"""Read-only workbook/source cross-check using XLSX XML (no spreadsheet rewriting)."""
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as E
import zipfile

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('workbook', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    source = ROOT / 'shared/linguistics/beriya_erfe_transliteration_mapping.json'
    data = json.loads(source.read_bytes())
    digest = hashlib.sha256(args.workbook.read_bytes()).hexdigest()
    assert digest == data['source_sha256'], 'Workbook SHA does not match supplied JSON'
    ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with zipfile.ZipFile(args.workbook) as z:
        shared = [''.join(t.itertext()) for t in E.fromstring(z.read('xl/sharedStrings.xml'))]
        rows = []
        for row in E.fromstring(z.read('xl/worksheets/sheet1.xml')).findall('.//s:row', ns):
            values = []
            for cell in row:
                v = cell.find('s:v', ns)
                if v is not None:
                    values.append(shared[int(v.text)] if cell.get('t') == 's' else v.text)
            rows.append(values)
    for r in data['letters']:
        assert [r[k] for k in ('erfe', 'latin_upper', 'latin_lower', 'arabic')] in rows
        assert [r[k] for k in ('erfe_lower_alias', 'latin_lower')] in rows
    report = {'workbook_name': args.workbook.name, 'workbook_sha256': digest,
              'declared_source_sha256_matches': True, 'canonical_rows_verified': 25,
              'lowercase_rows_verified': 25, 'json_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
    encoded = json.dumps(report, indent=2) + '\n'
    if args.output:
        args.output.write_text(encoded, encoding='utf-8')
    print(encoded)
