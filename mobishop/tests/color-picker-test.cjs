const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const source = fs.readFileSync(path.join(__dirname, '../admin/assets/color-picker.js'), 'utf8');
const markup = '<label id="label">Border color <span id="blank"> </span><input id="color" type="color" value="#123456"></label><label for="color" id="external">Color</label><label id="checkLabel"><input type="checkbox" id="check">Enabled</label><input id="text"><button id="save">Save</button>';
function setup() {
  const dom = new JSDOM(markup, {url:'https://builder.example/', runScripts:'outside-only'});
  return {dom, w:dom.window, doc:dom.window.document};
}
test('regression: label whitespace forwards a click before the fix, never after it', () => {
  const {dom,w,doc} = setup(); let opens = 0;
  doc.querySelector('#color').addEventListener('click', () => opens++);
  doc.querySelector('#blank').click(); assert.equal(opens,1);
  w.eval(source);
  for(let i=0;i<4;i++) doc.querySelector('#blank').click();
  doc.querySelector('#external').click(); assert.equal(opens,1);
  doc.querySelector('#color').click(); assert.equal(opens,2);
  dom.window.close();
});
test('outside pointer dismisses focus, while the swatch and unrelated fields retain native behavior', () => {
  const {dom,w,doc} = setup(); w.eval(source);
  const color=doc.querySelector('#color'); color.focus();
  color.dispatchEvent(new w.MouseEvent('pointerdown',{bubbles:true})); assert.equal(doc.activeElement,color);
  doc.querySelector('#blank').dispatchEvent(new w.MouseEvent('pointerdown',{bubbles:true}));
  assert.notEqual(doc.activeElement,color);
  doc.querySelector('#checkLabel').click(); assert.equal(doc.querySelector('#check').checked,true);
  let changes=0; color.addEventListener('change',()=>changes++);
  color.value='#abcdef';color.dispatchEvent(new w.Event('input',{bubbles:true}));color.dispatchEvent(new w.Event('change',{bubbles:true}));
  assert.equal(color.value,'#abcdef');assert.equal(changes,1);
  dom.window.close();
});
test('cached/dynamically loaded editor frames and newly added color fields are covered', async () => {
  const {dom,w,doc} = setup();w.eval(source);w.eval(source);
  const frame=doc.createElement('iframe');doc.body.append(frame);
  await Promise.resolve();
  frame.contentDocument.body.innerHTML=markup;
  frame.dispatchEvent(new w.Event('load'));
  const child=frame.contentDocument,color=child.querySelector('#color');let opens=0;
  color.addEventListener('click',()=>opens++);
  child.querySelector('#blank').click();assert.equal(opens,0);
  color.click();assert.equal(opens,1);
  color.focus();doc.querySelector('#save').dispatchEvent(new w.MouseEvent('pointerdown',{bubbles:true}));
  assert.notEqual(child.activeElement,color);
  child.body.insertAdjacentHTML('beforeend','<label id="new">New<input type="color"></label>');
  child.querySelector('#new input').addEventListener('click',()=>opens++);
  child.querySelector('#new').click();assert.equal(opens,1);
  dom.window.close();
});
