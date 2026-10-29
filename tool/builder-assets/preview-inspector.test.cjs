const {test}=require('node:test');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const fs=require('node:fs');
const source=fs.readFileSync(__dirname+'/preview-inspector.js','utf8');
function setup(page='home',markup='') {
  const dom=new JSDOM('<iframe id="kidia-shared-flutter"></iframe><iframe id="kidia-central-frame"></iframe>',{url:'https://builder.example/',runScripts:'outside-only'});
  const w=dom.window, editor=w.document.getElementById('kidia-central-frame'), phone=w.document.getElementById('kidia-shared-flutter');
  editor.dataset.screen=page==='splash'?'splash':page+'-builder';
  const doc=editor.contentDocument;
  doc.body.innerHTML=markup || '<div class="mobishop-builder-block is-collapsed" data-library-id="products"><input class="mobishop-block-id" value="products-42"><div class="mobishop-builder-block__header"><button class="mobishop-toggle-block-settings" aria-expanded="false"></button></div><div class="mobishop-builder-block__body"><input id="draft" value="Unsaved title"></div></div>';
  let clicks=0, changes=0, scrolls=[]; doc.addEventListener('click',()=>clicks++); doc.addEventListener('change',()=>changes++);
  editor.contentWindow.HTMLElement.prototype.scrollIntoView=function(){scrolls.push(this);};
  w.eval(source);
  const send=(value,opts={})=>w.dispatchEvent(new w.MessageEvent('message',{origin:'https://builder.example',source:phone.contentWindow,data:JSON.stringify({type:'mobishop-preview-edit',page,target:'products-42',...value}),...opts}));
  return {dom,w,editor,phone,doc,send,scrolls,counts:()=>({clicks,changes})};
}
test('exact stable block opens without changing unsaved values or forwarding center clicks',()=>{
  const s=setup(); s.send();
  const card=s.doc.querySelector('.mobishop-builder-block');
  assert.equal(card.classList.contains('is-collapsed'),false);
  assert.equal(card.querySelector('button').getAttribute('aria-expanded'),'true');
  assert.equal(s.doc.querySelector('#draft').value,'Unsaved title');
  assert.deepEqual(s.counts(),{clicks:0,changes:0});
  assert.equal(s.scrolls[0],card); s.dom.window.close();
});
test('repeated instance IDs select exact recommendation and open header subsection',()=>{
  const s=setup('wishlist','<section class="mobishop-page-card" data-element="products_recommendations" data-instance-id="first"><div class="mobishop-page-card__body" hidden></div></section><section class="mobishop-page-card" data-element="products_recommendations" data-instance-id="second"><div class="mobishop-page-card__body" hidden></div></section><section class="mobishop-page-card" data-chrome-part="header"><div class="mobishop-page-card__body" hidden><details><section data-item-section="cart">Cart controls</section></details></div></section>');
  s.send({target:'second'}); assert.equal(s.doc.querySelector('[data-instance-id="first"]>div').hidden,true);
  assert.equal(s.doc.querySelector('[data-instance-id="second"]>div').hidden,false);
  s.send({target:'header',item:'cart'});
  assert.equal(s.doc.querySelector('details').open,true);
  assert.equal(s.scrolls.at(-1).dataset.itemSection,'cart');
  assert.deepEqual(s.counts(),{clicks:0,changes:0}); s.dom.window.close();
});
test('rejects wrong origins, inactive frames, invalid pages and malformed targets',()=>{
  const s=setup();
  s.send({}, {origin:'https://evil.example'}); s.send({}, {source:s.editor.contentWindow});
  s.send({page:'setup'}); s.send({target:null}); s.send({item:'cart]'});
  assert.equal(s.scrolls.length,0); s.dom.window.close();
});
test('waits for requested editor; later selection wins without reloading the phone',async()=>{
  const s=setup(); let requested=[];
  s.w.addEventListener('mobishop:preview-edit-page',e=>requested.push(e.detail.screen));
  const runtime=s.phone;
  s.send({page:'category',target:'category'});
  s.send({page:'catalog',target:'product_grid'});
  s.editor.dataset.screen='catalog-builder';
  s.doc.body.innerHTML='<section class="mobishop-page-card" data-element="product_grid"><div class="mobishop-page-card__body" hidden></div></section>';
  await new Promise(r=>setTimeout(r,150));
  assert.deepEqual(requested,['category-builder','catalog-builder']);
  assert.equal(s.doc.querySelector('.mobishop-page-card__body').hidden,false);
  assert.equal(s.w.document.getElementById('kidia-shared-flutter'),runtime);
  s.dom.window.close();
});
