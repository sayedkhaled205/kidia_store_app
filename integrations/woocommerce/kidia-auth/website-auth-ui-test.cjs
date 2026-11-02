const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {JSDOM,VirtualConsole}=require('jsdom');
const base=__dirname;let checks=0;
function ok(v,m){assert.ok(v,m);checks++;}
const tick=()=>new Promise(r=>setImmediate(r));
async function settle(){for(let i=0;i<6;i++)await tick();}
function env(kind='anonymous',handler=async()=>({status:'authenticated'}),old=false){
 const dom=new JSDOM(fs.readFileSync(path.join(base,'fixture-'+kind+'.html'),'utf8'),{url:'https://example.test/login-register/',runScripts:'outside-only',virtualConsole:new VirtualConsole()});
 const w=dom.window,calls=[];w.AbortController=AbortController;w.KidiaSharedAuth={nonce:'test-nonce',ajaxUrl:'/ajax',loginUrl:'/login-register/',logoutUrl:'/logout?_wpnonce=fixture'};
 w.KidiaLogin={nonce:'identifier-nonce',ajaxUrl:'/ajax',loginUrl:'/login-register/',homeUrl:'/'};
 w.fetch=async(url,opts)=>{let data=Object.fromEntries(new URLSearchParams(opts.body));calls.push(data);let result=await handler(data);return{json:async()=>result&&result.success!==undefined?result:{success:true,data:result}};};
 if(old)w.eval(fs.readFileSync(path.join(base,'website/login.js'),'utf8'));
 w.eval(fs.readFileSync(path.join(base,'website/kidia-shared-auth.js'),'utf8'));
 return{dom,w,calls,close:()=>w.close()};
}
function submit(w,form){form.dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));}
function value(w,name,v){let input=w.document.querySelector('[name="'+name+'"]');assert.ok(input,'field '+name);input.value=v;return input;}
(async()=>{
 // Email register and sign-in use one coherent field set; providers stay intact.
 let e=env('anonymous',async d=>d.action==='kidia_check_email'?{exists:false}:{status:'authenticated'},true);
 value(e.w,'kidia_name','');let id=e.w.document.querySelector('#kidia-identifier');id.value='new@example.test';submit(e.w,e.w.document.querySelector('.kidia-identifier-form'));await settle();
 ok(!e.w.document.querySelector('.kidia-register-name-field').hidden,'Name visible for registration');
 ok(!e.w.document.querySelector('.kidia-register-confirm-field').hidden,'Confirmation visible for registration');
 e.w.document.querySelector('[data-kidia-switch-mode]').click();
 ok(e.w.document.querySelector('[name="kidia_name"]').disabled,'Hidden name does not block login');
 ok(e.w.document.querySelector('[name="kidia_password_confirm"]').disabled,'Hidden confirmation does not block login');
 ok(e.w.document.querySelector('.kidia-google-provider')&&e.w.document.querySelector('.kidia-facebook-provider'),'Both social providers retained');e.close();
 // An anonymous SMS failure needs matching contact + complete credentials.
 e=env('anonymous',async d=>d.method==='phone_enroll'?{ticket:'attempt'}:d.method==='phone_confirm'?{ticket:'confirmed'}:{status:'authenticated'});
 ok(e.w.KidiaAuthFallback('01000000001',false),'New phone fallback accepted');await settle();
 let form=e.w.document.querySelector('.kidia-shared-completion form');value(e.w,'phone','01000000002');value(e.w,'name','Fixture Name');value(e.w,'password','fixture-password');value(e.w,'confirm_password','fixture-password');submit(e.w,form);await settle();
 ok(!e.calls.some(c=>c.method==='phone_confirm'),'Different retyped contact rejected locally');
 value(e.w,'phone','01000000001');submit(e.w,form);await settle();
 ok(e.calls.some(c=>c.method==='register_customer'&&c.ticket==='confirmed'),'Register uses confirmed ticket');e.close();
 // Cancel between confirmation and registration must not create the abandoned account.
 let release;e=env('anonymous',async d=>d.method==='phone_enroll'?{ticket:'attempt'}:d.method==='phone_confirm'?await new Promise(r=>release=r):{status:'authenticated'});
 e.w.KidiaAuthFallback('01000000001',false);await settle();form=e.w.document.querySelector('.kidia-shared-completion form');value(e.w,'phone','01000000001');value(e.w,'name','Fixture Name');value(e.w,'password','fixture-password');value(e.w,'confirm_password','fixture-password');submit(e.w,form);await settle();
 e.w.document.dispatchEvent(new e.w.CustomEvent('kidia:otp-reset'));release({ticket:'confirmed'});await settle();
 ok(!e.calls.some(c=>c.method==='register_customer'),'Cancellation before registration blocks the next mutation');e.close();
 // Pending social account keeps profile values, respects SMS limits and allows changing number.
 e=env('account',async d=>d.method==='website_contact'?{ticket:'pending'}:{success:true,data:{}});
 e.w.firebase={auth:()=>({signInWithPhoneNumber:()=>Promise.reject(new Error('send_failed'))})};e.w.recaptchaVerifier={};
 value(e.w,'kidia_phone_username','Social Fixture');value(e.w,'kidia_phone_new_password','fixture-password');value(e.w,'kidia_phone_new_password_confirm','fixture-password');value(e.w,'kidia_setup_phone','01000000003');submit(e.w,e.w.document.querySelector('.kidia-phone-setup-form'));await settle();
 ok(e.calls.some(c=>c.action==='kidia_phone_send_permission'),'Website setup respects send permission endpoint');
 ok(e.w.document.querySelector('.kidia-shared-completion input[name="phone"]'),'Send failure shows retyped phone');
 ok(!e.w.document.querySelector('.kidia-shared-completion input[name="password"]'),'Profile fields not asked twice');
 [...e.w.document.querySelectorAll('.kidia-shared-completion button')].find(b=>b.textContent.includes('البدء')).click();
 ok(!e.w.document.querySelector('.kidia-phone-setup-form').hidden,'Can recover by changing number');e.close();
 // Email-created profile has no duplicated credentials and only stores its contact after confirmation.
 e=env('account-collected',async d=>({ticket:'email-contact'}));e.w.firebase={auth:()=>({signInWithPhoneNumber:()=>Promise.reject(new Error('send_failed'))})};e.w.recaptchaVerifier={};
 ok(!e.w.document.querySelector('[name="kidia_phone_new_password"]'),'Collected email profile omits second password page');
 value(e.w,'kidia_setup_phone','01000000004');submit(e.w,e.w.document.querySelector('.kidia-phone-setup-form'));await settle();
 value(e.w,'phone','01000000004');submit(e.w,e.w.document.querySelector('.kidia-shared-completion form'));await settle();
 ok(e.calls.some(c=>c.method==='website_contact'&&c.mode==='confirm'&&c.phone==='+201000000004'),'Pending email confirms its own contact');e.close();
 // The real FME verification callback must hand an unknown signed phone to profile entry, not reload/login.
 e=env('anonymous',async d=>({status:'authenticated'}));
 e.w.fmelwpDataObj={ajaxurl:'/ajax',nonce:'otp-fixture-nonce'};let sentOtp;
 e.w.jQuery={ajax:opts=>{sentOtp=opts.data;return Promise.resolve({success:true,registration:true,ticket:'verified-phone-ticket'});}};
 e.w.eval(fs.readFileSync(path.join(base,'website/kidia-firebase-otp.js'),'utf8'));
 e.w.confirmationResult={confirm:async()=>({user:{getIdToken:async()=> 'signed-fixture-token'}})};
 await e.w.fma_lwp_firebase_otp_validation('+201000000005','123456',false);await settle();
 ok(/^[a-f0-9]{64}$/.test(sentOtp.kidia_native_verifier),'Verified phone request carries its browser binding');
 ok(!e.calls.some(c=>c.method==='register_customer'),'OTP proof alone issues no account cookie');
 ok(!e.w.document.querySelector('.kidia-shared-completion input[name="phone"]'),'Successful OTP does not ask for repeated phone');
 value(e.w,'name','Verified Fixture');value(e.w,'password','fixture-password');value(e.w,'confirm_password','fixture-password');submit(e.w,e.w.document.querySelector('.kidia-shared-completion form'));await settle();
 ok(e.calls.some(c=>c.method==='register_customer'&&c.ticket==='verified-phone-ticket'&&c.verifier===sentOtp.kidia_native_verifier),'Verified signup preserves signed ticket and binding until profile submission');e.close();
 console.log(`Website auth UI: ${checks} checks passed.`);
})().catch(e=>{console.error(e);process.exitCode=1;});
