"""Build experimental SIL OFL 1.1 derivative font BeriyaNotoSansArabicProto-Regular.ttf in docs/qa_arabic_diacritics/fonts/."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = Path(__file__).resolve().parents[2]
FONTS = Path(__file__).resolve().parent / 'fonts'

ar_font = TTFont(ROOT / 'mobile/assets/fonts/NotoSansArabic-Regular.ttf')
lat_font = TTFont(ROOT / 'mobile/assets/fonts/NotoSans-Regular.ttf')

# Rename font family & unique ID cleanly (SIL OFL 1.1 compliance)
for rec in ar_font['name'].names:
    if rec.nameID in (1, 3, 4, 6):
        val = rec.toUnicode()
        new_val = (
            val.replace('Noto Sans Arabic', 'Beriya Arabic Proto')
            .replace('NotoSansArabic', 'BeriyaArabicProto')
            .replace(';GOOG;', ';BERIYA;')
        )
        rec.string = new_val.encode(rec.getEncoding())

lat_cmap = lat_font.getBestCmap()
ar_cmap = ar_font.getBestCmap()
ar_glyph_order = list(ar_font.getGlyphOrder())

# Ensure post format 2.0 or 3.0 handles new glyphs cleanly
marks_to_add = [
    (0x0300, 'bk_gravecomb'),
    (0x0301, 'bk_acutecomb'),
    (0x0304, 'bk_macroncomb'),
    (0x0307, 'bk_dotabovecomb'),
]

mark_anchors = {}

lat_gset = lat_font.getGlyphSet()

for cp, new_gname in marks_to_add:
    src_gname = lat_cmap[cp]
    # Flatten glyph outline (handles composite glyphs cleanly)
    rec = DecomposingRecordingPen(lat_gset)
    lat_gset[src_gname].draw(rec)
    pen = TTGlyphPen(None)
    rec.replay(pen)
    src_glyph = pen.glyph()
    src_glyph.recalcBounds(ar_font['glyf'])
    xMin, yMin, xMax, yMax = src_glyph.xMin, src_glyph.yMin, src_glyph.xMax, src_glyph.yMax

    # Shift glyph outline horizontally so its center is at x = 0 (prevents dx > xAdvance in PDF text extractors)
    cx_orig = (xMin + xMax) // 2
    if cx_orig != 0:
        from fontTools.pens.transformPen import TransformPen
        trec = DecomposingRecordingPen(lat_gset)
        tpen = TTGlyphPen(None)
        lat_gset[src_gname].draw(trec)
        trec.replay(TransformPen(tpen, (1, 0, 0, 1, -cx_orig, 0)))
        src_glyph = tpen.glyph()
        src_glyph.recalcBounds(ar_font['glyf'])
        xMin, yMin, xMax, yMax = src_glyph.xMin, src_glyph.yMin, src_glyph.xMax, src_glyph.yMax

    cx = (xMin + xMax) // 2
    anchor_y = yMin - 55
    mark_anchors[new_gname] = (cx, anchor_y)

    ar_font['glyf'].glyphs[new_gname] = src_glyph
    ar_font['hmtx'][new_gname] = (0, xMin)
    ar_glyph_order.append(new_gname)

    # Add to all Unicode cmap subtables
    for sub in ar_font['cmap'].tables:
        if sub.isUnicode():
            sub.cmap[cp] = new_gname

    # Set GDEF GlyphClassDef = 3 (Mark)
    ar_font['GDEF'].table.GlyphClassDef.classDefs[new_gname] = 3

ar_font.setGlyphOrder(ar_glyph_order)
ar_font['glyf'].glyphOrder = ar_glyph_order

# Attach all 4 new marks to Class 0 in GPOS Lookup 3 (MarkBasePos)
# Lookup 3 already has Class 0 top anchors on uni0627, uni0622, uni06CC, uni06C6, uni06C7 and their contextual forms!
lookup3 = ar_font['GPOS'].table.LookupList.Lookup[3]
assert lookup3.LookupType == 4
sub3 = lookup3.SubTable[0]

for _, new_gname in marks_to_add:
    cx, cy = mark_anchors[new_gname]
    sub3.MarkCoverage.glyphs.append(new_gname)
    mrec = otTables.MarkRecord()
    mrec.Class = 0
    anch = otTables.Anchor()
    anch.Format = 1
    anch.XCoordinate = cx
    anch.YCoordinate = cy
    mrec.MarkAnchor = anch
    sub3.MarkArray.MarkRecord.append(mrec)
    sub3.MarkArray.MarkCount = len(sub3.MarkArray.MarkRecord)

# Also sort MarkCoverage + MarkRecord in glyphID order (required by OpenType spec!)
glyph_id_map = {g: i for i, g in enumerate(ar_font.getGlyphOrder())}
paired = list(zip(sub3.MarkCoverage.glyphs, sub3.MarkArray.MarkRecord))
paired.sort(key=lambda item: glyph_id_map[item[0]])
sub3.MarkCoverage.glyphs = [p[0] for p in paired]
sub3.MarkArray.MarkRecord = [p[1] for p in paired]
sub3.MarkArray.MarkCount = len(paired)

# Raise Class 0 top anchors on uni06CC / uniFBFD above yMax so marks never sit inside the bowl or collide with the right hook
for gname, new_y in (('uni06CC', 435), ('uniFBFD', 235)):
    if gname in sub3.BaseCoverage.glyphs:
        b_idx = sub3.BaseCoverage.glyphs.index(gname)
        anchor = sub3.BaseArray.BaseRecord[b_idx].BaseAnchor[0]
        if anchor is not None:
            anchor.YCoordinate = new_y

out_ttf = FONTS / 'BeriyaArabicProto-Regular.ttf'
ar_font.save(out_ttf)
print(f'Built experimental font: {out_ttf} ({out_ttf.stat().st_size} bytes)')
