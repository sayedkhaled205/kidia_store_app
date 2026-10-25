const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const source = fs.readFileSync(path.join(__dirname, 'category-designer.js'), 'utf8');
function setup() {
  const dom = new JSDOM(`<form><section class="mobishop-category-general"><select name="category_general[category_layout]"><option value="default">Default</option><option value="visual_grid" selected>Old grid</option></select><select name="category_general[navigation_mode]"><option value="separate_page">Separate</option></select><input name="category_general[grid_columns]" value="3"><input name="category_general[card_height]" value="0"><input name="category_general[image_fit]" value="cover"></section><section class="mobishop-category-items"><ul class="mobishop-category-list"><li class="mobishop-category-row" data-term-id="999">Old QA category<input name="categories[999][hidden]" value="0"></li></ul></section></form>`, {url:'https://builder.example/',runScripts:'outside-only'});
  dom.window.eval(source);
  return {dom, w:dom.window, root:dom.window.document.querySelector('form'), api:dom.window.KidiaCategoryDesigner};
}
const catalog = [
  {id:41,name:'Clothing',parent:0,image:'https://shop.example/clothes.jpg'},
  {id:42,name:'Children',parent:41},
  {id:43,name:'Newborn',parent:42},
  {id:44,name:'Home',parent:0},
];
test('captured QA categories cannot leak into another connected merchant', () => {
  const s=setup();s.api.prepare(s.root);
  assert.equal(s.root.querySelectorAll('.mobishop-category-row').length,0);
  s.api.hydrate(s.root,{public_id:'merchant-a',url:'https://shop.example',category_items:catalog});
  assert.deepEqual(Array.from(s.root.querySelectorAll('.mobishop-category-row'),n=>n.dataset.termId),['41','42','43','44']);
  assert.equal(s.root.querySelector('[data-term-id="43"]').parentElement.dataset.parentId,'42');
  assert.equal(s.root.querySelector('[name="categories[999][hidden]"]'),null);
  s.api.hydrate(s.root,{public_id:'merchant-b',category_items:[{id:7,name:'Different shop'}]});
  assert.deepEqual(Array.from(s.root.querySelectorAll('.mobishop-category-row'),n=>n.dataset.termId),['7']);
  s.api.hydrate(s.root,{public_id:'merchant-empty',category_items:[]});
  assert.equal(s.root.querySelectorAll('.mobishop-category-row').length,0);
  s.dom.window.close();
});
test('six visual designs preserve merchant records and navigation preference', () => {
  const s=setup();s.api.prepare(s.root);s.api.hydrate(s.root,{category_items:catalog});
  const buttons=Array.from(s.root.querySelectorAll('.kidia-category-design'));
  assert.equal(buttons.length,6);
  assert.equal(s.root.querySelector('[data-design="visual_grid"]').getAttribute('aria-pressed'),'true');
  const records=()=>Array.from(new s.w.FormData(s.root)).filter(([key])=>key.startsWith('categories['));
  const before=records();
  for(const button of buttons){button.click();assert.equal(s.root.querySelector('[name="category_general[category_layout]"]').value,button.dataset.design);assert.equal(button.getAttribute('aria-pressed'),'true');assert.equal(s.root.querySelector('[name="category_general[navigation_mode]"]').value,'separate_page');assert.deepEqual(records(),before);}
  s.root.querySelector('[data-design="visual_grid"]').click();
  assert.equal(s.root.querySelector('[name="category_general[grid_columns]"]').value,'2');
  assert.equal(s.root.querySelector('[name="category_general[card_height]"]').value,'0');
  assert.equal(s.root.querySelector('[name="category_general[image_fit]"]').value,'contain');
  // A saved state hydration can update the layout before dispatching a change on another field.
  s.root.querySelector('[name="category_general[category_layout]"]').value='sidebar';
  s.root.querySelector('[name="category_general[grid_columns]"]').dispatchEvent(new s.w.Event('change',{bubbles:true}));
  assert.equal(s.root.querySelector('[data-design="sidebar"]').getAttribute('aria-pressed'),'true');
  s.dom.window.close();
});
test('invalid or circular parents and untrusted image URLs stay safe', () => {
  const s=setup();const result=s.api.normalize([{id:1,name:'A',parent:2,image:'javascript:alert(1)'},{id:2,name:'B',parent:1},{id:3,name:'Orphan',parent:999},{id:'bad'}]);
  assert.equal(result.length,3);assert.equal(result[0].parent,0);assert.equal(result[0].image,'');assert.equal(result[2].parent,0);
  s.dom.window.close();
});
