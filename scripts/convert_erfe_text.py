"""Explicit UTF-8 import/export. Never overwrites a file or writes the database."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from core.transliteration import normalize_erfe, transliterate

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('input', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--source', choices=['erfe', 'latin', 'arabic'])
    p.add_argument('--target', choices=['erfe', 'latin', 'arabic'])
    p.add_argument('--latin-lowercase', action='store_true')
    args = p.parse_args()
    if bool(args.source) != bool(args.target):
        p.error('--source and --target must be specified together')
    with args.input.open(encoding='utf-8', newline='') as src:
        text = src.read()
    result = transliterate(text, args.source, args.target, latin_lowercase=args.latin_lowercase) if args.source else {'text': normalize_erfe(text), 'unmapped': []}
    with args.output.open('x', encoding='utf-8', newline='') as dest:
        dest.write(result['text'])
    print(json.dumps({'output': str(args.output), 'unmapped': result['unmapped']}, ensure_ascii=True))
