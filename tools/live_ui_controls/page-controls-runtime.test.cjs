'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('jsdom');
const source=fs.readFileSync(require('node:path').join(__dirname,'page-controls.js'),'utf8');
const schema=JSON.parse(fs.readFileSync(require('node:path').join(__dirname,'schema.json'),'utf8'));
const {draftKey}=require('./page-controls.js');
async function fixture(store, draft, screen='account-builder') {
  const dom=new JSDOM('<main class="kidia-central-stage"><iframe data-screen="'+screen+'"></iframe></main>',{url:'https://builder.example/index.html?store='+store,runScripts:'outside-only'});
  const w=dom.window, frame=w.document.querySelector('iframe'), doc=frame.contentDocument;
  doc.body.innerHTML='<form class="mobishop-page-editor"><div class="mobishop-page-settings-card"></div><div class="mobishop-checkout-design-panel"></div><section data-element="logout_button"><div class="mobishop-page-card__body"></div></section></form>';
  if(draft) w.sessionStorage.setItem(draftKey(store,screen),JSON.stringify(draft));
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
  assert.ok(input({'checkout-builder':'cart_layout','catalog-builder':'filters_side_padding','product-builder':'quickadd_button_height'}[screen]||'auth_title_en'));
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
  const cart=await fixture('alpha',null,'checkout-builder');
  const mobile=cart.w.document.createElement('iframe'); mobile.id='kidia-shared-flutter'; cart.w.document.body.append(mobile);
  const navigations=[]; mobile.contentWindow.postMessage=(message,origin)=>navigations.push([JSON.parse(message),origin]);
  for(const page of ['cart','checkout']) cart.frame.contentDocument.querySelector('[data-wm-preview-page="'+page+'"]').click();
  assert.deepEqual(navigations, [
    [{type:'mobishop-preview-navigate',page:'cart'},'https://builder.example'],
    [{type:'mobishop-preview-navigate',page:'checkout'},'https://builder.example'],
  ]);
  assert.equal(cart.writes(),0,'Selecting cart preview must not save or publish');
  assert.equal(cart.input('cart_layout').tagName,'SELECT');
  assert.equal(cart.input('cart_layout').value,'theme');
  assert.equal(cart.input('cart_item_image_radius').value,'');
  assert.equal(cart.input('checkout_address_radius').value,'');
  assert.equal(f.input('orders_detail_image_size').value,'');
  assert.equal(f.input('auth_identifier_hint_en').value,'');
  await cart.w.MobiShopPageControls.save(cart.frame);
  assert.equal(cart.writes(),0,'Inherited sizes must not become edits');
  cart.input('cart_item_image_radius').value='0';
  cart.input('checkout_address_radius').value='0';
  cart.input('checkout_button_height').value='60';
  cart.input('cart_layout').value='compact';
  cart.input('cart_layout').dispatchEvent(new cart.w.Event('change',{bubbles:true}));
  const cartDraft=JSON.parse(cart.w.sessionStorage.getItem(draftKey('alpha','checkout-builder')));
  const cartRestored=await fixture('alpha',cartDraft,'checkout-builder');
  assert.equal(cartRestored.input('cart_item_image_radius').value,'0');
  assert.equal(cartRestored.input('cart_layout').value,'compact');
  await cartRestored.w.MobiShopPageControls.save(cartRestored.frame);
  assert.equal(cartRestored.values().cart_item_image_radius,0);
  assert.equal(cartRestored.values().cart_layout,'compact');
  assert.equal(cartRestored.values().checkout_address_radius,0);
  assert.equal(cartRestored.values().checkout_button_height,60);
  cartRestored.input('cart_layout').value='classic';
  cartRestored.frame.contentDocument.querySelector('form').reset();
  assert.equal(cartRestored.input('cart_layout').value,'compact','Reset restores the saved choice');
  cartRestored.input('cart_item_image_radius').value='';
  await cartRestored.w.MobiShopPageControls.save(cartRestored.frame);
  assert.equal(cartRestored.values().cart_item_image_radius,null,'Clear restores inheritance, not zero');
  assert.equal(cartRestored.input('cart_item_image_radius').value,'');
  for(const [screen,key,value] of [['catalog-builder','filters_side_padding','24'],['product-builder','quickadd_button_height','60'],['checkout-builder','receipt_section_radius','0']]) {
    const extra=await fixture('alpha',null,screen);
    await extra.w.MobiShopPageControls.save(extra.frame);assert.equal(extra.writes(),0);
    extra.input(key).value=value;extra.input(key).dispatchEvent(new extra.w.Event('input',{bubbles:true}));
    assert.equal(extra.w.MobiShopPageControls.decoratePreview(extra.packet).layouts.home.settings.ui_controls_v1[key],Number(value));
    assert.equal(extra.writes(),0,'New control preview must not publish/save');
    await extra.w.MobiShopPageControls.save(extra.frame);assert.equal(extra.values()[key],Number(value));
    extra.input(key).value='';await extra.w.MobiShopPageControls.save(extra.frame);assert.equal(extra.values()[key],null);
    extra.dom.window.close();
  }
  for(const x of [f,restored,other,cart,cartRestored]) x.dom.window.close();
  console.log('PASS live controls load, preview without writes, draft recovery, save cleanup, color normalization and merchant isolation');
})().catch(error=>{console.error(error);process.exitCode=1;});
