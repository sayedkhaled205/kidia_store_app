const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { JSDOM, VirtualConsole } = require('jsdom');
const results = [];
const settle = async () => { for (let i = 0; i < 8; i++) await new Promise(setImmediate); };
function environment(kind = 'anonymous', handler = async () => ({ exists: true }), scripts = ['login.js', 'kidia-shared-auth.js']) {
  const dom = new JSDOM(fs.readFileSync(path.join(__dirname, `fixture-${kind}.html`), 'utf8'), {
    url: 'https://example.test/login-register/?redirect_to=%2Fcheckout%2F', runScripts: 'outside-only', virtualConsole: new VirtualConsole()
  });
  const w = dom.window, calls = [], timers = new Map();
  let timerId = 100000;
  const originalTimer = w.setTimeout.bind(w), originalClear = w.clearTimeout.bind(w);
  w.setTimeout = (fn, ms, ...args) => {
    if (ms >= 1000) { const id = ++timerId; timers.set(id, { fn: () => fn(...args), ms }); return id; }
    return originalTimer(fn, ms, ...args);
  };
  w.clearTimeout = id => { timers.delete(id); originalClear(id); };
  w.AbortController = AbortController;
  w.KidiaLogin = { nonce: 'fixture', ajaxUrl: '/ajax', loginUrl: '/login-register/', homeUrl: '/' };
  w.KidiaSharedAuth = { nonce: 'fixture', ajaxUrl: '/ajax', loginUrl: '/login-register/', logoutUrl: '/logout' };
  w.fetch = async (url, options) => {
    const data = Object.fromEntries(new URLSearchParams(options.body)); calls.push(data);
    const response = await handler(data, options);
    return { ok: true, json: async () => response && response.success !== undefined ? response : { success: true, data: response } };
  };
  for (const file of scripts) w.eval(fs.readFileSync(path.join(__dirname, 'website', file), 'utf8'));
  return { w, calls, timers, close: () => w.close(), expire: async ms => {
    for (const [id, timer] of [...timers]) if (timer.ms <= ms) { timers.delete(id); timer.fn(); }
    await settle();
  }};
}
const input = (e, selector, value) => { const field = e.w.document.querySelector(selector); assert.ok(field, selector); field.value = value; return field; };
const submit = (e, selector) => e.w.document.querySelector(selector).dispatchEvent(new e.w.Event('submit', { bubbles: true, cancelable: true }));
const visibleStage = e => [...e.w.document.querySelectorAll('[data-kidia-stage]')].find(node => !node.hidden)?.dataset.kidiaStage;
async function test(name, fn) { try { await fn(); results.push({ name, passed: true }); } catch (error) { results.push({ name, passed: false, error: error.message }); } }
async function using(kind, handler, fn, scripts) { const e = environment(kind, handler, scripts); try { await fn(e); } finally { e.close(); } }
(async () => {
  for (const exists of [false, true]) await test(`email ${exists ? 'login' : 'signup'} fields and normalized identifier`, () => using('anonymous', async () => ({ exists }), async e => {
    input(e, '#kidia-identifier', 'Customer@Example.test'); submit(e, '.kidia-identifier-form'); await settle();
    assert.equal(visibleStage(e), 'email'); assert.equal(e.calls[0].email, 'customer@example.test');
    assert.equal(e.w.document.querySelector('[name="kidia_name"]').disabled, exists);
    assert.equal(e.w.document.querySelector('[name="kidia_password_confirm"]').disabled, exists);
  }));
  await test('email lookup network failure retains password and signup alternatives', () => using('anonymous', async () => { throw Error('offline'); }, async e => {
    input(e, '#kidia-identifier', 'customer@example.test'); submit(e, '.kidia-identifier-form'); await settle();
    assert.equal(visibleStage(e), 'email'); assert.equal(e.w.document.querySelector('.kidia-identifier-form button').disabled, false);
    e.w.document.querySelector('[data-kidia-switch-mode]').click(); assert.equal(e.w.document.querySelector('[name="kidia_name"]').disabled, false);
  }));
  await test('email lookup hanging network is bounded and remains usable', () => using('anonymous', (data, options) => new Promise((resolve, reject) => {
    options.signal?.addEventListener('abort', () => reject(Error('aborted')));
  }), async e => {
    input(e, '#kidia-identifier', 'customer@example.test'); submit(e, '.kidia-identifier-form'); await settle(); await e.expire(15000);
    assert.equal(visibleStage(e), 'email'); assert.equal(e.w.document.querySelector('.kidia-identifier-form button').disabled, false);
  }));
  await test('late lookup cannot reopen a cancelled flow', () => {
    let release; return using('anonymous', () => new Promise(resolve => { release = resolve; }), async e => {
      input(e, '#kidia-identifier', 'customer@example.test'); submit(e, '.kidia-identifier-form'); await settle();
      e.w.document.querySelector('[data-kidia-back]').click(); release({ exists: false }); await settle();
      assert.equal(visibleStage(e), 'identifier');
    });
  });
  await test('duplicate identifier submission sends only one pending lookup', () => {
    let release; return using('anonymous', () => new Promise(resolve => { release = resolve; }), async e => {
      input(e, '#kidia-identifier', 'customer@example.test'); submit(e, '.kidia-identifier-form'); submit(e, '.kidia-identifier-form'); await settle();
      assert.equal(e.calls.length, 1); release({ exists: true }); await settle();
    });
  });
  for (const value of ['not-an-email', '010', '012345678901234', '']) await test(`invalid identifier ${value || 'empty'} makes no request`, () => using('anonymous', undefined, async e => {
    input(e, '#kidia-identifier', value); submit(e, '.kidia-identifier-form'); await settle(); assert.equal(e.calls.length, 0);
  }));
  await test('existing phone retains OTP and password choices', () => using('anonymous', async () => ({ exists: true }), async e => {
    input(e, '#kidia-identifier', '01000000001'); submit(e, '.kidia-identifier-form'); await settle();
    assert.equal(visibleStage(e), 'phone'); assert.equal(e.w.document.querySelector('[data-kidia-phone-existing]').hidden, false);
    assert.equal(e.w.document.querySelector('[data-kidia-use-otp]').hidden, false);
    e.w.document.querySelector('[data-kidia-use-password]').click(); assert.equal(e.w.document.querySelector('.kidia-phone-password-form').hidden, false);
  }));
  await test('existing phone is never allowed into unverified signup fallback', () => using('anonymous', undefined, async e => {
    assert.equal(e.w.KidiaAuthFallback('01000000001', true), false); assert.equal(e.calls.length, 0);
  }));
  await test('signup preflight outage offers recovery instead of only a dead-end message', () => using('anonymous', async () => { throw Error('offline'); }, async e => {
    e.w.KidiaAuthFallback('01000000001', false); await settle();
    assert.ok(e.w.document.querySelector('.kidia-shared-completion button, .kidia-shared-completion a'), 'Recovery action missing');
  }, ['kidia-shared-auth.js']));
  await test('OTP verification deduplicates submits and ignores cancelled result', () => using('anonymous', undefined, async e => {
    let release, confirmations = 0, sent = 0;
    e.w.fmelwpDataObj = { ajaxurl: '/ajax', nonce: 'fixture' };
    e.w.jQuery = { ajax: () => { sent++; return Promise.resolve({ success: true }); } };
    e.w.confirmationResult = { confirm: () => { confirmations++; return new Promise(resolve => { release = resolve; }); } };
    e.w.eval(fs.readFileSync(path.join(__dirname, 'website/kidia-firebase-otp.js'), 'utf8'));
    const first = e.w.fma_lwp_firebase_otp_validation('+201000000001', '١٢٣٤٥٦', false);
    const second = e.w.fma_lwp_firebase_otp_validation('+201000000001', '١٢٣٤٥٦', false); await settle();
    assert.equal(confirmations, 1); e.w.document.dispatchEvent(new e.w.CustomEvent('kidia:otp-reset'));
    release({ user: { getIdToken: async () => 'fixture-token' } }); await Promise.all([first, second]); assert.equal(sent, 0);
  }, ['kidia-shared-auth.js']));
  await test('Google and Facebook choices remain after email signup/back', () => using('anonymous', async () => ({ exists: false }), async e => {
    input(e, '#kidia-identifier', 'new@example.test'); submit(e, '.kidia-identifier-form'); await settle();
    e.w.document.querySelector('[data-kidia-back]').click(); await settle();
    assert.equal(visibleStage(e), 'identifier'); assert.ok(e.w.document.querySelector('.kidia-google-provider')); assert.ok(e.w.document.querySelector('.kidia-facebook-provider'));
  }));
  console.log(JSON.stringify({ passed: results.filter(r => r.passed).length, failed: results.filter(r => !r.passed).length, results }, null, 2));
  if (results.some(r => !r.passed)) process.exitCode = 1;
})();
