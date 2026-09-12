"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");
const root = path.resolve(__dirname, "..");
const php = fs.readFileSync(path.join(root, "admin/pages/checkout-suggestions.php"), "utf8");
const css = fs.readFileSync(path.join(root, "admin/assets/page-builder.css"), "utf8");
const markup = php.match(/<label class="mobishop-page-status-control">[\s\S]*?<\/label>/)[0]
  .replace(/<\?php[\s\S]*?\?>/g, "");

for (const dir of ["ltr", "rtl"]) {
  const dom = new JSDOM(`<html dir="${dir}"><body><form>${markup}</form></body></html>`);
  const doc = dom.window.document;
  const input = doc.querySelector('input[type="checkbox"]');
  const track = doc.querySelector('.mobishop-page-status-control__track');
  assert.equal(input.nextElementSibling, track);
  assert.equal(track.getAttribute('aria-hidden'), 'true');
  assert.deepEqual(new dom.window.FormData(doc.querySelector('form')).getAll('checkout[enabled]'), ['0']);
  track.click();
  assert.equal(input.checked, true, `${dir}: clicking the visual track toggles the real field`);
  assert.deepEqual(new dom.window.FormData(doc.querySelector('form')).getAll('checkout[enabled]'), ['0', '1']);
  input.focus();
  assert.equal(doc.activeElement, input, `${dir}: checkbox remains focusable`);
  track.click();
  assert.equal(input.checked, false);
  dom.window.close();
}
assert.match(css, /input\[type=checkbox\]:focus-visible \+ \.mobishop-page-status-control__track\{[^}]*outline:2px/);
assert.match(css, /input\[type=checkbox\]:checked \+ \.mobishop-page-status-control__track:before\{[^}]*left:23px/);
console.log('Checkout status label, form submission and focus contracts passed in RTL/LTR.');
