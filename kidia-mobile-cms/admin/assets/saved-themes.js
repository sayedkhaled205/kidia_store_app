(function () {
	'use strict';

	const dialog = document.querySelector('[data-saved-theme-dialog]');
	const frame = dialog && dialog.querySelector('[data-saved-theme-dialog-frame]');
	const dialogTitle = dialog && dialog.querySelector('[data-saved-theme-dialog-title]');
	const loading = dialog && dialog.querySelector('[data-saved-theme-loading]');
	const loadingLabel = loading && loading.querySelector('b');
	const defaultLoadingText = loadingLabel ? loadingLabel.textContent : '';
	const pageButtons = dialog ? Array.from(dialog.querySelectorAll('[data-saved-theme-page]')) : [];
	const config = window.kidiaSavedThemePreview || {};
	let activePage = 'home';
	let activeSnapshot = null;
	let frameReady = false;
	let previewPayload = null;
	let requestNumber = 0;
	let frameOrigin = window.location.origin;

	function parseSnapshot(card) {
		const node = card && card.querySelector('[data-saved-theme-snapshot]');
		if (!node) return null;
		try {
			const snapshot = JSON.parse(node.textContent || '{}');
			return snapshot && typeof snapshot === 'object' ? snapshot : null;
		} catch (_) {
			return null;
		}
	}

	function setLoading(state, message) {
		if (!loading) return;
		loading.hidden = !state;
		loading.classList.toggle('is-error', Boolean(message));
		if (loadingLabel) loadingLabel.textContent = message || defaultLoadingText;
	}

	function postJson(url, body) {
		return window.fetch(String(url), {
			method: 'POST',
			credentials: 'same-origin',
			cache: 'no-store',
			headers: {
				'Content-Type': 'application/json',
				'X-WP-Nonce': String(config.restNonce || '')
			},
			body: JSON.stringify(body)
		}).then(function (response) {
			if (!response.ok) throw new Error('Preview request failed with HTTP ' + response.status + '.');
			return response.json();
		});
	}

	function pageLayout(snapshot, page) {
		const pages = snapshot && snapshot.pages && typeof snapshot.pages === 'object' ? snapshot.pages : {};
		return pages[page] && typeof pages[page] === 'object' ? pages[page] : {};
	}

	function buildPayload(snapshot, page) {
		const layoutRequest = postJson(
			String(config.layoutPreviewBase || '') + encodeURIComponent(page) + '/preview',
			{ layout: pageLayout(snapshot, page) }
		);

		if (page === 'home') {
			return Promise.all([
				layoutRequest,
				postJson(config.homePreviewEndpoint, { blocks: Array.isArray(snapshot.home) ? snapshot.home : [] })
			]).then(function (payloads) {
				return { type: 'kidia-preview-layout', page: page, layout: payloads[0], home: payloads[1] };
			});
		}

		if (page === 'category') {
			const category = snapshot.category && typeof snapshot.category === 'object' ? snapshot.category : {};
			return Promise.all([
				layoutRequest,
				postJson(config.categoryPreviewEndpoint, {
					general: category.general && typeof category.general === 'object' ? category.general : {}
				})
			]).then(function (payloads) {
				return { type: 'kidia-preview-layout', page: page, layout: payloads[0], category: payloads[1] };
			});
		}

		return layoutRequest.then(function (layout) {
			return { type: 'kidia-preview-layout', page: page, layout: layout };
		});
	}

	function deliverPayload() {
		if (!frameReady || !previewPayload || !frame || !frame.contentWindow) return;
		frame.contentWindow.postMessage(JSON.stringify(previewPayload), frameOrigin);
		previewPayload = null;
		setLoading(false);
	}

	function selectPage(page) {
		if (!activeSnapshot || !frame || !config.flutterUrl) return;
		activePage = page;
		frameReady = false;
		previewPayload = null;
		const currentRequest = ++requestNumber;
		pageButtons.forEach(function (button) {
			const selected = button.getAttribute('data-saved-theme-page') === page;
			button.classList.toggle('is-active', selected);
			if (selected) button.setAttribute('aria-current', 'page');
			else button.removeAttribute('aria-current');
		});
		setLoading(true);

		const previewUrl = new URL(String(config.flutterUrl), window.location.href);
		previewUrl.searchParams.set('page', page);
		previewUrl.searchParams.set('v', String(config.version || Date.now()));
		if (page === 'product') previewUrl.searchParams.set('product', String(config.productId || 1));
		frameOrigin = previewUrl.origin;
		frame.src = previewUrl.toString();

		buildPayload(activeSnapshot, page).then(function (payload) {
			if (currentRequest !== requestNumber || page !== activePage) return;
			previewPayload = payload;
			deliverPayload();
		}).catch(function (error) {
			if (currentRequest !== requestNumber) return;
			if (window.console && window.console.warn) window.console.warn(error);
			setLoading(true, String(config.errorLabel || 'The real preview could not be loaded.'));
		});
	}

	document.querySelectorAll('[data-saved-theme-preview]').forEach(function (button) {
		button.addEventListener('click', function () {
			if (!dialog || !frame || !dialogTitle) return;
			const card = button.closest('[data-saved-theme-card]');
			activeSnapshot = parseSnapshot(card);
			if (!activeSnapshot) return;
			dialogTitle.textContent = button.getAttribute('data-theme-name') || '';

			if (typeof dialog.showModal === 'function') dialog.showModal();
			else dialog.setAttribute('open', '');
			selectPage('home');
		});
	});

	pageButtons.forEach(function (button) {
		button.addEventListener('click', function () {
			selectPage(button.getAttribute('data-saved-theme-page') || 'home');
		});
	});

	window.addEventListener('message', function (event) {
		if (!frame || event.source !== frame.contentWindow || event.origin !== frameOrigin) return;
		let message = event.data;
		if (typeof message === 'string') {
			try { message = JSON.parse(message); } catch (_) { return; }
		}
		if (message && message.type === 'kidia-flutter-preview-ready') {
			frameReady = true;
			deliverPayload();
		}
	});

	if (dialog) {
		const close = dialog.querySelector('[data-saved-theme-dialog-close]');
		const closeDialog = function () {
			requestNumber += 1;
			activeSnapshot = null;
			previewPayload = null;
			frameReady = false;
			if (frame) frame.removeAttribute('src');
			if (typeof dialog.close === 'function') dialog.close();
			else dialog.removeAttribute('open');
		};
		if (close) close.addEventListener('click', closeDialog);
		dialog.addEventListener('click', function (event) {
			if (event.target !== dialog) return;
			const bounds = dialog.getBoundingClientRect();
			const inside = event.clientX >= bounds.left && event.clientX <= bounds.right
				&& event.clientY >= bounds.top && event.clientY <= bounds.bottom;
			if (!inside) closeDialog();
		});
	}

	document.querySelectorAll('.kidia-theme-file input[type="file"]').forEach(function (input) {
		input.addEventListener('change', function () {
			const label = input.closest('.kidia-theme-file');
			const filename = label && label.querySelector('[data-theme-file-name]');
			if (filename) filename.textContent = input.files && input.files[0] ? input.files[0].name : '';
		});
	});
})();
