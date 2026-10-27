(function (scope) {
  'use strict';
  const screens = new Set(['splash', 'home-builder', 'category-builder', 'catalog-builder', 'product-builder', 'size-chart-builder', 'wishlist-builder', 'account-builder', 'checkout-builder']);
  const message = 'تعذر تأكيد حفظ التعديلات. حدّث البيلدر وراجع القيم المحفوظة قبل النشر.';
  const snapshot = value => JSON.stringify(value);
  const labels = {'splash':'Splash','home-builder':'Home','category-builder':'Categories','catalog-builder':'Catalog','product-builder':'Product','size-chart-builder':'Size chart','wishlist-builder':'Wishlist','account-builder':'Account','checkout-builder':'Checkout'};
  function stable(value) {
    if (Array.isArray(value)) return value.map(stable);
    if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])]));
    return value;
  }
  function fingerprint(entries) {
    const encoded = entries.some(pair => pair[0] === 'blocks_payload_encoding' && pair[1] === 'base64');
    return snapshot(entries.map(([key, raw]) => {
      let value = raw;
      // Presentation grouping can reorder form fields / JSON keys after hydration.
      // Preserve list order, but do not mistake that grouping for merchant edits.
      if (key === 'blocks_payload' || key.endsWith('[layout_json]') || key.endsWith('[compact_layout_json]')) {
        try {
          const json = key === 'blocks_payload' && encoded ? new TextDecoder().decode(Uint8Array.from(atob(raw), char => char.charCodeAt(0))) : raw;
          value = stable(JSON.parse(json));
        } catch (_) { /* Invalid edits retain their raw value for validation. */ }
      }
      return [key, value];
    }).sort((a, b) => a[0].localeCompare(b[0])));
  }
  function sameSavedState(left, right) {
    return fingerprint(left?.entries || []) === fingerprint(right?.entries || []);
  }

  // A baseline is established only after hydration or an applied save receipt.
  function editor(options) {
    let baseline, pending = null, locked = false, uncertain = false;
    const read = () => fingerprint(options.serialize(options.form()));
    function inspect() {
      if (uncertain || options.busy()) throw new Error(message);
      if (baseline === undefined) return {ready: false, dirty: false};
      const stamp = read();
      return {ready: true, dirty: stamp !== baseline, stamp};
    }
    function fail(error) {
      if (!pending) return;
      const request = pending; pending = null;
      clearTimeout(request.timer);
      // Do not replay a possibly committed PUT, especially a new Home element.
      uncertain = true;
      request.reject(error);
    }
    return {
      inspect,
      savedState: () => options.savedState(),
      get locked() { return locked; },
      get requestId() { return pending?.id; },
      loaded() { if (pending || locked) { fail(new Error(message)); uncertain = true; return; } baseline = read(); },
      lock(value) { locked = value; options.lock(value || options.busy()); },
      validate() {
        if (!inspect().ready) throw new Error('الصفحة لسه بتتحمل. حاول النشر بعد اكتمالها.');
        const form = options.form();
        if (!form || !form.checkValidity()) throw new Error('راجع القيم المطلوبة في صفحة ' + options.screen + ' قبل النشر.');
      },
      save(id) {
        if (pending || !locked) return Promise.reject(new Error(message));
        return new Promise((resolve, reject) => {
          pending = {id, resolve, reject, started: false};
          pending.timer = setTimeout(() => fail(new Error(message)), options.timeout || 45000);
          try { options.form().requestSubmit(); } catch (error) { fail(error); }
        });
      },
      packet(packet) {
        if (packet.type === 'kidia:save' && pending && packet.request_id === pending.id) pending.started = true;
        if (packet.type === 'kidia:save-receipt-rejected') { uncertain = true; fail(new Error(message)); }
        if (packet.type !== 'kidia:save-receipt-applied') return;
        if (packet.applied !== true) { uncertain = true; fail(new Error(message)); return; }
        baseline = read();
        if (pending && pending.started && packet.request_id === pending.id) {
          const request = pending; pending = null; clearTimeout(request.timer); request.resolve();
        }
      },
      abort() { fail(new Error(message)); },
    };
  }

  function coordinator(options) {
    let batch = null;
    function assertStore(store) {
      if (!store || options.store() !== store) throw new Error('اتغير المتجر. حدّث البيلدر قبل النشر.');
    }
    async function collect(store) {
      assertStore(store);
      if (options.pending()) throw new Error('في حفظ شغال بالفعل. انتظر اكتماله قبل النشر.');
      const items = [];
      for (const frame of options.frames()) {
        if (!screens.has(frame.dataset.screen)) continue;
        const doc = frame.contentDocument, api = frame.contentWindow?.MobiShopPublishEditor;
        const state = api?.inspect();
        if (!state?.ready) {
          if (frame === options.active()) throw new Error('الصفحة لسه بتتحمل. حاول النشر بعد اكتمالها.');
          continue; // Unhydrated prewarmed frames cannot contain merchant edits.
        }
        const controls = await options.controls.inspect(frame);
        items.push({frame, doc, api, screen: frame.dataset.screen, dirty: state.dirty || controls.dirty, stamp: state.stamp, controlsStamp: controls.stamp});
      }
      assertStore(store);
      return items.sort((a, b) => Number(b.screen === 'home-builder') - Number(a.screen === 'home-builder'));
    }
    return {
      get busy() { return batch !== null; },
      accepts(frame, packet) { return Boolean(batch?.saving?.frame === frame && packet.type === 'kidia:save' && packet.screen === batch.saving.screen && packet.request_id === batch.saving.id); },
      async inspect(store) {
        if (batch) throw new Error('النشر شغال بالفعل.');
        const changed = (await collect(store)).filter(item => item.dirty);
        return {dirtyCount: changed.length, pages: changed.map(item => labels[item.screen])};
      },
      async begin(store) {
        if (batch) throw new Error('النشر شغال بالفعل.');
        const own = {items: [], saving: null, released: false}; batch = own;
        function assertCurrent() {
          assertStore(store);
          if (batch !== own || own.released) throw new Error(message);
          const frames = options.frames();
          if (frames.some(frame => screens.has(frame.dataset.screen) && !own.items.some(item => item.frame === frame) && frame.contentWindow?.MobiShopPublishEditor?.inspect().ready)) throw new Error('اكتمل تحميل صفحة إضافية. راجع التعديلات وحاول النشر مجددًا.');
          for (const item of own.items) {
            if (!frames.includes(item.frame) || item.frame.contentDocument !== item.doc || item.frame.dataset.screen !== item.screen || item.frame.contentWindow?.MobiShopPublishEditor !== item.api) throw new Error('اتغيرت صفحة البيلدر أثناء الحفظ. راجع التعديلات قبل النشر.');
            if (own.saving?.frame !== item.frame && (item.api.inspect().stamp !== item.stamp || options.controls.stamp(item.frame) !== item.controlsStamp)) throw new Error('اتغيرت تعديلات الصفحة أثناء النشر. راجعها وحاول مجددًا.');
          }
        }
        function release() {
          if (own.released) return;
          own.released = true;
          for (const item of own.items) item.api.lock(false);
          if (batch === own) batch = null;
        }
        try {
          own.items = await collect(store);
          if (options.pending()) throw new Error('في حفظ شغال بالفعل. انتظر اكتماله قبل النشر.');
          assertCurrent();
          // Validate every edited page before any write; untouched cached pages stay untouched.
          for (const item of own.items) item.api.lock(true);
          for (const item of own.items.filter(item => item.dirty)) {
            item.api.validate(); await options.controls.validate(item.frame); assertCurrent();
          }
          return {
            assertCurrent, release,
            async save() {
              assertCurrent();
              for (const item of own.items.filter(item => item.dirty)) {
                assertCurrent();
                own.saving = {...item, id: options.uuid()};
                try {
                  await item.api.save(own.saving.id);
                  item.stamp = item.api.inspect().stamp;
                  item.controlsStamp = options.controls.stamp(item.frame);
                } finally { own.saving = null; }
                assertCurrent();
                if (item.api.inspect().dirty || (await options.controls.inspect(item.frame)).dirty) throw new Error('اتغيرت تعديلات الصفحة أثناء الحفظ. راجعها قبل النشر.');
              }
            },
          };
        } catch (error) { release(); throw error; }
      },
    };
  }
  const api = {screens, editor, coordinator, sameSavedState, fingerprint};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else scope.KidiaPublishEdits = api;
})(typeof window === 'undefined' ? globalThis : window);
