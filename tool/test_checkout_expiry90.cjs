const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('connectors/woocommerce/source/api/class-embedded-checkout88.php', 'utf8');
const script = source.match(/<script id="mobishop-checkout88-expiry">([\s\S]*?)<\/script>/)[1];
function run(status, url, lang = 'ar') {
  let callback, notice, unblocked = 0, disabled = false;
  const document = {
    documentElement: {lang},
    addEventListener: (_, fn) => fn(),
    getElementById: () => notice,
    createElement: () => ({setAttribute() {}, scrollIntoView() {}}),
    querySelector: () => ({prepend: value => { notice = value; }}),
  };
  const $ = target => target === document ? {ajaxError: fn => { callback = fn; }} : {
    unblock: () => unblocked++,
    prop: (key, value) => { disabled = key === 'disabled' && value === true; },
  };
  vm.runInNewContext(script, {window: {jQuery: $}, document});
  callback(null, {status}, {url});
  return {notice, unblocked, disabled};
}
for (const [status, url] of [[500, '/?wc-ajax=update_order_review'], [403, '/?wc-ajax=checkout'], [403, '/gateway']]) {
  assert.equal(run(status, url).notice, undefined);
}
for (const lang of ['ar', 'en']) {
  const result = run(403, '/?wc-ajax=update_order_review', lang);
  assert.ok(result.notice.textContent.length > 20);
  assert.equal(result.unblocked, 1);
  assert.equal(result.disabled, true);
}
console.log('Checkout expiry recovery: 5 cases passed; no payment submission or auth renewal.');
