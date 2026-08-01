(function () {
	'use strict';
	const form = document.querySelector('.kidia-setup-form');
	if (!form) return;
	const steps = Array.from(form.querySelectorAll('.kidia-setup-step'));
	const progress = document.querySelector('.kidia-setup-progress');
	const next = form.querySelector('.kidia-setup-next');
	const back = form.querySelector('.kidia-setup-back');
	const apply = form.querySelector('.kidia-setup-apply');
	let current = 0;

	function pageEnabled(page) {
		const toggle = form.querySelector('[data-page-toggle="' + page + '"]');
		return !toggle || toggle.dataset.requiredPage === '1' || toggle.checked;
	}

	function activeSteps() {
		return steps.filter(function (step) {
			const page = step.getAttribute('data-theme-page');
			return !page || pageEnabled(page);
		});
	}

	function syncPageSteps() {
		steps.forEach(function (step) {
			const page = step.getAttribute('data-theme-page');
			if (!page) return;
			const enabled = pageEnabled(page);
			step.hidden = !enabled;
			step.querySelectorAll('input[type="radio"]').forEach(function (input) {
				input.disabled = !enabled;
				input.required = enabled;
			});
		});
		form.querySelectorAll('[data-review-page]').forEach(function (tag) {
			tag.hidden = !pageEnabled(tag.getAttribute('data-review-page'));
		});
	}

	function renderProgress(visibleSteps) {
		if (!progress) return;
		progress.innerHTML = '';
		visibleSteps.forEach(function (step, index) {
			const dot = document.createElement('span');
			dot.textContent = String(index + 1);
			dot.classList.toggle('is-active', index <= current);
			progress.appendChild(dot);
			if (index < visibleSteps.length - 1) progress.appendChild(document.createElement('i'));
			const number = step.querySelector('[data-step-number]');
			if (number) number.textContent = String(index + 1).padStart(2, '0');
		});
	}

	function updateActionTheme() {
		form.style.setProperty('--kidia-setup-theme-color', '#2f806e');
	}

	function normalizeHex(value) {
		const normalized = String(value || '').trim().toUpperCase();
		return /^#[0-9A-F]{6}$/.test(normalized) ? normalized : '';
	}

	function syncColorPair(key, source) {
		const picker = form.querySelector('[data-color-picker="' + key + '"]');
		const code = form.querySelector('[data-color-code="' + key + '"]');
		if (!picker || !code) return;
		if (source === code) {
			const valid = normalizeHex(code.value);
			code.classList.toggle('is-invalid', !valid);
			if (valid) picker.value = valid;
			return;
		}
		code.value = String(picker.value || '').toUpperCase();
		code.classList.remove('is-invalid');
	}

	function selectedThemeCard() {
		const selected = form.querySelector('input[name="setup[theme]"]:checked');
		return selected ? selected.closest('.kidia-theme-card') : null;
	}

	function updateThemeReview() {
		const card = selectedThemeCard();
		const review = form.querySelector('[data-review-theme]');
		if (card && review) review.textContent = card.dataset.themeName || '';
	}

	function show(index, shouldScroll) {
		syncPageSteps();
		const visibleSteps = activeSteps();
		current = Math.max(0, Math.min(visibleSteps.length - 1, index));
		const activeStep = visibleSteps[current];
		steps.forEach((step) => step.classList.toggle('is-active', step === activeStep));
		renderProgress(visibleSteps);
		back.hidden = current === 0;
		next.hidden = current === visibleSteps.length - 1;
		apply.hidden = current !== visibleSteps.length - 1;
		const name = form.querySelector('[name="setup[app_name]"]');
		const review = form.querySelector('[data-review-name]');
		if (name && review) review.textContent = name.value || name.placeholder;
		updateThemeReview();
		updateActionTheme();
		if (shouldScroll !== false) {
			const hero = document.querySelector('.kidia-setup-hero');
			const target = hero || form;
			window.scrollTo({ top: Math.max(0, target.getBoundingClientRect().top + window.scrollY - 90), behavior: 'smooth' });
		}
	}
	next.addEventListener('click', function () {
		const activeStep = activeSteps()[current];
		const required = activeStep.querySelectorAll('[required]:not(:disabled)');
		for (const input of required) {
			if (!input.reportValidity()) return;
		}
		show(current + 1);
	});
	back.addEventListener('click', function () { show(current - 1); });
	form.addEventListener('change', function (event) {
		if (event.target.matches('[data-page-toggle]')) {
			syncPageSteps();
			show(current, false);
		}
		if (event.target.matches('input[name="setup[theme]"]')) {
			// Theme previews keep their reference palette, but selecting a layout
			// must not overwrite branding calculated from the connected site.
			updateThemeReview();
		}
		if (event.target.matches('[data-color-picker]')) {
			syncColorPair(event.target.dataset.colorPicker, event.target);
		}
		if (event.target.matches('[data-color-code]')) {
			syncColorPair(event.target.dataset.colorCode, event.target);
		}
		if (event.target.matches('.kidia-theme-card input, [name="setup[primary_color]"], [name="setup[secondary_color]"]')) {
			updateActionTheme();
		}
	});
	form.addEventListener('input', function (event) {
		if (event.target.matches('[data-color-picker]')) {
			syncColorPair(event.target.dataset.colorPicker, event.target);
		}
		if (event.target.matches('[data-color-code]')) {
			syncColorPair(event.target.dataset.colorCode, event.target);
		}
	});

	const modal = document.querySelector('.kidia-theme-modal');
	const previewConfig = window.kidiaSetupThemePreview || {};
	const previewFrame = modal && modal.querySelector('[data-theme-modal-frame]');
	const previewLoading = modal && modal.querySelector('[data-theme-modal-loading]');
	const previewLoadingLabel = previewLoading && previewLoading.querySelector('b');
	const previewLoadingDefault = previewLoadingLabel ? previewLoadingLabel.textContent : '';
	const previewPageButtons = modal ? Array.from(modal.querySelectorAll('[data-theme-modal-page]')) : [];
	let previewedCard = null;
	let previewSnapshot = null;
	let previewPage = 'home';
	let previewFrameReady = false;
	let previewPayload = null;
	let previewRequest = 0;
	let previewFrameOrigin = window.location.origin;

	function setPreviewLoading(state, message) {
		if (!previewLoading) return;
		previewLoading.hidden = !state;
		previewLoading.classList.toggle('is-error', Boolean(message));
		if (previewLoadingLabel) previewLoadingLabel.textContent = message || previewLoadingDefault;
	}

	function postPreviewJson(url, body, attempt) {
		return window.fetch(String(url), {
			method: 'POST',
			credentials: 'same-origin',
			cache: 'no-store',
			headers: {
				'Content-Type': 'application/json',
				'X-WP-Nonce': String(previewConfig.restNonce || '')
			},
			body: JSON.stringify(body)
		}).then(function (response) {
			if (!response.ok) throw new Error('Theme preview request failed with HTTP ' + response.status + '.');
			return response.json();
		}).catch(function (error) {
			if (!attempt) {
				return new Promise(function (resolve) {
					window.setTimeout(resolve, 250);
				}).then(function () { return postPreviewJson(url, body, 1); });
			}
			throw error;
		});
	}

	function previewPageLayout(snapshot, page) {
		const pages = snapshot && snapshot.pages && typeof snapshot.pages === 'object' ? snapshot.pages : {};
		return pages[page] && typeof pages[page] === 'object' ? pages[page] : {};
	}

	function snapshotWithLiveBrand(snapshot) {
		const primaryInput = form.querySelector('[name="setup[primary_color]"]');
		const secondaryInput = form.querySelector('[name="setup[secondary_color]"]');
		const primary = primaryInput ? String(primaryInput.value || '').toLowerCase() : '';
		const secondary = secondaryInput ? String(secondaryInput.value || '').toLowerCase() : '';
		const originalPrimary = String(snapshot && snapshot.identity ? snapshot.identity.primary_color || '' : '').toLowerCase();
		const originalSecondary = String(snapshot && snapshot.identity ? snapshot.identity.secondary_color || '' : '').toLowerCase();
		const branded = JSON.parse(JSON.stringify(snapshot || {}), function (_key, value) {
			if (typeof value !== 'string') return value;
			const color = value.toLowerCase();
			if (primary && originalPrimary && color === originalPrimary) return primary;
			if (secondary && originalSecondary && color === originalSecondary) return secondary;
			return value;
		});
		if (branded.identity) {
			if (primary) branded.identity.primary_color = primary;
			if (secondary) branded.identity.secondary_color = secondary;
		}
		return branded;
	}

	function buildPreviewPayload(snapshot, page) {
		const demoCatalog = snapshot && snapshot.demo_catalog && typeof snapshot.demo_catalog === 'object'
			? snapshot.demo_catalog
			: { products: [], categories: [] };
		const pages = snapshot && snapshot.pages && typeof snapshot.pages === 'object' ? snapshot.pages : {};
		const layoutRequests = Object.keys(pages).map(function (pageName) {
			return postPreviewJson(
				String(previewConfig.layoutPreviewBase || '') + encodeURIComponent(pageName) + '/preview',
				{ layout: previewPageLayout(snapshot, pageName) }
			).then(function (layout) {
				return [pageName, layout];
			}).catch(function (error) {
				if (window.console && window.console.warn) window.console.warn(error);
				return [pageName, previewPageLayout(snapshot, pageName)];
			});
		});
		const category = snapshot.category && typeof snapshot.category === 'object' ? snapshot.category : {};
		const homeFallback = Array.isArray(snapshot.home) ? snapshot.home : [];
		const categoryFallback = category.general && typeof category.general === 'object' ? category.general : {};
		return Promise.all([
			Promise.all(layoutRequests),
			postPreviewJson(previewConfig.homePreviewEndpoint, {
				blocks: Array.isArray(snapshot.home) ? snapshot.home : [],
				demo_catalog: demoCatalog
			}).catch(function (error) {
				if (window.console && window.console.warn) window.console.warn(error);
				return homeFallback;
			}),
			postPreviewJson(previewConfig.categoryPreviewEndpoint, {
				general: category.general && typeof category.general === 'object' ? category.general : {}
			}).catch(function (error) {
				if (window.console && window.console.warn) window.console.warn(error);
				return categoryFallback;
			})
		]).then(function (payloads) {
			const layouts = {};
			payloads[0].forEach(function (entry) { layouts[entry[0]] = entry[1]; });
			return { type: 'kidia-preview-layout', page: page, layout: layouts[page] || {}, layouts: layouts, home: payloads[1], category: payloads[2], demo_catalog: demoCatalog };
		});
	}

	function deliverPreviewPayload() {
		if (!previewFrameReady || !previewPayload || !previewFrame || !previewFrame.contentWindow) return;
		previewFrame.contentWindow.postMessage(JSON.stringify(previewPayload), previewFrameOrigin);
		previewPayload = null;
		setPreviewLoading(false);
	}

	function selectPreviewPage(page) {
		if (!previewSnapshot || !previewFrame || !previewConfig.flutterUrl) return;
		previewPage = page;
		previewFrameReady = false;
		previewPayload = null;
		const currentRequest = ++previewRequest;
		previewPageButtons.forEach(function (button) {
			const selected = button.dataset.themeModalPage === page;
			button.classList.toggle('is-active', selected);
			if (selected) button.setAttribute('aria-current', 'page');
			else button.removeAttribute('aria-current');
		});
		setPreviewLoading(true);
		const previewUrl = new URL(String(previewConfig.flutterUrl), window.location.href);
		previewUrl.searchParams.set('page', page);
		previewUrl.searchParams.set('demo', '1');
		previewUrl.searchParams.set('v', String(previewConfig.version || Date.now()));
		if (page === 'product') previewUrl.searchParams.set('product', '9001');
		previewFrameOrigin = previewUrl.origin;
		previewFrame.src = previewUrl.toString();
		buildPreviewPayload(previewSnapshot, page).then(function (payload) {
			if (currentRequest !== previewRequest || page !== previewPage) return;
			previewPayload = payload;
			deliverPreviewPayload();
		}).catch(function (error) {
			if (currentRequest !== previewRequest) return;
			if (window.console && window.console.warn) window.console.warn(error);
			setPreviewLoading(true, String(previewConfig.errorLabel || 'The real theme preview could not be loaded.'));
		});
	}

	function closeThemeModal() {
		if (!modal) return;
		previewRequest += 1;
		previewSnapshot = null;
		previewPayload = null;
		previewFrameReady = false;
		if (previewFrame) previewFrame.removeAttribute('src');
		modal.hidden = true;
		document.body.classList.remove('kidia-theme-preview-open');
	}
	function openThemeModal(card) {
		if (!modal || !card) return;
		previewedCard = card;
		const configuredSnapshot = previewConfig.themes && previewConfig.themes[card.dataset.themeKey]
			? previewConfig.themes[card.dataset.themeKey]
			: null;
		if (!configuredSnapshot) return;
		previewSnapshot = snapshotWithLiveBrand(configuredSnapshot);
		modal.querySelector('[data-theme-modal-name]').textContent = card.dataset.themeName || '';
		const styles = window.getComputedStyle(card);
		for (const property of ['--theme-primary', '--theme-soft', '--theme-ink', '--theme-surface']) {
			modal.style.setProperty(property, styles.getPropertyValue(property).trim());
		}
		modal.hidden = false;
		document.body.classList.add('kidia-theme-preview-open');
		modal.querySelector('.kidia-theme-modal__close').focus();
		selectPreviewPage('home');
	}
	form.querySelectorAll('.kidia-theme-preview-button').forEach(function (button) {
		button.addEventListener('click', function (event) {
			event.preventDefault();
			event.stopPropagation();
			openThemeModal(button.closest('.kidia-theme-card'));
		});
	});
	if (modal) {
		form.querySelectorAll('[name="setup[primary_color]"], [name="setup[secondary_color]"]').forEach(function (input) {
			input.addEventListener('input', function () {
				if (modal.hidden || !previewedCard) return;
				const configuredSnapshot = previewConfig.themes && previewConfig.themes[previewedCard.dataset.themeKey];
				if (!configuredSnapshot) return;
				previewSnapshot = snapshotWithLiveBrand(configuredSnapshot);
				selectPreviewPage(previewPage);
			});
		});
		previewPageButtons.forEach(function (button) {
			button.addEventListener('click', function () {
				selectPreviewPage(button.dataset.themeModalPage || 'home');
			});
		});
		modal.querySelectorAll('[data-theme-modal-close]').forEach(function (button) {
			button.addEventListener('click', closeThemeModal);
		});
		modal.querySelector('.kidia-theme-modal__select').addEventListener('click', function () {
			const input = previewedCard && previewedCard.querySelector('input[name="setup[theme]"]');
			if (input) {
				input.checked = true;
				input.dispatchEvent(new Event('change', { bubbles: true }));
			}
			closeThemeModal();
		});
		document.addEventListener('keydown', function (event) {
			if (event.key === 'Escape' && !modal.hidden) closeThemeModal();
		});
	}
	window.addEventListener('message', function (event) {
		if (!previewFrame || event.source !== previewFrame.contentWindow || event.origin !== previewFrameOrigin) return;
		let message = event.data;
		if (typeof message === 'string') {
			try { message = JSON.parse(message); } catch (_) { return; }
		}
		if (message && message.type === 'kidia-flutter-preview-ready') {
			previewFrameReady = true;
			deliverPreviewPayload();
		}
	});

	const chooseLogo = form.querySelector('.kidia-setup-choose-logo');
	if (chooseLogo && window.wp && wp.media) {
		chooseLogo.addEventListener('click', function () {
			const frame = wp.media({ title: chooseLogo.textContent, library: { type: 'image' }, multiple: false });
			frame.on('select', function () {
				const image = frame.state().get('selection').first().toJSON();
				form.querySelector('[name="setup[logo_id]"]').value = image.id || 0;
				form.querySelector('[name="setup[logo_url]"]').value = image.url || '';
				form.querySelector('.kidia-setup-logo-preview').innerHTML = image.url ? '<img src="' + image.url + '" alt="">' : '';
			});
			frame.open();
		});
	}
	if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
	show(0, false);
	const resetScroll = function () {
		window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
	};
	if (window.requestAnimationFrame) {
		window.requestAnimationFrame(resetScroll);
	} else {
		resetScroll();
	}
})();
