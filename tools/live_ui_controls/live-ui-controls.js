(() => {
  'use strict';
  if (document.getElementById('wm-ui-controls')) return;
  const shell = document.querySelector('.mobishop-cms-save-theme');
  if (!shell) return;
  const make = (tag, text, parent) => {
    const element = document.createElement(tag);
    if (text) element.textContent = text;
    if (parent) parent.append(element);
    return element;
  };
  const button = make('button', 'إعدادات التطبيق الإضافية', shell);
  button.id = 'wm-ui-controls'; button.type = 'button'; button.className = 'button'; button.style.marginInlineStart = '8px';
  const style = make('style', '', document.head);
  style.textContent = '#wm-ui-dialog{box-sizing:border-box;border:1px solid #abc9c2;border-radius:20px;padding:24px;width:min(780px,94vw);max-height:88vh;color:#20413d;background:white;box-shadow:0 20px 60px #163c3833}#wm-ui-dialog::backdrop{background:#183d3870}#wm-ui-dialog h2{font-size:22px;margin:0 0 10px}#wm-ui-dialog p{line-height:1.7}#wm-ui-dialog details{border:1px solid #bad4cd;border-radius:12px;margin:12px 0;padding:14px}#wm-ui-dialog summary{font-weight:700;cursor:pointer;padding:4px}#wm-ui-dialog .wm-controls-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-top:18px}#wm-ui-dialog label{display:flex;flex-direction:column;gap:7px;font-size:14px;min-width:0}#wm-ui-dialog input{box-sizing:border-box;width:100%;min-height:40px;border:1px solid #a7c3bc;border-radius:8px;padding:8px;font-size:15px;background:#fff;color:#203d38}#wm-ui-dialog input[type=checkbox]{width:22px;height:22px;min-height:22px;accent-color:#217b69}#wm-ui-dialog input[type=color]{padding:4px}#wm-ui-dialog footer{display:flex;gap:8px;flex-wrap:wrap;position:sticky;bottom:-24px;background:#fff;border-top:1px solid #d7e6e1;padding:14px 0;margin-top:14px}#wm-ui-dialog button{padding:10px 16px;border:1px solid #76aba1;border-radius:10px;cursor:pointer;background:#f1f8f6;color:#20594e}#wm-ui-dialog button[type=submit]{background:#217b69;color:#fff}#wm-ui-dialog button:disabled{opacity:.5;cursor:default}#wm-ui-dialog [role=status]{min-height:25px;margin:8px 0}#wm-ui-dialog .wm-controls-note{font-size:13px;color:#607b75}@media(max-width:540px){#wm-ui-dialog .wm-controls-grid{grid-template-columns:1fr}}';
  const dialog = make('dialog', '', document.body); dialog.id = 'wm-ui-dialog'; dialog.dir = 'rtl';
  const form = make('form', '', dialog);
  make('h2', 'إعدادات التطبيق الإضافية', form);
  make('p', 'عدّل شكل تسجيل الدخول والحساب والسلة. احفظ الإعدادات هنا، ثم استخدم «نشر للموبايل» لإرسالها.', form);
  make('p', 'تحتاج هذه الخيارات نسخة تطبيق تدعم الإعدادات الإضافية. بعدها تتغير من البيلدر بدون بناء جديد. النص الفارغ يستخدم النص الأصلي.', form).className = 'wm-controls-note';
  const status = make('p', '', form); status.setAttribute('role', 'status'); status.setAttribute('aria-live', 'polite');
  const fields = make('div', '', form);
  const footer = make('footer', '', form);
  const save = make('button', 'حفظ الإعدادات', footer); save.type = 'submit';
  const reset = make('button', 'استعادة القيم الأصلية', footer); reset.type = 'button';
  const close = make('button', 'إغلاق', footer); close.type = 'button';
  let context, data, busy = false, generation = 0;
  const inputs = new Map();
  const storeId = () => new URL(location.href).searchParams.get('store');
  async function request(url, body) {
    const response = await fetch(url, {method: body ? 'POST' : 'GET', credentials: 'same-origin',
      headers: {Accept: 'application/json', ...(body ? {'Content-Type':'application/json', 'X-CSRF-TOKEN':context.csrf_token} : {})},
      ...(body ? {body:JSON.stringify(body)} : {})});
    if (!response.ok) {
      if ([401,419].includes(response.status)) throw new Error('انتهت الجلسة. سجّل الدخول من جديد.');
      if (response.status === 409) throw new Error('الإعدادات اتغيرت في جلسة أخرى. اقفل النافذة وافتحها لمراجعة أحدث نسخة.');
      if (response.status === 422) throw new Error('راجع القيم وحدود الأحجام. النصوص لا تقبل أكواد أو أسطر جديدة.');
      throw new Error('تعذر حفظ الإعدادات. افتح النافذة مجددًا للتحقق من آخر حفظ.');
    }
    if (!response.headers.get('Content-Type')?.includes('application/json')) {
      throw new Error('تعذر تأكيد الحفظ. أعد فتح البيلدر لتجديد الجلسة ثم راجع الإعدادات المحفوظة.');
    }
    return response.json();
  }
  function setBusy(value) { busy = value; save.disabled = reset.disabled = value || !data; close.disabled = value; }
  function fill(values) {
    for (const [key, input] of inputs) {
      const spec = data.schema[key], value = values[key] ?? spec.default;
      if (spec.type === 'boolean') input.checked = value;
      else input.value = String(value);
    }
  }
  function render() {
    fields.replaceChildren(); inputs.clear(); const groups = new Map();
    for (const [key, spec] of Object.entries(data.schema)) {
      if (!groups.has(spec.group)) {
        const section = make('details', '', fields); section.open = groups.size === 0;
        make('summary', spec.group, section);
        const grid = make('div', '', section); grid.className = 'wm-controls-grid'; groups.set(spec.group, grid);
      }
      const label = make('label', spec.label, groups.get(spec.group));
      const input = make('input', '', label); input.name = key;
      input.type = spec.type === 'boolean' ? 'checkbox' : spec.type === 'text' ? 'text' : spec.type;
      if (spec.type === 'number') { input.min = spec.min; input.max = spec.max; input.step = spec.step; input.required = true; }
      if (spec.type === 'text') { input.maxLength = spec.max_length; input.placeholder = 'النص الأصلي'; input.dir = key.endsWith('_en') ? 'ltr' : 'rtl'; }
      inputs.set(key, input);
    }
    fill(data.values);
  }
  button.addEventListener('click', async () => {
    const own = ++generation, store = storeId(); data = context = null; fields.replaceChildren(); setBusy(true);
    status.textContent = 'جار تحميل إعدادات التطبيق…'; dialog.showModal();
    try {
      const ctx = await request(`/account/builder/context?store=${encodeURIComponent(store || '')}`);
      const result = await request(`/account/builder/live-design/controls?store=${encodeURIComponent(store || '')}`);
      if (own !== generation || store !== storeId()) return;
      context = ctx; data = result; render(); status.textContent = 'الإعدادات المحفوظة جاهزة للتعديل.';
    } catch (error) { if (own === generation) status.textContent = error.message; }
    finally { if (own === generation) setBusy(false); }
  });
  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (busy || !data || !context || context.store !== storeId() || !form.reportValidity()) return;
    const controls = {};
    for (const [key, input] of inputs) {
      const spec = data.schema[key];
      controls[key] = spec.type === 'boolean' ? input.checked : spec.type === 'number' ? input.valueAsNumber : input.value;
    }
    setBusy(true); status.textContent = 'جار حفظ الإعدادات…';
    try {
      data = await request('/account/builder/live-design/controls', {store:context.store, controls, controls_digest:data.controls_digest});
      status.textContent = 'تم الحفظ. استخدم «نشر للموبايل» لتطبيق الإعدادات.';
    } catch (error) { status.textContent = error.message; }
    finally { setBusy(false); }
  });
  reset.addEventListener('click', () => { if (!busy && data) { fill({}); status.textContent = 'تمت استعادة القيم الأصلية في النموذج. اضغط حفظ لتأكيدها.'; } });
  close.addEventListener('click', () => { if (!busy) { ++generation; dialog.close(); } });
  dialog.addEventListener('cancel', event => { if (busy) event.preventDefault(); else ++generation; });
})();
