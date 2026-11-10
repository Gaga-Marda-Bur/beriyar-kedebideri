"""Limited, read-only Phase 6 probes. Writes evidence here, never business data.

Uses stdlib SFNT cmap format 4/12 parsing and existing Pillow; no dependency install.
Run from repo root with backend/venv/Scripts/python.exe and PYTHONDONTWRITEBYTECODE=1.
"""
from pathlib import Path
import hashlib
import json
import sqlite3
import struct
import sys
from html.parser import HTMLParser

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
from config.security import resolve_environment
from django.utils.html import format_html
from PIL import Image, ImageDraw, ImageFont


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def font_probe(path):
    data = path.read_bytes()
    u16 = lambda off: struct.unpack_from('>H', data, off)[0]
    u32 = lambda off: struct.unpack_from('>I', data, off)[0]
    tables = {}
    for off in range(12, 12 + 16 * u16(4), 16):
        tag = data[off:off + 4].decode('ascii')
        start, length = u32(off + 8), u32(off + 12)
        assert start + length <= len(data), tag
        tables[tag] = (start, length)
    cmap = {}
    base = tables['cmap'][0]
    formats = set()
    for off in range(base + 4, base + 4 + u16(base + 2) * 8, 8):
        platform, encoding = u16(off), u16(off + 2)
        if not (platform == 0 or platform == 3 and encoding in (1, 10)):
            continue
        sub = base + u32(off + 4)
        fmt = u16(sub)
        formats.add(fmt)
        if fmt == 12:
            for group in range(sub + 16, sub + 16 + u32(sub + 12) * 12, 12):
                first, last, gid = u32(group), u32(group + 4), u32(group + 8)
                for cp in range(first, last + 1):
                    cmap[cp] = gid + cp - first
        elif fmt == 4:
            n = u16(sub + 6) // 2
            ends, starts = sub + 14, sub + 16 + 2 * n
            deltas, ranges = starts + 2 * n, starts + 4 * n
            for i in range(n):
                for cp in range(u16(starts + 2 * i), u16(ends + 2 * i) + 1):
                    delta, ro = u16(deltas + 2 * i), u16(ranges + 2 * i)
                    gid = u16(ranges + 2 * i + ro + 2 * (cp - u16(starts + 2 * i))) if ro else cp
                    cmap[cp] = (gid + delta) % 65536 if gid or not ro else 0
    points = list(range(0x16EA0, 0x16EB9)) + list(range(0x16EBB, 0x16ED4))
    gids = [cmap.get(cp, 0) for cp in points]
    loca, head = tables['loca'][0], tables['head'][0]
    short = u16(head + 50) == 0
    offset = lambda gid: u16(loca + gid * 2) * 2 if short else u32(loca + gid * 4)
    padded = data + b'\0' * (-len(data) % 4)
    checksum = sum(struct.unpack('>' + 'I' * (len(padded) // 4), padded)) & 0xffffffff
    return {
        'path': path.relative_to(ROOT).as_posix(), 'bytes': len(data), 'sha256': sha(path),
        'same_as_mobile': data == (ROOT / 'mobile/assets/fonts' / path.name).read_bytes(),
        'cmap_formats': sorted(formats), 'sfnt_checksum_ok': checksum == 0xB1B0AFBA,
        'erfe_nonzero_glyphs': sum(gid != 0 for gid in gids),
        'erfe_distinct_glyphs': len(set(gids)),
        'erfe_glyphs_with_outline_data': sum(offset(gid + 1) > offset(gid) for gid in gids if gid),
        'combining_and_mixed_coverage': {f'U+{cp:04X}': bool(cmap.get(cp)) for cp in
            (0x0300, 0x0301, 0x0302, 0x0303, 0x0304, 0x0307, 0x25CC, 0x0159, 0x0158, 0x0627)},
        'arabic_block_glyphs': sum(bool(cmap.get(cp)) for cp in range(0x0600, 0x0700)),
    }


db = ROOT / 'backend/db.sqlite3'
before = sha(db)
with sqlite3.connect(db.as_uri() + '?mode=ro', uri=True) as connection:
    connection.execute('PRAGMA query_only=ON')
    rows = connection.execute(
        "SELECT id,slug,title_fr,status FROM learning_learningunit WHERE slug IN ('unite-2-ta','unite-3-de')"
    ).fetchall()
titles = [{'id': row[0], 'slug': row[1], 'title_fr': row[2], 'status': row[3],
           'erfe_codepoints': [f'U+{ord(c):05X}' for c in row[2] if 0x16EA0 <= ord(c) <= 0x16EDF]}
          for row in rows]
fonts = [font_probe(path) for path in sorted((ROOT / 'backend/static/webapp/fonts').glob('Kedebideri-*.ttf'))]
assert len(fonts) == 6
assert all(f['erfe_nonzero_glyphs'] == 50 and f['same_as_mobile'] and f['sfnt_checksum_ok'] for f in fonts)
try:
    resolve_environment({'DJANGO_ENV': 'staging'}.get)
    staging = {'rejected': False}
except Exception as error:
    staging = {'rejected': True, 'exception': type(error).__name__, 'message': str(error)}
try:
    format_html('<b>example</b>')
    admin = {'single_argument_rejected': False}
except Exception as error:
    admin = {'single_argument_rejected': True, 'exception': type(error).__name__, 'message': str(error)}
html = HERE / 'phase6_erfe_typography_diagnostic.html'
HTMLParser().feed(html.read_text(encoding='utf-8'))
# FreeType raster check: this does not test browser fallback, HTTP delivery or Flutter.
image = Image.new('RGB', (1400, 660), '#ffffff')
draw = ImageDraw.Draw(image)
label_font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 16)
draw.text((20, 12), 'Phase 6 - glyph rasterization / Pillow FreeType - not browser or Flutter proof', font=label_font, fill='black')
points = list(range(0x16EA0, 0x16EB9)) + list(range(0x16EBB, 0x16ED4))
for row, info in enumerate(fonts):
    font = ImageFont.truetype(str(ROOT / info['path']), 32)
    draw.text((10, 52 + row * 95), Path(info['path']).stem, font=label_font, fill='black')
    for col, cp in enumerate(points):
        x, y = 230 + col % 25 * 46, 45 + row * 95 + col // 25 * 40
        assert font.getmask(chr(cp)).getbbox() is not None
        draw.text((x, y), chr(cp), font=font, fill='#133d30')
image.save(HERE / 'font_glyphs_freetype.png')
result = {
    'date': '2026-11-10', 'scope': 'limited read-only probes, not production validation',
    'unicode_reference': 'Unicode 17.0; 50 assigned Beria Erfe codepoints',
    'original_report': {'bytes': (HERE / 'PHASE6_RAPPORT_ORIGINAL_2026-11-10.md').stat().st_size,
                        'sha256': sha(HERE / 'PHASE6_RAPPORT_ORIGINAL_2026-11-10.md')},
    'recovered_html': {'bytes': html.stat().st_size, 'sha256': sha(html),
                       'utf8_decodable': True, 'html_parser_completed': True,
                       'browser_render_verified': False, 'uses_absolute_file_font_urls': True},
    'database_before': before, 'database_after': sha(db), 'titles': titles,
    'fonts': fonts, 'staging_probe': staging, 'admin_format_html_probe': admin,
    'freetype': {'rasterized_glyphs': 300, 'browser_or_flutter_test': False},
}
assert result['database_before'] == result['database_after']
(HERE / 'PHASE6_VERIFICATIONS.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'fonts': len(fonts), 'glyphs_per_font': [f['erfe_nonzero_glyphs'] for f in fonts],
                  'source_db_unchanged': before == sha(db), 'staging': staging, 'admin': admin}, ensure_ascii=False))
