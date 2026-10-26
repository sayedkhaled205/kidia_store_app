/* category-designer-v4: curated layouts; optional saved name highlight. */
(function (scope) {
  'use strict';
  const shared = {card_width_percent:100, card_height:0, show_arrow:1,
    image_scale:100, image_effect:'none', border_width:0, image_text_gap:10,
    font_size:14, font_weight:600, text_max_lines:2, line_height:125,
    margin_top:0, margin_bottom:0, space_up:0, space_down:0};
  const designs = [
    ['default','Clean list','Clear rows with a photo and name',
      {card_radius:14,card_gap:10,card_style:'outlined',image_size:64,image_shape:'rounded',image_radius:18,image_fit:'contain',text_align:'start'}],
    ['visual_grid','Square cards','Two square cards side by side',
      {grid_columns:2,card_radius:16,card_gap:14,card_style:'outlined',image_size:118,image_shape:'rounded',image_radius:14,image_fit:'contain',text_align:'center'}],
    ['circular_grid','Circle gallery','Light, spacious circles in three columns',
      {grid_columns:3,card_radius:0,card_gap:12,card_style:'no_shadow',image_size:82,image_shape:'circle',image_radius:50,image_fit:'cover',text_align:'center',font_size:13}],
    ['compact_grid','Quick tiles','Compact horizontal tiles for many categories',
      {grid_columns:2,card_radius:12,card_gap:10,card_style:'outlined',image_size:44,image_shape:'rounded',image_radius:20,image_fit:'contain',text_align:'start',font_size:13,image_text_gap:6}],
    ['sidebar','Side menu','Main categories beside their subcategories',
      {grid_columns:2,card_radius:12,card_gap:10,card_style:'no_shadow',image_size:68,image_shape:'rounded',image_radius:16,image_fit:'contain',text_align:'center',font_size:13}],
    ['image_banner','Wide banners','Full-width photos with readable titles',
      {grid_columns:2,card_radius:18,card_gap:14,card_style:'no_shadow',image_size:118,image_shape:'rounded',image_radius:14,image_fit:'cover',text_align:'start',font_size:18}],
    ['top_tabs','Department tabs','Switch departments above a full-width grid',
      {grid_columns:2,card_radius:12,card_gap:12,card_style:'outlined',image_size:100,image_shape:'rounded',image_radius:12,image_fit:'contain',text_align:'center'}],
    ['split_rows','Split image rows','Large photos beside clear category names',
      {grid_columns:2,card_radius:12,card_gap:12,card_style:'no_shadow',image_size:118,image_shape:'square',image_radius:0,image_fit:'contain',text_align:'start',font_size:17}],
    ['grouped_shelves','Grouped shelves','Browse subcategories under each department',
      {grid_columns:2,card_radius:12,card_gap:10,card_style:'outlined',image_size:90,image_shape:'rounded',image_radius:12,image_fit:'contain',text_align:'center',font_size:13}],
    ['text_directory','Text directory','Fast scanning, even without category photos',
      {grid_columns:2,card_radius:0,card_gap:0,card_style:'no_shadow',image_size:64,image_shape:'square',image_radius:0,image_fit:'contain',text_align:'start',font_size:17}]
  ].map(([id,title,description,settings]) => ({id,title,description,settings:{...shared,...settings,category_layout:id}}));
  const q=(root,selector)=>root.querySelector(selector);
  const savedCategories=new WeakMap();
  const el=(doc,tag,cls,text)=>{const item=doc.createElement(tag);if(cls)item.className=cls;if(text!=null)item.textContent=text;return item;};
  function imageUrl(value){try{const u=new URL(String(value||''));return ['https:','http:'].includes(u.protocol)?u.href:'';}catch(_){return '';}}
  function normalize(items) {
    const map=new Map();
    for(const item of Array.isArray(items)?items:[]){const id=Number(item?.id);if(!Number.isSafeInteger(id)||id<1)continue;
      map.set(id,{id,name:String(item.name||''),parent:Number(item.parent)||0,count:Number(item.count)||0,image:imageUrl(item.image_url||item.image)});}
    for(const item of map.values()){let parent=item.parent;const seen=new Set([item.id]);while(parent){if(seen.has(parent)||!map.has(parent)){item.parent=0;break;}seen.add(parent);parent=map.get(parent).parent;}}
    return Array.from(map.values());
  }
  function prepare(root){
    const area=q(root,'.mobishop-category-items');if(!area)return;
    area.querySelectorAll('.mobishop-category-list,.kidia-menu-layout,.kidia-menu-tools').forEach(n=>n.remove());
    area.dataset.menuReady='loading';
    const status=el(root.ownerDocument,'p','kidia-category-source','Loading categories from your connected store…');
    status.setAttribute('role','status');area.append(status);
    installDesigns(root);
    if(!root.dataset.categoryRefreshReady){root.dataset.categoryRefreshReady='1';scope.addEventListener('message',event=>{
      if(event.source!==scope.parent||event.origin!==scope.location.origin||event.data?.type!=='kidia:catalog-update')return;
      refresh(root,event.data.store||{});
    });}
  }
  function hydrate(root,store,settings){
    const area=q(root,'.mobishop-category-items');if(!area)return;
    if(settings?.entries)savedCategories.set(root,settings.entries.filter(([name])=>name.startsWith('categories[')));
    if(!Array.isArray(store.category_items)&&area.querySelector('.mobishop-category-row'))return false;
    const items=normalize(store.category_items);
    const signature=JSON.stringify([store.public_id,items]);
    if(area.dataset.catalogSignature===signature)return false;
    // Only the current connector's category IDs may have form controls. Never
    // clone captured merchant rows, even when the connector returns no records.
    area.querySelectorAll('.mobishop-category-list,.kidia-menu-layout,.kidia-menu-tools').forEach(n=>n.remove());
    area.removeAttribute('data-menu-ready');
    area.dataset.catalogSignature=signature;
    const appearance=q(root,'.kidia-category-appearance');
    if(appearance){const general=q(appearance,'.mobishop-category-general');if(general)appearance.replaceWith(general);}
    const doc=root.ownerDocument;
    const status=q(area,'.kidia-category-source')||el(doc,'p','kidia-category-source');
    status.setAttribute('role','status');
    let host='';try{host=new URL(store.url).hostname;}catch(_){}
    status.textContent=items.length?`${items.length} categories from ${host||'your connected store'}`
      :store.items_error?'Categories are temporarily unavailable. Retrying automatically…':'No categories in the connected store.';
    if(!status.parentNode)area.prepend(status);
    const byParent=new Map();items.forEach(item=>{if(!byParent.has(item.parent))byParent.set(item.parent,[]);byParent.get(item.parent).push(item);});
    function field(card,id,key,value,cls,type='hidden'){
      const input=el(doc,'input',cls);input.type=type;input.name=`categories[${id}][${key}]`;input.value=String(value);card.append(input);return input;
    }
    function level(parent){const list=el(doc,'ul','mobishop-category-list');list.dataset.parentId=String(parent);
      for(const [order,item] of (byParent.get(parent)||[]).entries()){
        const row=el(doc,'li','mobishop-category-row');row.dataset.termId=String(item.id);row.dataset.defaultName=item.name;row.dataset.defaultImage=item.image;
        const card=el(doc,'div','mobishop-category-card');row.append(card);
        card.append(el(doc,'span','dashicons dashicons-move mobishop-category-handle'));
        const artwork=el(doc,'div','mobishop-category-image');if(item.image){const img=el(doc,'img');img.src=item.image;img.alt='';artwork.append(img);}else artwork.append(el(doc,'span','dashicons dashicons-format-image'));card.append(artwork);
        const name=el(doc,'div','mobishop-category-name');const label=el(doc,'label','','App display name');label.htmlFor='category-name-'+item.id;name.append(label);
        const input=field(name,item.id,'name','','mobishop-category-name-input','text');input.id=label.htmlFor;input.placeholder=item.name;
        name.append(el(doc,'small','',item.name));card.append(name);
        field(card,item.id,'order',order,'mobishop-category-order');field(card,item.id,'image_id',0,'mobishop-category-image-id');
        const actions=el(doc,'div','mobishop-category-image-actions');for(const [cls,title] of [['mobishop-category-image-button','Change image'],['mobishop-category-image-clear','Use website image']]){const b=el(doc,'button','button '+cls,title);b.type='button';actions.append(b);}card.append(actions);
        const visibility=el(doc,'label','mobishop-category-visibility mobishop-page-master-toggle');field(visibility,item.id,'hidden',1,'');const check=field(visibility,item.id,'hidden',0,'','checkbox');check.checked=true;check.setAttribute('aria-label','Show '+item.name);card.append(visibility);
        if(byParent.has(item.id)){const children=el(doc,'div','mobishop-category-children');children.hidden=true;children.append(level(item.id));row.append(children);}
        list.append(row);
      }return list;
    }
    area.append(level(0));
    return true;
  }
  function refresh(root,store){
    if(!Array.isArray(store.category_items)||store.items_error&&!store.category_items.length)return;
    const hadRows=Boolean(q(root,'.mobishop-category-row'));
    const draft=hadRows?Array.from(new scope.FormData(root.closest('form')||q(root,'form'))).filter(([name])=>name.startsWith('categories[')):(savedCategories.get(root)||[]);
    const customImages=new Map();root.querySelectorAll('.mobishop-category-row').forEach(row=>{const image=q(row,'.mobishop-category-image img');const id=q(row,'.mobishop-category-image-id');if(image&&Number(id?.value)>0)customImages.set(row.dataset.termId,image.src);});
    const open=Boolean(q(root,'.kidia-category-appearance')?.open);
    if(!hydrate(root,store))return;
    scope.KidiaCategoryMenu?.init();
    const groups=new Map();for(const [name,value] of draft){if(!groups.has(name))groups.set(name,[]);groups.get(name).push(String(value));}
    for(const input of root.querySelectorAll('input[name]')){const values=groups.get(input.name);if(!values)continue;if(input.type==='checkbox'||input.type==='radio')input.checked=values.includes(input.value);else if(!(input.type==='hidden'&&input.name.endsWith('[hidden]')))input.value=values[values.length-1];}
    scope.KidiaCategoryMenu?.restore();
    root.querySelectorAll('.mobishop-category-name-input').forEach(input=>input.dispatchEvent(new Event('input',{bubbles:true})));
    root.querySelectorAll('.mobishop-category-row').forEach(row=>{const src=customImages.get(row.dataset.termId);const box=q(row,'.mobishop-category-image');if(src&&box){const img=el(root.ownerDocument,'img');img.src=src;img.alt='';box.replaceChildren(img);}});
    const appearance=q(root,'.kidia-category-appearance');if(appearance)appearance.open=open;
    q(root,'.mobishop-category-name-input')?.dispatchEvent(new Event('change',{bubbles:true}));
  }
  function installDesigns(root){
    installNameHighlight(root);
    const select=q(root,'[name="category_general[category_layout]"]');if(!select||q(root,'.kidia-category-designs'))return;
    const doc=root.ownerDocument;const current=select.value;
    select.replaceChildren(...designs.map(d=>{const option=el(doc,'option','',d.title);option.value=d.id;return option;}));select.value=current||'default';
    select.hidden=true;select.tabIndex=-1;select.setAttribute('aria-hidden','true');
    const oldLabel=select.closest('label');if(oldLabel){oldLabel.hidden=true;oldLabel.classList.add('kidia-category-layout-field');}
    const section=el(doc,'section','kidia-category-designs');section.append(el(doc,'h3','','Choose a category design'),el(doc,'p','',`${designs.length} useful layouts. Choose the one that fits your catalog.`));
    const grid=el(doc,'div','kidia-category-design-grid');grid.setAttribute('role','group');grid.setAttribute('aria-label','Category designs');section.append(grid);
    function update(){grid.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.design===select.value)));}
    function apply(id){const preset=designs.find(d=>d.id===id);if(!preset)return;
      for(const [key,value] of Object.entries(preset.settings)){
        root.querySelectorAll(`[name="category_general[${key}]"]`).forEach(f=>{if(f.type==='checkbox')f.checked=Boolean(value);else f.value=String(value);});
      }
      update();select.dispatchEvent(new Event('input',{bubbles:true}));select.dispatchEvent(new Event('change',{bubbles:true}));
      select.closest('form')?.dispatchEvent(new CustomEvent('mobishop:dirty',{bubbles:true}));
    }
    for(const design of designs){const button=el(doc,'button','kidia-category-design');button.type='button';button.dataset.design=design.id;
      const sample=el(doc,'span','kidia-category-sample is-'+design.id);sample.setAttribute('aria-hidden','true');for(let i=0;i<6;i++){const tile=el(doc,'i');tile.append(el(doc,'b'),el(doc,'em'));sample.append(tile);}button.append(sample,el(doc,'strong','',design.title),el(doc,'small','',design.description));button.onclick=()=>apply(design.id);grid.append(button);}
    const general=q(root,'.mobishop-category-general');general.prepend(section);select.addEventListener('change',update);root.addEventListener('change',update);update();
    // Keep the hidden form value for saved themes; the gallery is the only picker.
    if(!doc.getElementById('kidia-category-designer-style')){const style=el(doc,'style');style.id='kidia-category-designer-style';style.textContent=`
      .kidia-category-designs{margin:0 0 22px;padding:18px;background:#f6faf9;border:1px solid #cfdfdb;border-radius:16px}.kidia-category-designs h3{margin:0 0 6px!important}.kidia-category-designs p{margin:0 0 16px!important;color:#647873}.kidia-category-design-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.kidia-category-design{padding:12px;border:1px solid #cbded8;border-radius:13px;background:#fff;color:#23433a;text-align:start;cursor:pointer;display:grid;gap:6px;min-width:0}.kidia-category-design[aria-pressed=true]{border:2px solid #287f6d;padding:11px;box-shadow:0 0 0 3px #e2f2ed;background:#f0f9f6}.kidia-category-design:focus-visible{outline:3px solid #319c85;outline-offset:3px}.kidia-category-design strong{font-size:14px}.kidia-category-design small{font-size:12px;line-height:1.45;color:#60756e}.kidia-category-sample{display:grid;gap:5px;background:#eef3f1;border-radius:8px;padding:10px;height:108px;box-sizing:border-box;overflow:hidden}.kidia-category-sample i{display:flex;align-items:center;gap:6px;background:white;border-radius:4px;padding:4px;min-height:0}.kidia-category-sample b{display:block;background:#b3d7ca;width:25%;height:100%;min-height:9px;border-radius:3px}.kidia-category-sample em{display:block;background:#83aa9e;width:45%;height:4px;border-radius:4px}.kidia-category-sample.is-default i:nth-child(n+4){display:none}.kidia-category-sample.is-visual_grid{grid-template-columns:repeat(2,1fr)}.kidia-category-sample.is-visual_grid i{flex-direction:column}.kidia-category-sample.is-visual_grid b{width:100%;flex:1}.kidia-category-sample.is-visual_grid i:nth-child(n+5){display:none}.kidia-category-sample.is-circular_grid{grid-template-columns:repeat(3,1fr)}.kidia-category-sample.is-circular_grid i{flex-direction:column;background:none}.kidia-category-sample.is-circular_grid b{width:25px;height:25px;border-radius:50%}.kidia-category-sample.is-circular_grid em{width:80%}.kidia-category-sample.is-compact_grid{grid-template-columns:repeat(2,1fr)}.kidia-category-sample.is-sidebar{grid-template-columns:30% 1fr 1fr}.kidia-category-sample.is-sidebar i:nth-child(3n+1){background:#c1e0d5}.kidia-category-sample.is-sidebar i{flex-direction:column}.kidia-category-sample.is-sidebar b{width:80%;flex:1}.kidia-category-sample.is-image_banner{grid-template-rows:1fr 1fr}.kidia-category-sample.is-image_banner i{background:linear-gradient(115deg,#85b2a2,#cfdfb9);align-items:end}.kidia-category-sample.is-image_banner b{display:none}.kidia-category-sample.is-image_banner em{background:#fff;width:60%}.kidia-category-sample.is-image_banner i:nth-child(n+3){display:none}.kidia-category-source{color:#44675d;padding:10px 0}.kidia-category-design-grid button:hover{border-color:#287f6d}@media(max-width:700px){.kidia-category-design-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
      .kidia-category-designs button.kidia-category-design{display:grid!important;grid-template-columns:minmax(0,1fr)!important;grid-auto-flow:row!important;align-content:start!important;align-items:start!important;height:auto!important;min-height:195px;white-space:normal!important;gap:6px!important;direction:ltr;text-align:left!important}.kidia-category-designs .kidia-category-sample{display:grid!important;width:100%!important;min-width:0!important;flex:none!important}.kidia-category-designs .kidia-category-design strong,.kidia-category-designs .kidia-category-design small{display:block!important;width:100%!important;white-space:normal!important;text-align:left!important}
      .kidia-category-layout-field{display:none!important}.kidia-category-general select[name="category_general[category_layout]"]{display:none!important}
      .kidia-category-designs{padding:14px}.kidia-category-designs h3{font-size:18px!important}.kidia-category-designs p{font-size:12px!important;margin-bottom:12px!important}
      .kidia-category-design-grid{grid-template-columns:repeat(4,minmax(0,1fr));gap:9px}
      .kidia-category-designs button.kidia-category-design{min-height:158px;padding:9px!important;gap:5px!important;border-width:1px;box-shadow:none}
      .kidia-category-designs button.kidia-category-design[aria-pressed=true]{border-color:#287f6d;box-shadow:inset 0 0 0 1px #287f6d;background:#eef8f4}
      .kidia-category-designs .kidia-category-sample{height:76px;padding:7px;gap:4px}
      .kidia-category-designs .kidia-category-design strong{font-size:12px!important;line-height:1.3}
      .kidia-category-designs .kidia-category-design small{font-size:11px!important;line-height:1.35}
      .kidia-category-sample.is-circular_grid b{width:17px;height:17px;min-height:17px}
      .kidia-category-sample.is-top_tabs{grid-template-columns:repeat(3,1fr);grid-template-rows:12px 1fr 1fr}
      .kidia-category-sample.is-top_tabs:before{content:'';grid-column:1/-1;background:repeating-linear-gradient(90deg,#6b9e8d 0 28%,transparent 28% 34%);border-radius:3px}
      .kidia-category-sample.is-top_tabs i{flex-direction:column}.kidia-category-sample.is-top_tabs b{width:80%;flex:1}
      .kidia-category-sample.is-split_rows{grid-template-rows:1fr 1fr 1fr}.kidia-category-sample.is-split_rows i{flex-direction:row-reverse}.kidia-category-sample.is-split_rows b{width:48%}.kidia-category-sample.is-split_rows i:nth-child(n+4){display:none}
      .kidia-category-sample.is-grouped_shelves{grid-template-columns:repeat(3,1fr);grid-template-rows:8px 1fr 8px 1fr}.kidia-category-sample.is-grouped_shelves:before,.kidia-category-sample.is-grouped_shelves:after{content:'';grid-column:1/-1;background:#83aa9e;width:55%;border-radius:3px}.kidia-category-sample.is-grouped_shelves:after{grid-row:3}.kidia-category-sample.is-grouped_shelves i{flex-direction:column}.kidia-category-sample.is-grouped_shelves b{width:80%;flex:1}
      .kidia-category-sample.is-text_directory{gap:0}.kidia-category-sample.is-text_directory i{border-radius:0;border-bottom:1px solid #cdded8}.kidia-category-sample.is-text_directory b{display:none}.kidia-category-sample.is-text_directory em{width:70%;height:3px}
      @media(max-width:540px){.kidia-category-design-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
    `;doc.head.append(style);}
  }
  function installNameHighlight(root){
    const general=q(root,'.mobishop-category-general');
    if(!general||q(general,'[name="category_general[name_highlight_enabled]"]'))return;
    const doc=root.ownerDocument;
    const anchor=q(general,'[name="category_general[font_color]"]')?.closest('label');
    const toggle=el(doc,'label','','Highlight category names');
    const off=el(doc,'input');off.type='hidden';off.name='category_general[name_highlight_enabled]';off.value='0';
    const input=el(doc,'input');input.type='checkbox';input.name=off.name;input.value='1';
    toggle.append(off,input);
    const colorLabel=el(doc,'label','','Name highlight color');
    const color=el(doc,'input');color.type='color';color.name='category_general[name_highlight_color]';color.value='#eff8f5';colorLabel.append(color);
    if(anchor){anchor.after(toggle,colorLabel);}else{general.append(toggle,colorLabel);}
    // The ordinary form pipeline owns persistence, dirty state and preview updates.
  }
  const api={designs,normalize,prepare,hydrate,refresh,installDesigns};scope.KidiaCategoryDesigner=api;
  if(typeof module!=='undefined')module.exports=api;
})(typeof window==='undefined'?globalThis:window);
