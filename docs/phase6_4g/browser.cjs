const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('C:/Users/MONSTER/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base='http://127.0.0.1:18778',out=__dirname,results=[],errors=[];
(async()=>{
 let browser;
 try{browser=await chromium.launch({channel:'chrome',headless:true});}
 catch(e){fs.writeFileSync(path.join(out,'BROWSER.json'),JSON.stringify({status:'blocked',reason:String(e)},null,2));process.exitCode=1;return;}
 const context=await browser.newContext({viewport:{width:1365,height:900}}),page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));
 const responses=[],origins=new Set();page.on('request',r=>origins.add(new URL(r.url()).origin));page.on('response',r=>{if(r.status()>=400)responses.push({path:new URL(r.url()).pathname,status:r.status()});});
 fs.mkdirSync(path.join(out,'captures'),{recursive:true});
 async function capture(name){await page.screenshot({path:path.join(out,'captures',name+'.png'),fullPage:true});}
 async function run(name,fn){try{results.push({name,status:'passed',proof:await fn()});}catch(e){results.push({name,status:'failed',error:String(e).slice(0,1000)});}}
 async function goto(route){const r=await page.goto(base+route);if(r.status()!==200)throw Error('HTTP '+r.status());await page.evaluate(()=>document.fonts.ready);}
 await run('navigation_desktop',async()=>{await goto('/');await page.locator('a[href="/alphabet/"]').first().click();await page.waitForURL('**/alphabet/');await capture('alphabet_desktop');return{url:page.url()};});
 await run('dictionary_search',async()=>{await goto('/vocabulaire/');const before=await page.locator('.word-card').count();if(!before)throw Error('No published dictionary entries');
   const text=(await page.locator('.word-text').first().innerText()).trim();await page.locator('input[name=q]').fill(text);await page.locator('form.toolbar button[type=submit]').click();await page.waitForLoadState();
   const after=await page.locator('.word-card').count();if(!after)throw Error('Existing entry not found');await capture('dictionary_search');return{before,after,query_from_existing_entry:true};});
 await run('keyboard_erfe',async()=>{await goto('/vocabulaire/');const input=page.locator('input[name=q]');await input.fill('');await input.focus();
   await page.locator('.beriya-keyboard-toggle').click();
   const key=page.locator('.beriya-key:visible').first();const symbol=await key.innerText();await key.click();
   if(await input.inputValue()!==symbol)throw Error('Keyboard insertion failed');
   await page.locator('[data-action=backspace]:visible').click();if(await input.inputValue()!=='')throw Error('Erfe deletion failed');
   await capture('keyboard_erfe');return{actual_click_insert_and_delete:true,unicode_scalars:[...symbol].length};});
 await run('unit_and_lessons',async()=>{await goto('/parcours/');await capture('learning_path');const links=await page.locator('a[href^="/parcours/"]').evaluateAll(a=>a.map(x=>x.getAttribute('href')).filter(h=>h!='/parcours/'));
   if(!links.length)throw Error('No unit links');await goto(links[0]);await capture('unit');return{unit_links:links.length,lesson_sections:await page.locator('.lesson-card,.lesson-item').count()};});
 await run('quiz_javascript',async()=>{await goto('/quiz/');const option=page.locator('.quiz-option-button:visible').first();await option.click();
   if(!await option.evaluate(e=>e.classList.contains('is-selected')))throw Error('Option selection JS failed');await page.locator('.quiz-validate-button:visible').first().click();
   const feedback=await page.locator('.quiz-feedback:visible').first().innerText();if(!feedback.trim())throw Error('Feedback missing');await capture('quiz_feedback');return{selection:true,feedback_displayed:true};});
 await run('audio_real_playback',async()=>{await goto('/vocabulaire/');const button=page.locator('button[data-audio]').first();const src=await button.getAttribute('data-audio');
   if(!src)throw Error('No published audio button');
   await page.evaluate(()=>{window.__audioProof={started:false,ended:false,error:null};const play=HTMLMediaElement.prototype.play;
     HTMLMediaElement.prototype.play=function(){this.addEventListener('timeupdate',()=>window.__audioProof.time=this.currentTime);this.addEventListener('playing',()=>{window.__audioProof.started=true;window.__audioProof.duration=this.duration;});this.addEventListener('ended',()=>window.__audioProof.ended=true);this.addEventListener('error',()=>window.__audioProof.error=this.error?.code);return play.apply(this,arguments);};});
   await button.click();await page.waitForFunction(()=>window.__audioProof.time>0.05||window.__audioProof.error,{},{timeout:12000});
   const proof=await page.evaluate(()=>window.__audioProof);if(!proof.started||proof.error)throw Error(JSON.stringify(proof));await capture('audio_playing');return{...proof,audible_to_human:'not_tested',file_http:(await page.request.get(new URL(src,base).href)).status()};});
 await run('browser_session_csrf_login_logout',async()=>{await goto('/');return await page.evaluate(async()=>{
   const root='/api/monetization/v1/session/';const token=await(await fetch(root+'csrf/')).json();
   const login=await fetch(root+'login/',{method:'POST',headers:{'Content-Type':'application/json','X-CSRFToken':token.csrf_token},body:JSON.stringify({username:'qa64g',password:'synthetic-browser-only'})});
   const identity=await login.json();const status=await fetch(root);const logout=await fetch(root+'logout/',{method:'POST',headers:{'Content-Type':'application/json','X-CSRFToken':identity.csrf_token},body:'{}'});const after=await fetch(root);
   if(login.status!==200||status.status!==200||logout.status!==200||after.status!==401)throw Error('Session flow failed');return{login:login.status,authenticated:status.status,logout:logout.status,after:after.status};});});
 await run('direct_published_unit_and_lesson_content',async()=>{await goto('/parcours/premiers-5-caracteres/');await capture('direct_unit_lesson');return{http:200,lesson_sections:await page.locator('.lesson-card,.lesson-item,.lesson-block').count(),note:'Direct opening does not resolve missing discovery from path index'};});
 await run('responsive_mobile_js_menu',async()=>{await page.setViewportSize({width:390,height:844});await goto('/');const menu=page.locator('.mobile-menu-button');await menu.click();if(await menu.getAttribute('aria-expanded')!=='true')throw Error('Menu did not open');
   await capture('home_mobile_menu');const widths=await page.evaluate(()=>({viewport:innerWidth,document:document.documentElement.scrollWidth}));if(widths.document>widths.viewport+2)throw Error('Horizontal overflow');return{...widths,menu_clicked:true};});
 await run('font_used_by_chrome',async()=>{await goto('/parcours/unite-2-ta/');const cdp=await context.newCDPSession(page);await cdp.send('DOM.enable');await cdp.send('CSS.enable');const doc=await cdp.send('DOM.getDocument');const node=await cdp.send('DOM.querySelector',{nodeId:doc.root.nodeId,selector:'h1'});const fonts=await cdp.send('CSS.getPlatformFontsForNode',{nodeId:node.nodeId});if(!fonts.fonts.some(f=>f.familyName==='Kedebideri'&&f.isCustomFont))throw Error('Kedebideri not actually used');await capture('unit_erfe_mobile');return fonts;});
 await run('theme_preference_light_dark',async()=>{const values=[];for(const scheme of ['light','dark']){await page.emulateMedia({colorScheme:scheme});await goto('/');values.push({scheme,background:await page.locator('html').evaluate(e=>getComputedStyle(e).backgroundColor)});await capture('web_'+scheme);}if(values[0].background===values[1].background)throw Error('Both preferences exercised but no distinct light/dark theme observed');return{values};});
 await run('six_font_weights_http_integrity',async()=>{
  const directory=path.join(__dirname,'../../backend/static/webapp/fonts');
  const names=fs.readdirSync(directory).filter(n=>/^Kedebideri-.*\.ttf$/.test(n));
  if(names.length!==6)throw Error('Expected six font weight files');const files=[];
  for(const name of names){const response=await page.request.get(base+'/static/webapp/fonts/'+name);const digest=crypto.createHash('sha256').update(await response.body()).digest('hex');
    if(response.status()!==200 || digest!==crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,name))).digest('hex'))throw Error('Font delivery mismatch');files.push({name,http:response.status(),sha256:digest});}return files;
 });
 fs.writeFileSync(path.join(out,'BROWSER.json'),JSON.stringify({engine:await browser.version(),real_browser:true,headless:true,base,results,page_errors:errors,http_errors:responses,third_party_origins:[...origins].filter(o=>o!==base)},null,2));
 await browser.close();console.log(JSON.stringify(results.map(r=>({name:r.name,status:r.status}))));
})().catch(e=>{console.error(e);process.exitCode=1;});
