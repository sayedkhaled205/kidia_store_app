const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const source = fs.readFileSync(path.join(__dirname, 'product-outline.js'), 'utf8');
function setup(style = 'outlined', type = 'product_grid') {
  const dom = new JSDOM(`<form><section data-element="${type}"><div class="mobishop-page-field"><label>Card style</label><select name="layout[elements][1][settings][card_style]"><option>outlined</option><option>minimal</option><option>elevated</option><option>no_shadow</option></select></div></section></form>`, {runScripts:'outside-only'});
  dom.window.eval(source);
  const root = dom.window.document.querySelector('form');
  root.querySelector('select').value = style;
  dom.window.KidiaProductOutline.prepare(root, {primary_color:'#347A89'});
  return {dom, root, select:root.querySelector('select'), field:root.querySelector('input')};
}
test('outline field uses merchant brand and is included in normal saved form', () => {
  const {dom,root,field} = setup();
  assert.equal(field.value, '#347a89');
  assert.equal(field.closest('[data-product-outline-field]').hidden, false);
  assert.equal(new dom.window.FormData(root).get(field.name), '#347a89');
  dom.window.close();
});
test('other styles hide the control without losing custom color', () => {
  const {dom,root,select,field} = setup();
  field.value = '#dc713a'; field.dispatchEvent(new dom.window.Event('change',{bubbles:true}));
  for (const style of ['minimal','elevated','no_shadow','outlined']) {
    select.value = style; select.dispatchEvent(new dom.window.Event('change',{bubbles:true}));
    assert.equal(field.closest('[data-product-outline-field]').hidden, style !== 'outlined');
    assert.equal(field.value, '#dc713a');
  }
  dom.window.KidiaProductOutline.prepare(root,{primary_color:'#abcdef'});
  assert.equal(field.value, '#dc713a');
  assert.equal(root.querySelectorAll('input').length,1);
  dom.window.close();
});
test('saved custom color hydrates and remains after default preparation', () => {
  const {dom,root,field} = setup();
  field.value = '#102938'; field.dispatchEvent(new dom.window.Event('change',{bubbles:true}));
  dom.window.KidiaProductOutline.prepare(root,{primary_color:'#347A89'});
  assert.equal(new dom.window.FormData(root).get(field.name),'#102938');
  dom.window.close();
});
test('does not add product controls to account summary', () => {
  const {dom,field} = setup('outlined','account_summary');
  assert.equal(field,null); dom.window.close();
});
