const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(__dirname + '/live-design-publish.js', 'utf8');
const flush = () => new Promise(resolve => setImmediate(resolve));

function deferred() {
  let resolve;
  const promise = new Promise(res => { resolve = res; });
  return { promise, resolve };
}

function setup({ withBridge = true } = {}) {
  const elements = new Map(), requests = [], timers = new Map();
  let timerId = 0;
  class Element {
    constructor() { this.children = new Map(); this.events = {}; this.style = {}; this.dataset = {}; this.hidden = false; this.open = false; }
    append(child) { if (child.id) elements.set(child.id, child); }
    setAttribute() {}
    querySelector(selector) { if (!this.children.has(selector)) this.children.set(selector, new Element()); return this.children.get(selector); }
    addEventListener(type, fn) { this.events[type] = fn; }
    click() { if (!this.disabled) return this.events.click?.(); }
    showModal() { this.open = true; }
    close() { this.open = false; }
  }
  const document = {head:new Element(),body:new Element(),createElement:()=>new Element(),getElementById:id=>elements.get(id),querySelector:()=>new Element()};
  const location = {href:'https://builder.test/?store=store-a'};
  const api = {
    state:{ready:true,has_changes:true,revision:7,draft_digest:'draft-a'}, post:null,
    dirty: 0, inspectError: null, beginError: null, saveError: null, assertError: null,
    inspectCalls: [], beginCalls: [], saveCalls: [], assertCalls: [], releaseCalls: [],
    beginWait: null, saveWait: null,
  };
  const bridge = {
    async inspect(store) {
      api.inspectCalls.push(store);
      if (api.inspectError) throw api.inspectError;
      return { dirtyCount: api.dirty };
    },
    async begin(store) {
      api.beginCalls.push(store);
      if (api.beginWait) await api.beginWait.promise;
      if (api.beginError) throw api.beginError;
      let released = false;
      return {
        async save() {
          api.saveCalls.push(store);
          if (api.saveWait) await api.saveWait.promise;
          if (api.saveError) throw api.saveError;
          if (api.onSave) api.onSave();
        },
        assertCurrent() {
          api.assertCalls.push(store);
          if (api.assertError) throw api.assertError;
        },
        release() { if (!released) { released = true; api.releaseCalls.push(store); } },
      };
    },
  };
  const context = {document,location,URL,AbortController,setTimeout:fn=>{timers.set(++timerId,fn);return timerId;},clearTimeout:id=>timers.delete(id),fetch:async(url,options)=>{
    requests.push({url,options});
    if (options.method === 'POST' && api.post) return api.post(url, options);
    if (options.method === 'GET' && url.includes('/live-design?') && api.failGet) return {ok:false,status:500};
    return {ok:true,json:async()=>url.includes('/context?') ? {store:'store-a',csrf_token:'fixture-csrf'} : {...api.state}};
  }, window: withBridge ? {MobiShopPublishEdits: bridge} : {}};
  vm.runInNewContext(source, context);
  const dialog = elements.get('wm-design-dialog');
  return {api,requests,timers,location,dialog,open:()=>elements.get('wm-publish-design').click(),publish:dialog.querySelector('[data-action=publish]'),cancel:dialog.querySelector('[data-action=close]'),status:dialog.querySelector('[data-status]'),title:dialog.querySelector('h2'),icon:dialog.querySelector('[data-icon]')};
}

test('Cancel closes confirmation without publishing', async () => {
  const ui = setup(); ui.open(); await flush();
  assert.equal(ui.title.textContent, 'Update app?');
  assert.equal(ui.publish.textContent, 'Update now');
  assert.equal(ui.status.hidden, true);
  ui.cancel.click();
  assert.equal(ui.dialog.open, false);
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.api.beginCalls.length, 0);
  assert.equal(ui.api.saveCalls.length, 0);
});

