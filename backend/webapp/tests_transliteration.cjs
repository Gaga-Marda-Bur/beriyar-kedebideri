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
        '1. 𖺯̄ 𖺧̄ !\n2. 𖺡𖺯̄𖺵 , 𖺡𖺧̄𖺵 ;\n3. 𖺠́ 𖺣̀ 𖺧̄ 𖺯̄ .\n4. 𖺶̄ 𖺠̄ 𖺣̄ ?\n' +
        '5. 𖺧̇ 𖺠̀ 𖺣́ :\n6. 𖺧̀ 𖺧́ 𖺶̀ 𖺶́ !\n7. 𖺯̀ 𖺯́ (𖺯̄ / 𖺧̄)\n8. 𖻊̄ 𖻂̄ — fin.';
    const expected =
        '1. \u06C6\u0304 \u06CC\u0304 !\n2. \u0628\u06C6\u0304\u062A , \u0628\u06CC\u0304\u062A ;\n' +
        '3. \u0627\u0301 \u0622\u0300 \u06CC\u0304 \u06C6\u0304 .\n4. \u06C7\u0304 \u0627\u0304 \u0622\u0304 ?\n' +
        '5. \u06CC\u0307 \u0627\u0300 \u0622\u0301 :\n6. \u06CC\u0300 \u06CC\u0301 \u06C7\u0300 \u06C7\u0301 !\n' +
        '7. \u06C6\u0300 \u06C6\u0301 (\u06C6\u0304 / \u06CC\u0304)\n8. \u06C6\u0304 \u06CC\u0304 — fin.';
    const res = engine.transliterate(sample, 'erfe', 'arabic');
    assert.equal(res.text, expected);
    assert.equal(Array.from(res.text).some(c => c.codePointAt(0) >= 0x16EA0 && c.codePointAt(0) <= 0x16EDF), false);
});
