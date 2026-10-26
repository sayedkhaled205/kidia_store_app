// Run with a staged commerce asset; uses a fake server, never a live store.
const {JSDOM}=require('jsdom');
const fs=require('fs');
const assert=require('node:assert/strict');
const script=fs.readFileSync(process.argv[2],'utf8');
const html='<main id="kidia-central-screen"></main>';
const dom=new JSDOM(html,{url:'https://builder.test/frame?screen=store-data&store=fixture&store_tab=discounts',runScripts:'outside-only'});
const w=dom.window, requests=[];
w.AbortController=AbortController;
w.fetch=async url=>{
 const query=new URL(url,w.location.href).searchParams;requests.push(Object.fromEntries(query));
 return {ok:true,json:async()=>({ok:true,platform:'woocommerce',checked_at:new Date().toISOString(),html:`<div class="mobishop-data-tabs"></div><form><input name="coupon_search" value=""><input type="hidden" name="coupon_page" value="1"><button>Filter</button></form><a href="?store_tab=discounts&coupon_page=2">2</a>`})};
};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{
 w.eval(script); await tick(); await tick();
 assert.equal(requests[0].store_tab,'discounts');
 w.document.querySelector('main a').click(); await tick();
 assert.equal(requests.at(-1).coupon_page,'2');
 w.document.querySelector('[name=coupon_search]').value='quantity';
 w.document.querySelector('form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await tick();
 assert.equal(requests.at(-1).coupon_page,'1');assert.equal(requests.at(-1).coupon_search,'quantity');
 const count=requests.length;
 w.dispatchEvent(new w.MessageEvent('message',{origin:'https://evil.test',source:w,data:{type:'kidia:commerce-tab',tab:'products'}}));await tick();assert.equal(requests.length,count);
 w.dispatchEvent(new w.MessageEvent('message',{origin:w.location.origin,source:w,data:{type:'kidia:commerce-tab',tab:'products'}}));await tick();assert.equal(requests.at(-1).store_tab,'products');
 w.dispatchEvent(new w.MessageEvent('message',{origin:w.location.origin,source:w,data:{type:'kidia:commerce-tab',tab:'discounts'}}));await tick();assert.equal(requests.at(-1).store_tab,'discounts');
 w.close();console.log('PASS: discounts initial navigation, pagination/search reset, same-frame switching and origin isolation');
})().catch(error=>{w.close();console.error(error);process.exitCode=1;});