test('Update sends the protected snapshot once, then shows Complete and auto closes', async () => {
  const ui = setup(); let finish;
  ui.api.post = () => new Promise(resolve=>{finish=resolve;});
  ui.open(); await flush();
  ui.publish.click(); ui.publish.click();
  await flush();
  assert.equal(ui.dialog.dataset.phase, 'updating');
  assert.equal(ui.cancel.disabled, true);
  assert.equal(ui.api.beginCalls.length, 1);
  assert.equal(ui.api.saveCalls.length, 1);
  const posts = ui.requests.filter(r=>r.options.method==='POST');
  assert.equal(posts.length, 1);
  assert.deepEqual(JSON.parse(posts[0].options.body), {store:'store-a',revision:7,draft_digest:'draft-a'});
  assert.equal(posts[0].options.headers['X-CSRF-TOKEN'], 'fixture-csrf');
  let blocked = false; ui.dialog.events.cancel({preventDefault(){blocked=true;}});
  assert.equal(blocked, true);
  finish({ok:true,json:async()=>({...ui.api.state,has_changes:false,revision:8})}); await flush();
  assert.equal(ui.title.textContent, 'Complete'); assert.equal(ui.icon.textContent, '✓');
  assert.equal(ui.dialog.open, true);
  assert.equal(ui.api.releaseCalls.length, 1);
  for (const callback of ui.timers.values()) callback();
  assert.equal(ui.dialog.open, false);
});

test('A failed update stays open and rechecks the server before retrying a POST', async () => {
  const ui = setup(); ui.api.post = async()=>({ok:false,status:500});
  ui.open(); await flush(); ui.publish.click(); await flush();
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.equal(ui.publish.disabled, false); assert.equal(ui.publish.textContent, 'Try again');
  assert.equal(ui.timers.size, 0); assert.equal(ui.dialog.open, true);
  // The server may have committed the update despite losing its response.
  ui.api.state.has_changes = false;
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 1);
  assert.equal(ui.status.textContent, 'Up to date');
  assert.equal(ui.publish.disabled, true);
});

test('Conflicting edits retain the server revision check and require a fresh snapshot', async () => {
  const ui = setup(); ui.api.post = async()=>({ok:false,status:409});
  ui.open(); await flush(); ui.publish.click(); await flush();
  assert.match(ui.status.textContent, /التعديلات اتغيرت/);
  ui.api.state.revision = 9; ui.api.state.draft_digest = 'draft-b';
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 1);
  ui.api.post = null; ui.publish.click(); await flush();
  assert.deepEqual(JSON.parse(ui.requests.at(-1).options.body), {store:'store-a',revision:9,draft_digest:'draft-b'});
});

test('Incomplete and unchanged designs cannot publish', async () => {
  for (const state of [{ready:false,has_changes:true},{ready:true,has_changes:false}]) {
    const ui = setup(); Object.assign(ui.api.state,state); ui.open(); await flush(); ui.publish.click();
    assert.equal(ui.publish.disabled, true);
    assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  }
});

test('Closing a loading dialog ignores its pending response; another store cannot submit', async () => {
  const ui = setup(); ui.open(); ui.cancel.click(); await flush();
  assert.equal(ui.dialog.open, false); assert.equal(ui.dialog.dataset.phase, 'loading');
  ui.open(); await flush(); ui.location.href = 'https://builder.test/?store=store-b'; ui.publish.click();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
});

test('An old completion timer cannot close a freshly opened dialog', async () => {
  const ui = setup(); ui.open(); await flush(); ui.publish.click(); await flush();
  const oldTimer = [...ui.timers.values()][0];
  ui.dialog.events.cancel({preventDefault(){}}); ui.dialog.close();
  ui.open(); await flush(); oldTimer();
  assert.equal(ui.dialog.open, true);
});

test('Local draft edits across two unsaved pages can publish even when the server has no saved changes', async () => {
  const ui = setup();
  ui.api.dirty = 2;
  Object.assign(ui.api.state, {ready: false, has_changes: false, revision: 7, draft_digest: 'draft-a'});
  ui.open(); await flush();
  assert.equal(ui.publish.disabled, false);
  ui.publish.click();
  await flush();
  assert.equal(ui.api.beginCalls.length, 1);
  assert.equal(ui.api.saveCalls.length, 1);
});

test('A save failure blocks the request before any POST and surfaces the bridge error', async () => {
  const ui = setup();
  ui.api.dirty = 1;
  ui.api.saveError = new Error('فشل حفظ التعديلات.');
  ui.open(); await flush();
  assert.equal(ui.publish.disabled, false);
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.equal(ui.status.textContent, 'فشل حفظ التعديلات.');
  assert.equal(ui.api.releaseCalls.length, 1);
});

