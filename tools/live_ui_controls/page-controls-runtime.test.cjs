'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('jsdom');
const source=fs.readFileSync(require('node:path').join(__dirname,'page-controls.js'),'utf8');
const schema=JSON.parse(fs.readFileSync(require('node:path').join(__dirname,'schema.json'),'utf8'));
const {draftKey}=require('./page-controls.js');
async function fixture(store, draft) {
  const dom=new JSDOM('<main class="kidia-central-stage"><iframe data-screen="account-builder"></iframe></main>',{url:'https://builder.example/index.html?store='+store,runScripts:'outside-only'});
  const w=dom.window, frame=w.document.querySelector('iframe'), doc=frame.contentDocument;
  doc.body.innerHTML='<form class="mobishop-page-editor"><div class="mobishop-page-settings-card"></div><section data-element="logout_button"><div class="mobishop-page-card__body"></div></section></form>';
  if(draft) w.sessionStorage.setItem(draftKey(store,'account-builder'),JSON.stringify(draft));
  let values={},writes=0,refreshes=0;
  w.fetch=async (url,options={})=>{
    if(url.includes('/context')) return {ok:true,headers:{get:()=> 'application/json'},json:async()=>({store,csrf_token:'local-fixture'})};
    if(options.body) {writes++;values=JSON.parse(options.body).controls;}
    return {ok:true,headers:{get:()=> 'application/json'},json:async()=>({schema,values,controls_digest:'fixture'})};
  };
  w.addEventListener('mobishop:page-controls-preview',()=>refreshes++);
  w.eval(source);
  for(let i=0;i<10 && !doc.querySelector('[data-wm-ui-control]');i++) await new Promise(resolve=>setImmediate(resolve));
  const input=key=>doc.querySelector('[data-wm-ui-control="'+key+'"]');
  assert.ok(input('auth_title_en'));
  const packet={page:'account',layouts:{home:{page:'home',settings:{existing:true}},account:{page:'account'}}};
  return {w,dom,frame,input,packet,writes:()=>writes,refreshes:()=>refreshes,values:()=>values};
}
(async()=>{
  const f=await fixture('alpha');
  assert.ok(f.refreshes()>0,'Async initial load refreshes preview');
  await f.w.MobiShopPageControls.save(f.frame);
  assert.equal(f.writes(),0,'Untouched colors must not count as edits');
  f.input('auth_title_en').value='Draft title';
  f.input('auth_title_en').dispatchEvent(new f.w.Event('input',{bubbles:true}));
  const key=draftKey('alpha','account-builder');
  const draft=JSON.parse(f.w.sessionStorage.getItem(key));
  assert.deepEqual(draft.changed,{auth_title_en:'Draft title'});
  const packet=f.w.MobiShopPageControls.decoratePreview(f.packet);
  assert.equal(packet.layouts.home.settings.ui_controls_v1.auth_title_en,'Draft title');
  assert.equal(packet.layouts.home.settings.existing,true);
  assert.equal(f.writes(),0,'Preview must not save merchant settings');
  const restored=await fixture('alpha',draft);
  assert.equal(restored.input('auth_title_en').value,'Draft title');
  await restored.w.MobiShopPageControls.save(restored.frame);
  assert.equal(restored.writes(),1);
  assert.equal(restored.values().auth_title_en,'Draft title');
  assert.equal(restored.w.sessionStorage.getItem(key),null);
  const other=await fixture('beta');
  assert.equal(other.input('auth_title_en').value,'');
  for(const x of [f,restored,other]) x.dom.window.close();
  console.log('PASS live controls load, preview without writes, draft recovery, save cleanup, color normalization and merchant isolation');
})().catch(error=>{console.error(error);process.exitCode=1;});
