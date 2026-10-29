const {test}=require('node:test');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const fs=require('node:fs');
test('quick add footer uses normal saved form and does not duplicate controls',()=>{
  const dom=new JSDOM('<form><div class="mobishop-page-field"><label>Shape</label><select name="layout[footer][settings][button_shape]"><option>pill</option></select></div></form>',{runScripts:'outside-only'});
  dom.window.eval(fs.readFileSync(__dirname+'/quick-add-footer-controls.js','utf8'));
  const root=dom.window.document.querySelector('form');
  dom.window.KidiaQuickAddFooter.prepare(root);dom.window.KidiaQuickAddFooter.prepare(root);
  const select=root.querySelector('[name="layout[footer][settings][quick_add_layout]"]');
  assert.equal(select.value,'button');select.value='wishlist_button';
  dom.window.KidiaQuickAddFooter.prepare(root);
  assert.equal(new dom.window.FormData(root).get(select.name),'wishlist_button');
  assert.equal(root.querySelectorAll('select').length,2);
  dom.window.close();
});
