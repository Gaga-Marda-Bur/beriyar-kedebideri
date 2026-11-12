/* Real Chrome interaction against local isolated Django, never a remote site. */
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/MONSTER/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const out = __dirname, results = [], errors = [];
(async () => {
  let browser;
  try { browser = await chromium.launch({channel: 'chrome', headless: true}); }
  catch(e) { fs.writeFileSync(path.join(out,'browser_results.json'), JSON.stringify({status:'blocked', error:String(e)},null,2)); process.exitCode=1; return; }
  const context = await browser.newContext({viewport:{width:1280,height:900}, permissions:['clipboard-read','clipboard-write']});
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(String(e)));
  async function run(name, fn) {
    try {results.push({name,status:'passed',proof:await fn()});}
    catch(e) {results.push({name,status:'failed',error:String(e)});}
  }
  await page.goto('http://127.0.0.1:18789/editeur/');
  const body = page.locator('#editorBody');
  const details = body.locator('xpath=following-sibling::details[1]');
  await details.locator('summary').click();
  const panel = details.locator('fieldset');
  await run('historical draft read does not rewrite local storage', async () => {
    const legacy = JSON.stringify({title:'𖺻',content:'𖺼',theme:'cream',alignment:'left',fontSize:24});
    await page.evaluate(raw => localStorage.setItem('beriya_editor_draft',raw),legacy);
    await page.reload(); await page.waitForTimeout(650);
    assert.equal(await body.inputValue(),'𖺡');
    assert.equal(await page.evaluate(() => localStorage.getItem('beriya_editor_draft')),legacy);
    await details.locator('summary').click();
    return {display:'canonical',storage:'unchanged'};
  });
  await run('HTTP fonts and converter scripts', async () => {
    await page.evaluate(() => document.fonts.ready);
    assert.equal(await panel.count(),1);
    assert.equal(await page.evaluate(() => document.fonts.check('24px Kedebideri', '𖺠𖺡𖺢')),true);
    return {converter:1,font_loaded:true};
  });
  await run('paste lower Erfe, multiline and native undo', async () => {
    await body.fill(''); await body.focus();
    await page.evaluate(() => navigator.clipboard.writeText('𖺻𖺼𖺽\n😀 123'));
    await body.press('Control+v');
    await page.waitForTimeout(100);
    assert.equal(await body.inputValue(),'𖺠𖺡𖺢\n😀 123');
    const selection = await body.evaluate(el => [el.selectionStart,el.selectionEnd]);
    await body.press('Control+z');
    assert.equal(await body.inputValue(),'');
    return {paste:'canonical',selection,undo:'restored'};
  });
  await run('selected Latin conversion, insertion and explicit undo', async () => {
    await body.fill('ABD\nABD');
    await body.evaluate(el => el.setSelectionRange(0,3));
    await panel.locator('select').nth(0).selectOption('latin');
    await panel.locator('select').nth(1).selectOption('erfe');
    await panel.getByRole('button',{name:'Convertir',exact:true}).click();
    assert.equal(await panel.locator('textarea').inputValue(),'𖺠𖺡𖺢');
    assert.match(await panel.locator('textarea').evaluate(el => getComputedStyle(el).fontFamily), /Kedebideri/);
    await page.screenshot({path:path.join(out,'web_erfe_conversion.png'),fullPage:true});
    assert.equal(await body.inputValue(),'ABD\nABD');
    await panel.getByRole('button',{name:'Insérer',exact:true}).click();
    assert.equal(await body.inputValue(),'𖺠𖺡𖺢\nABD');
    await panel.getByRole('button',{name:'Annuler la conversion',exact:true}).click();
    assert.equal(await body.inputValue(),'ABD\nABD');
    return {selection_only:true,conversion_explicit:true,undo:true};
  });
  await run('virtual keyboard canonical insertion and native undo', async () => {
    await body.fill(''); await body.focus();
    await page.locator('#openBeriyaKeyboardBtn').click();
    const key = page.locator('.beriya-keyboard-keys button').filter({hasText:/[\u{16EA0}-\u{16ED3}]/u}).first();
    await key.click();
    assert.ok((await body.inputValue()).length > 0);
    assert.ok(!/[\u{16EBB}-\u{16ED3}]/u.test(await body.inputValue()));
    await body.press('Control+z');
    assert.equal(await body.inputValue(),'');
    await page.locator('.beriya-keyboard-close').click();
    return {canonical:true,native_undo:true};
  });
  await run('strict Arabic, RTL, unknown report, copy and mobile', async () => {
    await body.fill('AEG IY 😀');
    await body.evaluate(el => el.setSelectionRange(0,0));
    await panel.locator('select').nth(1).selectOption('arabic');
    await panel.getByRole('button',{name:'Convertir',exact:true}).click();
    assert.equal(await panel.locator('textarea').inputValue(),'اآق یي 😀');
    assert.equal(await panel.locator('textarea').getAttribute('dir'),'rtl');
    assert.match(await panel.getByRole('status').textContent(),/U\+1F600/);
    await panel.getByRole('button',{name:'Copier',exact:true}).click();
    assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),'اآق یي 😀');
    await page.screenshot({path:path.join(out,'web_converter_desktop.png'),fullPage:true});
    await page.setViewportSize({width:390,height:844});
    await page.screenshot({path:path.join(out,'web_converter_mobile.png'),fullPage:true});
    const size=await page.evaluate(()=>({viewport:innerWidth,document:document.documentElement.scrollWidth}));
    assert.ok(size.document <= size.viewport+2);
    return size;
  });
  await run('sticker uses normalized text and explicit converter', async () => {
    await page.goto('http://127.0.0.1:18789/sticker-studio/');
    await page.locator('#stickerText').fill('𖺻𖺼𖺽');
    assert.equal(await page.locator('#stickerText').inputValue(),'𖺠𖺡𖺢');
    await page.screenshot({path:path.join(out,'web_sticker.png'),fullPage:true});
    return {canonical:true};
  });
  await browser.close();
  fs.writeFileSync(path.join(out,'browser_results.json'),JSON.stringify({browser:'Chrome headless real DOM',results,errors},null,2));
  console.log(JSON.stringify({results,errors}));
  if(errors.length || results.some(r=>r.status!=='passed')) process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
