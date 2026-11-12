"""Exact transliteration, never translation. Unknown scalars are preserved and reported."""
import unicodedata
from .transliteration_data import DATA

SCRIPTS = ('erfe', 'latin', 'arabic')
ROWS = DATA['rows']
ALIASES = {row[1]: row[0] for row in ROWS if len(row[1]) == 1}
TO_ERFE = {
    'erfe': {r[0]: r[0] for r in ROWS},
    'latin': {r[i]: r[0] for r in ROWS for i in (2, 3)},
    'arabic': {r[4]: r[0] for r in ROWS if r[4] is not None},
}


def normalize_erfe(text):
    return unicodedata.normalize('NFC', ''.join(ALIASES.get(c, c) for c in text))


def in_ranges(codepoint, ranges):
    return any(start <= codepoint <= end for start, end in ranges)


def text_units(text):
    """Base + following combining marks; never fall back to a partial letter."""
    index = 0
    while index < len(text):
        end = index + 1
        while end < len(text) and in_ranges(ord(text[end]), DATA['combining_ranges']):
            end += 1
        yield index, text[index:end]
        index = end


def transliterate(text, source_script, target_script, *, latin_lowercase=False):
    if source_script not in SCRIPTS or target_script not in SCRIPTS:
        raise ValueError('Script must be erfe, latin or arabic')
    target_index = {'erfe': 0, 'latin': 3 if latin_lowercase else 2, 'arabic': 4}[target_script]
    target = {r[0]: r[target_index] for r in ROWS}
    output, unmapped = [], []
    for index, unit in text_units(normalize_erfe(text)):
        canonical = TO_ERFE[source_script].get(unit)
        mapped = target.get(canonical)
        if mapped is not None:
            output.append(mapped)
        else:
            output.append(unit)
            if len(unit) != 1 or not in_ranges(ord(unit), DATA['passthrough_ranges']):
                item = {'character': unit, 'codepoint': ' '.join(f'U+{ord(c):04X}' for c in unit), 'index': index}
                if canonical is not None and target_script == 'arabic':
                    item['reason'] = 'missing_arabic_mapping'
                unmapped.append(item)
    return {'text': unicodedata.normalize('NFC', ''.join(output)), 'unmapped': unmapped}
