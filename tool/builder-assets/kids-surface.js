
(function(){
 function sync(){ document.querySelectorAll('.mobishop-preview__screen').forEach(function(screen){
  if(screen.querySelector('img[src*="/kids_baby/"]') && screen.style.backgroundColor !== 'rgb(255, 255, 255)') screen.style.backgroundColor='#FFFFFF';
  if(!screen.querySelector('img[src*="/kids_baby/"]'))return;
  document.querySelectorAll('.mobishop-builder-block[data-type="hero_slider"] input[name$="[button_link]"]').forEach(function(link){
   if(link.value.trim())return;
   var prefix=link.name.slice(0,-13), card=link.closest('.mobishop-builder-block');
   ['action_type','action_value'].forEach(function(key){
    var name=prefix+'['+key+']';
    if(!card.querySelector('[name="'+name+'"]')){var field=document.createElement('input');field.type='hidden';field.name=name;field.value=key==='action_type'?'collection':'latest';card.appendChild(field);}
   });
  });
 }); }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',sync);else sync();
 new MutationObserver(sync).observe(document.documentElement,{childList:true,subtree:true});
})();
