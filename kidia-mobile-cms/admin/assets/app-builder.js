(function () {
	'use strict';

	const config = window.kidiaAppBuilder || {};
	const roots = Array.from(document.querySelectorAll('[data-kidia-app-build]'));
	if (!roots.length || !config.ajaxUrl) return;

	const autoDownload = new WeakSet();
	let timer = 0;
	const requestTimeout = Math.max(100, Number(config.requestTimeout || 25000));

	function label(status, fallback) {
		return (config.labels && config.labels[status]) || fallback || '';
	}

	function isBuilding(status) {
		return ['queued', 'building'].includes(status);
	}

	function setActionState(root, status, progress, downloadReady) {
		const formAction = root.querySelector('[data-build-form-action]');
		const button = root.querySelector('[data-build-action]');
		const buttonLabel = root.querySelector('[data-build-action-label]');
		const icon = root.querySelector('[data-build-action-icon]');
		const cancelButton = root.querySelector('[data-build-cancel]');
		const canBuild = root.dataset.canBuild === '1';
		const ready = status === 'ready' && downloadReady;
		const building = isBuilding(status);

		if (formAction) {
			formAction.value = ready ? 'kidia_mobile_download_apk' : 'kidia_mobile_build_app';
		}
		if (button) {
			button.disabled = building || (!ready && !canBuild);
			button.classList.toggle('is-loading', building);
			button.setAttribute('aria-busy', building ? 'true' : 'false');
		}
		if (buttonLabel) {
			if (ready) {
				buttonLabel.textContent = label('download', 'Download APK');
			} else if (building) {
				const percentage = progress > 0 ? ' ' + progress + '%' : '';
				buttonLabel.textContent = label('building', 'Building your APK…') + percentage;
			} else {
				buttonLabel.textContent = label('buildDownload', 'Build & Download Your App');
			}
		}
		if (cancelButton) {
			cancelButton.hidden = !building;
			cancelButton.disabled = false;
		}
		if (icon) {
			icon.className = 'dashicons ' + (
				ready
					? 'dashicons-download'
					: (building ? 'dashicons-update' : 'dashicons-smartphone')
			);
		}
	}

	function requestDownload(root) {
		if (!autoDownload.has(root) || root.dataset.status !== 'ready') return;

		autoDownload.delete(root);
		root.dataset.autoDownload = '0';
		const form = root.querySelector('[data-build-form]');
		const button = root.querySelector('[data-build-action]');
		if (form && typeof form.requestSubmit === 'function') {
			form.requestSubmit(button || undefined);
		} else if (form) {
			form.submit();
		}
	}

	function render(state) {
		roots.forEach(function (root) {
			const status = state.status || root.dataset.status || 'idle';
			const progress = Math.max(0, Math.min(100, Number(state.progress || 0)));
			const message = root.querySelector('[data-build-message]');
			const meter = root.querySelector('[data-build-progress]');
			const value = root.querySelector('[data-build-progress-value]');
			const downloadReady = status === 'ready' && state.downloadReady !== false;

			root.dataset.status = status;
			if (message) message.textContent = state.message || label(status);
			if (meter) meter.hidden = !isBuilding(status);
			if (value) {
				value.style.width = progress + '%';
				value.setAttribute('aria-valuenow', String(progress));
			}
			setActionState(root, status, progress, downloadReady);
			if (downloadReady) requestDownload(root);
		});
	}

	function schedulePoll(delay) {
		if (timer) window.clearTimeout(timer);
		timer = window.setTimeout(poll, delay);
	}

	async function request(body) {
		const controller = typeof window.AbortController === 'function'
			? new window.AbortController()
			: null;
		const timeout = window.setTimeout(function () {
			if (controller) controller.abort();
		}, requestTimeout);

		try {
			const response = await fetch(config.ajaxUrl, {
				method: 'POST',
				credentials: 'same-origin',
				headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
				body: body.toString(),
				signal: controller ? controller.signal : undefined
			});
			const payload = await response.json();
			if (!response.ok || !payload.success) {
				throw new Error(payload.data && payload.data.message ? payload.data.message : label('failed'));
			}
			return payload.data || {};
		} catch (error) {
			if (error && error.name === 'AbortError') {
				throw new Error(label('timeout', 'The APK build request took too long. Please try again.'));
			}
			throw error;
		} finally {
			window.clearTimeout(timeout);
		}
	}

	async function poll() {
		const body = new URLSearchParams({
			action: 'kidia_mobile_app_build_status',
			nonce: config.nonce || ''
		});
		try {
			const state = await request(body);
			render(state);
			if (isBuilding(state.status)) schedulePoll(4000);
		} catch (error) {
			roots.forEach(function (root) {
				const message = root.querySelector('[data-build-message]');
				if (message) message.textContent = error.message || label('failed');
			});
			schedulePoll(8000);
		}
	}

	async function startBuild(root) {
		const nonce = root.querySelector('[name="kidia_mobile_build_nonce"]');
		const body = new URLSearchParams({
			action: 'kidia_mobile_app_build_start',
			nonce: nonce ? nonce.value : ''
		});

		autoDownload.add(root);
		render({
			status: 'queued',
			progress: 0,
			message: label('starting', 'Starting APK build…'),
			downloadReady: false
		});

		try {
			const state = await request(body);
			render(state);
			if (isBuilding(state.status)) schedulePoll(4000);
		} catch (error) {
			autoDownload.delete(root);
			render({
				status: 'failed',
				progress: 0,
				message: error.message || label('failed'),
				downloadReady: false
			});
		}
	}

	async function cancelBuild(root) {
		if (!isBuilding(root.dataset.status)) return;

		if (timer) {
			window.clearTimeout(timer);
			timer = 0;
		}
		const cancelButton = root.querySelector('[data-build-cancel]');
		if (cancelButton) cancelButton.disabled = true;
		const body = new URLSearchParams({
			action: 'kidia_mobile_app_build_cancel',
			nonce: config.cancelNonce || ''
		});

		try {
			const state = await request(body);
			autoDownload.delete(root);
			render(state);
		} catch (error) {
			if (cancelButton) cancelButton.disabled = false;
			const message = root.querySelector('[data-build-message]');
			if (message) message.textContent = error.message || label('cancelFailed', 'The build could not be cancelled.');
			schedulePoll(4000);
		}
	}

	roots.forEach(function (root) {
		const form = root.querySelector('[data-build-form]');
		if (root.dataset.autoDownload === '1') autoDownload.add(root);
		if (!form) return;

		form.addEventListener('submit', function (event) {
			if (root.dataset.status === 'ready') return;

			event.preventDefault();
			if (root.dataset.canBuild !== '1' || isBuilding(root.dataset.status)) return;
			startBuild(root);
		});

		const cancelButton = root.querySelector('[data-build-cancel]');
		if (cancelButton) {
			cancelButton.addEventListener('click', function () {
				cancelBuild(root);
			});
		}
	});

	const active = roots.some(function (root) {
		return isBuilding(root.dataset.status);
	});
	if (active) poll();

	roots.forEach(function (root) {
		if (root.dataset.status === 'ready') requestDownload(root);
	});

	window.addEventListener('beforeunload', function () {
		if (timer) window.clearTimeout(timer);
	});
})();
