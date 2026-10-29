(function(scope){
  'use strict';
  const allowed=/^\/(?:products|categories(?:\/[1-9][0-9]*)?|product\/[1-9][0-9]*|brand\/[1-9][0-9]*|brands|collection\/[a-zA-Z0-9_%\-]+|search|wishlist|cart|checkout|account)?$/;
  function pageLink(store,location,catalog){
    const base=new URL(store);
    if(base.protocol!=='https:'||base.username||base.password)throw Error('Store connection is unavailable.');
    const path=location==='/cms-preview/checkout'?'/checkout':location;
    if(typeof path!=='string'||!path.startsWith('/')||path.startsWith('//')||path.includes('\\'))throw Error('Open a customer page in the preview first.');
    const route=new URL(path,'https://preview.invalid');
    if(!allowed.test(route.pathname)||route.hash)throw Error('This design screen has no customer link.');
    for(const key of [...route.searchParams.keys()])if(!['q','name','collection','brand','view'].includes(key))route.searchParams.delete(key);
    if(catalog){
      if(catalog.length>1600)throw Error('Too many selections for one notification link. Reduce the filters and try again.');
      route.searchParams.set('view',catalog);
    }
    if((route.pathname+route.search).length>1700)throw Error('Too many selections for one notification link. Reduce the filters and try again.');
    base.search='';base.hash='';
    base.searchParams.set('mobishop_page',route.pathname+route.search);
    if(base.href.length>1900)throw Error('Too many selections for one notification link. Reduce the filters and try again.');
    return base.href;
  }
  if(typeof module!=='undefined'&&module.exports){module.exports={pageLink};return;}
  if(scope.__previewPageLinks)return;scope.__previewPageLinks=true;
  let storeUrl='',loading=false;
  const button=document.createElement('button');button.type='button';button.id='mobishop-copy-page-link';
  button.textContent='Copy page link';button.title='Copy this app page and its filters for a push notification';
  button.style.cssText='position:fixed;z-index:1200;height:34px;border:1px solid #b9d8cf;border-radius:9px;background:white;color:#207c68;font:600 13px system-ui;cursor:pointer;box-shadow:0 2px 8px #173c3010;';
  button.hidden=true;document.body.append(button);
  const status=document.createElement('div');status.setAttribute('role','status');
  status.style.cssText='position:fixed;z-index:2000;bottom:22px;left:50%;transform:translateX(-50%);background:#174d40;color:white;border-radius:12px;padding:12px 20px;max-width:80vw;';status.hidden=true;document.body.append(status);
  let timer;function notice(text){status.textContent=text;status.hidden=false;clearTimeout(timer);timer=setTimeout(()=>status.hidden=true,5000);}
  async function loadStore(){
    if(loading||storeUrl)return;loading=true;
    try{
      const store=new URL(location.href).searchParams.get('store');if(!store)return;
      const r=await fetch('/account/builder/state?'+new URLSearchParams({store,screen:'setup'}),{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json'}});
      if(!r.ok)throw Error('Store connection unavailable');
      const p=await r.json(),d=p.store_data||{};
      const value=d.url||d.home_url||d.website_url||d.base_url;
      if(value&&new URL(value).protocol==='https:')storeUrl=value;
    }catch(_){/* Keep copy disabled instead of producing a link for the wrong store. */}
    finally{loading=false;}
  }
  function current(){
    const frame=document.getElementById('kidia-shared-flutter'),doc=frame?.contentDocument;
    if(frame&&new URL(frame.src,window.location.href).searchParams.get('demo')==='1')throw Error('Open a live store preview to copy a page link. Demo products cannot be linked.');
    const location=doc?.documentElement.getAttribute('data-preview-location');
    if(!location)throw Error('The preview is still loading.');
    let states={};try{states=JSON.parse(doc.documentElement.getAttribute('data-preview-catalog-links')||'{}');}catch(_){}
    return pageLink(storeUrl,location,states[location]);
  }
  button.addEventListener('click',async()=>{
    try{
      const value=current();
      try{await navigator.clipboard.writeText(value);}catch(_){
        const area=document.createElement('textarea');area.value=value;area.style.cssText='position:fixed;left:0;top:0;';document.body.append(area);area.select();
        const copied=document.execCommand('copy');area.remove();if(!copied)throw Error('Clipboard unavailable. Allow clipboard access and try again.');
      }
      notice('Page link copied');
    }catch(error){notice(error.message);}
  });
  function position(){
    const host=document.getElementById('kidia-shared-mobile');
    if(!host||host.hidden||!host.getBoundingClientRect().width){button.hidden=true;return;}
    const r=host.getBoundingClientRect();button.hidden=false;
    Object.assign(button.style,{left:r.left+'px',top:Math.max(6,r.top-40)+'px',width:r.width+'px'});
    button.disabled=!storeUrl;button.style.opacity=storeUrl?'1':'.55';
  }
  loadStore();setInterval(position,250);addEventListener('focus',()=>{if(!storeUrl)loadStore();});
})(typeof window==='undefined'?globalThis:window);
