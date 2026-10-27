const {JSDOM} = require('jsdom');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const script = fs.readFileSync(__dirname + '/discount-rule-controls.js','utf8');
const row = `<table><tr data-discount-id="7" data-discount-title="Original &lt;offer&gt;" data-discount-channel="all" data-discount-enabled="1" data-discount-revision="${'a'.repeat(64)}"><td><button data-discount-action="edit">Control</button><button data-discount-action="clone">Copy</button></td></tr></table>`;
const dom = new JSDOM(`<main id="kidia-central-screen"><h3>Discounts</h3><button data-discount-action="create">Create</button>${row}</main>`, {url:'https://builder.test/frame?screen=store-data&store=fixture',runScripts:'outside-only'});
const w=dom.window, d=w.document, writes=[], rawWrites=[], created=new Map();
w.AbortController=AbortController;
let failNext=false, contextFails=false, pendingSave=null, nextReply=null, timeoutNext=false, saveTimeout=null, pendingTargets=null;
const realSetTimeout=w.setTimeout.bind(w);
w.setTimeout=(fn,delay,...args)=>{
 if(delay===60000) saveTimeout=fn;
 return realSetTimeout(fn,delay,...args);
};
w.fetch=async (url,options={}) => {
 if(url.startsWith('/account/builder/context')) return {ok:!contextFails,json:async()=>({store:'fixture',csrf_token:contextFails?'':'test-csrf'})};
 if(options.method!=='POST') return pendingTargets || {ok:true,json:async()=>({ok:true,items:[{id:11,label:'Product <safe>'},{id:12,label:'Product 2'}]})};
 assert.equal(options.headers['X-CSRF-TOKEN'],'test-csrf');
 const payload=JSON.parse(options.body), reply=nextReply; nextReply=null;
 writes.push(payload); rawWrites.push(options.body);
 if(reply && [409,422].includes(reply.status)) return {ok:false,status:reply.status,json:async()=>reply.data};
 // Simulate a server commit before losing its response, with idempotent replays.
 if(['create','clone'].includes(payload.operation) && !created.has(payload.request_id)) created.set(payload.request_id,{id:100+created.size,body:options.body});
 if(pendingSave) await pendingSave;
 if(timeoutNext) {
  timeoutNext=false;
  return new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(Object.assign(Error('Aborted'),{name:'AbortError'})),{once:true}));
 }
 if(failNext) {failNext=false; throw Error('Connection lost');}
 if(reply) return {ok:reply.status<400,status:reply.status,json:async()=>reply.data};
 return {ok:true,status:200,json:async()=>({ok:true,id:created.get(payload.request_id)?.id || 7})};
};
const tick=()=>new Promise(r=>setImmediate(r));
const button=text=>[...d.querySelectorAll('.mdrc-dialog button')].find(el=>el.textContent===text);
const field=label=>[...d.querySelectorAll('.mdrc-dialog label')].find(el=>el.firstElementChild?.textContent===label)?.querySelector('input,select');
let refreshes=0;
d.addEventListener('mobishop:discount-saved',()=>refreshes++);
(async()=>{
 w.eval(script);
 d.querySelector('[data-discount-action=edit]').click();
 assert.equal(writes.length,0,'open is read only');
 assert.equal(d.querySelector('.mdrc-dialog input[type=checkbox]').checked,true);
 d.querySelector('input[value=website]').click();
 // Existing live refresh replaces only the list, never the open draft.
 d.querySelector('main').innerHTML='<h3>Discounts</h3><button data-discount-action="create">Create</button>'+row;
 assert.equal(d.querySelector('.mdrc-dialog input[value=website]').checked,true);
 failNext=true; button('Save').click(); await tick(); await tick();
 assert.equal(writes[0].channel,'website'); assert.equal(writes[0].enabled,true);
 assert(d.querySelector('.mdrc-dialog input[value=mobile]').disabled,'uncertain save must lock draft');
 d.querySelector('.mdrc-dialog input[value=mobile]').checked=true;
 d.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
 assert(d.querySelector('.mdrc-dialog'),'uncertain save cannot be dismissed');
 button('Retry same save').click(); await tick(); await tick();
 assert.deepEqual(writes[1],writes[0],'retry uses exact original draft despite attempted changes');
 assert.equal(writes[0].request_id,writes[1].request_id,'unknown outcome retries same key');
 assert.equal(refreshes,1); assert.equal(d.querySelector('.mdrc-dialog'),null);
 d.querySelector('[data-discount-action=clone]').click();
 assert.equal(d.querySelector('input[value=mobile]').checked,true);
 assert.equal(d.querySelector('.mdrc-dialog input[type=checkbox]').checked,false);
 button('Save').click(); await tick(); await tick();
 assert.equal(writes.at(-1).operation,'clone'); assert.equal(writes.at(-1).revision,'a'.repeat(64));
 assert(writes.at(-1).title.includes('Original <offer>'));
 d.querySelector('[data-discount-action=create]').click();
 field('Title').value='Mobile offer'; field('Value').value='15';
 field('Applies to').value='products'; field('Applies to').dispatchEvent(new w.Event('change')); await tick(); await tick();
 const resultChecks=d.querySelectorAll('.mdrc-picker-results input[type=checkbox]');
 assert.equal(resultChecks.length,4,'gift and target pickers independent');
 resultChecks[0].click(); resultChecks[1].click();
 contextFails=true; button('Save').click(); await tick(); await tick();
 assert.equal(writes.length,3,'CSRF failure cannot write');
 assert.equal(field('Title').disabled,false,'failure before POST leaves draft editable');
 assert.equal(button('Cancel').disabled,false);
 contextFails=false;
 let release; pendingSave=new Promise(r=>release=r);
 const saveButton=button('Save'); saveButton.click(); await tick(); saveButton.click();
 assert.equal(writes.length,4,'one in-flight save');
 button('Cancel').click(); assert(d.querySelector('.mdrc-dialog'),'in-flight save cannot be dismissed');
 assert.deepEqual(writes.at(-1).ids,[11,12]); assert.equal(writes.at(-1).value,15);
 assert.equal(writes.at(-1).enabled,false); assert.equal(writes.at(-1).channel,'mobile');
 release(); await tick(); await tick(); pendingSave=null;
 assert.equal(refreshes,3);
 d.querySelector('[data-discount-action=create]').click();
 field('Discount type').value='shipping'; field('Discount type').dispatchEvent(new w.Event('change'));
 assert.equal(field('Applies to').value,'all'); assert(field('Applies to').closest('label').hidden);
 d.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
 assert.equal(d.querySelector('.mdrc-dialog'),null);

 const open=action=>{
  d.querySelector(`[data-discount-action=${action}]`).click();
  if(action==='create') {field('Title').value='Original draft';field('Value').value='15';}
 };
 const assertLocked=()=>{
  assert([...d.querySelectorAll('.mdrc-dialog input,.mdrc-dialog select')].every(el=>el.disabled),'uncertain draft fields are disabled');
  assert.equal(d.querySelector('.mdrc-body').inert,true,'late picker results are also inert');
  assert.equal(button('Cancel').disabled,true);
  assert.equal(button('Retry same save').disabled,false);
  assert.match(d.querySelector('.mdrc-error').textContent,/not confirmed/);
  button('Cancel').click();
  d.querySelector('.mdrc-backdrop').dispatchEvent(new w.MouseEvent('mousedown',{bubbles:true}));
  d.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
  assert(d.querySelector('.mdrc-dialog'),'uncertain draft stays open through every dismissal route');
  const unload=new w.Event('beforeunload',{cancelable:true}); w.dispatchEvent(unload);
  assert.equal(unload.defaultPrevented,true,'navigation warns while unresolved');
 };

 for(const scenario of [
  {action:'create',outcome:'lost'},
  {action:'clone',outcome:503},
  {action:'edit',outcome:502},
  {action:'create',outcome:'timeout'},
  {action:'create',outcome:'invalid-json'}
 ]) {
  open(scenario.action);
  const beforeCreated=created.size, beforeWrites=writes.length;
  if(scenario.outcome==='lost') failNext=true;
  else if(scenario.outcome==='timeout') timeoutNext=true;
  else nextReply={status:scenario.outcome==='invalid-json'?200:scenario.outcome,data:null};
  button('Save').click(); await tick(); await tick();
  if(scenario.outcome==='timeout') {saveTimeout();await tick();await tick();}
  assert.equal(writes.length,beforeWrites+1);
  assert.equal(created.size,beforeCreated+(scenario.action==='edit'?0:1),'server has committed the original request');
  assertLocked();
  const savedBody=rawWrites.at(-1);
  // Even direct DOM changes and invalid required fields cannot replace the frozen request.
  if(field('Title')) field('Title').value='';
  if(field('Value')) field('Value').value='99';
  d.querySelector('.mdrc-dialog input[type=checkbox]').checked=true;
  if(scenario.outcome==='lost') {
   contextFails=true; button('Retry same save').click(); await tick(); await tick();
   assert.equal(writes.length,beforeWrites+1,'failed context refresh cannot resend or discard unknown save');
   assertLocked(); contextFails=false;
  }
  button('Retry same save').click(); await tick(); await tick();
  assert.equal(rawWrites.at(-1),savedBody,'retry keeps byte-identical request body and UUID');
  assert.equal(created.size,beforeCreated+(scenario.action==='edit'?0:1),'retry cannot duplicate committed create or clone');
  assert.equal(d.querySelector('.mdrc-dialog'),null,'confirmed save closes dialog');
  const unload=new w.Event('beforeunload',{cancelable:true}); w.dispatchEvent(unload);
  assert.equal(unload.defaultPrevented,false,'resolved request removes navigation guard');
  open('create'); assert.equal(field('Title').disabled,false); assert.equal(button('Cancel').disabled,false); button('Cancel').click();
 }

 for(const status of [422,409]) {
  open('create');
  const beforeCreated=created.size;
  nextReply={status,data:{ok:false,message:status===422?'Invalid value.':'Offer changed; reload it.'}};
  button('Save').click(); await tick(); await tick();
  const rejectedKey=writes.at(-1).request_id;
  assert.equal(created.size,beforeCreated,'definite rejection does not commit');
  assert.equal(field('Title').disabled,false,'definite rejection unlocks editing');
  assert.equal(button('Cancel').disabled,false,'definite rejection allows closing to reload');
  const unload=new w.Event('beforeunload',{cancelable:true}); w.dispatchEvent(unload);
  assert.equal(unload.defaultPrevented,false);
  field('Title').value='Corrected draft';
  button('Save').click(); await tick(); await tick();
  assert.notEqual(writes.at(-1).request_id,rejectedKey,'changed draft after definite rejection gets a fresh request key');
  assert.equal(writes.at(-1).title,'Corrected draft');
  assert.equal(created.size,beforeCreated+1);
  assert.equal(d.querySelector('.mdrc-dialog'),null);
 }

 let finishTargets;
 pendingTargets=new Promise(resolve=>finishTargets=resolve);
 open('create'); const detachedResults=d.querySelector('.mdrc-picker-results'); button('Cancel').click();
 finishTargets({ok:true,json:async()=>({ok:true,items:[{id:99,label:'Late result'}]})}); await tick(); await tick();
 assert.equal(detachedResults.childElementCount,0,'late search cannot mutate a destroyed picker');
 w.close(); console.log('PASS: original controls; committed-but-lost saves (network, timeout, 502/503, malformed response); frozen edit/clone/create retries; context failures; locked dismissal; definite 409/422 recovery; destroyed picker response');
})().catch(e=>{w.close();console.error(e);process.exitCode=1;});
