const fs=require('fs');const crypto=require('crypto');const path=require('path');
const {chromium}=require('C:/Users/MONSTER/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const page=await browser.newPage({viewport:{width:390,height:844}});
 const response=await page.goto('http://127.0.0.1:8766/parcours/unite-2-ta/');
 if(response.status()!==200)throw Error('Django page failed');
 await page.evaluate(()=>document.fonts.ready);
 const client=await page.context().newCDPSession(page);await client.send('DOM.enable');await client.send('CSS.enable');
 const doc=await client.send('DOM.getDocument');const node=await client.send('DOM.querySelector',{nodeId:doc.root.nodeId,selector:'h1'});
 const fonts=await client.send('CSS.getPlatformFontsForNode',{nodeId:node.nodeId});
 if(!fonts.fonts.some(f=>f.familyName==='Kedebideri'&&f.isCustomFont))throw Error('Erfe font not rendered');
 const refs=JSON.parse(fs.readFileSync(path.join(__dirname,'../phase6_reprise/PHASE6_VERIFICATIONS.json'),'utf8')).fonts;
 const http=[];
 for(const ref of refs){
  const r=await page.request.get('http://127.0.0.1:8766/static/webapp/fonts/'+path.basename(ref.path));
  const digest=crypto.createHash('sha256').update(await r.body()).digest('hex');
  if(r.status()!==200||digest!==ref.sha256)throw Error('Font changed');
  http.push({font:path.basename(ref.path),http:r.status(),sha256_equal:true});
 }
 await page.screenshot({path:path.join(__dirname,'typography_http.png'),fullPage:true});
 fs.writeFileSync(path.join(__dirname,'TYPOGRAPHY_HTTP_RESULTS.json'),JSON.stringify({http:response.status(),fonts:fonts.fonts,font_http:http},null,2));
 await browser.close();console.log('Real HTTP typography: six binary checks and actual rendered font OK');
})();
