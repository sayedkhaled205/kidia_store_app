/* quick-add-footer-controls-v1 */
(function(scope) {
  'use strict';
  function prepare(root) {
    const name='layout[footer][settings][quick_add_layout]';
    if(root.querySelector('[name="'+name+'"]'))return;
    const anchor=root.querySelector('[name="layout[footer][settings][button_shape]"]')?.closest('.mobishop-page-field, label');
    if(!anchor)return;
    const doc=root.ownerDocument, label=doc.createElement('label'), select=doc.createElement('select'), field=doc.createElement('div');
    field.className='mobishop-page-field';field.dataset.setting='quick_add_layout';
    label.textContent='Quick add footer';select.name=name;
    for(const [value,text] of [['button','Add button only'],['wishlist_button','Wishlist beside rounded add button']]) {
      const option=doc.createElement('option');option.value=value;option.textContent=text;select.append(option);
    }
    label.append(select);field.append(label);anchor.after(field);
  }
  scope.KidiaQuickAddFooter={prepare};
})(typeof window==='undefined'?globalThis:window);
