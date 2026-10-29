/* product-option-controls-v1 */
(function(scope) {
  'use strict';
  function prepare(root) {
    root.querySelectorAll('[data-element="variations"] select[name$="[settings][style]"]').forEach(select => {
      if (Array.from(select.options).some(option => option.value === 'tiles')) return;
      const option = root.ownerDocument.createElement('option');
      option.value = 'tiles';
      option.textContent = 'Color photos and compact sizes';
      select.append(option);
    });
  }
  scope.KidiaProductOptions = {prepare};
})(typeof window==='undefined'?globalThis:window);
