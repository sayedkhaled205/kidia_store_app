/* shared-product-card-controls-v1 */
(function(scope) {
  'use strict';
  function prepare(root) {
    const grid=root.querySelector('[data-element="product_grid"]');
    if(!grid)return;
    const style=grid.querySelector('[name$="[settings][card_style]"]');
    const name=style.name.replace('[card_style]','[share_style_across_app]');
    if(root.querySelector('[name="'+name+'"]'))return;
    const doc=root.ownerDocument, field=doc.createElement('div'), label=doc.createElement('label'), input=doc.createElement('input');
    field.className='mobishop-page-field';field.dataset.setting='share_style_across_app';
    input.type='checkbox';input.name=name;input.value='1';
    const hidden=doc.createElement('input');hidden.type='hidden';hidden.name=name;hidden.value='0';
    label.append(input,doc.createTextNode(' Use this product card throughout the app'));
    const note=doc.createElement('p');note.className='description';note.textContent='When enabled, these card settings also control Home, Wishlist and recommendations. Save, then Publish now.';
    field.append(hidden,label,note);style.closest('.mobishop-page-field').before(field);
  }
  scope.KidiaSharedProductCard={prepare};
})(typeof window==='undefined'?globalThis:window);
