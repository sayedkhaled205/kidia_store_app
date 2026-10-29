const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const fs=require('node:fs');
for(const lang of ['en','ar']) {
  const dom=new JSDOM(`<html lang="${lang}"><main><label>Destination<select name="push_destination"><option value="home">Home</option><option value="collection">Collection</option><option value="category">Category</option><option value="url">URL</option></select></label><label>ID<input name="push_destination_id"></label></main></html>`,{runScripts:'outside-only'});
  dom.window.eval(fs.readFileSync(__dirname+'/push-destinations.js','utf8'));
  const {document,Event}=dom.window, root=document.querySelector('main'), api=dom.window.MobiShopPushDestinations;
  const payload={store:{category_items:[{id:1,name:'Kids',parent:0},{id:2,name:'Baby',parent:1}]},push_home_blocks:[{name:'NEW ARRIVAL',settings:{action_type:'collection',action_value:'latest'}},{name:'Unsafe',settings:{action_type:'url',action_value:'javascript:alert(1)'}}]};
  api.mount(root,payload);
  let select=root.querySelector('[data-push-ready-destination]');
  assert(select.textContent.includes('Kids / Baby'));assert(select.textContent.includes('NEW ARRIVAL'));assert(!select.textContent.includes('Unsafe'));
  const category=Array.from(select.options).find(o=>o.text==='Kids / Baby');
  select.value=category.value; select.dispatchEvent(new Event('change'));
  assert.equal(root.querySelector('[name=push_destination]').value,'category');assert.equal(root.querySelector('[name=push_destination_id]').value,'2');
  api.mount(root,payload);assert.equal(select.value,category.value);assert.equal(root.querySelectorAll('[data-push-ready-destination]').length,1);
  select.value='category';select.dispatchEvent(new Event('change'));assert.equal(root.querySelector('[name=push_destination_id]').closest('label').hidden,false);
  const page=Array.from(select.options).find(o=>o.dataset.destination==='categories');select.value=page.value;select.dispatchEvent(new Event('change'));assert.equal(root.querySelector('[name=push_destination]').value,'categories');
  dom.window.close();
}
console.log('Named destinations: Arabic/English, parent paths, shortcuts, saved selection and custom fallback passed.');
