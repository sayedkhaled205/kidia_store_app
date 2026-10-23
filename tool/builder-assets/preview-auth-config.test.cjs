const assert = require('node:assert/strict');
const {load} = require('./preview-auth-config.js');
(async () => {
  let calls = 0;
  const state = {platform:'woocommerce',store_data:{url:'https://shop.example/subdir/'}};
  const config = await load(state, async (url, options) => {
    calls++;
    assert.equal(url,'https://shop.example/subdir/wp-json/mobishop/v1/auth/native/config?platform=android');
    assert.equal(options.credentials,'omit');
    assert.equal(options.redirect,'error');
    assert.equal(options.headers['X-CSRF-TOKEN'],undefined);
    return {ok:true,status:200,json:async()=>({version:1,enabled:true,methods:{google:true,phone_otp:false,email_password:true},google:{server_client_id:'omit-me'},firebase:{apiKey:'omit-me'}})};
  });
  assert.equal(config.methods.google,true);
  assert.equal(config.methods.phone_otp,false);
  assert.equal(config.google,undefined);
  assert.equal(config.firebase,undefined);
  await assert.rejects(load({...state,platform:'shopify'},()=>{calls++;}));
  await assert.rejects(load({...state,store_data:{url:'http://shop.example'}},()=>{calls++;}));
  assert.equal(calls,1);
  await assert.rejects(load(state,async()=>({ok:false,status:500})));
  const legacy = await load(state,async()=>({ok:false,status:404}));
  assert.equal(legacy.methods.google,undefined);
  assert.equal(legacy.methods.email_password,true);
  console.log('Preview configuration routing and availability checks passed.');
})();
