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
  function bindEditor(frame) {
    const doc = frame.contentDocument;
    if (!doc || documents.has(doc)) return;
    documents.add(doc);
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
      focusTarget(frame, card.dataset.chromePart ||
        card.querySelector('.mobishop-block-id')?.value || card.dataset.libraryId || '');
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
    // Flutter handles wheel/touch input itself. Do not cancel those events or
    // relay them a second time: the persistent runtime also hosts other pages.
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
