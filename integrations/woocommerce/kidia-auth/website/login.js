(function () {
	'use strict';

	var config = window.KidiaLogin || {};
	var root = document.querySelector('.kidia-auth-shell');

	if (!root) {
		return;
	}

	var stages = Array.prototype.slice.call(root.querySelectorAll('[data-kidia-stage]'));
	var card = root.querySelector('.kidia-auth-card');
	var identifierForm = root.querySelector('.kidia-identifier-form');
	var identifierInput = root.querySelector('#kidia-identifier');
	var feedback = root.querySelector('#kidia-identifier-feedback');
	var continueButton = identifierForm ? identifierForm.querySelector('.kidia-primary-button') : null;
	var emailForm = root.querySelector('.kidia-email-form');
	var emailInput = root.querySelector('[data-kidia-email-input]');
	var registerEmailField = root.querySelector('.kidia-register-email-field');
	var emailDisplay = root.querySelector('[data-kidia-email-display]');
	var emailAction = root.querySelector('[data-kidia-email-action]');
	var emailTitle = root.querySelector('[data-kidia-email-title]');
	var emailSubmit = root.querySelector('[data-kidia-email-submit]');
	var switchModeButton = root.querySelector('[data-kidia-switch-mode]');
	var forgotButton = root.querySelector('[data-kidia-forgot]');
	var passwordInput = root.querySelector('#kidia-password');
	var passwordError = root.querySelector('[data-kidia-password-error]');
	if (passwordInput && passwordError) {
		passwordInput.addEventListener('input', function () {
			passwordError.hidden = true;
			passwordError.textContent = '';
		});
	}
	var phoneDisplay = root.querySelector('[data-kidia-phone-display]');
	var nativePhone = root.querySelector('#kidia-otp-native');
	var phoneStatus = root.querySelector('[data-kidia-phone-status]');
	var phoneFallback = root.querySelector('[data-kidia-phone-fallback]');
	var phoneExisting = root.querySelector('[data-kidia-phone-existing]');
	var phoneHiddenInputs = root.querySelectorAll('[data-kidia-phone-hidden]');
	var useOtpButton = root.querySelector('[data-kidia-use-otp]');
	var phoneAutoSendTimer = null;
	var phoneCooldownTimer = null;
	var phoneSendWatchdog = null;
	var phoneCooldownUntil = 0;
	var phoneSendAttempts = Object.create(null);
	var phoneRequestInFlight = false;
	var phoneFlowGeneration = 0;
	var identifierGeneration = 0, identifierController = null, identifierPending = false;
	var verificationAttempts = 0;
	var verificationWasVisible = false;
	var existingPhoneFlow = false;
	var strings = config.strings || {};
	var emailMode = 'login';
	var emailFallbackActive = false;
	var authIntro = root.querySelector('.kidia-auth-intro');
	var fallbackNotice = root.querySelector('[data-kidia-email-fallback-notice]');
	var EGYPT_PHONE_PATTERN = /^01[0125]\d{8}$/;
	var PHONE_COOLDOWN_SECONDS = 60;
	var PHONE_MAX_SENDS = 3;
	var googlePopup = null;
	var stageFocusTimer = null;
	var socialBlock = root.querySelector('[data-kidia-social-block]');
	var socialHome = root.querySelector('[data-kidia-social-home]');
	var fallbackSocialSlot = root.querySelector('[data-kidia-fallback-social-slot]');
	var socialDividerLabel = root.querySelector('[data-kidia-social-divider] span');
	var googleStatus = root.querySelector('[data-kidia-google-status]');

	/* Open during the customer's click so browsers can allow the popup.
	 * Keep Nextend's opener/BroadcastChannel completion and return URL.
	 * A blocked popup must not unexpectedly replace the login page. */
	root.addEventListener('click', function (event) {
		var link = event.target && event.target.closest
			? event.target.closest('a[data-plugin="nsl"][data-provider="google"][data-action="connect"]') : null;
		if (!link) { return; }
		event.preventDefault();
		event.stopImmediatePropagation();
		if (googleStatus) { googleStatus.hidden = true; googleStatus.textContent = ''; }
		try {
			if (googlePopup && !googlePopup.closed) { googlePopup.focus(); return; }
			if (typeof window.NSLPopup !== 'function') { throw new Error('popup-not-ready'); }
			var url = new URL(link.href, window.location.href);
			if (url.origin !== window.location.origin) { throw new Error('invalid-login-url'); }
			url.searchParams.set('display', 'popup');
			googlePopup = window.NSLPopup(url.href, 'nsl-social-connect', 600, 640);
			if (!googlePopup) { throw new Error('popup-blocked'); }
		} catch (error) {
			if (googleStatus) {
				googleStatus.textContent = 'تعذر فتح نافذة جوجل. اسمح بالنوافذ المنبثقة للموقع ثم اضغط جوجل مرة أخرى.';
				googleStatus.hidden = false;
			}
		}
	}, true);

	function showStage(name) {
		root.classList.toggle('kidia-phone-stage', name === 'phone');
		window.clearTimeout(stageFocusTimer);
		var googleAboveEmail = emailFallbackActive && name === 'identifier';
		var socialDestination = googleAboveEmail ? fallbackSocialSlot : socialHome;
		if (socialBlock && socialDestination) {
			// Move the existing button, keeping its popup behavior and avoiding duplicates.
			if (socialBlock.parentNode !== socialDestination) { socialDestination.appendChild(socialBlock); document.dispatchEvent(new CustomEvent('kidia:social-moved')); }
			socialBlock.classList.toggle('is-email-fallback', googleAboveEmail);
			if (socialDividerLabel) { socialDividerLabel.textContent = googleAboveEmail ? 'أو سجّل بالإيميل' : 'أو'; }
		}
		var keepKeyboardClosed = name === 'email' || name === 'phone' || googleAboveEmail;
		if (keepKeyboardClosed && document.activeElement && typeof document.activeElement.blur === 'function') {
			document.activeElement.blur();
		}
		stages.forEach(function (stage) {
			var active = stage.getAttribute('data-kidia-stage') === name;
			stage.hidden = !active;
			stage.classList.toggle('is-entering', active);
		});
		if (card) {
			card.scrollTop = 0;
		}

		if (keepKeyboardClosed) { return; }
		stageFocusTimer = window.setTimeout(function () {
			var activeStage = root.querySelector('[data-kidia-stage="' + name + '"]');
			if (!activeStage || activeStage.hidden) {
				return;
			}

			var focusTarget = activeStage.querySelector('input:not([type="hidden"])');
			/* The email fallback and password screens wait for the customer's tap. */
			if (focusTarget && focusTarget.type !== 'password') {
				focusTarget.focus({ preventScroll: true });
			}
		}, 80);
	}

	function setFeedback(message) {
		if (!feedback) {
			return;
		}

		feedback.textContent = message || '';
		identifierInput.setAttribute('aria-invalid', message ? 'true' : 'false');
	}

	function setLoading(loading) {
		if (!continueButton) {
			return;
		}

		continueButton.disabled = loading;
		continueButton.classList.toggle('is-loading', loading);
		var label = continueButton.querySelector('.kidia-button-label');
		if (label) {
			label.textContent = loading ? (strings.checking || 'جاري التحقق…') : 'متابعة';
		}
	}

	function isEmail(value) {
		return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
	}

	function isPhone(value) {
		var digits = value.replace(/\D/g, '');
		return EGYPT_PHONE_PATTERN.test(digits);
	}

	function normalizePhone(value) {
		return value.replace(/\D/g, '');
	}

	function isPhoneLike(value) {
		return /^[\d\s()+-]*$/.test(value);
	}

	function syncIdentifierButton() {
		if (!identifierInput || !continueButton || continueButton.classList.contains('is-loading')) {
			return;
		}

		var value = identifierInput.value.trim();
		var valid = isEmail(value) || (!emailFallbackActive && isPhone(value));
		continueButton.disabled = !valid;
		continueButton.setAttribute('aria-disabled', valid ? 'false' : 'true');
	}

	function showEmailFallback() {
        var failedPhone = phoneDisplay ? normalizePhone(phoneDisplay.textContent || '') : '';
        if (existingPhoneFlow) {
            resetFirebasePhoneSession();
            showExistingPhone(failedPhone, !!(root.querySelector('[data-kidia-phone-account-email]') && !root.querySelector('[data-kidia-phone-account-email]').hidden));
            if (useOtpButton) useOtpButton.hidden = true;
            setPhoneError('تعذر إرسال كود التحقق. ادخل بكلمة المرور أو جوجل.');
            return;
        }
        if (window.KidiaAuthFallback && window.KidiaAuthFallback(failedPhone, false)) return;
		if (emailFallbackActive) { return; }
		emailFallbackActive = true;
		window.clearInterval(phoneAutoSendTimer);
		window.clearInterval(phoneCooldownTimer);
		phoneCooldownUntil = 0;
		resetFirebasePhoneSession();
		root.classList.remove('kidia-phone-prefilled', 'kidia-phone-sending', 'kidia-phone-code-ready');
		setPhoneError('');
		setFeedback('');
		setLoading(false);
		if (identifierInput) {
			identifierInput.value = '';
			identifierInput.type = 'email';
			identifierInput.placeholder = 'البريد الإلكتروني';
			identifierInput.setAttribute('inputmode', 'email');
			identifierInput.setAttribute('autocomplete', 'email');
			identifierInput.setAttribute('aria-label', 'البريد الإلكتروني');
		}
		if (authIntro) { authIntro.textContent = 'تابع باستخدام جوجل أو بريدك الإلكتروني'; }
		if (fallbackNotice) {
			fallbackNotice.textContent = 'حصل خطأ في إرسال كود التحقق. سجّل بالإيميل أو جوجل.';
			fallbackNotice.hidden = false;
		}
		syncIdentifierButton();
		showStage('identifier');
	}

	function phoneErrorElement() {
		return nativePhone ? nativePhone.querySelector('#fme_lwp_phone_field_error') : null;
	}

	function phoneErrorMessage(message) {
		return message || '';
	}

	function setPhoneError(message) {
		message = phoneErrorMessage(message);
		if (phoneFallback) { phoneFallback.hidden = !message; }
		if (message) {
			window.clearTimeout(phoneSendWatchdog);
			root.classList.remove('kidia-phone-sending');
		}
		if (phoneStatus) {
			phoneStatus.textContent = message || '';
			phoneStatus.hidden = !message;
		}
		var error = phoneErrorElement();
		if (!error) {
			return;
		}
		error.textContent = message || '';
		/* Kidia renders the customer-facing error in phoneStatus above.
		 * Keep the vendor field populated for its internal flow, but hidden so
		 * the same sentence is not printed a second time underneath. */
		error.style.display = 'none';
	}

	document.addEventListener('kidia:otp-state', function (event) {
		var detail = event.detail || {};
		if (detail.state === 'error') {
			if (detail.phase === 'send') { showEmailFallback(); }
			else { setPhoneError(detail.message); }
		}
		if (detail.state === 'sending' || detail.state === 'verifying' || detail.state === 'sent') { setPhoneError(''); }
		if (detail.state === 'sent' || detail.state === 'error' || detail.state === 'success') {
			window.clearTimeout(phoneSendWatchdog);
			root.classList.remove('kidia-phone-sending');
		}
	});

	function popupText(popup) {
		return Array.prototype.map.call(
			popup.querySelectorAll('.swal2-title, .swal2-html-container, .sweet-alert h2, .sweet-alert p, .swal-title, .swal-text'),
			function (node) { return (node.textContent || '').trim(); }
		).filter(Boolean).join(' ');
	}

	function popupIsSuccess(popup) {
		return !!popup.querySelector('.swal2-success, .sa-success, .swal-icon--success') ||
			popup.classList.contains('swal2-icon-success');
	}

	function showPopupErrorInline(message) {
		var verification = nativePhone ? nativePhone.querySelector('#fma_lwp_verification_code_div') : null;
		var verificationVisible = verification && window.getComputedStyle(verification).display !== 'none';
		var target = verificationVisible && nativePhone
			? nativePhone.querySelector('#fme_lwp_verify_field_error')
			: phoneErrorElement();

		var normalized = (message || '').toLowerCase();
		if (normalized.indexOf('too_many_attempts') !== -1 || normalized.indexOf('too many attempts') !== -1) {
			message = 'تمت محاولات كثيرة خلال وقت قصير. غيّر رقم الهاتف أو حاول مرة أخرى لاحقًا.';
		} else if (normalized.indexOf('invalid') !== -1 && normalized.indexOf('code') !== -1) {
			message = 'كود التحقق غير صحيح. راجع الأرقام وحاول مرة أخرى.';
		} else if (normalized.indexOf('expired') !== -1) {
			message = 'انتهت صلاحية الكود. اطلب كودًا جديدًا.';
		} else if (!message || message.length < 3) {
			message = verificationVisible
				? 'تعذر تأكيد الكود. راجع الكود وحاول مرة أخرى.'
				: 'تعذر إرسال كود التحقق. اضغط تغيير الرقم ثم حاول مرة أخرى.';
		}

		if (!verificationVisible) { showEmailFallback(); return; }
		setPhoneError(message);
		if (target) {
			target.textContent = message;
			target.style.display = 'none';
		}
	}

	/*
	 * The phone-login extension uses SweetAlert for both success and failure.
	 * Keep its callback/redirect working, but never expose the modal to customers:
	 * success is confirmed automatically, while failures are rendered inline.
	 */
	function suppressPhonePopup(popup) {
		if (!popup || popup.getAttribute('data-kidia-popup-handled') === '1') {
			return;
		}

		popup.setAttribute('data-kidia-popup-handled', '1');
		popup.style.setProperty('display', 'none', 'important');

		var success = popupIsSuccess(popup);
		if (!success) {
			showPopupErrorInline(popupText(popup));
		}

		var confirm = popup.querySelector('.swal2-confirm, .sweet-alert .confirm, .swal-button--confirm, button.confirm');
		if (success && confirm) {
			window.setTimeout(function () { confirm.click(); }, 0);
		}

		function removePopup() {
			var container = popup.matches('.swal2-container, .swal-overlay')
				? popup
				: popup.closest('.swal2-container, .swal-overlay');
			if (container && container.parentNode) {
				container.parentNode.removeChild(container);
			} else if (popup.parentNode) {
				popup.parentNode.removeChild(popup);
			}
			document.querySelectorAll('.sweet-overlay, .swal2-backdrop-show').forEach(function (overlay) {
				overlay.style.setProperty('display', 'none', 'important');
			});
			document.documentElement.classList.remove('swal2-shown', 'swal2-height-auto');
			document.body.classList.remove('swal2-shown', 'swal2-height-auto', 'stop-scrolling');
			document.body.style.removeProperty('overflow');
		}

		if (success) {
			window.setTimeout(removePopup, 80);
		} else {
			removePopup();
		}
	}

	function inspectPhonePopups() {
		if (!document || !document.body) {
			return;
		}
		document.querySelectorAll('.swal2-container, .sweet-alert, .swal-modal, .swal-overlay').forEach(function (popup) {
			window.setTimeout(function () { suppressPhonePopup(popup); }, 0);
		});
	}

	var phonePopupObserver = new MutationObserver(inspectPhonePopups);
	phonePopupObserver.observe(document.body, { childList: true, subtree: true });
	inspectPhonePopups();

	function phoneAlertDetails(args) {
		var options = args[0] && typeof args[0] === 'object' ? args[0] : {};
		var icon = String(options.icon || options.type || args[2] || '').toLowerCase();
		var message = [options.title, options.text, options.html, args[0], args[1]]
			.filter(function (value) { return typeof value === 'string'; })
			.join(' ')
			.replace(/<[^>]+>/g, ' ')
			.trim();
		return {
			success: icon === 'success' || /success|verified|تم بنجاح|تم إرسال/.test(message.toLowerCase()),
			message: message
		};
	}

	function silentAlertResult(success) {
		return Promise.resolve(success
			? { isConfirmed: true, isDismissed: false, value: true }
			: { isConfirmed: false, isDismissed: true, value: false });
	}

	function wrapPhoneAlertFunction(owner, property) {
		if (!owner || typeof owner[property] !== 'function' || owner[property].__kidiaSilentPhoneAlert) {
			return;
		}

		var original = owner[property];
		var wrapped = function () {
			var args = Array.prototype.slice.call(arguments);
			var details = phoneAlertDetails(args);
			var callback = args.filter(function (arg) { return typeof arg === 'function'; }).pop();

			if (!details.success) {
				showPopupErrorInline(details.message);
			} else if (callback) {
				window.setTimeout(function () { callback(true); }, 0);
			}

			return silentAlertResult(details.success);
		};

		Object.keys(original).forEach(function (key) {
			try { wrapped[key] = original[key]; } catch (error) { /* Read-only library property. */ }
		});
		wrapped.__kidiaSilentPhoneAlert = true;
		wrapped.__kidiaOriginal = original;
		owner[property] = wrapped;
	}

	function installPhoneAlertInterceptors() {
		wrapPhoneAlertFunction(window, 'swal');
		wrapPhoneAlertFunction(window, 'sweetAlert');
		if (window.Swal) {
			wrapPhoneAlertFunction(window.Swal, 'fire');
		}
	}

	installPhoneAlertInterceptors();
	var phoneAlertInstallAttempts = 0;
	var phoneAlertInstallTimer = window.setInterval(function () {
		phoneAlertInstallAttempts += 1;
		installPhoneAlertInterceptors();
		if (phoneAlertInstallAttempts >= 120) {
			window.clearInterval(phoneAlertInstallTimer);
		}
	}, 250);

	function localizePhoneErrors() {
		if (!nativePhone) {
			return;
		}

		nativePhone.querySelectorAll('#fme_lwp_phone_field_error, #fme_lwp_verify_field_error').forEach(function (element) {
			var message = (element.textContent || '').trim();
			var normalized = message.toLowerCase();
			if (!message) {
				return;
			}

			if (normalized.indexOf('too_many_attempts') !== -1 || normalized.indexOf('too many attempts') !== -1) {
				element.textContent = 'تمت محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مرة أخرى.';
			} else if (normalized.indexOf('invalid-phone') !== -1 || normalized.indexOf('invalid phone') !== -1) {
				element.textContent = 'رقم الهاتف غير صحيح. اكتبه 11 رقمًا ويبدأ بـ 010 أو 011 أو 012 أو 015.';
			} else if (normalized.indexOf('quota') !== -1) {
				element.textContent = 'تعذر إرسال الكود مؤقتًا. حاول مرة أخرى لاحقًا.';
			} else if (normalized.indexOf('expired') !== -1) {
				element.textContent = 'انتهت صلاحية الكود. اطلب كودًا جديدًا.';
			} else if (normalized.indexOf('invalid') !== -1 && normalized.indexOf('code') !== -1) {
				element.textContent = 'كود التحقق غير صحيح. راجع الأرقام وحاول مرة أخرى.';
			}

			/* The vendor sometimes reports Firebase failures only in its own hidden
			 * element. Mirror send failures into Kidia's visible inline status. */
			if (element.id === 'fme_lwp_phone_field_error' && element.textContent.trim()) {
				var visibleMessage = phoneErrorMessage(element.textContent.trim());
				if (element.textContent.trim() !== visibleMessage) {
					element.textContent = visibleMessage;
				}
				if (phoneStatus && phoneStatus.textContent !== visibleMessage) {
					phoneStatus.textContent = visibleMessage;
					phoneStatus.hidden = false;
				}
				window.clearTimeout(phoneSendWatchdog);
				root.classList.remove('kidia-phone-sending');
			}
		});
	}

	function startPhoneSendWatchdog() {
		window.clearTimeout(phoneSendWatchdog);
		phoneSendWatchdog = window.setTimeout(function () {
			var verification = nativePhone ? nativePhone.querySelector('#fma_lwp_verification_code_div') : null;
			var visible = verification && window.getComputedStyle(verification).display !== 'none';
			if (!visible && (!phoneStatus || phoneStatus.hidden || !phoneStatus.textContent.trim())) {
				showEmailFallback();
			}
		}, 22000);
	}

	function nativePhoneElements() {
		return {
			input: nativePhone ? nativePhone.querySelector('#fme_lwp_phone_number_field') : null,
			button: nativePhone ? nativePhone.querySelector('#fma_lwp_send_code_btn') : null
		};
	}

	function syncNativePhoneButton(showError) {
		var elements = nativePhoneElements();
		if (!elements.input || !elements.button) {
			return false;
		}

		var digits = normalizePhone(elements.input.value).slice(0, 11);
		if (elements.input.value !== digits) {
			elements.input.value = digits;
		}

		var valid = EGYPT_PHONE_PATTERN.test(digits);
		var coolingDown = Date.now() < phoneCooldownUntil;
		var attemptLimitReached = (phoneSendAttempts[digits] || 0) >= PHONE_MAX_SENDS;
		var enabled = valid && !coolingDown && !attemptLimitReached;

		elements.button.disabled = !enabled;
		elements.button.setAttribute('aria-disabled', enabled ? 'false' : 'true');

		if (showError && digits && !valid) {
			setPhoneError(digits.length === 11
				? 'رقم الهاتف يجب أن يبدأ بـ 010 أو 011 أو 012 أو 015.'
				: 'اكتب رقم هاتف مصريًا مكوّنًا من 11 رقمًا.');
		} else if (valid && !attemptLimitReached) {
			setPhoneError('');
		}

		if (attemptLimitReached) {
			showEmailFallback();
		}

		return enabled;
	}

	function startPhoneCooldown(phone) {
		var digits = normalizePhone(phone);
		phoneSendAttempts[digits] = (phoneSendAttempts[digits] || 0) + 1;
		phoneCooldownUntil = Date.now() + (PHONE_COOLDOWN_SECONDS * 1000);
		window.clearInterval(phoneCooldownTimer);

		phoneCooldownTimer = window.setInterval(function () {
			var elements = nativePhoneElements();
			var remaining = Math.max(0, Math.ceil((phoneCooldownUntil - Date.now()) / 1000));
			if (elements.button && remaining > 0) {
				elements.button.disabled = true;
				elements.button.setAttribute('aria-disabled', 'true');
				elements.button.textContent = 'إعادة الإرسال بعد ' + remaining + ' ثانية';
				return;
			}

			window.clearInterval(phoneCooldownTimer);
			if (elements.button) {
				elements.button.textContent = 'إعادة إرسال الكود';
			}
			var lastError = phoneStatus && !phoneStatus.hidden ? phoneStatus.textContent : '';
			syncNativePhoneButton(false);
			if (lastError) { setPhoneError(lastError); }
		}, 250);
	}

	function localizeNativePhoneField(preserveError) {
		if (!nativePhone) {
			return false;
		}

		var input = nativePhone.querySelector('#fme_lwp_phone_number_field');
		if (!input) {
			return false;
		}

		input.setAttribute('placeholder', '01XXXXXXXXX');
		input.setAttribute('inputmode', 'numeric');
		input.setAttribute('enterkeyhint', 'send');
		input.setAttribute('autocomplete', 'tel-national');
		input.setAttribute('pattern', '01[0125][0-9]{8}');
		input.setAttribute('minlength', '11');
		input.setAttribute('maxlength', '11');
		input.setAttribute('dir', 'ltr');
		input.setAttribute('aria-label', 'رقم الهاتف المصري');
		if (!preserveError) {
			syncNativePhoneButton(false);
		}
		return true;
	}

	function setEmailMode(mode) {
		emailMode = mode === 'register' ? 'register' : 'login';
		var isRegister = emailMode === 'register';
        root.querySelectorAll('.kidia-register-name-field, .kidia-register-confirm-field').forEach(function(label){
            label.hidden = !isRegister;
            var input=label.querySelector('input'); input.disabled=!isRegister; input.required=isRegister;
        });
		root.classList.toggle('is-register-mode', isRegister);

		if (emailAction) {
			emailAction.value = emailMode;
		}
		if (emailTitle) {
			emailTitle.textContent = isRegister
				? (strings.registerTitle || 'أنشئ كلمة مرور جديدة')
				: (strings.loginTitle || 'أدخل كلمة المرور');
		}
		if (emailSubmit) {
			emailSubmit.textContent = isRegister
				? (strings.registerButton || 'إنشاء الحساب')
				: (strings.loginButton || 'تسجيل الدخول');
		}
		if (switchModeButton) {
			switchModeButton.textContent = isRegister ? 'لديك حساب بالفعل؟' : 'إنشاء حساب جديد';
		}
		if (emailForm) {
			emailForm.classList.toggle('is-register-mode', isRegister);
		}
		if (registerEmailField) {
			registerEmailField.hidden = !isRegister;
		}
		if (passwordInput) {
			passwordInput.autocomplete = isRegister ? 'new-password' : 'current-password';
			passwordInput.value = '';
		}
	}

	function openEmail(email, exists) {
		if (emailInput) {
			emailInput.value = email;
		}
		if (emailDisplay) {
			emailDisplay.textContent = email;
		}
		setEmailMode(exists ? 'login' : 'register');
		showStage('email');
	}

	function fillNativePhone(phone) {
		if (!nativePhone) {
			return false;
		}

		// The country picker adds a text search before the actual telephone field.
		var input = nativePhone.querySelector('#fme_lwp_phone_number_field');
		if (!input) {
			return false;
		}

		localizeNativePhoneField();
		input.value = normalizePhone(phone);
		input.dispatchEvent(new Event('input', { bubbles: true }));
		input.dispatchEvent(new Event('change', { bubbles: true }));
		return true;
	}

	function nativePhoneReady() {
		var button = nativePhone ? nativePhone.querySelector('#fma_lwp_send_code_btn') : null;
		var input = nativePhone ? nativePhone.querySelector('#fme_lwp_phone_number_field') : null;
		if (!button || !input || !isPhone(input.value) || Date.now() < phoneCooldownUntil || phoneRequestInFlight || !window.fme_lwp_phone_input_field || !window.recaptchaVerifier || typeof window.fma_lwp_firebase_otp_init !== 'function') {
			return false;
		}
		try {
			return window.fme_lwp_phone_input_field.isValidNumber();
		} catch (error) {
			return false;
		}
	}

	function requestPhoneSendPermission(phone) {
		if (!config.ajaxUrl || !config.nonce || !window.fetch) {
			return Promise.reject(new Error('تعذر تأمين طلب الإرسال. حدّث الصفحة وحاول مرة أخرى.'));
		}

		var body = new URLSearchParams();
		body.append('action', 'kidia_phone_send_permission');
		body.append('nonce', config.nonce);
		body.append('phone', normalizePhone(phone));

		var controller = new AbortController();
		var timeout = window.setTimeout(function () { controller.abort(); }, 15000);
		return window.fetch(config.ajaxUrl, {
			method: 'POST',
			signal: controller.signal,
			credentials: 'same-origin',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
			body: body.toString()
		}).then(function (response) {
			return response.json().catch(function () { return null; });
		}).then(function (payload) {
			if (!payload || !payload.success) {
				var message = payload && payload.data && payload.data.message
					? payload.data.message
					: 'تعذر بدء إرسال الكود. حاول مرة أخرى.';
				throw new Error(message);
			}
			return payload.data;
		}).catch(function (error) {
			if (error && error.name === 'AbortError') { throw new Error('الاتصال استغرق وقتًا طويلًا. أعد إدخال الرقم وحاول مرة أخرى.'); }
			throw error;
		}).finally(function () {
			window.clearTimeout(timeout);
		});
	}

	function resetFirebasePhoneSession() {
		phoneFlowGeneration += 1;
		window.clearTimeout(phoneSendWatchdog);
		phoneRequestInFlight = false;
		verificationAttempts = 0;
		verificationWasVisible = false;
		window.confirmationResult = null;
		document.dispatchEvent(new CustomEvent('kidia:otp-reset'));

		/* The phone provider owns this verifier and renders it asynchronously.
		 * Clearing it and calling its global render() here raced the provider's
		 * own next-tick render, producing "reCAPTCHA has already been rendered".
		 * Keep the single verifier alive when changing numbers; Firebase supports
		 * reusing it for the next sign-in attempt. */

		if (nativePhone) {
			nativePhone.querySelectorAll('#verificationCode, #fme_lwp_phone_number_field').forEach(function (input) {
				input.value = '';
			});
			nativePhone.querySelectorAll('#fme_lwp_phone_field_error, #fme_lwp_verify_field_error').forEach(function (error) {
				error.textContent = '';
				error.style.display = 'none';
			});
			var verification = nativePhone.querySelector('#fma_lwp_verification_code_div');
			if (verification) { verification.style.display = 'none'; }
		}
	}

	function autoSendPhoneCode(phone) {
		var attempts = 0;
		window.clearInterval(phoneAutoSendTimer);
		root.classList.add('kidia-phone-prefilled', 'kidia-phone-sending');

		phoneAutoSendTimer = window.setInterval(function () {
			attempts += 1;
			fillNativePhone(phone);
			if (emailFallbackActive) { window.clearInterval(phoneAutoSendTimer); return; }

			if (nativePhoneReady()) {
				window.clearInterval(phoneAutoSendTimer);
				var sendButton = nativePhone.querySelector('#fma_lwp_send_code_btn');
				sendButton.disabled = false;
				sendButton.click();
				return;
			}

			if (attempts >= 150) {
				window.clearInterval(phoneAutoSendTimer);
				root.classList.remove('kidia-phone-sending');
				showEmailFallback();
			}
		}, 100);
	}

	localizeNativePhoneField();
	if (nativePhone) {
		nativePhone.addEventListener('input', function (event) {
			if (event.target && event.target.id === 'fme_lwp_phone_number_field') {
				syncNativePhoneButton(true);
			}
		});

		nativePhone.addEventListener('click', function (event) {
			var verifyButton = event.target && event.target.closest ? event.target.closest('#fma_lwp_code_verfiy_btn') : null;
			if (verifyButton) {
				var codeInput = nativePhone.querySelector('#verificationCode');
				if (!codeInput || !/^\d{6}$/.test(codeInput.value)) {
					event.preventDefault();
					event.stopImmediatePropagation();
					setPhoneError('اكتب كود التحقق المكون من 6 أرقام.');
					return;
				}
				verificationAttempts += 1;
				if (verificationAttempts > 5) {
					event.preventDefault();
					event.stopImmediatePropagation();
					verifyButton.disabled = true;
					setPhoneError('تم تجاوز 5 محاولات. أعد إدخال الرقم لطلب كود جديد.');
					var verifyError = nativePhone.querySelector('#fme_lwp_verify_field_error');
					if (verifyError) {
						verifyError.textContent = 'تم تجاوز 5 محاولات. اطلب كودًا جديدًا ثم حاول مرة أخرى.';
						verifyError.style.display = 'block';
					}
				}
				return;
			}

			var button = event.target && event.target.closest ? event.target.closest('#fma_lwp_send_code_btn') : null;
			if (!button) {
				return;
			}

			event.preventDefault();
			event.stopImmediatePropagation();

			var elements = nativePhoneElements();
			if (!elements.input || !syncNativePhoneButton(true)) {
				return;
			}

			if (phoneRequestInFlight) {
				return;
			}

			var digits = normalizePhone(elements.input.value);
			var currentFlow = phoneFlowGeneration;
			phoneRequestInFlight = true;
			button.disabled = true;
			button.setAttribute('aria-disabled', 'true');
			button.textContent = 'جاري الإرسال…';

			requestPhoneSendPermission(digits)
				.then(function () {
					if (currentFlow !== phoneFlowGeneration) { return; }
					verificationAttempts = 0;
					startPhoneCooldown(digits);
					startPhoneSendWatchdog();
					var sendResult;
					try {
						sendResult = window.fma_lwp_firebase_otp_init('+20' + digits.slice(1));
					} catch (error) {
						throw error;
					}
					if (sendResult && typeof sendResult.catch === 'function') {
						return sendResult.catch(function (error) {
							throw error;
						});
					}
					return sendResult;
				})
				.catch(function (error) {
					if (currentFlow !== phoneFlowGeneration) { return; }
					window.clearInterval(phoneCooldownTimer);
					phoneCooldownUntil = 0;
					button.textContent = 'إرسال الكود';
					syncNativePhoneButton(false);
					/* Keep this after button syncing: syncing a valid number clears stale
					 * errors, so placing the real provider failure before it hid the only
					 * useful message from the customer. */
					showEmailFallback();
				})
				.finally(function () {
					if (currentFlow === phoneFlowGeneration) { phoneRequestInFlight = false; }
				});
		}, true);

		var phoneUiObserver = new MutationObserver(function () {
			/* Text changes inside the vendor error nodes also trigger this observer.
			 * Do not re-sync the input here because a valid input would clear the
			 * provider error immediately after we rendered it. */
			localizeNativePhoneField(true);
			localizePhoneErrors();
		});
		phoneUiObserver.observe(nativePhone, { childList: true, subtree: true });
		window.setTimeout(function () { phoneUiObserver.disconnect(); }, 5000);
	}

	function openPhone(phone) {
		existingPhoneFlow = false;
		setPhoneError('');
		if (phoneDisplay) {
			phoneDisplay.textContent = phone;
		}
		showStage('phone');
		phoneHiddenInputs.forEach(function (input) { input.value = phone; });
		if (phoneExisting) { phoneExisting.hidden = true; }
		if (nativePhone) { nativePhone.hidden = false; }

		if (!nativePhone || nativePhone.getAttribute('data-phone-ready') !== '1') {
			showEmailFallback();
			return;
		}

		fillNativePhone(phone);
		autoSendPhoneCode(phone);
	}

	function showExistingPhone(phone, multiple) {
		// The customer chooses before a password field or SMS is requested.
		var accountEmail = root.querySelector('[data-kidia-phone-account-email]');
		if (accountEmail) {
			accountEmail.hidden = !multiple;
			var emailField = accountEmail.querySelector('input');
			emailField.disabled = !multiple; emailField.required = !!multiple;
		}
		var form = root.querySelector('.kidia-phone-password-form');
		var passwordChoice = root.querySelector('[data-kidia-use-password]');
		if (form) { form.hidden = !form.querySelector('.kidia-password-error'); }
		if (passwordChoice) { passwordChoice.setAttribute('aria-expanded', form && !form.hidden ? 'true' : 'false'); }
		existingPhoneFlow = true;
        if (useOtpButton) useOtpButton.hidden = false;
		setPhoneError('');
		if (phoneDisplay) { phoneDisplay.textContent = phone; }
		phoneHiddenInputs.forEach(function (input) { input.value = phone; });
		showStage('phone');
		root.classList.add('kidia-phone-prefilled');
		if (phoneExisting) { phoneExisting.hidden = false; }
		if (nativePhone) { nativePhone.hidden = true; }
	}

	function checkPhone(phone) {
		if (!config.ajaxUrl || !config.nonce || !window.fetch) {
			openPhone(phone);
			return;
		}
		setLoading(true);
		identifierPending = true;
		var currentLookup = ++identifierGeneration;
		var body = new URLSearchParams();
		body.append('action', 'kidia_check_phone');
		body.append('nonce', config.nonce);
		body.append('phone', phone);
		var lookupController = new AbortController();
		identifierController = lookupController;
		var lookupTimer = window.setTimeout(function () { lookupController.abort(); }, 15000);
		window.fetch(config.ajaxUrl, {
			signal: lookupController.signal,
			method: 'POST',
			credentials: 'same-origin',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
			body: body.toString()
		})
			.then(function (response) { return response.json(); })
			.then(function (payload) {
				if (currentLookup !== identifierGeneration) return;
				if (!payload || !payload.success) {
					throw new Error(payload && payload.data && payload.data.message ? payload.data.message : 'error');
				}
				if (payload.data.exists) {
					showExistingPhone(phone, !!payload.data.multiple);
				} else {
					openPhone(phone);
				}
			})
			.catch(function (error) {
				if (currentLookup !== identifierGeneration) return;
				showEmailFallback();
			})
			.finally(function () { window.clearTimeout(lookupTimer); if (currentLookup !== identifierGeneration) return; identifierPending = false; identifierController = null; setLoading(false); syncIdentifierButton(); });
	}

	var passwordChoice = root.querySelector('[data-kidia-use-password]');
	if (passwordChoice) {
		passwordChoice.addEventListener('click', function () {
			var form = root.querySelector('.kidia-phone-password-form');
			if (!form) { return; }
			form.hidden = false;
			passwordChoice.setAttribute('aria-expanded', 'true');
			var input = form.querySelector('input[type="email"]:not(:disabled)') || form.querySelector('input[type="password"]');
			if (input) { input.focus({preventScroll:true}); }
		});
	}

	if (useOtpButton) {
		useOtpButton.addEventListener('click', function () {
			existingPhoneFlow = true;
			var phone = phoneDisplay ? normalizePhone(phoneDisplay.textContent || '') : '';
			if (phoneExisting) { phoneExisting.hidden = true; }
			if (nativePhone) { nativePhone.hidden = false; }
			fillNativePhone(phone);
			autoSendPhoneCode(phone);
		});
	}

	if (nativePhone) {
		var verificationObserver = new MutationObserver(function () {
			var verification = nativePhone.querySelector('#fma_lwp_verification_code_div');
			if (!verification) {
				return;
			}
			var visible = verification.style.display !== 'none' && window.getComputedStyle(verification).display !== 'none';
			if (visible && !verificationWasVisible) {
				window.clearTimeout(phoneSendWatchdog);
				verificationAttempts = 0;
				root.classList.remove('kidia-phone-sending');
				root.classList.add('kidia-phone-code-ready');
				var codeInput = verification.querySelector('#verificationCode');
				if (codeInput) {
					codeInput.setAttribute('inputmode', 'numeric');
					codeInput.setAttribute('pattern', '[0-9]*');
					codeInput.setAttribute('autocomplete', 'one-time-code');
					codeInput.setAttribute('maxlength', '6');
					codeInput.setAttribute('dir', 'ltr');
					if (existingPhoneFlow) {
						/* A registered number already showed the password/OTP choice. Keep
						 * its keyboard closed until the customer taps the code field. */
						codeInput.blur();
						window.setTimeout(function () {
							if (document.activeElement === codeInput) {
								codeInput.blur();
							}
						}, 120);
					} else {
						/* A new number has an OTP-only screen, so open the numeric keyboard
						 * directly on the verification field. */
						codeInput.focus({ preventScroll: true });
					}
				}
			}
			verificationWasVisible = visible;
		});
		verificationObserver.observe(nativePhone, { attributes: true, childList: true, subtree: true, attributeFilter: ['style', 'class'] });
	}

	function checkEmail(email) {
		if (!config.ajaxUrl || !config.nonce || !window.fetch) {
			openEmail(email, true);
			return;
		}

		setLoading(true);
		identifierPending = true;
		var currentLookup = ++identifierGeneration;
		var lookupController = new AbortController();
		identifierController = lookupController;
		var lookupTimer = window.setTimeout(function () { lookupController.abort(); }, 15000);
		var body = new URLSearchParams();
		body.append('action', 'kidia_check_email');
		body.append('nonce', config.nonce);
		body.append('email', email);

		window.fetch(config.ajaxUrl, {
			signal: lookupController.signal,
			method: 'POST',
			credentials: 'same-origin',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
			body: body.toString()
		})
			.then(function (response) { return response.json(); })
			.then(function (payload) {
				if (currentLookup !== identifierGeneration) return;
				if (!payload || !payload.success) {
					throw new Error(payload && payload.data && payload.data.message ? payload.data.message : 'error');
				}
				openEmail(email, Boolean(payload.data.exists));
			})
			.catch(function (error) {
				if (currentLookup !== identifierGeneration) return;
				/* Some hosts protect admin-ajax.php with an anti-bot layer. Do not
				 * block the customer when the email lookup is unavailable. Continue
				 * in login mode; new customers can switch to account creation from
				 * the next step. The final server-side authentication remains the
				 * source of truth. */
				setFeedback('');
				openEmail(email, true);
			})
			.finally(function () { window.clearTimeout(lookupTimer); if (currentLookup !== identifierGeneration) return; identifierPending = false; identifierController = null; setLoading(false); });
	}
	function cancelIdentifierLookup() {
		identifierGeneration++;
		if (identifierController) identifierController.abort();
		identifierController = null; identifierPending = false;
		setLoading(false);
	}
	window.addEventListener('pagehide', cancelIdentifierLookup);

	if (identifierForm && identifierInput) {
		syncIdentifierButton();
		identifierForm.addEventListener('submit', function (event) {
			event.preventDefault();
			if (identifierPending) return;
			setFeedback('');

			var value = identifierInput.value.trim();
			if (isEmail(value)) {
				checkEmail(value.toLowerCase());
				return;
			}
			if (!emailFallbackActive && isPhone(value)) {
				checkPhone(normalizePhone(value));
				return;
			}

			setFeedback(emailFallbackActive ? 'اكتب بريدًا إلكترونيًا صحيحًا.' : (strings.invalidIdentifier || 'اكتب بريدًا إلكترونيًا صحيحًا أو رقم هاتف صحيحًا.'));
			identifierInput.focus();
		});

		identifierInput.addEventListener('input', function () {
			setFeedback('');
			if (!emailFallbackActive && isPhoneLike(identifierInput.value)) {
				identifierInput.value = normalizePhone(identifierInput.value).slice(0, 11);
			}
			syncIdentifierButton();
		});
	}

	root.querySelectorAll('[data-kidia-back]').forEach(function (button) {
		button.addEventListener('click', function () {
			cancelIdentifierLookup();
			window.clearInterval(phoneAutoSendTimer);
			window.clearInterval(phoneCooldownTimer);
			phoneCooldownUntil = 0;
			if (!emailFallbackActive && identifierInput && phoneDisplay && phoneDisplay.textContent.trim()) { identifierInput.value = phoneDisplay.textContent.trim(); syncIdentifierButton(); }
			resetFirebasePhoneSession();
			root.classList.remove('kidia-phone-prefilled', 'kidia-phone-sending', 'kidia-phone-code-ready');
			showStage('identifier');
		});
	});

	if (switchModeButton) {
		switchModeButton.addEventListener('click', function () {
			setEmailMode(emailMode === 'login' ? 'register' : 'login');
			if (emailMode === 'register' && emailInput) {
				emailInput.focus();
				emailInput.select();
			} else if (passwordInput) {
				passwordInput.focus();
			}
		});
	}

	if (forgotButton) {
		forgotButton.addEventListener('click', function () {
			var forgotEmail = root.querySelector('#kidia-forgot-email');
			if (forgotEmail && emailInput) {
				forgotEmail.value = emailInput.value;
			}
			showStage('forgot');
		});
	}

	function enhanceFields(container) {
		container.querySelectorAll('input.kidia-input').forEach(function (input) {
			if (!['text', 'email', 'password'].includes(input.type)) return;
			var label = input.closest('label') || (input.id && root.querySelector('label[for="' + input.id + '"]'));
			var caption = label && label.querySelector('span');
			var name = input.getAttribute('aria-label') || (caption ? caption.textContent : label && label.textContent) || input.placeholder;
			if (name) {
				input.setAttribute('aria-label', name.trim());
				if (!input.placeholder) input.placeholder = name.trim();
			}
			if (caption) caption.classList.add('screen-reader-text');
			else if (label && !label.contains(input)) label.classList.add('screen-reader-text');
			if (input.type !== 'password') return;
			var wrap = input.closest('.kidia-password-wrap');
			if (!wrap) {
				wrap = document.createElement('span');
				wrap.className = 'kidia-field-wrap kidia-password-wrap';
				input.before(wrap); wrap.appendChild(input);
			}
			if (wrap.querySelector('[data-kidia-password-toggle]')) return;
			var toggle = document.createElement('button');
			toggle.type = 'button'; toggle.className = 'kidia-password-toggle';
			toggle.setAttribute('data-kidia-password-toggle', '');
			toggle.setAttribute('aria-label', 'إظهار كلمة المرور');
			toggle.setAttribute('aria-pressed', 'false');
			toggle.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6z"></path><circle cx="12" cy="12" r="2.6"></circle></svg>';
			wrap.appendChild(toggle);
		});
	}
	enhanceFields(root);
	root.addEventListener('kidia:fields-added', function (event) { enhanceFields(event.target); });
	root.addEventListener('click', function (event) {
		var toggle = event.target.closest('[data-kidia-password-toggle]');
		if (!toggle || !root.contains(toggle)) return;
		var input = toggle.closest('.kidia-password-wrap').querySelector('input');
		if (!input || input.disabled) return;
		event.preventDefault();
		var reveal = input.type === 'password';
		input.type = reveal ? 'text' : 'password';
		toggle.setAttribute('aria-pressed', String(reveal));
		toggle.setAttribute('aria-label', reveal ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور');
	});

	var closeButton = root.querySelector('[data-kidia-close]');
	if (closeButton) {
		closeButton.addEventListener('click', function () {
			var referrer = document.referrer;
			var sameOrigin = false;
			try {
				sameOrigin = Boolean(referrer) && new URL(referrer).origin === window.location.origin;
			} catch (error) {
				sameOrigin = false;
			}

			if (sameOrigin && window.history.length > 1) {
				window.history.back();
				return;
			}
			window.location.href = config.homeUrl || '/';
		});
	}

	var initialStage = root.getAttribute('data-initial-stage');
	var initialMode = root.getAttribute('data-initial-mode');
	var initialEmail = config.initialEmail || (identifierInput ? identifierInput.value : '');
	var initialPhone = root.querySelector('[data-kidia-phone-display]') ? root.querySelector('[data-kidia-phone-display]').textContent.trim() : '';

	if (initialStage === 'email' && initialEmail) {
		if (emailInput) { emailInput.value = initialEmail; }
		if (emailDisplay) { emailDisplay.textContent = initialEmail; }
		setEmailMode(initialMode === 'register' ? 'register' : 'login');
		showStage('email');
	} else if (initialStage === 'phone' && isPhone(initialPhone)) {
		showExistingPhone(normalizePhone(initialPhone), new URLSearchParams(window.location.search).get('kidia_phone_multiple') === '1');
	} else if (initialStage === 'forgot') {
		showStage('forgot');
	} else if (initialStage === 'phone-setup') {
		showStage('phone-setup');
	}
})();
