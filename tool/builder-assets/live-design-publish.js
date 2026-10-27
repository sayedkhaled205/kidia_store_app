(() => {
  'use strict';
  if (document.getElementById('wm-publish-design')) return;
  const shell = document.querySelector('.mobishop-cms-save-theme');
  if (!shell) return;
  const button = document.createElement('button');
  button.id = 'wm-publish-design'; button.type = 'button';
  button.className = 'button button-primary'; button.textContent = 'Publish now';
  button.style.marginInlineStart = '8px'; shell.append(button);
  const style = document.createElement('style');
  style.textContent = `
    #wm-design-dialog{border:1px solid #d8e8e3;border-radius:22px;padding:32px;width:min(360px,90vw);box-sizing:border-box;text-align:center;color:#20413d;background:#fff;box-shadow:0 20px 60px #163c3833;font:15px/1.5 system-ui}
    #wm-design-dialog::backdrop{background:#183d3870}
    #wm-design-dialog h2{font-size:22px;margin:0}
    #wm-design-dialog p{margin:12px 0 0;color:#607b75}
    #wm-design-dialog footer{display:flex;gap:10px;margin-top:26px}
    #wm-design-dialog [hidden]{display:none!important}
    #wm-design-dialog button{flex:1;padding:11px 16px;border:1px solid #bad8d0;border-radius:11px;cursor:pointer;background:#fff;color:#20594e;font:600 14px system-ui}
    #wm-design-dialog button[data-action=publish]{background:var(--web-accent,#217b69);border-color:transparent;color:#fff}
    #wm-design-dialog button:disabled{opacity:.5;cursor:default}
    #wm-design-dialog [data-icon]{display:block;width:48px;height:48px;box-sizing:border-box;margin:0 auto 20px}
    #wm-design-dialog[data-phase=loading] [data-icon],#wm-design-dialog[data-phase=updating] [data-icon]{border:4px solid #e0eee9;border-top-color:var(--web-accent,#217b69);border-radius:50%;animation:wm-publish-spin .8s linear infinite}
    #wm-design-dialog[data-phase=complete] [data-icon]{border-radius:50%;background:#e8f6f0;color:#217b69;font-size:30px;line-height:48px}
    #wm-design-dialog[data-phase=error] p{color:#a33636}
    @keyframes wm-publish-spin{to{transform:rotate(360deg)}}
    @media(prefers-reduced-motion:reduce){#wm-design-dialog [data-icon]{animation-duration:2s!important}}
  `;
  document.head.append(style);
  const dialog = document.createElement('dialog'); dialog.id = 'wm-design-dialog'; dialog.dir = 'ltr';
  dialog.setAttribute('aria-labelledby', 'wm-design-dialog-title');
  dialog.innerHTML = '<div role="status" aria-live="polite"><span data-icon aria-hidden="true" hidden></span><h2 id="wm-design-dialog-title">Update app?</h2><p data-status hidden></p></div><footer><button type="button" data-action="close">Cancel</button><button type="button" data-action="publish" disabled>Update now</button></footer>';
  document.body.append(dialog);
  const status = dialog.querySelector('[data-status]');
  const publish = dialog.querySelector('[data-action=publish]');
  const cancel = dialog.querySelector('[data-action=close]');
  const title = dialog.querySelector('h2');
  const icon = dialog.querySelector('[data-icon]');
  const footer = dialog.querySelector('footer');
  let context, state, busy = false, generation = 0, closeTimer, needsRefresh = false, dirty = 0;
  const storeId = () => new URL(location.href).searchParams.get('store');
  function requireBridge() {
    const bridge = window.MobiShopPublishEdits;
    if (!bridge || typeof bridge.inspect !== 'function' || typeof bridge.begin !== 'function') {
      throw new Error('تعذر التحقق من التعديلات. حدّث الصفحة وحاول مرة أخرى.');
    }
    return bridge;
  }
  async function request(url, body) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);
    try {
    const response = await fetch(url, {method: body ? 'POST' : 'GET', credentials: 'same-origin', cache: 'no-store', signal: controller.signal,
      headers: {Accept: 'application/json', ...(body ? {'Content-Type': 'application/json', 'X-CSRF-TOKEN': context.csrf_token} : {})},
      ...(body ? {body: JSON.stringify(body)} : {})});
    if (!response.ok) {
      if ([401,419].includes(response.status)) throw new Error('انتهت الجلسة. أعد تسجيل الدخول ثم حاول مجددًا.');
      if (response.status === 409) throw new Error('التعديلات اتغيرت. حاول تاني لتحميل آخر نسخة.');
      if (response.status === 422) throw new Error('احفظ كل الصفحات وتأكد من اكتمال تصميم الرئيسية قبل النشر.');
      throw new Error('تعذر تأكيد التحديث. حاول مرة أخرى.');
    }
    return await response.json();
    } catch (error) {
      if (controller.signal.aborted) throw new Error('تعذر تأكيد التحديث في الوقت المحدد. حاول تاني للتحقق من حالة الحفظ والنشر.');
      throw error;
    } finally { clearTimeout(timeout); }
  }
  function render(phase, message = '') {
    dialog.dataset.phase = phase;
    title.textContent = {loading:'Loading…',ready:'Update app?',updating:'Updating…',complete:'Complete',error:'Update failed'}[phase];
    status.textContent = message;
    status.hidden = !message;
    icon.hidden = !['loading','updating','complete'].includes(phase);
    icon.textContent = phase === 'complete' ? '✓' : '';
    footer.hidden = phase === 'updating' || phase === 'complete';
    cancel.disabled = busy;
    publish.textContent = phase === 'error' ? 'Try again' : 'Update now';
    const canPublish = dirty > 0 || (state && state.ready && state.has_changes);
    publish.disabled = busy || phase === 'loading' || (phase !== 'error' && !canPublish);
  }
  async function loadState() {
    const ownGeneration = ++generation;
    const store = storeId(); state = null; context = null; dirty = 0; busy = false;
    needsRefresh = false;
    clearTimeout(closeTimer);
    render('loading');
    try {
      const bridge = requireBridge();
      const ctx = await request(`/account/builder/context?store=${encodeURIComponent(store || '')}`);
      if (ownGeneration !== generation || store !== storeId()) return;
      context = ctx;
      const data = await request(`/account/builder/live-design?store=${encodeURIComponent(store)}`);
      if (ownGeneration !== generation || store !== storeId()) return;
      const inspection = await bridge.inspect(store);
      if (ownGeneration !== generation || store !== storeId()) return;
      state = data; dirty = inspection.dirtyCount;
      render('ready', dirty ? 'سيتم حفظ تعديلات الصفحات قبل النشر: ' + (inspection.pages?.join('، ') || dirty) : (!state.ready ? 'احفظ الصفحات لإكمال التصميم قبل التحديث.' : !state.has_changes ? 'Up to date' : ''));
    } catch (error) {
      if (ownGeneration === generation) { needsRefresh = true; render('error', error.message); }
    }
  }
  button.addEventListener('click', () => {
    if (dialog.open) return;
    loadState();
    dialog.showModal();
  });
  async function submit() {
    if (busy) return;
    // Recheck the server after any failure: a timed-out request may have succeeded.
    if (needsRefresh) { await loadState(); return; }
    if (!context || context.store !== storeId()) return;
    if (!(dirty > 0 || (state && state.ready && state.has_changes))) return;
    const ownGeneration = generation, store = storeId();
    const aborted = () => {
      if (ownGeneration !== generation) return true;
      if (store !== storeId()) { ++generation; dialog.close(); return true; }
      return false;
    };
    busy = true; render('updating');
    let session;
    try {
      const bridge = requireBridge();
      session = await bridge.begin(store);
      if (aborted()) return;
      render('updating', 'جارٍ حفظ التعديلات…');
      await session.save();
      if (aborted()) return;
      session.assertCurrent();
      render('updating');
      const fresh = await request(`/account/builder/live-design?store=${encodeURIComponent(store)}`);
      if (aborted()) return;
      session.assertCurrent();
      if (context.store !== storeId()) return;
      state = fresh; dirty = 0;
      if (!state.ready) throw new Error('احفظ كل الصفحات وتأكد من اكتمال تصميم الرئيسية قبل النشر.');
      if (!state.has_changes) {
        busy = false; render('complete');
        closeTimer = setTimeout(() => { if (ownGeneration === generation && dialog.open) { ++generation; dialog.close(); } }, 1400);
        return;
      }
      const data = await request('/account/builder/live-design/publish', {store: context.store,
        revision: state.revision, draft_digest: state.draft_digest});
      if (aborted()) return;
      session.assertCurrent();
      busy = false;
      state = data; render('complete');
      closeTimer = setTimeout(() => { if (ownGeneration === generation && dialog.open) { ++generation; dialog.close(); } }, 1400);
    } catch (error) {
      if (ownGeneration === generation) { busy = false; needsRefresh = true; render('error', error.message); }
    } finally {
      if (session) { try { session.release(); } catch (_) {} }
    }
  }
  publish.addEventListener('click', submit);
  cancel.addEventListener('click', () => { if (!busy) { ++generation; clearTimeout(closeTimer); dialog.close(); } });
  dialog.addEventListener('cancel', event => { if (busy) event.preventDefault(); else { ++generation; clearTimeout(closeTimer); } });
})();
