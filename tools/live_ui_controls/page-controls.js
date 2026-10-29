(function (scope) {
  'use strict';
  const pageKeys = (screen, schema) => Object.keys(schema).filter(key =>
    screen === 'account-builder' ? /^(auth_|logout_|support_|orders_)/.test(key) :
    screen === 'home-builder' ? /^(cart_pulse_|message_)/.test(key) :
    screen === 'checkout-builder' ? /^(cart_|checkout_|receipt_)/.test(key) && !key.startsWith('cart_pulse_') :
    screen === 'catalog-builder' ? key.startsWith('filters_') :
    screen === 'product-builder' ? key.startsWith('quickadd_') : false);
  const valueOf = (data, key) => data.values[key] ?? data.schema[key].default;
  function setSavedInput(input, spec, value) {
    if (spec.type === 'boolean') { input.defaultChecked = input.checked = value; return; }
    input.value = value === null ? '' : String(value);
    if (spec.type === 'choice') for (const option of input.options) option.defaultSelected = option.value === value;
    else input.defaultValue = input.value;
  }
  function mergeChanges(schema, baseline, changed, latest) {
    const merged = {...latest};
    for (const [key, value] of Object.entries(changed)) {
      if (!schema[key]) throw new Error('Unknown control');
      const current = latest[key] ?? schema[key].default;
      if (current !== baseline[key] && current !== value) {
        throw new Error('الإعدادات اتغيرت في جلسة أخرى. حدّث الصفحة لمراجعة أحدث نسخة قبل الحفظ.');
      }
      merged[key] = value;
    }
    return merged;
  }
  function decoratePacket(packet, controls) {
    const home = packet.layouts?.home;
    if (!home || !controls) return packet;
    const layout = {...home, settings: {...home.settings, ui_controls_v1: {...controls}}};
    return {...packet, layouts: {...packet.layouts, home: layout},
      ...(packet.page === 'home' ? {layout} : {})};
  }
  function inputValue(input, spec) { return spec.type === 'boolean' ? input.checked : spec.type === 'number' ? (spec.default === null && input.value === '' ? null : input.valueAsNumber) : spec.type === 'color' ? input.value.toUpperCase() : input.value; }
  const draftKey = (store, screen) => 'mobishop-controls-draft-v1:' + store + ':' + screen;
  function draftChanges(schema, baseline, values) {
    return Object.fromEntries(Object.keys(values).filter(key => schema[key] && values[key] !== baseline[key]).map(key => [key, values[key]]));
  }
  const model = {pageKeys, valueOf, mergeChanges, decoratePacket, draftKey, draftChanges, inputValue};
  if (typeof module !== 'undefined' && module.exports) { module.exports = model; return; }
  if (scope.MobiShopPageControls) return;
  const states = new WeakMap(), observed = new WeakSet();
  let loaded, previewData;
  const store = new URL(location.href).searchParams.get('store') || '';
  const endpoint = '/account/builder/live-design/controls';
  const supported = new Set(['home-builder', 'account-builder', 'checkout-builder','catalog-builder','product-builder']);
  async function request(url, body, csrf) {
    const response = await fetch(url, {
      method: body ? 'POST' : 'GET', credentials: 'same-origin',
      headers: {Accept: 'application/json', ...(body ? {'Content-Type': 'application/json', 'X-CSRF-TOKEN': csrf} : {})},
      ...(body ? {body: JSON.stringify(body)} : {}),
    });
    if (!response.ok || !response.headers.get('Content-Type')?.includes('application/json')) {
      if (response.status === 409) throw new Error('الإعدادات اتغيرت في جلسة أخرى. حدّث الصفحة قبل الحفظ.');
      if (response.status === 422) throw new Error('راجع القيم والأحجام والنصوص قبل الحفظ.');
      throw new Error('تعذر تأكيد حفظ إعدادات الصفحة. حدّث البيلدر وراجع القيم المحفوظة.');
    }
    return response.json();
  }
  function load() {
    if (!loaded) loaded = Promise.all([
      request('/account/builder/context?store=' + encodeURIComponent(store)),
      request(endpoint + '?store=' + encodeURIComponent(store)),
    ]).then(([context, data]) => {
      if (context.store !== store || !data.schema || !data.values) throw new Error('تعذر تحميل إعدادات الصفحة.');
      previewData = data;
      refreshPreview();
      return {context, data};
    }).catch(error => { loaded = null; throw error; });
    return loaded;
  }
  function refreshPreview() { scope.dispatchEvent(new Event('mobishop:page-controls-preview')); }
  function inputValues(state) {
    return Object.fromEntries([...state.inputs].map(([key, input]) => [key,
      input.checkValidity() ? inputValue(input, state.data.schema[key]) : state.baseline[key]]));
  }
  function storeDraft(state) {
    const changed = draftChanges(state.data.schema, state.baseline, inputValues(state));
    try {
      const key = draftKey(store, state.screen);
      if (Object.keys(changed).length) sessionStorage.setItem(key, JSON.stringify({baseline: state.baseline, changed}));
      else sessionStorage.removeItem(key);
    } catch (_) {}
  }
  function decoratePreview(packet) {
    if (!previewData || store !== new URL(location.href).searchParams.get('store')) return packet;
    const values = Object.fromEntries(Object.keys(previewData.schema).map(key => [key, valueOf(previewData, key)]));
    for (const frame of document.querySelectorAll('iframe[data-screen]')) {
      const state = states.get(frame.contentDocument);
      if (state?.data) Object.assign(values, draftChanges(state.data.schema, state.baseline, inputValues(state)));
    }
    return decoratePacket(packet, values);
  }
  function make(doc, tag, text, parent, className) {
    const node = doc.createElement(tag);
    if (text) node.textContent = text;
    if (className) node.className = className;
    if (parent) parent.append(node);
    return node;
  }
  function style(doc) {
    if (doc.getElementById('wm-page-controls-style')) return;
    const node = make(doc, 'style', '', doc.head);
    node.id = 'wm-page-controls-style';
    node.textContent = '.wm-page-controls{margin:14px 0;direction:rtl;color:#20413d}.wm-page-controls-card{border:1px solid #c5dcd6;border-radius:14px;background:#fff;overflow:hidden}.wm-page-controls summary{display:flex;align-items:center;justify-content:space-between;cursor:pointer;font-size:16px;font-weight:700;padding:18px;list-style:none}.wm-page-controls summary::after{content:"⌄";font-size:22px;color:#277d6d}.wm-page-controls[open]>summary::after{transform:rotate(180deg)}.wm-page-controls-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;padding:16px}.wm-page-controls label{display:flex;flex-direction:column;gap:7px;min-width:0;font-size:14px}.wm-page-controls input,.wm-page-controls select{box-sizing:border-box;width:100%;height:40px;border:1px solid #a8c7bf;border-radius:9px;padding:8px;background:#fff;color:#203d38;font-size:14px}.wm-page-controls button[data-wm-preview-page]{min-height:40px;padding:8px 12px;border:1px solid #a8c7bf;border-radius:9px;background:#edf7f4;color:#217b69;font:inherit;cursor:pointer}.wm-page-controls input[type=color]{padding:4px}.wm-page-controls input[type=checkbox]{width:22px;height:22px;accent-color:#217b69}.wm-page-controls-note{margin:0;padding:0 16px 14px;font-size:12px;color:#627d76}.wm-page-controls-status:empty{display:none}.wm-page-controls-status{margin:10px 0;color:#a32922}.wm-page-controls-heading{font-size:15px;font-weight:700;padding:12px 16px 0}.wm-page-controls-error{padding:12px;border:1px solid #d9a79e;border-radius:8px;color:#a32922}@media(max-width:560px){.wm-page-controls-grid{grid-template-columns:1fr}}';
  }
  function card(doc, title) {
    const section = make(doc, 'details', '', null, 'wm-page-controls wm-page-controls-card');
    make(doc, 'summary', title, section);
    return section;
  }
  function targetContainers(doc, screen, form) {
    const containers = {};
    if (screen === 'account-builder') {
      const settings = form.querySelector('.mobishop-page-settings-card');
      const logoutBody = form.querySelector('[data-element="logout_button"] > .mobishop-page-card__body');
      if (!settings || !logoutBody) return null;
      const auth = card(doc, 'تسجيل الدخول');
      auth.dataset.wmControlsGroup = 'auth';
      settings.insertAdjacentElement('afterend', auth);
      const logout = make(doc, 'div', '', null, 'wm-page-controls');
      logout.dataset.wmControlsGroup = 'logout';
      make(doc, 'div', 'حجم ونص زر تسجيل الخروج', logout, 'wm-page-controls-heading');
      logoutBody.prepend(logout);
      containers.auth = auth; containers.logout = logout;
      const support = card(doc, 'بيانات خدمة العملاء');
      support.dataset.wmControlsGroup = 'support';
      auth.insertAdjacentElement('afterend', support); containers.support = support;
      const orders = card(doc, 'صور منتجات الطلبات');
      orders.dataset.wmControlsGroup = 'orders';
      support.insertAdjacentElement('afterend', orders); containers.orders = orders;
    } else if (screen === 'home-builder') {
      const body = form.querySelector('[data-chrome-part="header"] > .mobishop-page-card__body');
      if (!body) return null;
      const pulse = card(doc, 'حركة عدّاد السلة');
      pulse.dataset.wmControlsGroup = 'pulse'; body.prepend(pulse); containers.pulse = pulse;
      const messages = card(doc, 'رسائل التطبيق');
      messages.dataset.wmControlsGroup = 'messages'; pulse.insertAdjacentElement('afterend', messages); containers.messages = messages;
    } else if (screen==='catalog-builder'||screen==='product-builder') {
      const settings=form.querySelector('.mobishop-page-settings-card');
      if (!settings) return null;
      const key=screen==='catalog-builder'?'filters':'quickadd';
      const section=card(doc,key==='filters'?'مظهر الفلاتر':'فوتر الإضافة السريعة');
      section.dataset.wmControlsGroup=key;settings.insertAdjacentElement('afterend',section);containers[key]=section;
    } else {
      const design = form.querySelector('.mobishop-checkout-design-panel');
      if (!design) return null;
      const cart = card(doc, 'السلة');
      cart.dataset.wmControlsGroup = 'cart'; design.insertAdjacentElement('afterend', cart); containers.cart = cart;
      const checkout = card(doc, 'مظهر إتمام الطلب والعناوين');
      checkout.dataset.wmControlsGroup = 'checkout'; cart.insertAdjacentElement('afterend', checkout); containers.checkout = checkout;
      const receipt=card(doc,'تأكيد الطلب');receipt.dataset.wmControlsGroup='receipt';checkout.insertAdjacentElement('afterend',receipt);containers.receipt=receipt;
      const previews = make(doc, 'div', '', cart, 'wm-page-controls-grid');
      for (const [page, title] of [['cart', 'معاينة السلة'], ['checkout', 'معاينة إتمام الطلب']]) {
        const button = make(doc, 'button', title, previews);
        button.type = 'button';
        button.dataset.wmPreviewPage = page;
        button.addEventListener('click', () => {
          const preview = document.getElementById('kidia-shared-flutter');
          if (preview) preview.contentWindow.postMessage(JSON.stringify({type: 'mobishop-preview-navigate', page}), location.origin);
        });
      }
    }
    return containers;
  }
  function group(key) { return key.startsWith('filters_')?'filters':key.startsWith('quickadd_')?'quickadd':key.startsWith('receipt_')?'receipt':key.startsWith('support_') ? 'support' : key.startsWith('auth_') ? 'auth' : key.startsWith('logout_') ? 'logout' : key.startsWith('orders_') ? 'orders' : key.startsWith('message_') ? 'messages' : key.startsWith('checkout_') ? 'checkout' : key.startsWith('cart_pulse_') ? 'pulse' : 'cart'; }
  async function mount(frame) {
    const screen = frame.dataset.screen;
    if (!supported.has(screen)) return null;
    const doc = frame.contentDocument;
    const form = doc?.querySelector(screen === 'home-builder' ? '#mobishop-home-builder-form' : 'form.mobishop-page-editor');
    if (!form) return null;
    if (states.has(doc)) return states.get(doc);
    const state = {form, screen, inputs: new Map(), baseline: {}, ready: null};
    states.set(doc, state);
    state.ready = load().then(({context, data}) => {
      if (!frame.isConnected || frame.contentDocument !== doc) return;
      style(doc);
      const containers = targetContainers(doc, screen, form);
      if (!containers) throw new Error('تعذر تحميل مكان إعدادات الصفحة. حدّث البيلدر.');
      state.context = context; state.data = data;
      const grids = {};
      for (const [key, parent] of Object.entries(containers)) grids[key] = make(doc, 'div', '', parent, 'wm-page-controls-grid');
      for (const key of pageKeys(screen, data.schema)) {
        const spec = data.schema[key], label = make(doc, 'label', spec.label, grids[group(key)]);
        const input = make(doc, spec.type === 'choice' ? 'select' : 'input', '', label);
        // Keep the existing page serializer intact; the same Save Page action
        // persists these versioned controls before committing the page layout.
        input.dataset.wmUiControl = key;
        if (spec.type === 'choice') {
          for (const [value, caption] of Object.entries(spec.options)) make(doc, 'option', caption, input).value = value;
        } else input.type = spec.type === 'boolean' ? 'checkbox' : spec.type;
        if (spec.type === 'number') { input.min = spec.min; input.max = spec.max; input.step = spec.step; input.required = spec.default !== null; if (spec.default === null) input.placeholder = 'حسب الثيم'; }
        if (spec.type === 'text') { input.maxLength = spec.max_length; input.placeholder = 'النص الأصلي'; input.dir = key.endsWith('_en') ? 'ltr' : 'rtl'; }
        if (spec.format === 'email') { input.type = 'email'; input.dir = 'ltr'; input.placeholder = 'support@example.com'; }
        if (spec.format === 'phone') { input.type = 'tel'; input.dir = 'ltr'; input.placeholder = '+201234567890'; input.pattern = '\\+?[0-9][0-9 ()\\-]{5,30}[0-9]'; }
        const value = valueOf(data, key);
        setSavedInput(input, spec, value);
        state.baseline[key] = value; state.inputs.set(key, input);
      }
      for (const container of Object.values(containers)) make(doc, 'p', 'تُحفظ مع إعدادات الصفحة. النص الفارغ يستخدم النص الأصلي، والحجم الفارغ يتبع الثيم.', container, 'wm-page-controls-note');
      state.status = make(doc, 'p', '', Object.values(containers)[0], 'wm-page-controls-status');
      state.status.setAttribute('role', 'status');
      state.status.setAttribute('aria-live', 'polite');
      try {
        const draft = JSON.parse(sessionStorage.getItem(draftKey(store, screen)) || 'null');
        if (draft?.baseline && draft?.changed) {
          for (const [key, input] of state.inputs) {
            if (!Object.hasOwn(draft.changed, key) || !Object.hasOwn(draft.baseline, key)) continue;
            const spec = data.schema[key], value = draft.changed[key];
            if (spec.type === 'number' && spec.default === null ? value !== null && typeof value !== 'number' : typeof value !== typeof valueOf(data, key)) continue;
            if (spec.type === 'choice' && !Object.hasOwn(spec.options, value)) continue;
            if (spec.type === 'boolean') input.checked = value; else input.value = value === null ? '' : String(value);
            state.baseline[key] = draft.baseline[key];
          }
          state.status.textContent = 'تم استرجاع تعديلاتك غير المحفوظة.';
        }
      } catch (_) {}
      const update = event => {
        if (!event.target?.dataset?.wmUiControl) return;
        storeDraft(state); refreshPreview();
      };
      form.addEventListener('input', update);
      form.addEventListener('change', update);
      form.addEventListener('reset', () => setTimeout(() => { storeDraft(state); refreshPreview(); }, 0));
      doc.addEventListener('click', event => {
        if (event.target.closest('#mobishop-collapse-all')) for (const node of Object.values(containers)) if (node.tagName === 'DETAILS') node.open = false;
        if (event.target.closest('#mobishop-expand-all')) for (const node of Object.values(containers)) if (node.tagName === 'DETAILS') node.open = true;
      });
      doc.querySelector('.wm-page-controls-error')?.remove();
      refreshPreview();
    }).catch(error => {
      states.delete(doc); style(doc);
      let notice = doc.querySelector('.wm-page-controls-error');
      if (!notice) { notice = make(doc, 'p', '', null, 'wm-page-controls-error'); form.prepend(notice); }
      notice.textContent = error.message; throw error;
    });
    return state;
  }
  async function save(frame) {
    if (!supported.has(frame.dataset.screen)) return;
    const state = await mount(frame);
    if (!state) throw new Error('إعدادات الصفحة لسه بتتحمل. حاول الحفظ بعد اكتمالها.');
    await state.ready;
    if (!state.data || store !== new URL(location.href).searchParams.get('store')) throw new Error('اتغير المتجر. حدّث الصفحة قبل الحفظ.');
    const changed = {};
    for (const [key, input] of state.inputs) {
      if (!input.checkValidity()) { input.reportValidity(); throw new Error('راجع القيم والأحجام قبل الحفظ.'); }
      const spec = state.data.schema[key];
      const value = inputValue(input, spec);
      if (value !== state.baseline[key]) changed[key] = value;
    }
    if (!Object.keys(changed).length) { storeDraft(state); return; }
    const latest = await request(endpoint + '?store=' + encodeURIComponent(store));
    const controls = mergeChanges(latest.schema, state.baseline, changed, latest.values);
    const result = await request(endpoint, {store, controls, controls_digest: latest.controls_digest}, state.context.csrf_token);
    for (const [key, input] of state.inputs) {
      const value = valueOf(result, key);
      state.baseline[key] = value;
      setSavedInput(input, result.schema[key], value);
    }
    state.data = result;
    previewData = result;
    storeDraft(state);
    state.status.textContent = '';
    loaded = Promise.resolve({context: state.context, data: result});
    refreshPreview();
  }
  function observe() {
    for (const frame of document.querySelectorAll('iframe[data-screen]')) {
      if (observed.has(frame)) continue;
      observed.add(frame);
      frame.addEventListener('load', () => { mount(frame).then(s => s?.ready).catch(() => {}); });
      mount(frame).then(s => s?.ready).catch(() => {});
    }
  }
  addEventListener('message', event => {
    if (event.origin !== location.origin || !['kidia:ready', 'kidia:visual-ready'].includes(event.data?.type)) return;
    const frame = [...document.querySelectorAll('iframe[data-screen]')].find(f => f.contentWindow === event.source && f.dataset.screen === event.data.screen);
    if (frame) mount(frame).then(s => s?.ready).catch(() => {});
  });
  new MutationObserver(observe).observe(document.querySelector('.kidia-central-stage') || document.body, {childList: true, subtree: true});
  scope.MobiShopPageControls = {save, decoratePreview};
  observe();
  load().catch(() => {});
})(typeof window === 'undefined' ? globalThis : window);
