const {test} = require('node:test');
const assert = require('node:assert/strict');
const {editor, coordinator, sameSavedState, fingerprint} = require('./publish-edits.js');

function fixture() {
  let store = 'a', pending = false, seq = 0;
  const frames = [], saves = [];
  const controls = {
    inspect: async frame => ({dirty: frame.controls !== frame.savedControls, stamp: frame.controls}),
    stamp: frame => frame.controls,
    validate: async frame => { if (frame.invalidControls) throw Error('Invalid controls'); },
  };
  const batch = coordinator({frames: () => frames, active: () => frames[0], store: () => store, pending: () => pending, controls, uuid: () => 'request-' + ++seq});
  function page(screen, value = 'original') {
    const frame = {dataset: {screen}, contentDocument: {}, contentWindow: {}, controls: '', savedControls: ''};
    let busy = false;
    frame.value = value; frame.locked = false; frame.valid = true;
    const form = {
      checkValidity: () => frame.valid,
      requestSubmit() {
        const id = api.requestId;
        const packet = {type: 'kidia:save', screen, request_id: id};
        assert.equal(batch.accepts(frame, {...packet, request_id: 'foreign'}), false);
        assert.equal(batch.accepts(frame, {...packet, screen: 'setup'}), false);
        assert.equal(batch.accepts(frame, packet), true);
        saves.push(screen); busy = true; api.packet(packet);
        queueMicrotask(() => {
          if (frame.noReceipt) { busy = false; return; }
          if (frame.reject) { busy = false; api.packet({type: 'kidia:save-receipt-rejected', request_id: id}); return; }
          // The real save receipt replaces newly-created Home IDs before this packet.
          if (frame.canonical) frame.value = frame.canonical;
          frame.savedControls = frame.controls;
          busy = false; api.packet({type: 'kidia:save-receipt-applied', request_id: id, applied: true});
        });
      },
    };
    const api = editor({screen, form: () => form, serialize: () => [['value', frame.value]], busy: () => busy,
      lock: value => { frame.locked = value; }, timeout: 20});
    frame.contentWindow.MobiShopPublishEditor = api;
    frame.api = api; frames.push(frame); api.loaded();
    return frame;
  }
  return {batch, page, saves, frames, switchStore: () => { store = 'b'; }, manualSave: () => { pending = true; }};
}

test('Saves active and inactive dirty pages but leaves untouched prewarmed snapshots alone', async () => {
  const f = fixture(), a = f.page('account-builder'), b = f.page('home-builder'), untouched = f.page('catalog-builder');
  a.value = 'changed'; b.value = 'new-local-id'; b.canonical = 'confirmed-server-id';
  assert.equal((await f.batch.inspect('a')).dirtyCount, 2);
  assert.deepEqual(f.saves, []);
  const session = await f.batch.begin('a');
  assert.ok(untouched.locked);
  await session.save(); session.assertCurrent(); session.release();
  assert.deepEqual(f.saves, ['home-builder', 'account-builder']);
  assert.equal(b.value, 'confirmed-server-id');
  assert.equal((await f.batch.inspect('a')).dirtyCount, 0);
  assert.ok(f.frames.every(frame => !frame.locked));
});

test('Invalid edited page blocks every write and unlocks all pages', async () => {
  const f = fixture(), a = f.page('account-builder'), b = f.page('home-builder');
  a.value = 'edit'; b.value = 'edit'; b.valid = false;
  await assert.rejects(f.batch.begin('a'));
  assert.deepEqual(f.saves, []); assert.ok(f.frames.every(frame => !frame.locked));
});

test('Controls-only changes save once; invalid controls never get hidden by preview fallback', async () => {
  const f = fixture(), a = f.page('checkout-builder'); a.controls = 'zero';
  assert.equal((await f.batch.inspect('a')).dirtyCount, 1);
  a.invalidControls = true; await assert.rejects(f.batch.begin('a'), /Invalid controls/);
  assert.deepEqual(f.saves, []);
  a.invalidControls = false; const session = await f.batch.begin('a');
  await session.save(); session.release(); assert.deepEqual(f.saves, ['checkout-builder']);
});

