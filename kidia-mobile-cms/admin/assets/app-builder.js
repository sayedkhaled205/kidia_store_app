(function () {
	'use strict';

	const config = window.kidiaAppBuilder || {};
	const roots = Array.from(document.querySelectorAll('[data-kidia-app-build]'));
	if (!roots.length || !config.ajaxUrl) return;

	let timer = 0;

	function label(status, fallback) {
		return (config.labels && config.labels[status]) || fallback || '';
	}

	function render(state) {
		roots.forEach(function (root) {
			const status = state.status || root.dataset.status || 'idle';
			const progress = Math.max(0, Math.min(100, Number(state.progress || 0)));
			const message = root.querySelector('[data-build-message]');
			const meter = root.querySelector('[data-build-progress]');
			const value = root.querySelector('[data-build-progress-value]');
			const download = root.querySelector('[data-build-download]');

			root.dataset.status = status;
			if (message) message.textContent = state.message || label(status);
			if (meter) meter.hidden = !['queued', 'building'].includes(status);
			if (value) {
				value.style.width = progress + '%';
				value.setAttribute('aria-valuenow', String(progress));
			}
			if (download) {
				download.hidden = status !== 'ready' || !state.downloadReady;
				if (!download.hidden) download.href = config.downloadUrl;
			}
		});
	}

	async function poll() {
		const body = new URLSearchParams({
			action: 'kidia_mobile_app_build_status',
			nonce: config.nonce || ''
		});
		try {
			const response = await fetch(config.ajaxUrl, {
				method: 'POST',
				credentials: 'same-origin',
				headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
				body: body.toString()
			});
			const payload = await response.json();
			if (!response.ok || !payload.success) {
				throw new Error(payload.data && payload.data.message ? payload.data.message : label('failed'));
			}
			render(payload.data || {});
			if (['queued', 'building'].includes(payload.data.status)) {
				timer = window.setTimeout(poll, 4000);
			}
		} catch (error) {
			roots.forEach(function (root) {
				const message = root.querySelector('[data-build-message]');
				if (message) message.textContent = error.message || label('failed');
			});
			timer = window.setTimeout(poll, 8000);
		}
	}

	const active = roots.some(function (root) {
		return ['queued', 'building'].includes(root.dataset.status);
	});
	if (active) poll();

	window.addEventListener('beforeunload', function () {
		if (timer) window.clearTimeout(timer);
	});
})();
