(function () {
    'use strict';
    var generation = 0, activeVerification = null, activeRequest = null;
    var smsController = null, smsTimeout = null, choiceSession = null, choicePanel = null, selecting = false;
    function byId(id) { return document.getElementById(id); }
    function emit(state, message, phase) {
        document.dispatchEvent(new CustomEvent('kidia:otp-state', {detail: {state: state, message: message || '', phase: phase || ''}}));
    }
    function failure(error) {
        var messages = {
            'auth/invalid-verification-code': 'كود التحقق غير صحيح. راجع الرسالة واكتب الكود مرة أخرى.',
            'auth/code-expired': 'انتهت صلاحية الكود. أعد إدخال الرقم لطلب كود جديد.',
            'auth/session-expired': 'انتهت صلاحية الكود. أعد إدخال الرقم لطلب كود جديد.',
            'auth/too-many-requests': 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا أو استخدم الدخول بجوجل.',
            'auth/error-code:-39': 'إرسال الكود غير متاح لهذا الرقم حاليًا. حاول لاحقًا أو استخدم الدخول بجوجل.',
            'auth/quota-exceeded': 'إرسال رسائل التحقق غير متاح مؤقتًا. حاول لاحقًا أو استخدم الدخول بجوجل.',
            'auth/invalid-phone-number': 'اكتب رقم موبايل مصري صحيح من 11 رقمًا.',
            'auth/operation-not-allowed': 'خدمة الدخول بالموبايل غير متاحة حاليًا. استخدم الدخول بجوجل.',
            'auth/billing-not-enabled': 'إرسال رسائل التحقق غير متاح حاليًا. استخدم الدخول بجوجل.',
            'auth/unauthorized-domain': 'تعذر تهيئة خدمة التحقق على هذا الموقع.',
            'auth/captcha-check-failed': 'تعذر التحقق من المتصفح. أعد إدخال الرقم وحاول مرة أخرى.',
            'auth/network-request-failed': 'تعذر الاتصال. راجع اتصال الإنترنت وحاول مرة أخرى.',
            'kidia/timeout': 'الاتصال استغرق وقتًا طويلًا. حاول مرة أخرى أو استخدم الدخول بجوجل.'
        };
        return error && error.kidiaMessage || messages[error && error.code] || 'تعذر إتمام التحقق. حاول مرة أخرى أو استخدم الدخول بجوجل.';
    }
    function showError(message, verification) {
        var field = byId(verification ? 'fme_lwp_verify_field_error' : 'fme_lwp_phone_field_error');
        if (field) { field.textContent = message; }
        var input = byId('verificationCode');
        if (verification && input) { input.setAttribute('aria-invalid', 'true'); }
        emit('error', message, verification ? 'verify' : 'send');
    }
    function busy(value) {
        document.querySelectorAll('#fma_lwp_code_verfiy_btn, .fma_lwp_code_verfiy_btn').forEach(function (button) {
            button.disabled = value;
            button.setAttribute('aria-busy', value ? 'true' : 'false');
            button.setAttribute('aria-disabled', value ? 'true' : 'false');
            if (!value) { button.style.removeProperty('background-color'); button.style.removeProperty('color'); }
        });
        var spinner = byId('fma_lwp_spinner_code_verify_icon');
        if (spinner) { spinner.style.display = value ? '' : 'none'; }
        var input = byId('verificationCode');
        if (input) { input.readOnly = value; }
    }
    function bounded(promise, milliseconds) {
        return new Promise(function (resolve, reject) {
            var timer = window.setTimeout(function () { reject({code: 'kidia/timeout'}); }, milliseconds);
            Promise.resolve(promise).then(function (value) { window.clearTimeout(timer); resolve(value); }, function (error) { window.clearTimeout(timer); reject(error); });
        });
    }
    function stopSms() {
        window.clearTimeout(smsTimeout);
        if (smsController) { smsController.abort(); smsController = null; }
    }
    function digits(value) {
        return String(value || '').replace(/[٠-٩]/g, function (v) { return String(v.charCodeAt(0) - 1632); })
            .replace(/[۰-۹]/g, function (v) { return String(v.charCodeAt(0) - 1776); }).replace(/[^0-9]/g, '').slice(0, 6);
    }
    function prepareInput() {
        var input = byId('verificationCode');
        if (!input) { return; }
        input.setAttribute('autocomplete', 'one-time-code');
        input.setAttribute('inputmode', 'numeric');
        input.setAttribute('pattern', '[0-9]{6}');
        input.setAttribute('maxlength', '6');
        input.setAttribute('aria-label', 'كود التحقق المكون من 6 أرقام');
        input.setAttribute('dir', 'ltr');
        if (!input.dataset.kidiaOtpInput) {
            input.dataset.kidiaOtpInput = '1';
            input.addEventListener('input', function () {
                input.value = digits(input.value);
                input.removeAttribute('aria-invalid');
            });
        }
    }
    function startSms() {
        stopSms();
        prepareInput();
        if (!('OTPCredential' in window) || !navigator.credentials || !window.AbortController) { return; }
        smsController = new AbortController();
        var controller = smsController, current = generation;
        smsTimeout = window.setTimeout(stopSms, 120000);
        // WebOTP only reads an origin-bound SMS after the browser obtains consent.
        Promise.resolve().then(function () {
            return navigator.credentials.get({otp: {transport: ['sms']}, signal: controller.signal});
        }).then(function (credential) {
            if (current !== generation || controller.signal.aborted || !credential) { return; }
            var input = byId('verificationCode');
            if (input) { input.value = digits(credential.code); input.dispatchEvent(new Event('input', {bubbles: true})); }
            stopSms();
        }).catch(function () {
            if (smsController === controller) { stopSms(); }
            /* Manual entry remains available when unsupported or declined. */
        });
    }
    function completeLogin() {
        if (typeof fme_lwp_save_checkout_fields === 'function') { fme_lwp_save_checkout_fields(); }
        emit('success');
        var destination = new URL(window.KidiaLogin && KidiaLogin.loginUrl || '/login-register/', location.origin);
        window.location.replace(destination.origin === location.origin ? destination.href : '/login-register/');
    }
    function clearChoices() {
        choiceSession = null; selecting = false;
        if (choicePanel) { choicePanel.remove(); choicePanel = null; }
        var native = byId('kidia-otp-native');
        if (native) { native.classList.remove('kidia-choosing-account'); }
    }
    function showChoices(accounts, session) {
        var native = byId('kidia-otp-native');
        if (!native || !Array.isArray(accounts) || accounts.length < 2) {
            throw {kidiaMessage:'تعذر عرض الحسابات. أعد التحقق من الهاتف.'};
        }
        clearChoices();
        choiceSession = session;
        session.accounts = accounts;
        var panel = document.createElement('section');
        panel.className = 'kidia-otp-accounts';
        panel.setAttribute('aria-labelledby', 'kidia-accounts-title');
        var title = document.createElement('h3');
        title.id = 'kidia-accounts-title'; title.tabIndex = -1;
        title.textContent = 'اختار الحساب اللي تحب تدخل بيه';
        var intro = document.createElement('p');
        intro.className = 'kidia-accounts-intro';
        intro.textContent = 'تم تأكيد رقمك. اختار حسابك عشان تكمّل.';
        var list = document.createElement('div'); list.className = 'kidia-accounts-list';
        accounts.forEach(function (account, index) {
            var button = document.createElement('button');
            button.type = 'button'; button.className = 'kidia-account-option';
            var number = document.createElement('span'); number.className = 'kidia-account-number';
            number.textContent = String(index + 1); number.setAttribute('aria-hidden', 'true');
            var details = document.createElement('span'); details.className = 'kidia-account-description';
            var name = document.createElement('strong'); name.textContent = account.name;
            var email = document.createElement('span'); email.className = 'kidia-account-hint';
            email.textContent = account.email || 'حساب برقم الهاتف';
            if (account.email) { email.dir = 'ltr'; }
            var date = document.createElement('small'); date.textContent = 'عضو منذ ' + account.since;
            details.append(name, email, date);
            var arrow = document.createElement('span'); arrow.className = 'kidia-account-arrow';
            arrow.textContent = '←'; arrow.setAttribute('aria-hidden', 'true');
            button.append(number, details, arrow);
            button.addEventListener('click', function () { selectAccount(account.id, button); });
            list.appendChild(button);
        });
        var feedback = document.createElement('p');
        feedback.className = 'kidia-account-feedback'; feedback.hidden = true; feedback.setAttribute('role', 'status');
        panel.append(title, intro, list, feedback);
        choicePanel = panel;
        native.appendChild(panel); native.classList.add('kidia-choosing-account');
        emit('choosing');
        title.focus({preventScroll:true});
        panel.scrollIntoView({block:'nearest',behavior:'auto'});
    }
    async function selectAccount(id, button) {
        var session = choiceSession, panel = choicePanel;
        if (selecting || !session || session.current !== generation) { return; }
        selecting = true;
        var buttons = panel.querySelectorAll('.kidia-account-option');
        buttons.forEach(function (item) { item.disabled = true; });
        button.classList.add('is-selecting'); panel.setAttribute('aria-busy', 'true');
        var feedback = panel.querySelector('.kidia-account-feedback');
        feedback.hidden = false; feedback.classList.add('is-loading'); feedback.setAttribute('role', 'status');
        feedback.textContent = 'جاري تسجيل الدخول…';
        try {
            // Revalidate the same signed phone proof and exact selected ID on the server.
            activeRequest = jQuery.ajax({url:fmelwpDataObj.ajaxurl,method:'POST',timeout:20000,dataType:'json',data:{
                action:'fme_lwp_process_otp_validation',phone_number:session.phone,
                nonce:fmelwpDataObj.nonce,firebaseIdToken:session.token,kidia_account_id:id
            }});
            var response = await bounded(activeRequest, 21000);
            if (choiceSession !== session || session.current !== generation) { return; }
            if (!response || !response.success || response.chooseAccount) { throw {kidiaMessage:response && response.message}; }
            choiceSession = null;
            completeLogin();
        } catch (error) {
            if (choiceSession !== session || session.current !== generation) { return; }
            feedback.classList.remove('is-loading'); feedback.setAttribute('role','alert');
            feedback.textContent = error && error.responseJSON && error.responseJSON.message || failure(error);
            buttons.forEach(function (item) { item.disabled = false; });
        } finally {
            if (session.current === generation) {
                selecting = false; activeRequest = null;
                button.classList.remove('is-selecting'); panel.removeAttribute('aria-busy');
            }
        }
    }

    document.addEventListener('kidia:otp-reset', function () {
        generation += 1;
        clearChoices();
        activeVerification = null;
        if (activeRequest && activeRequest.abort) { activeRequest.abort(); }
        activeRequest = null;
        stopSms();
        busy(false);
    });
    window.addEventListener('pagehide', stopSms);
    prepareInput();

    window.fma_lwp_firebase_otp_init = function (phone) {
        var current = ++generation;
        clearChoices();
        if (activeRequest && activeRequest.abort) { activeRequest.abort(); }
        activeRequest = null;
        activeVerification = null;
        window.confirmationResult = null;
        busy(false);
        emit('sending');
        startSms();
        return bounded(Promise.resolve().then(function () {
            return firebase.auth().signInWithPhoneNumber(phone, window.recaptchaVerifier);
        }), 20000).then(function (confirmation) {
            if (current !== generation) { return; }
            window.confirmationResult = confirmation;
            prepareInput();
            fme_lwp_disable_button();
            fme_lwp_resend_otp_timer();
            return bounded(jQuery.ajax({url: fmelwpDataObj.ajaxurl, method: 'POST', timeout: 15000, dataType: 'json', data: {
                action: 'fme_lwp_process_otp_init', phone_number: phone,
                nonce: fmelwpDataObj.nonce, firebaseResponse: confirmation.verificationId
            }}), 16000).then(function (response) {
                if (current !== generation) { return; }
                if (!response || !response.success) { throw {kidiaMessage: response && response.message || 'تعذر تجهيز خانة الكود. أعد إدخال الرقم.'}; }
                fme_lwp_process_otp_init_response(response);
                emit('sent');
            });
        }).catch(function (error) {
            if (current !== generation) { return; }
            generation += 1;
            window.confirmationResult = null;
            stopSms();
            fme_lwp_enable_button();
            var spinner = byId('fma_lwp_spinner_icon');
            if (spinner) { spinner.style.display = 'none'; }
            showError(failure(error), false);
            console.warn('Kidia phone sign-in:', error && error.code || 'send-failed');
            throw new Error(failure(error));
        });
    };

    window.fma_lwp_firebase_otp_validation = function (phone, code, changeRequest) {
        if (activeVerification) { return activeVerification; }
        code = digits(code);
        if (!window.confirmationResult || changeRequest || code.length !== 6) {
            busy(false);
            showError(code.length !== 6 ? 'اكتب كود التحقق المكون من 6 أرقام.' : 'أعد إدخال الرقم لطلب كود تحقق جديد.', true);
            return Promise.resolve();
        }
        stopSms();
        var current = generation, confirmation = window.confirmationResult;
        busy(true);
        emit('verifying');
        var verification = bounded(Promise.resolve().then(function () { return confirmation.confirm(code); }), 25000)
            .then(function (result) {
                if (current !== generation) { throw {cancelled: true}; }
                return bounded(result.user.getIdToken(true), 15000);
            }).then(function (idToken) {
                if (current !== generation) { throw {cancelled: true}; }
                activeRequest = jQuery.ajax({url: fmelwpDataObj.ajaxurl, method: 'POST', timeout: 20000, dataType: 'json', data: {
                    action: 'fme_lwp_process_otp_validation', phone_number: phone,
                    nonce: fmelwpDataObj.nonce, firebaseIdToken: idToken
                }});
                return bounded(activeRequest, 21000).then(function (response) {
                    if (response && response.chooseAccount && response.success && current === generation) {
                        showChoices(response.accounts, {phone:phone, token:idToken, current:current});
                    }
                    return response;
                });
            }).then(function (response) {
                if (current !== generation) { return; }
                if (!response || !response.success) { throw {kidiaMessage: response && response.message}; }
                if (response.chooseAccount) { return; }
                completeLogin();
            }).catch(function (error) {
                if (current !== generation || error && error.cancelled) { return; }
                var message = error && error.responseJSON && error.responseJSON.message || failure(error);
                showError(message, true);
            }).finally(function () {
                if (current === generation) { busy(false); activeRequest = null; activeVerification = null; }
            });
        activeVerification = verification;
        return verification;
    };
}());
