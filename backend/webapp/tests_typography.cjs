const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {execFileSync} = require('node:child_process');
for (const file of ['beriya_keyboard.js', 'sticker_studio.js']) {
  test(`${file}: all assigned Erfe characters select the Erfe style`, () => {
    const relative = `backend/static/webapp/js/${file}`;
    const source = process.env.TYPOGRAPHY_BASELINE === '1'
      ? execFileSync('git', ['show', `4cb8708:${relative}`], {encoding:'utf8'})
      : fs.readFileSync(path.resolve(__dirname, '../static/webapp/js', file), 'utf8');
    // Test the private production predicate without adding a public JS API.
    const predicate = source.match(/function hasBeriya\(text\) \{[\s\S]*?\n    \}/)[0];
    const hasErfe = vm.runInNewContext(`(${predicate})`);
    for (const cp of [...Array.from({length:25},(_,i)=>0x16ea0+i),
                      ...Array.from({length:25},(_,i)=>0x16ebb+i)]) {
      assert.equal(hasErfe(`Beřiya ${String.fromCodePoint(cp)}\u0304`), true, cp.toString(16));
    }
    assert.equal(hasErfe('Beřiya العربية'), false);
    assert.equal(hasErfe('\u{16eb9}'), false);
  });
}
