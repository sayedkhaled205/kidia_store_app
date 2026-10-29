const {test}=require('node:test');
const assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const fs=require('node:fs');
test('shared appearance is a normal checked and unchecked saved field, mounted once',()=>{
  const dom=new JSDOM('<form><section data-element="product_grid"><div class="mobishop-page-field"><label>Card style</label><select name="layout[elements][1][settings][card_style]"><option>outlined</option></select></div></section></form>',{runScripts:'outside-only'});
  dom.window.eval(fs.readFileSync(__dirname+'/shared-product-card-controls.js','utf8'));
  const root=dom.window.document.querySelector('form');
  dom.window.KidiaSharedProductCard.prepare(root);dom.window.KidiaSharedProductCard.prepare(root);
  const input=root.querySelector('[type=checkbox]');
  assert.equal(root.querySelectorAll('[type=checkbox]').length,1);
  assert.deepEqual(new dom.window.FormData(root).getAll(input.name),['0']);
  input.checked=true;
  assert.deepEqual(new dom.window.FormData(root).getAll(input.name),['0','1']);
  dom.window.close();
});
