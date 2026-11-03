const assert = require('node:assert/strict');
const {load} = require('./preview-auth-config.js');
(async () => {
  let calls = 0;
  const state = {platform:'woocommerce',store_data:{url:'https://shop.example/subdir/'}};
  const config = await load(state, async (url, options) => {
    calls++;
    const request = new URL(url);
    assert.equal(request.origin + request.pathname,'https://shop.example/subdir/wp-json/mobishop/v1/auth/native/config');
    assert.equal(request.searchParams.get('platform'),'android');
    assert.match(request.searchParams.get('_preview'),/^[0-9a-z]+$/);
    assert.equal(options.cache,'no-store');
    assert.equal(options.credentials,'omit');
    assert.equal(options.redirect,'error');
    assert.equal(options.headers['X-CSRF-TOKEN'],undefined);
    return {ok:true,status:200,json:async()=>({version:1,enabled:true,phone_country_code:'20',methods:{google:true,facebook:true,phone_otp:false,email_password:true},google:{server_client_id:'omit-me'},firebase:{apiKey:'omit-me'}})};
  });
  assert.equal(config.methods.google,true);
  assert.equal(config.methods.facebook,true);
  assert.equal(config.phone_country_code,'20');
  assert.equal(config.methods.phone_otp,false);
  assert.equal(config.google,undefined);
  assert.equal(config.firebase,undefined);
  const policyState = {...state,store_data:{url:'https://policy.example'}};
  for (const [candidate, expected] of [
    ['https://merchant.example/privacy','https://merchant.example/privacy'],
    ['javascript:alert(1)',''], ['https://user:secret@merchant.example/privacy','']
  ]) {
    const policy = await load(policyState, async()=>({ok:true,status:200,json:async()=>({
      version:1,enabled:true,methods:{},privacy_policy_url:candidate,
    })}),{fresh:true});
    assert.equal(policy.privacy_policy_url,expected);
  }
  await assert.rejects(load({...state,platform:'shopify'},()=>{calls++;}));
  await assert.rejects(load({...state,store_data:{url:'http://shop.example'}},()=>{calls++;}));
  assert.equal(calls,1);
  await assert.rejects(load(state,async()=>({ok:false,status:500}),{fresh:true}));
  const legacy = await load(state,async()=>({ok:false,status:404}),{fresh:true});
  assert.equal(legacy.methods.google,undefined);
  assert.equal(legacy.methods.email_password,true);
  // Model a browser holding the pre-registration response. A subsequent
  // preview must request current flags rather than silently hide Google.
  let enabled = true;
  const current = async (_url, options) => ({
    ok:true, status:200, json:async()=>({version:1,enabled:true,methods:{
      email_password:true,phone_otp:true,google:options.cache === 'no-store' && enabled
    }})
  });
  assert.equal((await load(state,current,{fresh:true})).methods.google,true);
  enabled = false;
  assert.equal((await load(state,current,{fresh:true})).methods.google,false);
  enabled = true;
  assert.equal((await load(state,current,{fresh:true})).methods.google,true);
  const secondStore = {...state,store_data:{url:'https://other.example'}};
  assert.equal((await load(secondStore,async (url,options) => {
    assert.equal(new URL(url).origin,'https://other.example');
    return current(url,options);
  })).methods.google,true);
  let resolve;
  let slowCalls = 0;
  const slowState = {...state,store_data:{url:'https://slow.example'}};
  const slowFetch = () => { slowCalls++; return new Promise(r => {resolve = r;}); };
  const first = load(slowState, slowFetch);
  const second = load(slowState, slowFetch);
  assert.equal(slowCalls,1);
  resolve({ok:true,status:200,json:async()=>({version:1,enabled:true,methods:{google:true}})});
  assert.deepEqual(await first,await second);
  await load(slowState,slowFetch);
  assert.equal(slowCalls,1);
  const realNow = Date.now;
  Date.now = () => realNow() + 31000;
  try {
    const expired = await load(slowState,async()=>({ok:true,status:200,json:async()=>({version:1,enabled:true,methods:{google:false}})}));
    assert.equal(expired.methods.google,false);
  } finally { Date.now = realNow; }
  const failedState = {...state,store_data:{url:'https://retry.example'}};
  await assert.rejects(load(failedState,async()=>{throw new Error('offline');}));
  assert.equal((await load(failedState,current)).methods.google,true);
  console.log('Preview configuration routing, concurrent reuse, expiry and retry checks passed.');
})();
