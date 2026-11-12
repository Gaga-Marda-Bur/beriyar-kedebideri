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
