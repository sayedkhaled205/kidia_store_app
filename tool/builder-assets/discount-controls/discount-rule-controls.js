/*!
 * discount-rule-controls.js
 * Adds create/edit/clone controls for FlyCart discount rules inside the
 * WooMobile builder's store-data screen. Reuses the existing read-side
 * summary markup (.mobishop-discount-rules-summary) and survives the
 * screen's periodic refresh by keeping its own dialog outside the
 * refreshed container and using a single delegated click listener.
 */
(function () {
  'use strict';

  if (window.__mdrcLoaded) return;
  window.__mdrcLoaded = true;

  if (!/(?:^|[?&])screen=store-data(?:&|$)/.test(location.search)) return;

  var ENDPOINT_CONTEXT = '/account/builder/context';
  var ENDPOINT_RULES = '/account/builder/discount-rules';
  var SAVE_TIMEOUT_MS = 60000;
  var TARGETS_DEBOUNCE_MS = 250;
  var TARGETS_MAX_RESULTS = 50;

  var uidCounter = 0;

  var TYPE_OPTIONS = [
    { value: 'simple', label: 'Product discount' },
    { value: 'cart', label: 'Cart discount' },
    { value: 'bulk', label: 'Quantity discount' },
    { value: 'set', label: 'Bundle / set price' },
    { value: 'bxgx', label: 'Buy X get X' },
    { value: 'bxgy', label: 'Buy X get Y (automatic gift)' },
    { value: 'shipping', label: 'Free shipping' }
  ];

  document.addEventListener('click', handleDocumentClick, false);

  function handleDocumentClick(event) {
    var target = event.target && event.target.closest ? event.target.closest('[data-discount-action]') : null;
    if (!target || document.querySelector('.mdrc-backdrop')) return;

    var action = target.getAttribute('data-discount-action');
    if (action === 'create') {
      event.preventDefault();
      openCreateDialog(target);
      return;
    }
    if (action === 'edit' || action === 'clone') {
      var row = target.closest('[data-discount-id]');
      if (!row) return;
      event.preventDefault();
      if (action === 'edit') openEditDialog(target, row);
      else openCloneDialog(target, row);
    }
  }

  // ---------------------------------------------------------------------
  // Store / context helpers
  // ---------------------------------------------------------------------

  function getStoreId() {
    try {
      if (window.parent && window.parent !== window && window.parent.location &&
          typeof window.parent.location.search === 'string') {
        var parentStore = new URLSearchParams(window.parent.location.search).get('store');
        if (parentStore) return parentStore;
      }
    } catch (e) {
      // cross-origin parent access blocked; fall back to own query string
    }
    return new URLSearchParams(location.search).get('store') || '';
  }

  function getContext(store, signal) {
    var qs = new URLSearchParams({ store: store });
    return fetch(ENDPOINT_CONTEXT + '?' + qs.toString(), {
      method: 'GET',
      signal: signal,
      credentials: 'same-origin',
      cache: 'no-store',
      headers: { 'Accept': 'application/json' }
    }).then(function (res) {
      return res.json().catch(function () { return null; }).then(function (data) {
        if (!res.ok || !data || typeof data.csrf_token !== 'string' || !data.csrf_token || data.store !== store) {
          throw new Error('CONTEXT_FAILED');
        }
        return data;
      });
    });
  }

  // ---------------------------------------------------------------------
  // Small utilities
  // ---------------------------------------------------------------------

  function uuidv4() {
    if (window.crypto && typeof window.crypto.randomUUID === 'function') {
      return window.crypto.randomUUID();
    }
    var bytes = new Uint8Array(16);
    if (window.crypto && typeof window.crypto.getRandomValues === 'function') {
      window.crypto.getRandomValues(bytes);
    } else {
      for (var i = 0; i < 16; i++) bytes[i] = Math.floor(Math.random() * 256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    var hex = Array.prototype.map.call(bytes, function (b) {
      return ('0' + b.toString(16)).slice(-2);
    });
    return hex.slice(0, 4).join('') + '-' + hex.slice(4, 6).join('') + '-' +
      hex.slice(6, 8).join('') + '-' + hex.slice(8, 10).join('') + '-' + hex.slice(10, 16).join('');
  }

  function toNumericOrRaw(value) {
    var num = Number(value);
    return Number.isFinite(num) ? num : value;
  }

  function formatDateTimeValue(value) {
    if (!value) return '';
    return value.replace('T', ' ');
  }

  // ---------------------------------------------------------------------
  // Modal shell
  // ---------------------------------------------------------------------

  function createModal(titleText, triggerEl) {
    var backdrop = document.createElement('div');
    backdrop.className = 'mdrc-backdrop';

    var dialog = document.createElement('div');
    dialog.className = 'mdrc-dialog';
    dialog.setAttribute('role', 'dialog');
    dialog.setAttribute('aria-modal', 'true');
    dialog.tabIndex = -1;

    var headingId = 'mdrc-heading-' + (++uidCounter);
    var heading = document.createElement('h2');
    heading.id = headingId;
    heading.className = 'mdrc-heading';
    heading.textContent = titleText;
    dialog.setAttribute('aria-labelledby', headingId);

    var errorEl = document.createElement('div');
    errorEl.className = 'mdrc-error';
    errorEl.setAttribute('role', 'alert');
    errorEl.hidden = true;

    var body = document.createElement('div');
    body.className = 'mdrc-body';

    var footer = document.createElement('div');
    footer.className = 'mdrc-footer';

    dialog.appendChild(heading);
    dialog.appendChild(errorEl);
    dialog.appendChild(body);
    dialog.appendChild(footer);
    backdrop.appendChild(dialog);
    document.body.appendChild(backdrop);

    var busy = false;
    var draftLocked = false;
    var closed = false;
    var abortControllers = [];
    var cleanupFns = [];

    function trapFocus(e) {
      if (e.key !== 'Tab') return;
      var focusables = Array.from(dialog.querySelectorAll('button, input, select, textarea, [tabindex]:not([tabindex="-1"])')).filter(function (el) { return !el.disabled && !el.closest('[hidden]') && (!draftLocked || !body.contains(el)); });
      if (!focusables.length) return;
      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }

    function onKeydown(e) {
      if (e.key === 'Escape') {
        e.preventDefault();
        close();
      } else {
        trapFocus(e);
      }
    }

    function onBackdropMouseDown(e) {
      if (e.target === backdrop) close();
    }

    function onBeforeUnload(e) {
      if (!busy && !draftLocked) return;
      e.preventDefault();
      e.returnValue = '';
    }

    document.addEventListener('keydown', onKeydown, true);
    backdrop.addEventListener('mousedown', onBackdropMouseDown);
    window.addEventListener('beforeunload', onBeforeUnload);

    function restoreFocus() {
      if (triggerEl && document.body.contains(triggerEl) && typeof triggerEl.focus === 'function') {
        triggerEl.focus();
        return;
      }
      var screen = document.getElementById('kidia-central-screen');
      var fallbackHeading = screen ? screen.querySelector('h1, h2, h3') : null;
      if (fallbackHeading && typeof fallbackHeading.focus === 'function') {
        if (!fallbackHeading.hasAttribute('tabindex')) fallbackHeading.setAttribute('tabindex', '-1');
        fallbackHeading.focus();
      }
    }

    function close() {
      if (closed) return;
      if (busy || draftLocked) return; // Resolve an uncertain save before discarding its retry key.
      closed = true;
      cleanupFns.forEach(function (fn) {
        try { fn(); } catch (e) { /* ignore cleanup errors */ }
      });
      abortControllers.forEach(function (controller) {
        try { controller.abort(); } catch (e) { /* ignore */ }
      });
      document.removeEventListener('keydown', onKeydown, true);
      backdrop.removeEventListener('mousedown', onBackdropMouseDown);
      window.removeEventListener('beforeunload', onBeforeUnload);
      if (backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
      restoreFocus();
    }

    return {
      dialog: dialog,
      body: body,
      footer: footer,
      setBusy: function (value) { busy = value; },
      isBusy: function () { return busy; },
      setDraftLocked: function (value) {
        draftLocked = value;
        body.inert = value; // Also covers picker results that arrive while locked.
        body.querySelectorAll('input, select, textarea, button').forEach(function (el) { el.disabled = value; });
      },
      showError: function (msg) {
        errorEl.textContent = msg;
        errorEl.hidden = false;
      },
      clearError: function () {
        errorEl.hidden = true;
        errorEl.textContent = '';
      },
      registerAbortController: function (controller) { abortControllers.push(controller); },
      registerCleanup: function (fn) { cleanupFns.push(fn); },
      close: close,
      focusFirst: function () {
        var focusable = dialog.querySelector('input, select, textarea, button');
        if (focusable && typeof focusable.focus === 'function') focusable.focus();
        else dialog.focus();
      }
    };
  }

  function setSaveControls(modal, saveState, buttons, busy) {
    var unresolved = !!saveState.pendingBody;
    modal.setBusy(busy);
    modal.setDraftLocked(busy || unresolved);
    buttons.saveBtn.disabled = busy;
    buttons.cancelBtn.disabled = busy || unresolved;
    buttons.saveBtn.textContent = busy ? 'Saving...' : unresolved ? 'Retry same save' : 'Save';
  }

  function buildFooter(modal) {
    var cancelBtn = document.createElement('button');
    cancelBtn.type = 'button';
    cancelBtn.className = 'mdrc-btn mdrc-btn-secondary';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.addEventListener('click', function () { modal.close(); });

    var saveBtn = document.createElement('button');
    saveBtn.type = 'button';
    saveBtn.className = 'mdrc-btn mdrc-btn-primary';
    saveBtn.textContent = 'Save';

    modal.footer.appendChild(cancelBtn);
    modal.footer.appendChild(saveBtn);

    return { cancelBtn: cancelBtn, saveBtn: saveBtn };
  }

  // ---------------------------------------------------------------------
  // Form field builders
  // ---------------------------------------------------------------------

  function buildTextField(labelText, defaultValue, maxLength, required) {
    var wrap = document.createElement('label');
    wrap.className = 'mdrc-field';
    var span = document.createElement('span');
    span.className = 'mdrc-field-label';
    span.textContent = labelText;
    var input = document.createElement('input');
    input.type = 'text';
    input.value = defaultValue || '';
    if (maxLength) input.maxLength = maxLength;
    if (required) input.required = true;
    wrap.appendChild(span);
    wrap.appendChild(input);
    return { el: wrap, input: input, labelSpan: span };
  }

  function buildSelectField(labelText, options) {
    var wrap = document.createElement('label');
    wrap.className = 'mdrc-field';
    var span = document.createElement('span');
    span.className = 'mdrc-field-label';
    span.textContent = labelText;
    var select = document.createElement('select');
    options.forEach(function (opt) {
      var optionEl = document.createElement('option');
      optionEl.value = opt.value;
      optionEl.textContent = opt.label;
      select.appendChild(optionEl);
    });
    wrap.appendChild(span);
    wrap.appendChild(select);
    return { el: wrap, select: select, labelSpan: span };
  }

  function buildNumberField(labelText, defaultValue, step) {
    var wrap = document.createElement('label');
    wrap.className = 'mdrc-field';
    var span = document.createElement('span');
    span.className = 'mdrc-field-label';
    span.textContent = labelText;
    var input = document.createElement('input');
    input.type = 'number';
    input.step = String(step || 1);
    input.min = '0';
    if (defaultValue !== undefined && defaultValue !== null) input.value = String(defaultValue);
    wrap.appendChild(span);
    wrap.appendChild(input);
    return { el: wrap, input: input, labelSpan: span };
  }

  function buildDateTimeField(labelText) {
    var wrap = document.createElement('label');
    wrap.className = 'mdrc-field';
    var span = document.createElement('span');
    span.className = 'mdrc-field-label';
    span.textContent = labelText;
    var input = document.createElement('input');
    input.type = 'datetime-local';
    wrap.appendChild(span);
    wrap.appendChild(input);
    return { el: wrap, input: input };
  }

  function buildCheckboxRow(labelText, defaultChecked) {
    var wrap = document.createElement('label');
    wrap.className = 'mdrc-checkbox-row';
    var input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = !!defaultChecked;
    var span = document.createElement('span');
    span.textContent = labelText;
    wrap.appendChild(input);
    wrap.appendChild(span);
    return { el: wrap, input: input };
  }

  function buildScopeFieldset(current) {
    var fieldset = document.createElement('fieldset');
    fieldset.className = 'mdrc-fieldset';
    var legend = document.createElement('legend');
    legend.textContent = 'Sales channels';
    fieldset.appendChild(legend);

    var options = [
      { value: 'all', label: 'Website + Mobile app' },
      { value: 'website', label: 'Website only' },
      { value: 'mobile', label: 'Mobile app only' }
    ];
    var name = 'mdrc-scope-' + (++uidCounter);
    options.forEach(function (opt) {
      var label = document.createElement('label');
      label.className = 'mdrc-radio-row';
      var radio = document.createElement('input');
      radio.type = 'radio';
      radio.name = name;
      radio.value = opt.value;
      radio.checked = current === opt.value || (current !== 'website' && current !== 'mobile' && opt.value === 'all');
      var text = document.createElement('span');
      text.textContent = opt.label;
      label.appendChild(radio);
      label.appendChild(text);
      fieldset.appendChild(label);
    });

    return {
      el: fieldset,
      getValue: function () {
        var checked = fieldset.querySelector('input[type="radio"]:checked');
        return checked ? checked.value : 'all';
      }
    };
  }

  // ---------------------------------------------------------------------
  // Target / gift picker (checkbox multi-select with chips)
  // ---------------------------------------------------------------------

  function createPicker(getStoreFn, kindGetter) {
    var root = document.createElement('div');
    root.className = 'mdrc-picker';

    var searchInput = document.createElement('input');
    searchInput.type = 'search';
    searchInput.className = 'mdrc-picker-search';
    searchInput.placeholder = 'Search...';
    searchInput.setAttribute('aria-label', 'Search');

    var resultsList = document.createElement('div');
    resultsList.className = 'mdrc-picker-results';
    resultsList.setAttribute('role', 'group');

    var chipsRow = document.createElement('div');
    chipsRow.className = 'mdrc-picker-chips';

    var clearBtn = document.createElement('button');
    clearBtn.type = 'button';
    clearBtn.className = 'mdrc-picker-clear';
    clearBtn.textContent = 'Clear all';
    clearBtn.hidden = true;

    root.appendChild(searchInput);
    root.appendChild(resultsList);
    root.appendChild(chipsRow);
    root.appendChild(clearBtn);

    var selected = new Map(); // numeric id -> label
    var seq = 0;
    var currentController = null;
    var debounceTimer = null;

    function renderChips() {
      chipsRow.textContent = '';
      selected.forEach(function (label, id) {
        var chip = document.createElement('span');
        chip.className = 'mdrc-chip';
        var text = document.createElement('span');
        text.textContent = label;
        var removeBtn = document.createElement('button');
        removeBtn.type = 'button';
        removeBtn.className = 'mdrc-chip-remove';
        removeBtn.setAttribute('aria-label', 'Remove ' + label);
        removeBtn.textContent = 'x';
        removeBtn.addEventListener('click', function () {
          selected.delete(id);
          renderChips();
          syncCheckboxes();
        });
        chip.appendChild(text);
        chip.appendChild(removeBtn);
        chipsRow.appendChild(chip);
      });
      clearBtn.hidden = selected.size === 0;
    }

    function syncCheckboxes() {
      var boxes = resultsList.querySelectorAll('input[type="checkbox"]');
      boxes.forEach(function (box) {
        box.checked = selected.has(Number(box.value));
      });
    }

    clearBtn.addEventListener('click', function () {
      selected.clear();
      renderChips();
      syncCheckboxes();
    });

    function renderResults(items) {
      resultsList.textContent = '';
      if (!items.length) {
        var empty = document.createElement('p');
        empty.className = 'mdrc-picker-empty';
        empty.textContent = 'No results';
        resultsList.appendChild(empty);
        return;
      }
      items.forEach(function (item) {
        var id = Number(item.id);
        if (!Number.isFinite(id)) return;
        var label = document.createElement('label');
        label.className = 'mdrc-picker-item';
        var box = document.createElement('input');
        box.type = 'checkbox';
        box.value = String(id);
        box.checked = selected.has(id);
        var itemLabel = String(item.label != null ? item.label : id);
        box.addEventListener('change', function () {
          if (box.checked) selected.set(id, itemLabel);
          else selected.delete(id);
          renderChips();
        });
        var text = document.createElement('span');
        text.textContent = itemLabel;
        label.appendChild(box);
        label.appendChild(text);
        resultsList.appendChild(label);
      });
    }

    function doSearch(term) {
      seq += 1;
      var mySeq = seq;
      if (currentController) {
        try { currentController.abort(); } catch (e) { /* ignore */ }
      }
      var controller = new AbortController();
      currentController = controller;

      var qs = new URLSearchParams({
        store: getStoreFn(),
        operation: 'targets',
        kind: kindGetter(),
        search: term
      });

      fetch(ENDPOINT_RULES + '?' + qs.toString(), {
        method: 'GET',
        credentials: 'same-origin',
        cache: 'no-store',
        headers: { 'Accept': 'application/json' },
        signal: controller.signal
      }).then(function (res) {
        return res.json().catch(function () { return null; }).then(function (data) {
          return { res: res, data: data };
        });
      }).then(function (result) {
        if (mySeq !== seq) return; // superseded by a newer search
        if (!result.res.ok || !result.data || result.data.ok !== true || !Array.isArray(result.data.items)) {
          renderResults([]);
          return;
        }
        renderResults(result.data.items.slice(0, TARGETS_MAX_RESULTS));
      }).catch(function (err) {
        if (err && err.name === 'AbortError') return;
        if (mySeq !== seq) return;
        renderResults([]);
      });
    }

    searchInput.addEventListener('input', function () {
      var term = searchInput.value;
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () { doSearch(term); }, TARGETS_DEBOUNCE_MS);
    });

    renderChips();
    doSearch('');

    return {
      el: root,
      getSelectedIds: function () { return Array.from(selected.keys()); },
      destroy: function () {
        ++seq; // Ignore any response already resolving when the dialog closes.
        if (currentController) {
          try { currentController.abort(); } catch (e) { /* ignore */ }
        }
        if (debounceTimer) clearTimeout(debounceTimer);
      }
    };
  }

  // ---------------------------------------------------------------------
  // Save pipeline (shared by update / clone / create)
  // ---------------------------------------------------------------------

  function performSave(modal, saveState, store, payloadBase, buttons) {
    if (modal.isBusy()) return;
    modal.clearError();

    // Keep the exact body, not just its UUID: the original request may already have committed.
    var requestBody = saveState.pendingBody || JSON.stringify(Object.assign({}, payloadBase, { request_id: uuidv4() }));
    var payload = JSON.parse(requestBody);

    setSaveControls(modal, saveState, buttons, true);

    var controller = new AbortController();
    modal.registerAbortController(controller);
    var timedOut = false;
    var timer = setTimeout(function () { timedOut = true; controller.abort(); }, SAVE_TIMEOUT_MS);
    getContext(store, controller.signal).then(function (ctx) {
      saveState.pendingBody = requestBody;
      return fetch(ENDPOINT_RULES, {
        method: 'POST',
        credentials: 'same-origin',
        cache: 'no-store',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-TOKEN': ctx.csrf_token
        },
        body: requestBody,
        signal: controller.signal
      }).then(function (res) {
        return res.json().catch(function () { return null; }).then(function (data) {
          return { res: res, data: data };
        });
      });
    }).then(function (result) {
      clearTimeout(timer);
      var saved = result.res.ok && result.data && result.data.ok === true;
      var rejected = result.res.status === 409 || result.res.status === 422;
      if (saved || rejected) saveState.pendingBody = null;
      setSaveControls(modal, saveState, buttons, false);
      if (saved) {
        var savedId = result.data.id != null ? result.data.id : payload.id;
        modal.close();
        document.dispatchEvent(new CustomEvent('mobishop:discount-saved', { detail: { id: savedId } }));
      } else {
        var msg = (result.data && typeof result.data.message === 'string' && result.data.message)
          ? result.data.message
          : 'Could not save the discount. Please try again.';
        modal.showError(rejected ? msg : uncertainSaveMessage());
      }
    }).catch(function (err) {
      clearTimeout(timer);
      setSaveControls(modal, saveState, buttons, false);
      if (saveState.pendingBody) {
        modal.showError(uncertainSaveMessage());
      } else if (timedOut) {
        modal.showError('The connection timed out before saving. Please try again.');
      } else {
        modal.showError('Could not save the discount. Please check your connection and try again.');
      }
    });
  }

  function uncertainSaveMessage() {
    return 'Saving is not confirmed. Use "Retry same save" to check the result. Editing and closing stay locked to avoid a duplicate.';
  }

  // ---------------------------------------------------------------------
  // Dialog: edit (update scope/enabled only)
  // ---------------------------------------------------------------------

  function openEditDialog(triggerEl, row) {
    var id = row.getAttribute('data-discount-id');
    var revision = row.getAttribute('data-discount-revision');
    var channel = row.getAttribute('data-discount-channel') || 'all';
    var enabled = row.getAttribute('data-discount-enabled') === '1';
    var title = row.getAttribute('data-discount-title') || '';
    var store = getStoreId();

    var modal = createModal('Control offer', triggerEl);

    var titleLine = document.createElement('p');
    titleLine.className = 'mdrc-readonly-title';
    titleLine.appendChild(document.createTextNode('Offer: '));
    var titleStrong = document.createElement('strong');
    titleStrong.textContent = title;
    titleLine.appendChild(titleStrong);
    modal.body.appendChild(titleLine);

    var form = document.createElement('form');
    form.className = 'mdrc-form';
    form.addEventListener('submit', function (e) { e.preventDefault(); });

    var scopeFieldset = buildScopeFieldset(channel);
    form.appendChild(scopeFieldset.el);

    var enabledRow = buildCheckboxRow('Enabled', enabled);
    form.appendChild(enabledRow.el);

    var note = document.createElement('p');
    note.className = 'mdrc-note';
    note.textContent = 'Website only stops this discount in the app. Turning Enabled off stops it in both channels. Schedule and conditions stay unchanged.';
    form.appendChild(note);

    modal.body.appendChild(form);

    var saveState = {};
    var buttons = buildFooter(modal);
    buttons.saveBtn.addEventListener('click', function () {
      if (saveState.pendingBody) return performSave(modal, saveState, store, null, buttons);
      if (!form.reportValidity()) return;
      var payloadBase = {
        store: store,
        operation: 'update',
        id: toNumericOrRaw(id),
        revision: revision,
        channel: scopeFieldset.getValue(),
        enabled: enabledRow.input.checked
      };
      performSave(modal, saveState, store, payloadBase, buttons);
    });

    modal.focusFirst();
  }

  // ---------------------------------------------------------------------
  // Dialog: clone
  // ---------------------------------------------------------------------

  function openCloneDialog(triggerEl, row) {
    var id = row.getAttribute('data-discount-id');
    var revision = row.getAttribute('data-discount-revision');
    var originalTitle = row.getAttribute('data-discount-title') || '';
    var store = getStoreId();

    var modal = createModal('Clone discount', triggerEl);

    var form = document.createElement('form');
    form.className = 'mdrc-form';
    form.addEventListener('submit', function (e) { e.preventDefault(); });

    var titleField = buildTextField('Title', originalTitle + ' (copy)', 200, true);
    form.appendChild(titleField.el);

    var scopeFieldset = buildScopeFieldset('mobile');
    form.appendChild(scopeFieldset.el);

    var enabledRow = buildCheckboxRow('Enabled', false);
    form.appendChild(enabledRow.el);

    var note = document.createElement('p');
    note.className = 'mdrc-note';
    note.textContent = 'All existing conditions are copied to the new offer. The original offer is not changed.';
    form.appendChild(note);

    modal.body.appendChild(form);

    var saveState = {};
    var buttons = buildFooter(modal);
    buttons.saveBtn.addEventListener('click', function () {
      if (saveState.pendingBody) return performSave(modal, saveState, store, null, buttons);
      if (!form.reportValidity()) return;
      var titleValue = titleField.input.value.trim();
      if (!titleValue) {
        modal.showError('Title is required.');
        return;
      }
      var payloadBase = {
        store: store,
        operation: 'clone',
        id: toNumericOrRaw(id),
        revision: revision,
        title: titleValue,
        channel: scopeFieldset.getValue(),
        enabled: enabledRow.input.checked
      };
      performSave(modal, saveState, store, payloadBase, buttons);
    });

    modal.focusFirst();
  }

  // ---------------------------------------------------------------------
  // Dialog: create
  // ---------------------------------------------------------------------

  function openCreateDialog(triggerEl) {
    var store = getStoreId();
    var modal = createModal('Create discount', triggerEl);

    var form = document.createElement('form');
    form.className = 'mdrc-form mdrc-form-grid';
    form.addEventListener('submit', function (e) { e.preventDefault(); });

    var titleField = buildTextField('Title', '', 200, true);
    form.appendChild(titleField.el);

    var scopeFieldset = buildScopeFieldset('mobile');
    form.appendChild(scopeFieldset.el);

    var enabledRow = buildCheckboxRow('Enabled', false);
    form.appendChild(enabledRow.el);

    var typeField = buildSelectField('Discount type', TYPE_OPTIONS);
    form.appendChild(typeField.el);

    var targetField = buildSelectField('Applies to', [
      { value: 'all', label: 'All products' },
      { value: 'products', label: 'Specific products' },
      { value: 'categories', label: 'Specific categories' }
    ]);
    form.appendChild(targetField.el);

    var targetPickerWrap = document.createElement('div');
    targetPickerWrap.className = 'mdrc-picker-wrap';
    form.appendChild(targetPickerWrap);
    var targetPicker = null;

    function rebuildTargetPicker() {
      if (targetPicker) {
        targetPicker.destroy();
        targetPickerWrap.textContent = '';
        targetPicker = null;
      }
      var targetValue = targetField.select.value;
      if (targetValue === 'products' || targetValue === 'categories') {
        targetPicker = createPicker(function () { return store; }, function () { return targetValue; });
        targetPickerWrap.appendChild(targetPicker.el);
        targetPickerWrap.hidden = false;
      } else {
        targetPickerWrap.hidden = true;
      }
    }

    targetField.select.addEventListener('change', rebuildTargetPicker);
    rebuildTargetPicker();

    var discountKindField = buildSelectField('Discount kind', [
      { value: 'percentage', label: 'Percentage' },
      { value: 'flat', label: 'Flat amount' }
    ]);
    form.appendChild(discountKindField.el);

    var valueField = buildNumberField('Value', '', 0.01);
    form.appendChild(valueField.el);

    var minQtyField = buildNumberField('Minimum quantity', 1, 1);
    form.appendChild(minQtyField.el);

    var freeQtyField = buildNumberField('Free quantity', 1, 1);
    form.appendChild(freeQtyField.el);

    var giftPickerWrap = document.createElement('div');
    giftPickerWrap.className = 'mdrc-picker-wrap';
    var giftLabel = document.createElement('p');
    giftLabel.className = 'mdrc-field-label';
    giftLabel.textContent = 'Gift product (must be a simple product or a specific variation)';
    giftPickerWrap.appendChild(giftLabel);
    form.appendChild(giftPickerWrap);
    var giftPicker = createPicker(function () { return store; }, function () { return 'products'; });
    giftPickerWrap.appendChild(giftPicker.el);

    var dateFromField = buildDateTimeField('Start date (optional)');
    var dateToField = buildDateTimeField('End date (optional)');
    form.appendChild(dateFromField.el);
    form.appendChild(dateToField.el);

    var dateNote = document.createElement('p');
    dateNote.className = 'mdrc-note mdrc-note-full';
    dateNote.textContent = "Dates use your store's local timezone.";
    form.appendChild(dateNote);

    modal.body.appendChild(form);
    modal.registerCleanup(function () {
      if (targetPicker) targetPicker.destroy();
      giftPicker.destroy();
    });

    function updateVisibility() {
      var type = typeField.select.value;
      if (type === 'shipping') { targetField.select.value = 'all'; rebuildTargetPicker(); }
      targetField.el.hidden = type === 'shipping';
      var showKindValue = type === 'simple' || type === 'cart' || type === 'bulk' || type === 'set';

      discountKindField.el.hidden = !showKindValue || type === 'set';
      valueField.el.hidden = !showKindValue;
      valueField.labelSpan.textContent = type === 'set' ? 'Set price' : 'Value';

      var showMinQty = type === 'bulk' || type === 'set' || type === 'bxgx' || type === 'bxgy';
      minQtyField.el.hidden = !showMinQty;
      if (type === 'bxgx' || type === 'bxgy') minQtyField.labelSpan.textContent = 'Buy quantity';
      else if (type === 'set') minQtyField.labelSpan.textContent = 'Bundle quantity';
      else minQtyField.labelSpan.textContent = 'Minimum quantity';

      var showFreeQty = type === 'bxgx' || type === 'bxgy';
      freeQtyField.el.hidden = !showFreeQty;

      giftPickerWrap.hidden = type !== 'bxgy';
    }

    typeField.select.addEventListener('change', updateVisibility);
    updateVisibility();

    var saveState = {};
    var buttons = buildFooter(modal);
    buttons.saveBtn.addEventListener('click', function () {
      if (saveState.pendingBody) return performSave(modal, saveState, store, null, buttons);
      modal.clearError();
      if (!form.reportValidity()) return;

      var type = typeField.select.value;
      var targetValue = targetField.select.value;
      var titleValue = titleField.input.value.trim();
      if (!titleValue) {
        modal.showError('Title is required.');
        return;
      }

      var ids = [];
      if (targetValue === 'products' || targetValue === 'categories') {
        ids = targetPicker ? targetPicker.getSelectedIds() : [];
        if (!ids.length) {
          modal.showError('Select at least one item for the chosen target.');
          return;
        }
      }

      var payloadBase = {
        store: store,
        operation: 'create',
        title: titleValue,
        channel: scopeFieldset.getValue(),
        enabled: enabledRow.input.checked,
        type: type,
        target: targetValue,
        ids: ids
      };

      if (type === 'simple' || type === 'cart' || type === 'bulk') {
        var value = parseFloat(valueField.input.value);
        if (!(value > 0)) {
          modal.showError('Enter a value greater than zero.');
          return;
        }
        var kind = discountKindField.select.value;
        if (kind === 'percentage' && value > 100) {
          modal.showError('Percentage value cannot exceed 100.');
          return;
        }
        payloadBase.discount_kind = kind;
        payloadBase.value = value;
      } else if (type === 'set') {
        var setValue = parseFloat(valueField.input.value);
        if (!(setValue > 0)) {
          modal.showError('Enter a set price greater than zero.');
          return;
        }
        payloadBase.discount_kind = 'fixed_set_price';
        payloadBase.value = setValue;
      }

      if (type === 'bulk' || type === 'set' || type === 'bxgx' || type === 'bxgy') {
        var minQty = parseInt(minQtyField.input.value, 10);
        if (!(minQty >= 1) || Number(minQtyField.input.value) !== minQty) {
          modal.showError('Minimum quantity must be at least 1.');
          return;
        }
        payloadBase.min_qty = minQty;
      }

      if (type === 'bxgx' || type === 'bxgy') {
        var freeQty = parseInt(freeQtyField.input.value, 10);
        if (!(freeQty >= 1) || Number(freeQtyField.input.value) !== freeQty) {
          modal.showError('Free quantity must be at least 1.');
          return;
        }
        payloadBase.free_qty = freeQty;
      }

      if (type === 'bxgy') {
        var giftIds = giftPicker.getSelectedIds();
        if (!giftIds.length) {
          modal.showError('Select a gift product.');
          return;
        }
        payloadBase.gift_ids = giftIds;
      }

      var dateFrom = formatDateTimeValue(dateFromField.input.value);
      var dateTo = formatDateTimeValue(dateToField.input.value);
      if (dateFrom) payloadBase.date_from = dateFrom;
      if (dateTo) payloadBase.date_to = dateTo;

      performSave(modal, saveState, store, payloadBase, buttons);
    });

    modal.focusFirst();
  }
})();
