const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname + '/kids-surface.js', 'utf8');
function run(existing) {
  const fields = new Map(Object.entries(existing));
  const prefix = 'blocks[1][settings][items][0]';
  const card = {
    querySelector(selector) { return fields.get(selector.slice(7, -2)); },
    appendChild(field) { fields.set(field.name, field); },
  };
  const screen = {style: {}, querySelector: () => ({})};
  const document = {
    readyState: 'complete', documentElement: {}, createElement: () => ({}),
    querySelectorAll(selector) {
      if (selector === '.mobishop-preview__screen') return [screen];
      return [{value: '', name: prefix + '[button_link]', closest: () => card}];
    },
  };
  vm.runInNewContext(source, {document, MutationObserver: class {observe() {}}});
  return fields;
}
const prefix = 'blocks[1][settings][items][0]';
const native = {[prefix + '[action_type]']: {value: 'category'}, [prefix + '[action_value]']: {value: '64'}};
const retained = run(native);
assert.equal(retained.get(prefix + '[action_type]').value, 'category');
assert.equal(retained.get(prefix + '[action_value]').value, '64');
assert.equal(run({[prefix + '[action_type]']: {value: 'category'}}).size, 1, 'Never invent a collection value for a partially loaded native action');
const legacy = run({});
assert.equal(legacy.get(prefix + '[action_type]').value, 'collection');
assert.equal(legacy.get(prefix + '[action_value]').value, 'latest');
console.log('PASS: native hero actions survive legacy Kids fallback; untouched legacy slides retain defaults');
