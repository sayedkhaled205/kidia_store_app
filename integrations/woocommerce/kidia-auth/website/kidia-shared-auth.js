(function () {
    'use strict';
    var cfg = window.KidiaSharedAuth, root = document.querySelector('.kidia-auth-shell');
    if (!cfg || !root || !window.crypto || !window.crypto.getRandomValues) return;
    var generation = 0, active = false, panel = null;
    function local(phone) { var s=String(phone||'').replace(/\D/g,''); return s.indexOf('20')===0 && s.length===12 ? '0'+s.slice(2):s; }
    function canonical(phone) { return '+20'+local(phone).slice(1); }
    async function requestPermission(phone) {
        var base=window.KidiaLogin||{};
        var response=await timeout(fetch(base.ajaxUrl,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},body:new URLSearchParams({action:'kidia_phone_send_permission',nonce:base.nonce,phone:local(phone)}).toString()}),12000);
        var data=await response.json();if(!data || !data.success)throw new Error('send_permission');
    }
    function verifier() { var v=new Uint8Array(32);crypto.getRandomValues(v);return Array.from(v,function(x){return x.toString(16).padStart(2,'0');}).join(''); }
    function timeout(promise,ms) { return new Promise(function(resolve,reject){var t=setTimeout(function(){reject(new Error('send_timeout'));},ms);Promise.resolve(promise).then(function(v){clearTimeout(t);resolve(v);},function(e){clearTimeout(t);reject(e);});}); }
    async function request(method,data) {
        var controller=new AbortController(), timer=setTimeout(function(){controller.abort();},12000);
        var values=Object.assign({action:'kidia_shared_auth',nonce:cfg.nonce,method:method},data);
        try {
            var response=await fetch(cfg.ajaxUrl,{method:'POST',credentials:'same-origin',signal:controller.signal,headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},body:new URLSearchParams(values).toString()});
            var result=await response.json();
            if(!result || !result.success) throw new Error(result && result.data && result.data.code || 'request_failed');
            return result.data;
        } finally { clearTimeout(timer); }
    }
    function field(form,label,name,type,placeholder) {
        var wrap=document.createElement('label');wrap.textContent=label;
        var input=document.createElement('input');input.className='kidia-input';input.name=name;input.type=type||'text';input.required=true;
        if(placeholder)input.placeholder=placeholder;
        if(type==='tel'){input.inputMode='numeric';input.pattern='01[0125][0-9]{8}';input.maxLength=11;input.dir='ltr';input.autocomplete='tel-national';}
        if(type==='password'){input.minLength=8;input.maxLength=4096;input.autocomplete='new-password';}
        if(name==='name'){input.maxLength=120;input.autocomplete='name';}
        wrap.appendChild(input);form.appendChild(wrap);return input;
    }
    function message(form,text) { var p=document.createElement('p');p.className='kidia-feedback';p.setAttribute('role','status');p.textContent=text;form.appendChild(p);return p; }
    function button(form,text,action) {var b=document.createElement('button');b.type=action?'button':'submit';b.className='kidia-primary-button';b.textContent=text;if(action)b.addEventListener('click',action);form.appendChild(b);return b;}
    function fresh(stage,title) {
        if(panel)panel.remove();panel=document.createElement('section');panel.className='kidia-shared-completion';panel.style.cssText='display:grid;gap:14px';
        var h=document.createElement('h2');h.textContent=title;panel.appendChild(h);stage.appendChild(panel);return panel;
    }
    function friendly(error) {
        if(/invalid_profile/.test(error.message))return 'راجع الاسم وتطابق كلمة المرور وتأكيدها (٨ أحرف على الأقل).';
        if(/invalid_ticket|invalid_proof/.test(error.message))return 'انتهت جلسة التحقق. أعد المحاولة من البداية.';
        if(/rate_limited/.test(error.message))return 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا أو استخدم طريقة دخول أخرى.';
        return 'تعذر الاتصال الآن. حاول مرة أخرى.';
    }
    function conflict(stage,phone,retry) {
        var box=fresh(stage,'الرقم مرتبط بحساب موجود');message(box,'ادخل لحسابك الموجود بكلمة المرور أو الكود أو جوجل، أو استخدم رقمًا مختلفًا.');
        var link=document.createElement('a');link.className='kidia-primary-button';link.textContent='تسجيل الدخول للحساب الموجود';
        var login=new URL(cfg.loginUrl,location.origin);login.searchParams.set('kidia_stage','phone');login.searchParams.set('kidia_phone',local(phone));
        var logout=new URL(cfg.logoutUrl,location.origin);logout.searchParams.set('redirect_to',login.href);link.href=logout.href;box.appendChild(link);
        button(box,'استخدام رقم مختلف',retry);
    }
    function fallbackForm(stage,phone,details,send,myGeneration,retry,verified) {
        var box=fresh(stage,verified?'أكمل إنشاء حسابك':'أكّد رقم موبايلك');message(box,verified?'تم تأكيد رقمك. اكتب اسمك وكلمة مرور لحسابك.':'اكتب نفس الرقم مرة تانية عشان تكمّل إنشاء حسابك.');
        var form=document.createElement('form');form.style.cssText='display:grid;gap:14px';box.appendChild(form);
        var repeated=verified?null:field(form,'رقم الموبايل','phone','tel','01xxxxxxxxx');
        if(!details){field(form,'الاسم','name');field(form,'كلمة المرور','password','password');field(form,'تأكيد كلمة المرور','confirm_password','password');}
        var status=message(form,''),submit=button(form,'إنشاء الحساب');
        if(retry)button(form,'تغيير الرقم أو البدء من جديد',retry);
        form.addEventListener('submit',async function(e){e.preventDefault();if(submit.disabled)return;
            if(repeated && local(repeated.value)!==local(phone)){status.textContent='الرقم مختلف. اكتب نفس الرقم الذي أدخلته أول مرة.';return;}
            var values=details||Object.fromEntries(new FormData(form));
            if(values.password!==undefined && values.password!==values.confirm_password){status.textContent='كلمة المرور وتأكيدها مش متطابقين.';return;}
            submit.disabled=true;status.textContent='جاري إكمال الحساب…';
            try {await send(values);if(myGeneration!==generation)return;location.replace(cfg.loginUrl);}
            catch(error){if(myGeneration!==generation)return;status.textContent=/existing_phone/.test(error.message)?'الرقم مرتبط بحساب موجود. غيّر الرقم أو سجّل دخولك للحساب الموجود.':friendly(error);submit.disabled=false;}
        });
    }
    // Existing verified-account sign-in remains owned by the original UI.
    window.KidiaAuthFallback=function(phone,existing){
        if(existing || !/^01[0125][0-9]{8}$/.test(local(phone)))return false;
        if(active)return true;
        document.dispatchEvent(new CustomEvent('kidia:otp-reset'));
        active=true;var myGeneration=++generation, stage=root.querySelector('[data-kidia-stage="phone"]');
        var native=root.querySelector('#kidia-otp-native');if(native)native.hidden=true;
        root.classList.remove('kidia-phone-sending');
        var box=fresh(stage,'أكّد رقم موبايلك'),status=message(box,'جاري تجهيز الحساب…'),v=verifier();
        request('phone_enroll',{phone:canonical(phone),verifier:v}).then(function(attempt){
            if(myGeneration!==generation)return;
            fallbackForm(stage,phone,null,async function(details){
                if(myGeneration!==generation)return;
                if(!attempt.confirmed) { var next=await request('phone_confirm',{phone:canonical(phone),verifier:v,ticket:attempt.ticket}); if(myGeneration!==generation)return; attempt.ticket=next.ticket; attempt.confirmed=true; }
                if(myGeneration!==generation)return;
                await request('register_customer',Object.assign({},details,{phone:canonical(phone),verifier:v,ticket:attempt.ticket}));
            },myGeneration,function(){generation++;active=false;if(panel){panel.remove();panel=null;}location.replace(cfg.loginUrl);});
        }).catch(function(error){if(myGeneration!==generation)return;status.textContent=/existing_phone/.test(error.message)?'الرقم مسجل بالفعل. ارجع وادخل لحسابك بكلمة المرور أو جوجل.':friendly(error);});
        return true;
    };
    window.KidiaVerifiedPhoneRegistration=function(phone,ticket,v) {
        document.dispatchEvent(new CustomEvent('kidia:otp-reset'));
        active=true;var myGeneration=++generation,stage=root.querySelector('[data-kidia-stage="phone"]');
        var native=root.querySelector('#kidia-otp-native');if(native)native.hidden=true;
        fallbackForm(stage,phone,null,async function(details){
            if(myGeneration!==generation)return;
            await request('register_customer',Object.assign({},details,{verifier:v,ticket:ticket}));
        },myGeneration,function(){generation++;active=false;location.replace(cfg.loginUrl);},true);
    };
    document.addEventListener('kidia:otp-reset',function(){generation++;active=false;if(panel){panel.remove();panel=null;}});
    var setup=root.querySelector('.kidia-phone-setup-form');
    if(!setup || setup.dataset.kidiaSetupType==='otp')return;
    setup.addEventListener('submit',async function(event){
        event.preventDefault();event.stopImmediatePropagation();if(active)return;
        if(!setup.reportValidity())return;
        var values=Object.fromEntries(new FormData(setup)), phone=local(values.kidia_setup_phone);
        var details={name:values.kidia_phone_username||'',password:values.kidia_phone_new_password||'',confirm_password:values.kidia_phone_new_password_confirm||''};
        if(details.password!==details.confirm_password){var mismatch=setup.querySelector('[data-kidia-shared-error]');if(!mismatch){mismatch=message(setup,'');mismatch.dataset.kidiaSharedError='1';}mismatch.textContent='كلمة المرور وتأكيدها مش متطابقين.';return;}
        active=true;var myGeneration=++generation,v=verifier(),stage=setup.parentNode;
        setup.hidden=true;var box=fresh(stage,'تأكيد رقم الموبايل'),status=message(box,'جاري إرسال كود التحقق…');
        function retry(){generation++;active=false;if(panel){panel.remove();panel=null;}setup.hidden=false;}
        try {
            var attempt=await request('website_contact',{phone:canonical(phone),verifier:v,mode:'prepare'});
            if(myGeneration!==generation)return;
            var base={phone:canonical(phone),verifier:v,ticket:attempt.ticket};
            async function finish(mode,extra){if(myGeneration!==generation)throw new Error('cancelled');return request('website_contact',Object.assign({},details,base,{mode:mode},extra||{}));}
            var confirmation;
            try {
                if(!window.firebase || !window.recaptchaVerifier)throw new Error('not_ready');
                await requestPermission(phone);
                if(myGeneration!==generation)return;
                confirmation=await timeout(firebase.auth().signInWithPhoneNumber(canonical(phone),window.recaptchaVerifier),20000);
            } catch(sendError) {
                if(myGeneration!==generation)return;
                fallbackForm(stage,phone,details,function(){return finish('confirm');},myGeneration,retry);return;
            }
            if(myGeneration!==generation)return;
            box=fresh(stage,'أدخل كود التحقق');var form=document.createElement('form');form.style.cssText='display:grid;gap:14px';box.appendChild(form);
            var code=field(form,'كود التحقق','code','text');code.inputMode='numeric';code.autocomplete='one-time-code';code.pattern='[0-9]{6}';code.maxLength=6;code.dir='ltr';
            status=message(form,'تم إرسال الكود إلى موبايلك.');var submit=button(form,'تأكيد');button(form,'تغيير الرقم',retry);
            form.addEventListener('submit',async function(e){e.preventDefault();if(submit.disabled)return;submit.disabled=true;
                try {var credential=await timeout(confirmation.confirm(code.value),20000);if(myGeneration!==generation)return;var token=await credential.user.getIdToken();if(myGeneration!==generation)return;await finish('verify',{id_token:token});if(myGeneration===generation)location.replace(cfg.loginUrl);}
                catch(error){if(myGeneration!==generation)return;status.textContent=/existing_phone|account_conflict/.test(error.message)?'الرقم مرتبط بحساب موجود. غيّر الرقم أو ادخل لحسابك الموجود.':/invalid_ticket/.test(error.message)?'انتهت جلسة التحقق. ابدأ من جديد.':'تعذر تأكيد الكود أو الاتصال. راجع الكود أو ابدأ من جديد.';submit.disabled=false;}
            });
        } catch(error) {
            if(myGeneration!==generation)return;
            if(/existing_phone/.test(error.message)){conflict(stage,phone,retry);return;}
            status.textContent=friendly(error);button(box,'المحاولة مرة أخرى',retry);
        }
    },true);
})();
