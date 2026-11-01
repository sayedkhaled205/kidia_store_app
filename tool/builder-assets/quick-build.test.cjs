const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.env.QUICK_BUILD_SOURCE || __dirname + '/quick-build.js', 'utf8');
const flush = async () => { for(let i=0;i<120;i++) await Promise.resolve(); };
const deferred = () => { let resolve,reject; const promise=new Promise((a,b)=>{resolve=a;reject=b;}); return {promise,resolve,reject}; };
const response = (data,status=200) => ({ok:status<400,status,json:async()=>data});
const build = (status,id='old') => ({id,status,progress:status==='completed'?100:20,step:1,cancel_url:'/cancel/'+id,started_at:'2026-01-01T00:00:00Z',checked_at:'2026-01-01T00:01:00Z',output_label:'Android',...(status==='failed'?{error:'Old failure'}:{}),...(status==='completed'?{download_url:'/download/'+id}:{})});
function setup(initial=null) {
  const elements=[],requests=[],timers=new Map(),intervals=new Map(),storage=new Map(),events={}; let timerId=0;
  class Element {
    constructor(tag='button',text='') { this.tag=tag;this.textContent=text;this.children=[];this.events={};this.dataset={};this.attrs={};this.hidden=false;this.open=false;elements.push(this); }
    append(...children) {this.children.push(...children);}
    setAttribute(k,v){this.attrs[k]=v;}
    removeAttribute(k){delete this.attrs[k];if(k==='value')delete this.value;}
    addEventListener(k,fn){this.events[k]=fn;}
    closest(selector){return selector==='button,a'?this:null;}
    click(){if(!this.disabled)return this.events.click?.();}
    showModal(){this.open=true;}
    close(){this.open=false;this.events.close?.();}
  }
  const api={build:initial,onGet:null,onPost:null,onContext:null,onCancel:null};
  const location={origin:'https://builder.test',href:'https://builder.test/?store=00000000-0000-0000-0000-000000000001'};
  const window={addEventListener:(k,fn)=>events[k]=fn}; window.parent=window;
  const document={head:new Element('head'),body:new Element('body'),createElement:tag=>new Element(tag),querySelector:()=>null};
  vm.runInNewContext(source,{window,document,location,Element,URL,AbortController,console,
    sessionStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},
    setTimeout:(fn,ms)=>{timers.set(++timerId,{fn,ms});return timerId;},clearTimeout:id=>timers.delete(id),
    setInterval:(fn,ms)=>{intervals.set(++timerId,{fn,ms});return timerId;},clearInterval:id=>intervals.delete(id),
    fetch:async(url,options={})=>{
      requests.push({url,options});
      if(url.includes('/context?'))return api.onContext?api.onContext():response({ok:true,csrf_token:'fixture'});
      if(url.includes('/cancel/'))return api.onCancel?api.onCancel(url):response({ok:true,status:'cancelled'});
      if(options.method==='POST') {
        if(api.onPost)return api.onPost();
        api.build=build('queued','new');return response({ok:true});
      }
      return api.onGet?api.onGet():response({ok:true,build:api.build});
    }});
  const button=text=>elements.find(e=>e.tag==='button'&&e.textContent===text);
  return {api,requests,timers,intervals,storage,elements,location,
    open(){events.click({target:new Element('button','Build Your App'),preventDefault(){},stopImmediatePropagation(){}});},
    get dialog(){return elements.find(e=>e.tag==='dialog');},
    get status(){return elements.find(e=>e.className==='woo-build-progress__stage')?.textContent;},
    get cancel(){return button('Cancel')||button('Cancel build')||button('Cancelling…');},
    get retry(){return button('Try again')||button('Build again');},
    get close(){return button('Hide progress')||button('OK');},
    get posts(){return requests.filter(r=>r.options.method==='POST'&&r.url.includes('quick-build'));},
    async run(ms){const entries=[...timers].filter(([,x])=>x.ms===ms);for(const [id,x]of entries){timers.delete(id);x.fn();}await flush();}
  };
}