test('Missing publish-edits bridge fails closed with no network calls', async () => {
  const ui = setup({ withBridge: false });
  ui.open(); await flush();
  assert.equal(ui.requests.length, 0);
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.equal(ui.publish.textContent, 'Try again');
  ui.publish.click(); await flush();
  assert.equal(ui.requests.length, 0);
});

test('After saving, the update is sent with the freshly fetched revision and digest', async () => {
  const ui = setup();
  ui.api.dirty = 1;
  Object.assign(ui.api.state, {ready: false, has_changes: false, revision: 7, draft_digest: 'draft-a'});
  // The bridge's save persists the dirty editors; the server now reports a new saved revision.
  ui.api.onSave = () => Object.assign(ui.api.state, {ready: true, has_changes: true, revision: 8, draft_digest: 'draft-b'});
  ui.open(); await flush();
  assert.equal(ui.publish.disabled, false);
  ui.publish.click(); await flush();
  const posts = ui.requests.filter(r=>r.options.method==='POST');
  assert.equal(posts.length, 1);
  assert.deepEqual(JSON.parse(posts[0].options.body), {store:'store-a', revision: 8, draft_digest: 'draft-b'});
  assert.equal(ui.api.releaseCalls.length, 1);
});

test('A clean result after saving finishes without a POST', async () => {
  const ui = setup();
  ui.open(); await flush();
  assert.equal(ui.publish.disabled, false);
  ui.api.state = {ready: true, has_changes: false, revision: 7, draft_digest: 'draft-a'};
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.dialog.dataset.phase, 'complete');
  assert.equal(ui.api.releaseCalls.length, 1);
});

test('A still-incomplete design after saving is blocked with a helpful message and no POST', async () => {
  const ui = setup();
  ui.api.dirty = 1;
  Object.assign(ui.api.state, {ready: false, has_changes: false});
  ui.open(); await flush();
  assert.equal(ui.publish.disabled, false);
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.match(ui.status.textContent, /احفظ كل الصفحات/);
  assert.equal(ui.api.releaseCalls.length, 1);
});

test('A begin() rejection surfaces an error without acquiring a lock to release', async () => {
  const ui = setup();
  ui.api.beginError = new Error('تعذر قفل المحرر.');
  ui.open(); await flush();
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.equal(ui.status.textContent, 'تعذر قفل المحرر.');
  assert.equal(ui.api.releaseCalls.length, 0);
});

test('A rejected fresh snapshot after saving still releases the lock with no POST', async () => {
  const ui = setup();
  ui.open(); await flush();
  ui.api.failGet = true;
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.equal(ui.api.releaseCalls.length, 1);
});

test('A store switch mid-save releases the lock and blocks the stale submission', async () => {
  const ui = setup();
  ui.api.saveWait = deferred();
  ui.open(); await flush();
  assert.equal(ui.publish.disabled, false);
  ui.publish.click();
  await flush();
  ui.location.href = 'https://builder.test/?store=store-b';
  ui.api.saveWait.resolve();
  await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 0);
  assert.equal(ui.api.releaseCalls.length, 1);
  assert.equal(ui.dialog.open, false);
});

test('Double-clicking Update sends exactly one POST', async () => {
  const ui = setup();
  ui.open(); await flush();
  ui.publish.click(); ui.publish.click(); ui.publish.click();
  await flush();
  assert.equal(ui.requests.filter(r=>r.options.method==='POST').length, 1);
  assert.equal(ui.api.beginCalls.length, 1);
});

test('Timed-out publication releases editors, then retry only rechecks server state', async () => {
  const ui = setup(); ui.open(); await flush();
  ui.api.post = (url, options) => new Promise((resolve, reject) => options.signal.addEventListener('abort', () => reject(Error('aborted'))));
  ui.publish.click(); await flush();
  for (const timer of [...ui.timers.values()]) timer();
  await flush();
  assert.equal(ui.dialog.dataset.phase, 'error');
  assert.equal(ui.api.releaseCalls.length, 1);
  ui.api.state.has_changes = false;
  ui.publish.click(); await flush();
  assert.equal(ui.requests.filter(r => r.options.method === 'POST').length, 1);
  assert.equal(ui.status.textContent, 'Up to date');
});
