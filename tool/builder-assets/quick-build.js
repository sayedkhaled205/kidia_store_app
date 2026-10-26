(() => {
  'use strict';
  if (window.__wooQuickBuildInstalled) return;
  window.__wooQuickBuildInstalled = true;
  const uuid = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
  const storeId = () => new URL(location.href).searchParams.get('store');
  let busy = false, starting = false, polling = false, timer = null, clock = null;
  let modal = null, ui = {}, current = null, offset = 0, connectionError = false, activeStore = null;
  let cancelling = false, cancelInFlight = false, cancelTimer = null, postSent = false;
  const terminal = build => build && ['failed', 'cancelled', 'completed'].includes(build.status);
  const cancelKey = store => 'woo:pending-build-cancel:' + store;
  function rememberCancel(id) { try { sessionStorage.setItem(cancelKey(activeStore), id); } catch (_) {} }
  function pendingCancel(store) { try { return sessionStorage.getItem(cancelKey(store)); } catch (_) { return null; } }
  function forgetCancel() { try { sessionStorage.removeItem(cancelKey(activeStore)); } catch (_) {} }
  function cancelState() {
    ui.cancel.hidden = !busy && !starting && !cancelling;
    ui.cancel.disabled = cancelling;
    ui.cancel.textContent = cancelling ? 'Cancelling…' : 'Cancel build';
    if (cancelling) { ui.status.textContent = 'Stopping the build…'; ui.again.hidden = true; }
  }
  async function cancelBuild() {
    if (cancelInFlight) return;
    cancelling = true; clearTimeout(timer); clearTimeout(cancelTimer); cancelState();
    rememberCancel(current && !terminal(current) ? current.id : 'pending');
    if (!current || terminal(current)) return; // start() will stop before POST, or cancel the accepted request.
    rememberCancel(current.id);
    cancelInFlight = true;
    try {
      const context = await json(`/account/builder/context?store=${encodeURIComponent(activeStore)}`);
      const result = await json(safeLink(current.cancel_url), {method:'POST', keepalive:true,
        headers:{'Content-Type':'application/json','X-CSRF-TOKEN':context.csrf_token}, body:'{}'});
      // Only the server's confirmed terminal status may end cancellation.
      if (result.status === 'cancelled') {
        render({...current, status:'cancelled', progress:0, error:null, stage_label:'Build cancelled', finished_at:new Date().toISOString()});
      } else { await poll(activeStore); }
    } catch (error) {
      if (error.status === 409) {
        ui.status.textContent = 'Waiting for the build service to confirm cancellation…';
        cancelTimer = setTimeout(cancelBuild, 3000);
      } else {
        cancelling = false; cancelState();
        ui.notice.hidden = false;
        ui.notice.textContent = 'Cancellation is not confirmed. The build may still be running. Press Cancel build to retry.';
      }
    } finally { cancelInFlight = false; }
  }
  const steps = ['Queued', 'Preparing', 'Checking', 'Building', 'Publishing', 'Ready'];
  function make(tag, className, text) {
    const el = document.createElement(tag);
    if (className) el.className = className;
    if (text) el.textContent = text;
    return el;
  }
  function ensureDialog() {
    if (modal) return;
    const style = make('style');
    style.textContent = `
      .woo-build-progress{box-sizing:border-box;border:1px solid #bad7d2;border-radius:20px;padding:26px;width:min(520px,calc(100vw - 32px));max-height:calc(100dvh - 32px);overflow:auto;color:#193d36;background:#fff;font:14px/1.55 system-ui;box-shadow:0 18px 70px #1235;text-align:start}
      .woo-build-progress::backdrop{background:#173c3655;backdrop-filter:blur(2px)}
      .woo-build-progress h2{font-size:23px;line-height:1.3;margin:0 0 18px}
      .woo-build-progress p{margin:0}
      .woo-build-progress__head{display:flex;justify-content:space-between;align-items:center;gap:16px}
      .woo-build-progress__stage{font-size:16px;font-weight:700}
      .woo-build-progress__percent{font-size:27px;font-weight:800;color:#207e6b;font-variant-numeric:tabular-nums;white-space:nowrap}
      .woo-build-progress progress{display:block;width:100%;height:10px;margin:12px 0 6px;accent-color:#207e6b;border:0;border-radius:8px;overflow:hidden;background:#e7efed}
      .woo-build-progress progress::-webkit-progress-bar{background:#e7efed;border-radius:8px}
      .woo-build-progress progress::-webkit-progress-value{background:#207e6b;border-radius:8px;transition:width .35s ease}
      .woo-build-progress__hint{color:#68827b;font-size:12px}
      .woo-build-progress__steps{list-style:none;display:grid;grid-template-columns:repeat(6,minmax(0,1fr));direction:rtl;gap:6px;padding:0;margin:18px 0}
      .woo-build-progress__steps li{display:flex;flex-direction:column;align-items:center;justify-content:center;min-width:0;gap:6px;padding:10px 2px;border:1px solid #e1ece8;border-radius:8px;font-size:11px;color:#728780;text-align:center}
      .woo-build-progress__step-number{display:inline-flex;align-items:center;justify-content:center;flex:none;width:26px;height:26px;border-radius:50%;background:#edf2f0;color:#526e65;font-size:13px;font-weight:700;direction:ltr;unicode-bidi:isolate;font-variant-numeric:tabular-nums}
      .woo-build-progress__step-label{direction:ltr;unicode-bidi:isolate;white-space:nowrap}
      .woo-build-progress__steps li[data-state=current] .woo-build-progress__step-number{background:#207e6b;color:#fff}
      .woo-build-progress__steps li[data-state=done] .woo-build-progress__step-number{background:#d9eee6;color:#166451}
      .woo-build-progress__steps li[data-state=done]{color:#267c68;background:#f0f8f5}
      .woo-build-progress__steps li[data-state=current]{color:#166451;background:#e6f4ed;border-color:#69a792;font-weight:700}
      .woo-build-progress__meta{display:flex;flex-wrap:wrap;gap:6px 18px;color:#647c74;font-size:12px}
      .woo-build-progress__notice{background:#fff7e6;color:#805b18;border-radius:8px;padding:10px;margin-top:12px!important;font-size:13px}
      .woo-build-progress__actions{display:flex;flex-wrap:wrap;align-items:center;gap:9px;margin-top:20px}
      .woo-build-progress button,.woo-build-progress a{box-sizing:border-box;display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:8px 16px;border:1px solid #9cc4bb;border-radius:9px;background:#eef7f4;color:#193d36;font:600 13px system-ui;cursor:pointer;text-decoration:none}
      .woo-build-progress a{background:#207e6b;color:white;border-color:#207e6b}
      .woo-build-progress [hidden]{display:none!important}
      .woo-build-progress button:focus-visible,.woo-build-progress a:focus-visible{outline:3px solid #7bc1af;outline-offset:3px}
      @media(max-width:420px){.woo-build-progress{padding:20px}.woo-build-progress__steps{grid-template-columns:minmax(0,1fr);gap:5px}.woo-build-progress__steps li{flex-direction:row;justify-content:flex-start;gap:10px;padding:6px 10px;font-size:12px}}
    `;
    document.head.append(style);
    modal = make('dialog', 'woo-build-progress');
    modal.setAttribute('aria-label', 'Build your app');
    const title = make('h2', '', 'Build your app');
    ui.outputs = make('p', 'woo-build-progress__hint');
    const header = make('div', 'woo-build-progress__head');
    ui.status = make('p', 'woo-build-progress__stage');
    ui.status.setAttribute('role', 'status');
    ui.status.setAttribute('aria-live', 'polite');
    ui.percent = make('span', 'woo-build-progress__percent');
    header.append(ui.status, ui.percent);
    ui.progress = make('progress'); ui.progress.max = 100;
    ui.progress.setAttribute('aria-label', 'Build progress');
    ui.hint = make('p', 'woo-build-progress__hint', 'Estimated progress based on the current build stage.');
    ui.steps = make('ol', 'woo-build-progress__steps');
    steps.forEach((label, i) => {
      const li = make('li'); li.append(make('span', 'woo-build-progress__step-number', String(i + 1)), make('span', 'woo-build-progress__step-label', label));
      ui.steps.append(li);
    });
    const meta = make('div', 'woo-build-progress__meta');
    ui.elapsed = make('span'); ui.checked = make('span'); meta.append(ui.elapsed, ui.checked);
    ui.notice = make('p', 'woo-build-progress__notice'); ui.notice.hidden = true;
    const actions = make('div', 'woo-build-progress__actions');
    ui.link = make('a', '', 'Download app files'); ui.link.hidden = true;
    ui.again = make('button', '', 'Build again'); ui.again.type = 'button'; ui.again.hidden = true;
    ui.again.addEventListener('click', () => start(activeStore, true));
    ui.cancel = make('button', '', 'Cancel build'); ui.cancel.type = 'button'; ui.cancel.hidden = true;
    ui.cancel.addEventListener('click', cancelBuild);
    ui.close = make('button', '', 'Hide progress'); ui.close.type = 'button';
    ui.close.addEventListener('click', () => modal.close());
    actions.append(ui.link, ui.again, ui.cancel, ui.close);
    ui.footer = make('p', 'woo-build-progress__hint', 'Cancel build stops the process. Hide progress only hides this window.');
    modal.append(title, ui.outputs, header, ui.progress, ui.hint, ui.steps, meta, ui.notice, actions, ui.footer);
    document.body.append(modal);
    modal.addEventListener('close', () => { clearTimeout(timer); clearInterval(clock); timer = clock = null; });
  }
  function show(message) {
    ensureDialog();
    ui.status.textContent = message;
    ui.close.textContent = 'Hide progress';
    if (!current) {
      ui.progress.removeAttribute('value'); ui.percent.textContent = '…';
      ui.steps.hidden = true; ui.link.hidden = true; ui.again.hidden = true; ui.hint.hidden = true;
    }
    if (!modal.open) modal.showModal();
    clearInterval(clock); clock = setInterval(tick, 1000); tick();
  }
  function duration(ms) {
    const secs = Math.max(0, Math.floor(ms / 1000));
    return `${Math.floor(secs / 60)}m ${String(secs % 60).padStart(2, '0')}s`;
  }
  function tick() {
    if (!current || cancelling) return;
    const now = Date.now() + offset;
    const terminal = ['failed', 'cancelled', 'completed'].includes(current.status) && !busy;
    const end = terminal && current.finished_at ? Date.parse(current.finished_at) : now;
    const start = Date.parse(current.started_at);
    ui.elapsed.textContent = Number.isFinite(start) ? `Elapsed: ${duration(end - start)}` : '';
    const checked = Date.parse(current.checked_at);
    ui.checked.textContent = Number.isFinite(checked) ? `Last server update: ${duration(now - checked)} ago` : 'Waiting for the first server update';
    const delayed = busy && (connectionError || current.sync_delayed || (Number.isFinite(checked) && now - checked > 90000));
    ui.notice.hidden = !delayed;
    ui.notice.textContent = connectionError ? 'Connection interrupted. Retrying automatically; your build may still be running.' : 'The build service has not sent a recent update. We are checking again; the displayed progress is the last confirmed stage.';
  }
  function safeLink(value) {
    const url = new URL(value, location.origin);
    if (url.origin !== location.origin) throw new Error('Unexpected build link.');
    return url.href;
  }
  function render(build) {
    // A GET already in flight must not resurrect a confirmed cancellation.
    if (current?.id === build.id && current.status === 'cancelled' && build.status !== 'cancelled') return;
    if (terminal(build)) { cancelling = false; forgetCancel(); clearTimeout(cancelTimer); }
    const done = build.status === 'completed' && !!build.download_url;
    ui.close.textContent = done ? 'OK' : 'Hide progress';
    const failed = ['failed', 'cancelled'].includes(build.status);
    current = build; connectionError = false;
    ui.outputs.textContent = build.output_label || '';
    if (build.server_time) offset = Date.parse(build.server_time) - Date.now();
    busy = !done && !failed;
    ui.status.textContent = failed ? (build.error || build.stage_label || 'The build did not complete.') : (build.stage_label || 'Checking build progress…');
    const value = Number(build.progress);
    if (Number.isFinite(value)) { ui.progress.value = done ? 100 : Math.min(95, Math.max(0, value)); ui.percent.textContent = `${ui.progress.value}%`; }
    else { ui.progress.removeAttribute('value'); ui.percent.textContent = '…'; }
    ui.hint.hidden = done || failed;
    ui.steps.hidden = false;
    Array.from(ui.steps.children).forEach((li, i) => {
      li.dataset.state = i < build.step || done ? 'done' : (i === build.step ? 'current' : 'next');
      if (i === build.step) li.setAttribute('aria-current', 'step'); else li.removeAttribute('aria-current');
    });
    ui.link.hidden = !done;
    ui.again.hidden = !done && !failed;
    ui.again.textContent = failed ? 'Try again' : 'Build again';
    if (done) ui.link.href = safeLink(build.download_url);
    else ui.link.removeAttribute('href');
    ui.footer.hidden = !busy;
    cancelState();
    if (build.status === 'cancelled') {
      ui.steps.hidden = true; ui.percent.textContent = ''; ui.progress.hidden = true;
      ui.footer.hidden = false; ui.footer.textContent = 'The build has stopped. Refreshing will not start it again.';
    } else {
      ui.progress.hidden = false; ui.footer.textContent = 'Cancel build stops the process. Hide progress only hides this window.';
    }
    tick();
    if (!busy) { clearTimeout(timer); clearInterval(clock); timer = clock = null; }
  }
  async function json(url, options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);
    try {
      const response = await fetch(url, {...options, credentials:'same-origin', signal:controller.signal, headers:{Accept:'application/json', ...options.headers}});
      const data = await response.json().catch(() => ({}));
      if (!response.ok || data.ok !== true) {
        const error = new Error(data.message || 'Could not update the build.'); error.status = response.status; throw error;
      }
      return data;
    } finally { clearTimeout(timeout); }
  }
  function schedule(store) {
    clearTimeout(timer);
    if (busy && !cancelling && modal.open) timer = setTimeout(() => poll(store), 8000);
  }
  async function poll(store) {
    if (polling) return;
    polling = true;
    try {
      const data = await json(`/account/stores/${encodeURIComponent(store)}/quick-build`);
      if (!data.build) throw new Error('The build request was not found.');
      render(data.build);
    } catch (error) {
      if ([401, 403, 404].includes(error.status)) {
        busy = false; ui.status.textContent = error.status === 401 ? 'Please sign in again to view your build.' : error.message;
        ui.notice.hidden = true; clearInterval(clock);
      } else {
        connectionError = true;
        if (!current) { ui.notice.hidden = false; ui.notice.textContent = 'Waiting for the server. Retrying automatically without starting another build.'; }
        tick();
      }
    } finally { polling = false; schedule(store); }
  }
  async function start(store, forceNew = false) {
    if (!uuid.test(store || '') || starting || cancelling) return;
    activeStore = store;
    show(busy ? 'Checking your build…' : 'Checking for an existing build…');
    if (current && !busy && !forceNew) { render(current); return; }
    if (busy) { clearTimeout(timer); await poll(store); return; }
    starting = true; postSent = false;
    try {
      const existing = await json(`/account/stores/${encodeURIComponent(store)}/quick-build`);
      const active = existing.build && (!['failed', 'cancelled', 'completed'].includes(existing.build.status) || (existing.build.status === 'completed' && !existing.build.download_url));
      if (existing.build && (!forceNew || active)) {
        render(existing.build); schedule(store); return;
      }
      current = null; show('Starting your app build…'); busy = true; cancelState();
      const context = await json(`/account/builder/context?store=${encodeURIComponent(store)}`);
      if (cancelling) { busy = false; cancelling = false; forgetCancel(); ui.status.textContent = 'Build cancelled before it started'; cancelState(); return; }
      postSent = true;
      let result = await json(`/account/stores/${encodeURIComponent(store)}/quick-build`, {
        method:'POST', keepalive:true, headers:{'Content-Type':'application/json','X-CSRF-TOKEN':context.csrf_token}, body:'{}'
      });
      if (result.preparing) {
        // No remote build exists yet. Only this explicit click can continue;
        // refreshing reads status and never recreates this pending intent.
        postSent = false;
        show(result.setup.message);
        let setup = result.setup;
        while (!setup.ready && !cancelling) {
          await new Promise(resolve => setTimeout(resolve, 5000));
          if (cancelling) break;
          const state = await json(`/account/stores/${encodeURIComponent(store)}/quick-build`);
          if (state.build && !terminal(state.build)) {
            render(state.build);
            if (cancelling) await cancelBuild(); else await poll(store);
            return;
          }
          setup = state.setup;
          if (setup?.blocked) { const error = new Error(setup.message); error.status = 409; throw error; }
          if (!setup) throw new Error('Store preparation status is unavailable.');
          ui.status.textContent = setup.message;
        }
        if (cancelling) { busy=false; cancelling=false; forgetCancel(); ui.status.textContent='Build cancelled before it started'; cancelState(); return; }
        // Preparation is complete. Refresh CSRF and send exactly one build request.
        const freshContext = await json(`/account/builder/context?store=${encodeURIComponent(store)}`);
        if (cancelling) { busy=false; cancelling=false; forgetCancel(); ui.status.textContent='Build cancelled before it started'; cancelState(); return; }
        postSent = true;
        result = await json(`/account/stores/${encodeURIComponent(store)}/quick-build`, {
          method:'POST', keepalive:true, headers:{'Content-Type':'application/json','X-CSRF-TOKEN':freshContext.csrf_token}, body:'{}'
        });
        if (result.preparing) { busy=false; postSent=false; ui.status.textContent='The store connection changed during preparation. Try again when it is ready.'; ui.again.textContent='Try again'; ui.again.hidden=false; cancelState(); return; }
      }
      await poll(store);
    } catch (error) {
      // A POST may have reached the server even if the response was lost. Only GET is retried.
      if (cancelling && !postSent) {
        // The interrupted request only checked preparation. There is no remote
        // build to cancel; a failed GET must not leave a disabled Cancel button.
        busy = false; cancelling = false; forgetCancel();
        ui.status.textContent = 'Build cancelled before it started';
        ui.notice.hidden = true; ui.footer.hidden = true; clearInterval(clock);
      } else if (busy && postSent && (!error.status || error.status >= 500)) { connectionError = true; await poll(store); }
      else { busy = false; ui.status.textContent = error.message; ui.notice.hidden = true; ui.footer.hidden = true; ui.again.textContent = 'Try again'; ui.again.hidden = false; clearInterval(clock); }
    } finally {
      starting = false;
      if (cancelling && postSent) await cancelBuild();
      else cancelState();
    }
  }
  window.addEventListener('click', event => {
    const button = event.target instanceof Element ? event.target.closest('button,a') : null;
    if (!button || !/\b(Build Your App|Build app)\b/i.test(button.textContent.trim())) return;
    const formStore = button.closest('form')?.getAttribute('action')?.match(/\/stores\/([^/]+)\/builds(?:\?|$)/)?.[1];
    const store = storeId() || formStore;
    if (window.parent !== window) {
      event.preventDefault(); event.stopImmediatePropagation();
      window.parent.postMessage({type:'woomobile:quick-build'}, location.origin);
    } else if (uuid.test(store || '')) { event.preventDefault(); event.stopImmediatePropagation(); start(store); }
  }, true);
  window.addEventListener('message', event => {
    const frame = document.querySelector('#kidia-central-frame');
    if (event.origin === location.origin && event.source === frame?.contentWindow && event.data?.type === 'woomobile:quick-build') start(storeId());
  });
  async function recoverPendingStart(store, attempt = 0) {
    // The start POST may still be committing when the page is refreshed.
    // Wait using GET only, then stop that build as soon as it becomes visible.
    activeStore = store; cancelling = true; busy = true;
    show('Waiting to confirm the cancelled request…'); cancelState();
    try {
      const data = await json(`/account/stores/${encodeURIComponent(store)}/quick-build`);
      if (data.build && !terminal(data.build)) { render(data.build); await cancelBuild(); return; }
      if (attempt >= 15) {
        cancelling = busy = false; forgetCancel();
        if (data.build) render(data.build);
        else { ui.status.textContent = 'No running build found. No new build was started.'; cancelState(); }
        return;
      }
    } catch (_) { /* A lost connection must not turn into a build request. */ }
    cancelTimer = setTimeout(() => recoverPendingStart(store, attempt + 1), 8000);
  }
  // Resume an active build after refresh; this read-only check never requests a new build.
  if (window.parent === window && uuid.test(storeId() || '')) {
    const store = storeId();
    json(`/account/stores/${encodeURIComponent(store)}/quick-build`).then(data => {
      if (!starting && !modal && pendingCancel(store) === 'pending' && (!data.build || terminal(data.build))) {
        recoverPendingStart(store); return;
      }
      if (!starting && !modal && data.build && !['failed', 'cancelled', 'completed'].includes(data.build.status)) {
        activeStore = store; show('Checking your build…'); render(data.build);
        if (['pending', data.build.id].includes(pendingCancel(store))) cancelBuild(); else schedule(store);
      }
    }).catch(() => {});
  }
})();
