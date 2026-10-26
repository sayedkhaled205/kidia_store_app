/* Product card outlines share the merchant identity and the normal saved form. */
(function (scope) {
  'use strict';
  const roots = new WeakMap();
  const valid = value => /^#[0-9a-f]{6}$/i.test(String(value || ''));
  const selector = 'select[name$="[settings][card_style]"]';
  function prepare(root, identity) {
    let state = roots.get(root);
    if (!state) {
      state = {brand: '#2F806E'};
      roots.set(root, state);
      root.addEventListener('change', event => {
        if (event.target.matches(selector)) refresh(root);
        if (event.target.name?.endsWith('[card_outline_color]')) delete event.target.dataset.outlineBrandDefault;
      });
      if (scope.MutationObserver) new scope.MutationObserver(() => refresh(root)).observe(root, {childList: true, subtree: true});
    }
    if (valid(identity?.primary_color)) state.brand = identity.primary_color;
    refresh(root);
  }
  function refresh(root) {
    const state = roots.get(root);
    if (!state) return;
    root.querySelectorAll(selector).forEach(style => {
      const card = style.closest('[data-element],[data-type]');
      const type = card?.dataset.element || card?.dataset.type;
      if (!['product_grid', 'product_carousel', 'wishlist_grid'].includes(type)) return;
      const name = style.name.replace('[card_style]', '[card_outline_color]');
      let field = Array.from(card.querySelectorAll('input[name]')).find(input => input.name === name);
      const anchor = style.closest('.mobishop-page-field,.mobishop-builder-field') || style.closest('label');
      if (!anchor) return;
      let wrapper;
      if (!field) {
        wrapper = root.ownerDocument.createElement('div');
        wrapper.className = anchor.className || 'mobishop-page-field';
        const label = root.ownerDocument.createElement('label');
        label.textContent = 'Outline color';
        field = root.ownerDocument.createElement('input');
        field.type = 'color'; field.name = name; field.value = state.brand;
        field.setAttribute('aria-label', 'Outline color');
        field.dataset.outlineBrandDefault = '1';
        wrapper.append(label, field); anchor.after(wrapper);
      } else wrapper = field.closest('[data-product-outline-field],.mobishop-page-field,.mobishop-builder-field');
      if (!wrapper) return;
      wrapper.dataset.productOutlineField = '1';
      if (field.dataset.outlineBrandDefault && field.value.toLowerCase() !== state.brand.toLowerCase()) field.value = state.brand;
      const hidden = style.value !== 'outlined';
      if (wrapper.hidden !== hidden) wrapper.hidden = hidden;
      wrapper.style.display = hidden ? 'none' : '';
      // Keep the color beside Card style even when the legacy section grouper moves fields.
      if (anchor.nextElementSibling !== wrapper) anchor.after(wrapper);
    });
  }
  scope.KidiaProductOutline = {prepare, refresh};
})(typeof window === 'undefined' ? globalThis : window);
