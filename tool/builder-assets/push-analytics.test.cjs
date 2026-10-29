const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {JSDOM} = require('jsdom');
const source=readFileSync(__dirname+'/push-analytics.js','utf8');
function page(lang='en') {
  const dom=new JSDOM(`<html lang="${lang}"><body><main><div class="mobishop-push-stats"></div><section class="mobishop-push-history"></section></main></body></html>`,{runScripts:'outside-only'});
  dom.window.eval(source);return dom;
}
const row={id:'campaign-123',title:'<img onerror=alert(1)>',message:'Message',created_at:Math.floor(Date.now()/1000),status:'sent',audience:'test',targeted:10,sent:8,failed:2,received:3,opened:2,orders:2,buyers:1,paid_orders:1,revenue:{EGP:'0.100000',USD:'2.99'},platforms:{android:{received:3,opened:2}}};
for(const lang of ['en','ar']) {
  const dom=page(lang),document=dom.window.document,api=dom.window.MobiShopPushReport,root=document.querySelector('main');
  api.mount(root,{status:'ready',version:2,conversion_supported:true,campaigns:[row,{...row,id:'campaign-456',revenue:{EGP:'0.200000'}}]});
  assert.equal(root.querySelectorAll('.wm-push-campaign').length,2);
  assert.equal(root.querySelectorAll('img').length,0);
  assert.match(root.textContent,/EGP 0.30/);assert.match(root.textContent,/USD 2.99/);assert.match(root.textContent,/20.0%/);
  const notice=document.createElement('p');api.notice(notice,'Sending',false,true);
  assert.equal(notice.getAttribute('aria-busy'),'true');assert.equal(notice.getAttribute('role'),'status');assert(notice.classList.contains('is-busy'));
  api.notice(notice,'Done',false,false);assert.equal(notice.getAttribute('aria-busy'),'false');assert(!notice.classList.contains('notice'));
  api.notice(notice,'Failed',true,false);assert.equal(notice.getAttribute('role'),'alert');
  api.mount(root,{status:'ready',version:2,conversion_supported:false,campaigns:[row]});
  assert.equal(root.querySelectorAll('.wm-push-analytics').length,1);assert.match(root.textContent,/—/);
  const select=root.querySelector('select');select.value='7';select.dispatchEvent(new dom.window.Event('change'));assert.equal(root.querySelectorAll('.wm-push-campaign').length,1);
  api.mount(root,{status:'ready',version:2,campaigns:[{...row,created_at:1}]});assert.equal(root.querySelectorAll('.wm-push-campaign').length,0);
  api.mount(root,null);assert.equal(root.querySelectorAll('.wm-push-metrics').length,0);
  dom.window.close();
}
console.log('Push analytics rendering, precision, isolation and state contracts passed (English/Arabic).');
