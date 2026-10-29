/* quick-add-footer-controls-v1 */
(function(scope) {
  'use strict';
  function prepare(root) {
    const name='layout[footer][settings][quick_add_layout]';
    if(root.querySelector('[name="'+name+'"]'))return;
    const anchor=root.querySelector('[name="layout[footer][settings][button_shape]"]')?.closest('label');
    if(!anchor)return;
    const doc=root.ownerDocument, label=doc.createElement('label'), select=doc.createElement('select');
    label.textContent='Quick add footer';select.name=name;
    for(const [value,text] of [['button','Add button only'],['wishlist_button','Wishlist beside rounded add button']]) {
      const option=doc.createElement('option');option.value=value;option.textContent=text;select.append(option);
    }
    label.append(select);anchor.after(label);
  }
  scope.KidiaQuickAddFooter={prepare};
})(typeof window==='undefined'?globalThis:window);
