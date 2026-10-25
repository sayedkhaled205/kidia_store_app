/* Keep editor selection and the single shared Flutter preview in sync. */
(function () {
  'use strict';
  const documents = new WeakSet();
  const frames = new WeakSet();
  let pendingFocus = 0;

  function mobile() { return document.getElementById('kidia-shared-flutter'); }
  function activeEditor(frame) {
    return frame === document.getElementById('kidia-central-frame') &&
      new URL(frame.src, location.href).searchParams.get('screen') === 'home-builder';
  }
  function send(frame, packet) {
    frame.contentWindow.postMessage(JSON.stringify(packet), location.origin);
  }
  function select(preview, packet) {
    // Existing Flutter bundles expose selection as an equality-filtered state.
    // Clear that state with an unmatched target before replaying a command, so
    // selecting the same card after a manual scroll/navigation still works.
    send(preview, {type: 'mobishop-preview-focus', page: 'home', target: '__preview_focus_reset__'});
    send(preview, packet);
  }
  function focusTarget(editor, target) {
    const preview = mobile();
    if (!preview || !activeEditor(editor) || typeof target !== 'string' || !target) return;
    markSelection(editor.contentDocument, target);
    clearTimeout(pendingFocus);
    const packet = {type: 'mobishop-preview-focus', page: 'home', target};
    const route = preview.contentDocument?.documentElement.getAttribute('data-preview-route');
    if (route && route !== '/') {
      send(preview, {type: 'mobishop-preview-navigate', page: 'home'});
      pendingFocus = setTimeout(() => {
        if (activeEditor(editor) && preview === mobile()) select(preview, packet);
      }, 250);
    } else select(preview, packet);
  }
  function cardId(card) {
    return card.dataset.chromePart || card.querySelector('.mobishop-block-id')?.value || card.dataset.libraryId || '';
  }
  function markSelection(doc, target) {
    doc.documentElement.dataset.previewSelectedBlock = target;
    for (const card of doc.querySelectorAll('.mobishop-builder-block,.mobishop-fixed-chrome-card')) {
      card.classList.toggle('is-preview-selected', cardId(card) === target);
    }
  }
  function bindEditor(frame) {
    const doc = frame.contentDocument;
    if (!doc || documents.has(doc)) return;
    documents.add(doc);
    const style = doc.createElement('style');
    style.textContent = `
      body.kidia-cms-builder-screen .mobishop-builder-block.is-preview-selected,
      body.kidia-cms-builder-screen .mobishop-fixed-chrome-card.is-preview-selected {background:#eaf6f2!important;border-color:#78b7aa!important;box-shadow:inset 3px 0 #318b78!important;}
      body.kidia-cms-builder-screen .is-preview-selected > .mobishop-builder-block__header,
      body.kidia-cms-builder-screen .is-preview-selected > .mobishop-page-card__header {background:#eaf6f2!important;}
    `;
    (doc.head || doc.documentElement).append(style);
    doc.addEventListener('mobishop:home-preview-state', () => {
      const selected = doc.documentElement.dataset.previewSelectedBlock;
      if (selected) markSelection(doc, selected);
    });
    doc.addEventListener('mobishop:home-preview-focus', event => {
      focusTarget(frame, event.detail?.target);
    });
    // Header clicks already emit the event above. Blank card space should also
    // select a block, without hijacking form controls, action buttons or links.
    doc.addEventListener('click', event => {
      if (!activeEditor(frame) || !event.target.closest) return;
      if (event.target.closest('button,input,select,textarea,a,label,[role="button"],[contenteditable="true"],.mobishop-builder-block__header,.mobishop-page-card__header')) return;
      const card = event.target.closest('.mobishop-builder-block,.mobishop-fixed-chrome-card');
      if (!card) return;
      focusTarget(frame, cardId(card));
    });
  }
  function bindPreview(frame) {
    const doc = frame.contentDocument;
    if (!doc || documents.has(doc)) return;
    documents.add(doc);
    // Moving from a field in the editor back to the phone should transfer
    // keyboard/wheel focus without requiring an extra click on the phone.
    doc.addEventListener('pointerover', event => {
      if (!event.relatedTarget) frame.contentWindow.focus();
    });
    doc.addEventListener('keydown', event => {
      if (doc.documentElement.getAttribute('data-preview-route') !== '/') return;
      if (event.target.closest?.('input,textarea,select,[contenteditable="true"]')) return;
      const delta = {ArrowDown: 72, ArrowUp: -72, PageDown: 420, PageUp: -420}[event.key];
      if (!delta) return;
      send(frame, {type: 'mobishop-preview-scroll', page: 'home', deltaY: delta});
      event.preventDefault();
    });
    // Real mouse wheels can be swallowed by CanvasKit/semantics in a scaled
    // iframe. Route Home through its controller once, before engine listeners;
    // do not interfere with text fields, horizontal scrolling, or browser zoom.
    doc.addEventListener('wheel', event => {
      if (doc.documentElement.getAttribute('data-preview-route') !== '/' ||
          event.ctrlKey || event.shiftKey || !event.deltaY ||
          Math.abs(event.deltaX) > Math.abs(event.deltaY) ||
          event.target.closest?.('input,textarea,select,[contenteditable="true"]')) return;
      const unit = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? frame.contentWindow.innerHeight : 1;
      send(frame, {type: 'mobishop-preview-scroll', page: 'home', deltaY: event.deltaY * unit});
      event.preventDefault();
      event.stopImmediatePropagation();
    }, {capture: true, passive: false});
  }
  function scan() {
    if (!window.document) return;
    for (const frame of document.querySelectorAll('iframe')) {
      if (frame.id !== 'kidia-shared-flutter' && frame.id !== 'kidia-central-frame') continue;
      if (!frames.has(frame)) {
        frames.add(frame);
        frame.addEventListener('load', scan);
      }
      try {
        if (new URL(frame.src, location.href).origin !== location.origin) continue;
        if (frame.id === 'kidia-shared-flutter') bindPreview(frame);
        else bindEditor(frame);
      } catch (_) { /* A navigation may temporarily make a frame unavailable. */ }
    }
  }
  new MutationObserver(scan).observe(document.documentElement, {
    subtree: true, childList: true, attributes: true, attributeFilter: ['id', 'src']
  });
  scan();
})();
