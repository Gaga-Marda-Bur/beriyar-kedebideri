"""Exact transliteration, never translation. Unknown scalars are preserved and reported."""
import unicodedata
from .transliteration_data import DATA

SCRIPTS = ('erfe', 'latin', 'arabic')
ROWS = DATA['rows']
ALIASES = {row[1]: row[0] for row in ROWS}
TO_ERFE = {
    'erfe': {r[0]: r[0] for r in ROWS},
    'latin': {r[i]: r[0] for r in ROWS for i in (2, 3)},
    'arabic': {r[4]: r[0] for r in ROWS},
}


def normalize_erfe(text):
    return unicodedata.normalize('NFC', ''.join(ALIASES.get(c, c) for c in text))


def transliterate(text, source_script, target_script, *, latin_lowercase=False):
    if source_script not in SCRIPTS or target_script not in SCRIPTS:
        raise ValueError('Script must be erfe, latin or arabic')
    target_index = {'erfe': 0, 'latin': 3 if latin_lowercase else 2, 'arabic': 4}[target_script]
    target = {r[0]: r[target_index] for r in ROWS}
    output, unmapped = [], []
    for index, char in enumerate(normalize_erfe(text)):
        canonical = TO_ERFE[source_script].get(char)
        if canonical is not None:
            output.append(target[canonical])
        else:
            output.append(char)
            if not any(start <= ord(char) <= end for start, end in DATA['passthrough_ranges']):
                unmapped.append({'character': char, 'codepoint': f'U+{ord(char):04X}', 'index': index})
    return {'text': unicodedata.normalize('NFC', ''.join(output)), 'unmapped': unmapped}
