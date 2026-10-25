const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const source = fs.readFileSync(path.join(__dirname, 'preview-interactions.js'), 'utf8');
function setup() {
  const dom = new JSDOM('<iframe id="kidia-central-frame" src="?screen=home-builder"></iframe><iframe id="kidia-shared-flutter" src="?page=home"></iframe>', {
    url: 'https://builder.example/index.html', runScripts: 'outside-only'
  });
  const w = dom.window, editor = w.document.getElementById('kidia-central-frame');
  const preview = w.document.getElementById('kidia-shared-flutter');
  editor.contentDocument.write('<html><body></body></html>');
  preview.contentDocument.write('<html><body></body></html>');
  editor.contentDocument.body.innerHTML = '<div class="mobishop-builder-block" data-library-id="hero-4"><div class="blank">Hero</div><input value="Title"><button>Remove</button></div>';
  preview.contentDocument.body.innerHTML = '<div id="surface"></div><input id="search">';
  preview.contentDocument.documentElement.setAttribute('data-preview-route', '/');
  const messages = [];
  preview.contentWindow.postMessage = (data, origin) => messages.push({data: JSON.parse(data), origin});
  w.eval(source);
  return {dom, w, editor, preview, messages};
}
test('selected home card reaches shared Flutter with its exact stable ID', () => {
  const s = setup();
  s.editor.contentDocument.dispatchEvent(new s.w.CustomEvent('mobishop:home-preview-focus', {detail: {target: 'banner-42'}}));
  assert.deepEqual(s.messages, [{data: {type: 'mobishop-preview-focus', page: 'home', target: 'banner-42'}, origin: 'https://builder.example'}]);
  s.dom.window.close();
});
test('blank card area selects; controls and existing header handler are not duplicated', () => {
  const s = setup(), doc = s.editor.contentDocument;
  doc.querySelector('.blank').click();
  assert.equal(s.messages[0].data.target, 'hero-4');
  doc.querySelector('input').click(); doc.querySelector('button').click();
  assert.equal(s.messages.length, 1);
  s.dom.window.close();
});
test('cached inactive editor cannot move the current preview', () => {
  const s = setup(); s.editor.id = 'cached-home';
  s.editor.contentDocument.dispatchEvent(new s.w.CustomEvent('mobishop:home-preview-focus', {detail: {target: 'hero'}}));
  assert.equal(s.messages.length, 0); s.dom.window.close();
});
test('card navigation returns from a mobile route before focusing; runtime is retained', async () => {
  const s = setup();
  s.preview.contentDocument.documentElement.setAttribute('data-preview-route', '/account');
  s.editor.contentDocument.dispatchEvent(new s.w.CustomEvent('mobishop:home-preview-focus', {detail: {target: 'hero'}}));
  assert.equal(s.messages[0].data.type, 'mobishop-preview-navigate');
  await new Promise(resolve => setTimeout(resolve, 280));
  assert.equal(s.messages[1].data.target, 'hero');
  assert.equal(s.w.document.getElementById('kidia-shared-flutter'), s.preview);
  s.dom.window.close();
});
test('wheel remains native on home and other routes; keys only scroll Home outside fields', () => {
  const s = setup(), doc = s.preview.contentDocument;
  for (const route of ['/', '/products', '/account', '/auth']) {
    doc.documentElement.setAttribute('data-preview-route', route);
    const wheel = new s.w.WheelEvent('wheel', {deltaY: 80, bubbles: true, cancelable: true});
    doc.getElementById('surface').dispatchEvent(wheel);
    assert.equal(wheel.defaultPrevented, false);
  }
  const down = () => new s.w.KeyboardEvent('keydown', {key: 'ArrowDown', bubbles: true, cancelable: true});
  doc.getElementById('surface').dispatchEvent(down());
  assert.equal(s.messages.length, 0);
  doc.documentElement.setAttribute('data-preview-route', '/');
  doc.getElementById('search').dispatchEvent(down());
  assert.equal(s.messages.length, 0);
  doc.getElementById('surface').dispatchEvent(down());
  assert.equal(s.messages[0].data.deltaY, 72);
  s.dom.window.close();
});
test('preview shell does not swallow wheel events based on stale initial page', () => {
  for (const file of ['web/index.html', 'mobishop/admin/flutter-preview/index.html']) {
    const html = fs.readFileSync(path.join(__dirname, '../..', file), 'utf8');
    assert.doesNotMatch(html, /document\.addEventListener\('wheel'/);
  }
});
