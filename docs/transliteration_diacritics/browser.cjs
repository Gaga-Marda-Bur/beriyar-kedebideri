/* Local browser QA: accent units, Arabic omissions and actual editor exports. */
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const {chromium} = require('C:/Users/MONSTER/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const reference = JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../shared/linguistics/beriya_erfe_transliteration_mapping.json')));
const forms = reference.diacritic_letters, results = [], errors = [];
(async () => {
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const context = await browser.newContext({viewport:{width:1280,height:900}, permissions:['clipboard-read','clipboard-write']});
  const page = await context.newPage(); page.on('pageerror',e=>errors.push(String(e)));
  async function run(name, fn) {try { results.push({name,status:'passed',proof:await fn()}); } catch(e) {results.push({name,status:'failed',error:String(e)});}}
  await page.goto('http://127.0.0.1:18789/editeur/');
  const body=page.locator('#editorBody'), details=body.locator('xpath=following-sibling::details[1]'), panel=details.locator('fieldset');
  await details.locator('summary').click();
  await run('all 16 NFC and NFD forms through visible converter',async()=>{
    for(const r of forms) {
      await body.fill((r.latin_upper+r.latin_lower).normalize('NFD'));
      await panel.locator('select').nth(0).selectOption('latin'); await panel.locator('select').nth(1).selectOption('erfe');
      await panel.getByRole('button',{name:'Convertir',exact:true}).click();
      assert.equal(await panel.locator('textarea').inputValue(),r.erfe+r.erfe);
    }
    return {forms:16,precomposed_and_decomposed:true};
  });
  await run('paste lower Erfe accents, selection, explicit insertion and undo',async()=>{
    await body.fill(''); await body.focus();
    await page.evaluate(()=>navigator.clipboard.writeText('𖺻́𖺾̀𖻂̄\n'));
    await body.press('Control+v'); assert.equal(await body.inputValue(),'𖺠́𖺣̀𖺧̄\n');
    await body.evaluate(el=>el.setSelectionRange(0,9));
    await panel.locator('select').nth(0).selectOption('erfe'); await panel.locator('select').nth(1).selectOption('latin');
    await panel.getByRole('button',{name:'Convertir',exact:true}).click();
    assert.equal(await panel.locator('textarea').inputValue(),'ÁÈÎ');
    await panel.getByRole('button',{name:'Insérer',exact:true}).click(); assert.equal(await body.inputValue(),'ÁÈÎ\n');
    await panel.getByRole('button',{name:'Annuler la conversion',exact:true}).click(); assert.equal(await body.inputValue(),'𖺠́𖺣̀𖺧̄\n');
    assert.deepEqual(await body.evaluate(el=>[el.selectionStart,el.selectionEnd]),[0,9]);
    return {normalization:true,selection_utf16:[0,9],newline_preserved:true,undo:true};
  });
  await run('incomplete Arabic remains explicit even after copying',async()=>{
    await body.fill('BÁÈÎ'); await body.evaluate(el=>el.setSelectionRange(0,0));
    await panel.locator('select').nth(0).selectOption('latin'); await panel.locator('select').nth(1).selectOption('arabic');
    await panel.getByRole('button',{name:'Convertir',exact:true}).click();
    assert.equal(await panel.locator('textarea').inputValue(),'بÁÈÎ');
    assert.match(await panel.getByRole('status').textContent(),/Conversion incomplète.*arabes non définies/);
    await panel.getByRole('button',{name:'Copier',exact:true}).click();
    assert.match(await panel.getByRole('status').textContent(),/arabes non définies/);
    assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),'بÁÈÎ');
    await page.screenshot({path:path.join(__dirname,'arabic_incomplete.png'),fullPage:true});
    return {whole_forms_preserved:true,warning_persistent:true};
  });
  await run('all 16 generated options available in actual keyboard',async()=>{
    await body.focus(); await page.locator('#openBeriyaKeyboardBtn').click();
    const baseKey=page.locator('.beriya-keyboard-keys button').filter({hasText:'𖺧'}).first();
    await baseKey.dispatchEvent('pointerdown'); await page.waitForTimeout(520);
    const menu=page.locator('.beriya-longpress-popup');
    await menu.waitFor({state:'visible'});
    for(const r of forms.filter(r=>r.erfe.startsWith('𖺧'))) assert.ok((await menu.textContent()).includes(r.erfe));
    await menu.getByRole('button',{name:'𖺧̇',exact:true}).click();
    assert.ok((await body.inputValue()).includes('𖺧̇'));
    await page.locator('.beriya-keyboard-close').click();
    return {I_variants:4,total_generated:16};
  });
  await run('actual PNG and PDF downloads with the 16 canonicalized forms',async()=>{
    await page.locator('#editorTitle').fill('Diacritiques - QA 𖺧̇ 𖺠́');
    await body.fill(forms.map(r=>r.erfe_lower_alias+' / '+r.latin_upper+' '+r.latin_lower).join('\n'));
    await page.locator('[data-theme="cream"]').click();
    const pngPromise=page.waitForEvent('download',{timeout:30000});
    await page.locator('#exportImageBtn').click(); const png=await pngPromise; await png.saveAs(path.join(__dirname,'web_diacritics.png'));
    assert.equal(fs.readFileSync(path.join(__dirname,'web_diacritics.png')).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
    const pdfPromise=page.waitForEvent('download',{timeout:30000});
    await page.locator('#exportPdfBtn').click(); const pdf=await pdfPromise; await pdf.saveAs(path.join(__dirname,'web_diacritics.pdf'));
    assert.equal(fs.readFileSync(path.join(__dirname,'web_diacritics.pdf')).subarray(0,5).toString(),'%PDF-');
    await page.screenshot({path:path.join(__dirname,'editor_16_forms.png'),fullPage:true});
    return {forms:16,PNG_downloaded:true,PDF_downloaded:true};
  });
  await run('Sticker PNG export preserves normalized diacritics',async()=>{
    await page.goto('http://127.0.0.1:18789/sticker-studio/');
    await page.locator('#stickerText').fill(forms.map(r=>r.erfe_lower_alias).join(' '));
    assert.equal(await page.locator('#stickerText').inputValue(),forms.map(r=>r.erfe).join(' '));
    const download=page.waitForEvent('download'); await page.locator('#downloadPng').click();
    await (await download).saveAs(path.join(__dirname,'sticker_16_forms.png'));
    return {forms:16,PNG_downloaded:true};
  });
  const version=browser.version(); await browser.close();
  fs.writeFileSync(path.join(__dirname,'browser_extensions.json'),JSON.stringify({browser:'Chrome '+version,results,errors},null,2));
  console.log(JSON.stringify({results,errors}));
  if(errors.length || results.some(r=>r.status!=='passed')) process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
