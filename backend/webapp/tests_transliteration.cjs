const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const engine = require('../static/webapp/js/transliteration.js');
const source = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../shared/linguistics/beriya_erfe_transliteration_mapping.json')));
const vectors = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../shared/linguistics/transliteration_vectors.json')));
test('cross-platform reference vectors', () => {
    for (const v of vectors) assert.deepEqual(engine.transliterate(v.input, v.source, v.target, v.lowercase), v.expected, v.name);
});
test('all lower Erfe aliases, NFC and round trips', () => {
    for (const r of source.letters) {
        assert.equal(engine.normalize_erfe(r.erfe_lower_alias), r.erfe);
        for (const s of ['latin', 'arabic']) {
            const value = engine.transliterate(r.erfe, 'erfe', s).text;
            assert.equal(engine.transliterate(value, s, 'erfe').text, r.erfe);
        }
    }
    assert.equal(engine.normalize_erfe('𖺻𖺼𖺽'), '𖺠𖺡𖺢');
    assert.throws(() => engine.transliterate('A', 'auto', 'erfe'));
});
test('all 16 diacritics Erfe -> Arabic -> Erfe and 8-item regression', () => {
    for (const r of source.diacritic_letters) {
        const ar = engine.transliterate(r.erfe, 'erfe', 'arabic');
        assert.equal(ar.text, r.arabic);
        assert.deepEqual(ar.unmapped, []);
        const back = engine.transliterate(ar.text, 'arabic', 'erfe');
        assert.equal(back.text, r.erfe);
        assert.deepEqual(back.unmapped, []);
    }
    const sample =
        '𖺯̄𖺩𖺩𖺧𖺸𖺠 𖺡𖺣𖺲𖺧𖺸𖺠𖺱 𖺩𖺣𖺢𖺣𖺡𖺧𖺢𖺣𖺲𖺧 𖺩𖺧̄𖺸𖺧𖺱 𖺩𖺧𖺸𖺣 𖺢𖺧𖺢𖺧 𖺩𖺧̄ 𖺣𖺱 𖺨𖺧𖺸𖺧 𖺣𖺥𖺯 𖺬𖺠𖺢𖺠𖺬𖺢𖺣𖺣 𖺣𖺢𖺧.\n\n' +
        '1. 𖺢𖺧𖺡𖺯 𖺥𖺥𖺠𖺱𖺢𖺧\n2. 𖺫𖺯̄𖺥𖺯𖺷\n3. 𖺫𖺠𖺦𖺠\n4. 𖺦𖺠𖺥𖺠\n' +
        '5. 𖺠𖺱𖺥𖺠𖺬𖺠\n6. 𖺦𖺣𖺸𖺥𖺯\n7. 𖺵𖺧𖺩𖺵𖺯𖺩\n8. 𖺥𖺠𖺱𖺢𖺧';
    const expected =
        'ۆ̄ككیيا بآڕیيار كآدآبیدآڕی كی̄يیر كیيآ دیدی كی̄ آر جیيی آقۆ ناداندآآ آدی.\n\n' +
        '1. دیبۆ ققاردی\n2. مۆ̄قۆو\n3. ماها\n4. هاقا\n' +
        '5. ارقانا\n6. هآيقۆ\n7. تیكتۆك\n8. قاردی';
    const res = engine.transliterate(sample, 'erfe', 'arabic');
    assert.equal(res.text, expected);
    assert.deepEqual(res.unmapped, []);
    assert.equal(Array.from(res.text).some(c => c.codePointAt(0) >= 0x16EA0 && c.codePointAt(0) <= 0x16EDF), false);
    const back = engine.transliterate(expected, 'arabic', 'erfe');
    assert.equal(back.text, sample);
    assert.deepEqual(back.unmapped, []);
});
