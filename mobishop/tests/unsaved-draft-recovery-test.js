'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../admin/assets/unsaved-changes.js'), 'utf8');
// Run the real restore routine against the same form element shape.
const routine = source.slice(source.indexOf('\tfunction restoreDraft('), source.indexOf('\n\tfunction closeModal('));
function restore(elements, saved) {
  const context = {form: {elements}, saved};
  vm.runInNewContext(routine + '\nrestoreDraft(saved);', context);
}
for (const name of ['wishlist_access_mode', 'checkout_design']) {
  const elements = [{name, type: 'radio', value: 'first', checked: false},
    {name, type: 'radio', value: 'last', checked: true}];
  restore(elements, elements.map((e, i) => ({...e, checked: i === 0})));
  assert.equal(elements[0].checked, true);
  assert.equal(elements[1].checked, false);
}
for (const [fallback, on] of [['0', '1'], ['1', '0']]) {
  const elements = [{name: 'enabled', type: 'hidden', value: fallback},
    {name: 'enabled', type: 'checkbox', value: on, checked: true}];
  restore(elements, elements.map(e => ({...e})));
  elements[1].checked = false;
  assert.equal(elements[0].value, fallback, 'Restoring must not corrupt the off fallback');
}
console.log('PASS unsaved draft radios, normal and inverted toggle recovery');