test('Rejected or missing canonical receipt blocks future replay until reload', async () => {
  for (const failure of ['reject', 'noReceipt']) {
    const f = fixture(), a = f.page('home-builder'); a.value = 'new'; a[failure] = true;
    const session = await f.batch.begin('a');
    await assert.rejects(session.save()); session.release();
    await assert.rejects(f.batch.begin('a'));
    assert.deepEqual(f.saves, ['home-builder']);
  }
});

test('Merchant switch and frame replacement stop before write', async () => {
  for (const change of ['store', 'document', 'screen', 'api']) {
    const f = fixture(), a = f.page('account-builder'); a.value = 'new';
    const session = await f.batch.begin('a');
    if (change === 'store') f.switchStore();
    if (change === 'document') a.contentDocument = {};
    if (change === 'screen') a.dataset.screen = 'checkout-builder';
    if (change === 'api') a.contentWindow.MobiShopPublishEditor = {};
    await assert.rejects(session.save()); session.release(); assert.deepEqual(f.saves, []);
  }
});

test('Cannot overlap another publish or a manual save', async () => {
  const f = fixture(); f.page('account-builder');
  const session = await f.batch.begin('a');
  await assert.rejects(f.batch.begin('a')); await assert.rejects(f.batch.inspect('a'));
  session.release(); f.manualSave(); await assert.rejects(f.batch.begin('a'));
});

test('Detects programmatic edits while the fresh publish snapshot is loading', async () => {
  for (const field of ['value', 'controls']) {
    const f = fixture(), a = f.page('home-builder'); a.value = 'edited';
    const session = await f.batch.begin('a'); await session.save();
    a[field] = 'changed-again'; assert.throws(session.assertCurrent); session.release();
  }
});

test('Non-design screens are never saved or included in automatic publication', async () => {
  const f = fixture(); for (const screen of ['setup', 'discounts', 'app-icon', 'push']) f.page(screen).value = 'changed';
  assert.equal((await f.batch.inspect('a')).dirtyCount, 0);
  const session = await f.batch.begin('a'); await session.save(); session.release();
  assert.deepEqual(f.saves, []);
});

test('A late prewarmed editor restoring its draft cannot be omitted from publication', async () => {
  const f = fixture(), a = f.page('account-builder'); a.value = 'edit';
  const late = {dataset: {screen: 'checkout-builder'}, contentWindow: {}, contentDocument: {}};
  f.frames.push(late);
  const session = await f.batch.begin('a'); await session.save();
  late.contentWindow.MobiShopPublishEditor = {inspect: () => ({ready: true, dirty: true})};
  assert.throws(session.assertCurrent); session.release();
});

test('Concurrent server edits differ from the loaded baseline; object metadata/order do not', () => {
  const before = {entries: [['b', '2'], ['a', '1']], loaded: true};
  assert.ok(sameSavedState(before, {entries: [['a', '1'], ['b', '2']]}));
  assert.ok(!sameSavedState(before, {entries: [['a', 'changed'], ['b', '2']]}));
});

test('Home grouping may reorder field and JSON keys without changing the design', () => {
  const encode = value => Buffer.from(JSON.stringify(value), 'utf8').toString('base64');
  const a = [['title', 'أهلًا'], ['blocks_payload_encoding','base64'], ['blocks_payload', encode([{id:'confirmed',settings:{title:'منتجات',columns:3}}])]];
  const b = [['blocks_payload', encode([{settings:{columns:3,title:'منتجات'},id:'confirmed'}])], ['blocks_payload_encoding','base64'], ['title','أهلًا']];
  assert.equal(fingerprint(a), fingerprint(b));
  b[0][1] = encode([{settings:{columns:4,title:'منتجات'},id:'confirmed'}]);
  assert.notEqual(fingerprint(a), fingerprint(b));
  assert.notEqual(fingerprint([['layout[header][settings][layout_json]','[1,2]']]), fingerprint([['layout[header][settings][layout_json]','[2,1]']]));
});