test('failed/cancelled persisted build starts fresh on explicit Build; refresh alone is GET only',async()=>{
  for(const status of ['failed','cancelled']){
    const ui=setup(build(status));await flush();assert.equal(ui.dialog,undefined);assert.equal(ui.posts.length,0);
    ui.open();ui.open();await flush();assert.equal(ui.posts.length,1);assert.equal(ui.posts[0].options.headers['X-CSRF-TOKEN'],'fixture');assert.equal(ui.status,'Checking build progress…');
  }
});
test('failed build has Cancel and Cancel then Build starts a new attempt',async()=>{
  const ui=setup();await flush();ui.api.onPost=async()=>{ui.api.build=build('failed','attempt-1');return response({ok:true});};
  ui.open();await flush();assert.equal(ui.status,'Old failure');assert.equal(ui.cancel.hidden,false);assert.equal(ui.cancel.textContent,'Cancel');
  ui.cancel.click();await flush();assert.equal(ui.dialog.open,false);assert.equal(ui.storage.size,0);assert.equal(ui.requests.filter(r=>r.url.includes('/cancel/')).length,0);
  ui.api.onPost=null;ui.open();await flush();assert.equal(ui.posts.length,2);assert.notEqual(ui.status,'Old failure');
});
test('rejected POST with no accepted build can be cancelled and retried',async()=>{
  const ui=setup();await flush();ui.api.onPost=async()=>response({ok:false,message:'Design rejected'},422);
  ui.open();await flush();assert.equal(ui.status,'Design rejected');assert.equal(ui.cancel.hidden,false);ui.cancel.click();await flush();assert.equal(ui.dialog.open,false);
  ui.api.onPost=null;ui.open();await flush();assert.equal(ui.posts.length,2);assert.equal(ui.dialog.open,true);
});
test('Try again after failure rechecks active build before any new POST',async()=>{
  const ui=setup();await flush();ui.api.onPost=async()=>{ui.api.build=build('failed','attempt-1');return response({ok:true});};ui.open();await flush();
  ui.api.build=build('building','other-tab');ui.retry.click();await flush();assert.equal(ui.posts.length,1);assert.equal(ui.cancel.textContent,'Cancel build');
});
test('active build is resumed with no POST; completed build keeps download and explicit Build again',async()=>{
  const active=setup(build('building'));await flush();active.open();await flush();assert.equal(active.posts.length,0);assert.equal(active.cancel.hidden,false);
  const complete=setup(build('completed'));await flush();complete.open();await flush();assert.equal(complete.posts.length,0);
  assert.equal(complete.elements.find(e=>e.tag==='a').href,'https://builder.test/download/old');complete.retry.click();await flush();assert.equal(complete.posts.length,1);
});
test('stale GET from a cancelled attempt cannot replace a new build',async()=>{
  const ui=setup(build('building'));await flush();const pending=deferred();ui.api.onGet=()=>pending.promise;ui.open();await flush();
  ui.cancel.click();await flush();assert.equal(ui.status,'Build cancelled');ui.cancel.click();await flush();assert.equal(ui.dialog.open,false);
  ui.api.onGet=null;ui.api.build=build('cancelled');ui.open();await flush();assert.equal(ui.posts.length,1);
  pending.resolve(response({ok:true,build:build('failed')}));await flush();assert.notEqual(ui.status,'Old failure');assert.equal(ui.cancel.textContent,'Cancel build');
});
test('lost POST plus old terminal status keeps polling and cannot start a duplicate',async()=>{
  const ui=setup(build('failed'));await flush();ui.api.onPost=async()=>{throw new Error('network');};
  ui.open();await flush();assert.equal(ui.posts.length,1);assert.equal(ui.cancel.textContent,'Cancel build');ui.open();await flush();assert.equal(ui.posts.length,1);assert.notEqual(ui.status,'Old failure');
  ui.cancel.click();await flush();assert.equal(ui.dialog.open,true);assert.ok(ui.storage.size);assert.equal(ui.cancel.disabled,true);
  ui.api.build=build('building','accepted-new');await ui.run(3000);assert.equal(ui.status,'Build cancelled');assert.equal(ui.storage.size,0);assert.equal(ui.requests.filter(r=>r.url.endsWith('/cancel/accepted-new')).length,1);
});
test('direct Try again after confirmed cancel detaches an old in-flight poll',async()=>{
  const ui=setup(build('building'));await flush();const pending=deferred();ui.api.onGet=()=>pending.promise;ui.open();await flush();
  ui.cancel.click();await flush();assert.equal(ui.status,'Build cancelled');
  ui.api.onGet=null;ui.api.build=build('cancelled');ui.retry.click();await flush();assert.equal(ui.posts.length,1);assert.equal(ui.status,'Checking build progress…');
  pending.resolve(response({ok:true,build:build('failed')}));await flush();assert.notEqual(ui.status,'Old failure');
  ui.api.build=build('completed','new');await ui.run(8000);assert.equal(ui.close.textContent,'OK');
});
test('cancel during context preparation sends no build request',async()=>{
  const ui=setup();await flush();const context=deferred();ui.api.onContext=()=>context.promise;ui.open();await flush();ui.cancel.click();await flush();
  context.resolve(response({ok:true,csrf_token:'fixture'}));await flush();assert.equal(ui.posts.length,0);assert.equal(ui.storage.size,0);assert.equal(ui.cancel.disabled,false);
  ui.cancel.click();assert.equal(ui.dialog.open,false);
});
test('new attempt clears old elapsed/output and hidden progress',async()=>{
  const ui=setup(build('completed'));await flush();ui.open();await flush();const context=deferred();ui.api.onContext=()=>context.promise;ui.retry.click();await flush();
  assert.equal(ui.elements.find(e=>e.className==='woo-build-progress__meta').children[0].textContent,'');
  assert.equal(ui.elements.find(e=>e.className==='woo-build-progress__meta').children[1].textContent,'');
  assert.equal(ui.elements.find(e=>e.tag==='progress').hidden,false);
  context.resolve(response({ok:true,csrf_token:'fixture'}));await flush();
});
test('remote cancellation error remains retryable and does not pretend success',async()=>{
  const ui=setup(build('building'));await flush();ui.api.onCancel=async()=>response({ok:false,message:'offline'},503);ui.cancel.click();await flush();
  assert.equal(ui.dialog.open,true);assert.equal(ui.cancel.disabled,false);assert.equal(ui.cancel.textContent,'Cancel build');assert.ok(ui.storage.size);
  ui.api.onCancel=null;ui.cancel.click();await flush();assert.equal(ui.status,'Build cancelled');assert.equal(ui.storage.size,0);
});
test('accepted cancellation that is not terminal continues checking the server',async()=>{
  const ui=setup(build('building'));await flush();ui.api.onCancel=async()=>response({ok:true,status:'cancelling'});ui.cancel.click();await flush();
  assert.equal(ui.cancel.disabled,true);assert.ok([...ui.timers.values()].some(x=>x.ms===3000));
  ui.api.build=build('cancelled');await ui.run(3000);assert.equal(ui.cancel.disabled,false);assert.equal(ui.storage.size,0);
});
