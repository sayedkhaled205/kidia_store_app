/* A color field's grid-sized label must not reopen the native picker. */
(function () {
  'use strict';
  if (window.mobishopColorPickerGuardInstalled) return;
  window.mobishopColorPickerGuardInstalled = true;
  const documents = new WeakSet();
  const frames = new WeakSet();

  function blurOutside(doc, target) {
    const active = doc.activeElement;
    if (!active || active === target) return;
    if (active.matches('input[type="color"]')) active.blur();
    else if (active.tagName === 'IFRAME') {
      try { if (active.contentDocument) blurOutside(active.contentDocument, target); } catch (_) {}
    }
  }

  function bindFrame(frame) {
    if (!frames.has(frame)) {
      frames.add(frame);
      frame.addEventListener('load', () => bindFrame(frame));
    }
    try { if (frame.contentDocument) bindDocument(frame.contentDocument); } catch (_) {}
  }

  function bindDocument(doc) {
    if (documents.has(doc) || !doc.documentElement) return;
    documents.add(doc);
    doc.addEventListener('pointerdown', event => blurOutside(document, event.target), true);
    doc.addEventListener('click', event => {
      const target = event.target;
      if (!target.closest || target.closest('input,select,textarea,button,a,[contenteditable="true"]')) return;
      const label = target.closest('label');
      const control = label && label.control;
      if (control && control.matches('input[type="color"]')) {
        // Chromium forwards clicks on label whitespace to its color input.
        // Cancel that default activation only; normal swatch clicks, keyboard
        // activation, and input/change events keep their native behavior.
        event.preventDefault();
        control.blur();
      }
    }, true);
    doc.querySelectorAll('iframe').forEach(bindFrame);
    new MutationObserver(records => {
      for (const record of records) for (const node of record.addedNodes) {
        if (node.nodeType !== 1) continue;
        if (node.tagName === 'IFRAME') bindFrame(node);
        node.querySelectorAll('iframe').forEach(bindFrame);
      }
    }).observe(doc.documentElement, {childList: true, subtree: true});
  }
  bindDocument(document);
}());
