/* Open the exact editor card without saving, navigating the phone, or reloading it. */
(function () {
  'use strict';
  const pages = new Set(['home','category','catalog','product','wishlist','account','checkout','splash']);
  const cards = '.mobishop-builder-block,.mobishop-page-card';
  let pending = null, timer = 0, sequence = 0;
  function identity(card) {
    return card.dataset.chromePart || card.querySelector('.mobishop-block-id')?.value ||
      card.dataset.instanceId || card.dataset.element || card.dataset.libraryId || '';
  }
  function findCard(doc, request) {
    if (request.page === 'splash' && request.target === 'splash')
      return doc.querySelector('.mobishop-splash-builder .mobishop-page-card');
    if (request.page === 'checkout' && request.target === 'checkout')
      return doc.querySelector('.mobishop-checkout-design-panel');
    if (request.page === 'checkout' && request.target.startsWith('field:'))
      return [...doc.querySelectorAll('[data-checkout-field]')].find(card =>
        card.querySelector('[name$="[key]"]')?.value === request.target.slice(6));
    return [...doc.querySelectorAll(cards)].find(card => identity(card) === request.target);
  }
  function expand(card) {
    // Updating only presentation state avoids click handlers which send a
    // reverse focus command or mark merchant forms as edited.
    card.classList.remove('is-collapsed');
    card.hidden = false;
    card.classList.remove('is-wishlist-state-hidden');
    card.classList.add('is-open', 'is-preview-selected');
    const body = card.querySelector(':scope > .mobishop-page-card__body,:scope > .mobishop-builder-block__body');
    if (body) { body.hidden = false; body.style.display = ''; }
    card.querySelectorAll(':scope > .mobishop-page-card__header .mobishop-page-expand,:scope > .mobishop-builder-block__header .mobishop-toggle-block-settings')
      .forEach(button => button.setAttribute('aria-expanded','true'));
  }
  window.addEventListener('mobishop:preview-editor-navigation', () => {
    pending = null; sequence++; clearTimeout(timer);
  });
  function reveal() {
    if (!pending) return;
    const frame = document.getElementById('kidia-central-frame');
    if (!frame || frame.hidden || frame.inert || frame.dataset.screen !== pending.screen) return;
    let doc;
    try { doc = frame.contentDocument; } catch (_) { return; }
    if (!doc) return;
    const card = findCard(doc, pending);
    if (!card) return;
    doc.querySelectorAll('.is-preview-selected').forEach(node => node.classList.remove('is-preview-selected'));
    doc.documentElement.dataset.previewSelectedBlock = pending.target;
    expand(card);
    if (!doc.getElementById('mobishop-preview-inspector-style')) {
      const style = doc.createElement('style'); style.id = 'mobishop-preview-inspector-style';
      style.textContent = '.is-preview-selected{outline:2px solid #78b7aa!important;outline-offset:2px}.is-preview-item-selected{background:#eaf6f2!important;border-radius:8px}';
      (doc.head || doc.documentElement).append(style);
    }
    doc.querySelectorAll('.is-preview-item-selected').forEach(node => node.classList.remove('is-preview-item-selected'));
    const section = pending.item && [...card.querySelectorAll('[data-item-section]')].find(node => node.dataset.itemSection === pending.item);
    if (section) {
      for (let node = section; node && node !== card; node = node.parentElement) {
        if (node.tagName === 'DETAILS') node.open = true;
      }
      section.classList.add('is-preview-item-selected');
    }
    const target = section || card;
    target.scrollIntoView({behavior:'smooth', block:'start', inline:'nearest'});
    // Keyboard users land on the expanded card, never a form input whose value
    // could accidentally change. The phone runtime remains mounted.
    if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex','-1');
    target.focus({preventScroll:true});
    document.dispatchEvent(new CustomEvent('mobishop:preview-settings-opened', {detail:{page:pending.page,target:pending.target}}));
    pending = null; clearTimeout(timer);
  }
  window.addEventListener('message', event => {
    const preview = document.getElementById('kidia-shared-flutter');
    if (event.origin !== location.origin || !preview || event.source !== preview.contentWindow) return;
    let value = event.data;
    if (typeof value === 'string') { try { value = JSON.parse(value); } catch (_) { return; } }
    if (!value || value.type !== 'mobishop-preview-edit' || !pages.has(value.page) ||
        typeof value.target !== 'string' || !value.target || value.target.length > 200 ||
        (value.item != null && (typeof value.item !== 'string' || !/^[a-z_]{1,60}$/.test(value.item)))) return;
    const screen = value.page === 'splash' ? 'splash' : value.page + '-builder';
    pending = {page:value.page,target:value.target,item:value.item,screen};
    const request = ++sequence;
    clearTimeout(timer);
    window.dispatchEvent(new CustomEvent('mobishop:preview-edit-page', {detail:{screen}}));
    reveal();
    if (pending) {
      // A cold editor may still be hydrating. Poll only while this explicit
      // request is pending, with a deadline; later requests cancel old ones.
      const retry = () => {
        if (!pending || request !== sequence) return;
        reveal();
        if (pending && Date.now() < deadline) timer = setTimeout(retry,100);
        else pending = null;
      };
      const deadline = Date.now() + 30000;
      timer = setTimeout(retry,100);
    }
  });
})();
