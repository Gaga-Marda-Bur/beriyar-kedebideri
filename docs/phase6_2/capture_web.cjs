// Uses the existing bundled Playwright; no project dependency added.
const { chromium } = require('C:/Users/MONSTER/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const stage = process.argv[2];
  const out = path.resolve(__dirname, 'captures'); fs.mkdirSync(out, {recursive:true});
  const browser = await chromium.launch({headless:true, channel:'chrome'});
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const fonts=[];
  page.on('response', r => {if(r.url().endsWith('.ttf'))fonts.push({url:r.url(),status:r.status(),type:r.headers()['content-type']});});
  const response=await page.goto('http://127.0.0.1:8766/parcours/unite-2-ta/');
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({path:path.join(out,`django_${stage}.png`),fullPage:true});
  const title=await page.locator('h1').first().evaluate(el=>({text:el.textContent,font:getComputedStyle(el).fontFamily}));
  // Inspect the engine's actual rendered fonts, not just computed CSS.
  const cdp=await page.context().newCDPSession(page);
  await cdp.send('DOM.enable'); await cdp.send('CSS.enable');
  const doc=await cdp.send('DOM.getDocument');
  const node=await cdp.send('DOM.querySelector',{nodeId:doc.root.nodeId,selector:'h1'});
  const rendered=await cdp.send('CSS.getPlatformFontsForNode',{nodeId:node.nodeId});
  if(response.status()!==200) throw new Error('Not a successful Django page');
  fs.writeFileSync(path.join(out,`web_${stage}.json`),JSON.stringify({http:response.status(),title,fonts,rendered},null,2));
  if(stage==='after') {
    await page.evaluate(() => {
      const points=[...Array.from({length:25},(_,i)=>0x16ea0+i),...Array.from({length:25},(_,i)=>0x16ebb+i)];
      const main=document.querySelector('main'); main.replaceChildren();
      for(const weight of [400,500,600,700,800,900]) {
        const block=document.createElement('p'); block.style.cssText=`font-weight:${weight};font-size:26px;padding:12px;overflow-wrap:anywhere`;
        block.textContent=`QA ${weight} — Beřiya — العربية\n`+String.fromCodePoint(...points)+'\n𖺠̄ 𖺣̄ 𖺧̄ 𖺯̄ 𖺶̄';main.append(block);
      }
      const rtl=document.createElement('p');rtl.dir='rtl';rtl.style.fontSize='26px';
      rtl.textContent='العربية (𖺵̄) Beřiya';main.append(rtl);
    });
    await page.evaluate(()=>document.fonts.ready);
    await page.screenshot({path:path.join(out,'web_grid_after.png'),fullPage:true});
    for(const name of ['Regular','Medium','SemiBold','Bold','ExtraBold','Black']) {
      const r=await page.request.get(`http://127.0.0.1:8766/static/webapp/fonts/Kedebideri-${name}.ttf`);
      if(r.status()!==200)throw new Error(`Font HTTP ${name}`);
    }
    fs.writeFileSync(path.join(out,'web_font_http.json'),JSON.stringify(fonts,null,2));
    await page.goto('http://127.0.0.1:8766/editeur/');
    await page.locator('#editorTitle').fill('Beřiya 𖺵');
    await page.locator('#editorBody').fill('𖺠̄ 𖺣̄ 𖺧̄ 𖺯̄ 𖺶̄\nالعربية — Beřiya 𖺢');
    await page.evaluate(()=>document.fonts.ready);
    await page.screenshot({path:path.join(out,'editor_mixed_after.png'),fullPage:true});
    const download=page.waitForEvent('download',{timeout:30000});
    await page.locator('#exportPdfBtn').click();
    await (await download).saveAs(path.join(out,'web_export_after.pdf'));
    const image=page.waitForEvent('download',{timeout:30000});
    await page.locator('#exportImageBtn').click();
    await (await image).saveAs(path.join(out,'web_image_export_after.png'));
  }
  await browser.close();
})();
