const {test} = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./preview-commerce-config');
const payload = {platform:'woocommerce',store_data:{url:'https://store.example/shop'}};
const config = {version:8,renderer:'native',fields:[{key:'billing_state',label:'Province',secret:'x'}],
  defaults:{country:'EG',states:{C:'Cairo'},private:'x'}, shipping:{allow_different_address:false},
  payment_methods:[{id:'card',title:'Card',native_adapter:'kashier',secret:'x'}],saved_addresses:[{phone:'private'}]};
test('fetches the connected store and exposes only public configuration',async()=>{
  let requested;
  const result = await load(payload,async(url,opts)=>{requested=url;assert.equal(opts.credentials,'omit');
    assert.equal(opts.cache,'no-store');return {ok:true,json:async()=>config};});
  assert.equal(new URL(requested).pathname,'/shop/wp-json/mobishop/v1/checkout-config');
  assert.deepEqual(result.payment_methods,[{id:'card',title:'Card',native_adapter:'kashier'}]);
  assert.equal(result.fields[0].label,'Province');
  assert.equal(JSON.stringify(result).includes('private'),false);
  assert.equal(JSON.stringify(result).includes('secret'),false);
});
test('does not turn a failed or unsupported response into a free checkout',async()=>{
  await assert.rejects(load(payload,async()=>({ok:false})));
  await assert.rejects(load(payload,async()=>({ok:true,json:async()=>({version:7})})));
  await assert.rejects(load({...payload,platform:'shopify'},()=>{throw Error('must not fetch');}));
});
test('separate stores and disabled gateways are not mixed',async()=>{
  const a=await load(payload,async()=>({ok:true,json:async()=>config}));
  const b=await load({...payload,store_data:{url:'https://other.example'}},async(url)=>{
    assert.equal(new URL(url).hostname,'other.example');
    return {ok:true,json:async()=>({...config,payment_methods:[{id:'cod',title:'Cash',native_adapter:'offline'}]})};
  });
  assert.equal(a.payment_methods[0].id,'card');assert.equal(b.payment_methods[0].id,'cod');
});
