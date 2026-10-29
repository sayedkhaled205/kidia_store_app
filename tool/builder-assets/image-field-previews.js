(function(){
  'use strict';
  if(window.__imageFieldPreviews)return;window.__imageFieldPreviews=true;
  const inputs='input.mobishop-media-url,input.kidia-media-url,input.mobishop-banner-image-url,input.kidia-banner-image-url,input.mobishop-app-header-logo-url,input.kidia-app-header-logo-url,input.mobishop-hero-block-image-url,input.kidia-hero-block-image-url,input[name="setup[logo_url]"],input[data-field="image_url"],input[data-field="logo_url"],input[name$="[image_url]"],input[name$="[logo_url]"],input[name$="[background_image]"],input[name$="[background_image_url]"],input[name$="[poster_url]"]';
  const fields='.kidia-page-field,.kidia-builder-field,.mobishop-page-field,.mobishop-builder-field,[data-field]';
  const items='.mobishop-hero-block-item,.kidia-hero-block-item,.mobishop-repeatable-item,.kidia-repeatable-item,.mobishop-builder-grid,.kidia-builder-grid';
  const buttons='.mobishop-select-hero-block-image,.kidia-page-media-choose,.kidia-select-banner-image,.kidia-select-media,.kidia-select-app-header-logo,.mobishop-page-media-choose,.mobishop-select-banner-image,.mobishop-select-media,.mobishop-select-app-header-logo';
  const previews='img.mobishop-media-preview,img.kidia-media-preview,img.mobishop-page-media-preview,img.kidia-page-media-preview,img.mobishop-banner-image-preview,img.kidia-banner-image-preview,img.mobishop-hero-block-image-preview';
  const style=document.createElement('style');style.textContent=`
    .wm-image-value,.wm-image-label{display:none!important}
    .mobishop-hero-block-item__header,.kidia-hero-block-item__header{height:auto!important;min-height:0!important;padding-bottom:10px!important;box-sizing:border-box}
    .mobishop-repeatable-item-actions .button,.kidia-repeatable-item-actions .button{height:32px!important;min-height:32px!important;padding:0 11px!important;font-size:12px!important;line-height:1.2!important;box-sizing:border-box}
    .wm-image-row{display:flex!important;align-items:center!important;flex-wrap:nowrap!important;gap:12px!important;min-width:0;width:100%;margin:4px 0!important}
    .wm-image-row .wm-image-thumb{display:block!important;width:80px!important;height:64px!important;min-width:80px!important;max-width:80px!important;object-fit:contain!important;background:#f3f7f5;border:1px solid #cbded8;border-radius:9px;padding:4px;box-sizing:border-box;margin:0!important}
    .wm-image-row button{display:inline-flex!important;align-items:center;justify-content:center;white-space:nowrap;flex:0 1 auto;margin:0!important;min-height:40px}
    .wm-image-empty{width:80px;height:64px;min-width:80px;border:1px dashed #b4cfc6;border-radius:9px;display:grid;place-items:center;color:#68867c;font:12px system-ui;text-align:center}
    .wm-image-empty[hidden],.wm-image-row .wm-image-thumb[hidden]{display:none!important}
  `;document.head.append(style);
  const records=new Map();
  function sync(input,record){
    const value=input.value.trim();if(record.value===value)return;record.value=value;
    let url='';try{const parsed=new URL(value,document.baseURI);if(value&&['https:','http:'].includes(parsed.protocol))url=parsed.href;}catch(_){}
    record.image.hidden=!url;record.empty.hidden=!!url;
    record.empty.textContent=url?'Image unavailable':'No image';
    if(url)record.image.src=url;else record.image.removeAttribute('src');
  }
  function enhance(){
    document.querySelectorAll('.mobishop-hero-block-item__header,.kidia-hero-block-item__header').forEach(header=>{
      for(const [key,value]of Object.entries({'height':'auto','min-height':'0','padding-bottom':'10px','box-sizing':'border-box'}))header.style.setProperty(key,value,'important');
    });
    document.querySelectorAll('.mobishop-repeatable-item-actions .button,.kidia-repeatable-item-actions .button').forEach(button=>{
      for(const [key,value]of Object.entries({'height':'32px','min-height':'32px','padding':'0 11px','font-size':'12px','line-height':'1.2','box-sizing':'border-box'}))button.style.setProperty(key,value,'important');
    });
    document.querySelectorAll(inputs).forEach(input=>{
      if(records.has(input)||input.type==='hidden')return;
      const field=input.closest(fields)||input.parentElement;
      if(!field)return;
      const item=input.closest(items);
      let button=field.querySelector(buttons);
      if(!button&&item)button=[...item.querySelectorAll(buttons)].find(b=>!b.closest('.wm-image-row'));
      if(!button)return;
      const old=button.parentElement;
      let image=field.querySelector(previews)||(item&&item.querySelector(previews));
      if(!image)image=document.createElement('img');
      image.classList.add('wm-image-thumb');image.alt='Selected image';
      const empty=document.createElement('span');empty.className='wm-image-empty';
      const row=field.querySelector(':scope > .wm-image-row')||document.createElement('div');row.className='wm-image-row';
      button.textContent='Select Image';
      input.classList.add('wm-image-value');input.tabIndex=-1;
      const label=field.querySelector('label');if(label&&/^(image(?: url)?|logo url|poster image url)$/i.test(label.textContent.trim())){label.classList.add('wm-image-label');row.setAttribute('aria-label',label.textContent.replace(/\s+URL$/i,''));}
      row.replaceChildren(image,empty,button);field.append(row);
      if(old!==field&&!old.contains(input)&&!old.textContent.trim()&&!old.querySelector('input,button,select,textarea,img'))old.hidden=true;
      const record={image,empty,value:null};records.set(input,record);
      image.addEventListener('error',()=>{image.hidden=true;empty.hidden=false;empty.textContent='Image unavailable';});
      input.addEventListener('input',()=>sync(input,record));input.addEventListener('change',()=>sync(input,record));sync(input,record);
    });
    for(const [input,record]of records){if(!input.isConnected)records.delete(input);else sync(input,record);}
  }
  let pending=false;
  const observer=new MutationObserver(()=>{if(!pending){pending=true;requestAnimationFrame(()=>{pending=false;enhance();});}});
  observer.observe(document.body,{childList:true,subtree:true});
  enhance();setInterval(enhance,750);
})();
