(function () {
	'use strict';

	const config = window.kidiaAppBuilder || {};
	const roots = Array.from(document.querySelectorAll('[data-kidia-app-build]'));
	if (!roots.length || !config.ajaxUrl) return;

	const autoDownload = new WeakSet();
	const openedProgress = new WeakSet();
	const progressModals = new WeakMap();
	roots.forEach(function (root) {
		const modal = root.querySelector('[data-build-modal]');
		if (modal) progressModals.set(root, modal);
	});
	let timer = 0;
	let pollFailures = 0;
	const requestTimeout = Math.max(100, Number(config.requestTimeout || 25000));

	function label(status, fallback) {
		return (config.labels && config.labels[status]) || fallback || '';
	}

	function isBuilding(status) {
		return ['queued', 'building'].includes(status);
	}

	function progressModal(root) {
		return progressModals.get(root) || null;
	}

	function openProgress(root) {
		const modal = progressModal(root);
		if (!modal) return;
		openedProgress.add(root);
		modal.hidden = false;
		modal.classList.remove('is-docked');
		modal.style.removeProperty('left');
		modal.style.removeProperty('top');
		modal.style.removeProperty('right');
		modal.style.removeProperty('bottom');
		document.body.classList.add('kidia-ai-is-generating');
	}

	function closeProgress(root) {
		const modal = progressModal(root);
		if (!modal) return;
		openedProgress.delete(root);
		modal.hidden = true;
		modal.classList.remove('is-docked', 'is-dragging');
		document.body.classList.remove('kidia-ai-is-generating');
	}

	function persistProgress(root) {
		const modal = progressModal(root);
		if (!modal || !isBuilding(root.dataset.status)) return;
		modal.hidden = false;
		modal.classList.add('is-docked', 'is-global');
		document.body.appendChild(modal);
		document.body.classList.remove('kidia-ai-is-generating');
	}

	function dockProgress(root) {
		const modal = progressModal(root);
		if (!modal || modal.hidden) return;
		modal.classList.add('is-docked');
		document.body.classList.remove('kidia-ai-is-generating');
		const stored = window.localStorage.getItem('kidiaAppBuildDockPosition');
		if (!stored) return;
		try {
			const position = JSON.parse(stored);
			const width = modal.offsetWidth || 380;
			const height = modal.offsetHeight || 180;
			const left = Math.max(8, Math.min(window.innerWidth - width - 8, Number(position.left)));
			const top = Math.max(8, Math.min(window.innerHeight - height - 8, Number(position.top)));
			modal.style.left = left + 'px';
			modal.style.top = top + 'px';
			modal.style.right = 'auto';
			modal.style.bottom = 'auto';
		} catch (_error) {
			window.localStorage.removeItem('kidiaAppBuildDockPosition');
		}
	}

	function bindDockDrag(root) {
		const modal = progressModal(root);
		const card = modal && modal.querySelector('.kidia-app-build__modal-card');
		if (!modal || !card || card.dataset.buildDragBound === '1') return;
		card.dataset.buildDragBound = '1';
		card.addEventListener('pointerdown', function (event) {
			if (!modal.classList.contains('is-docked') || event.target.closest('button, a, input')) return;
			event.preventDefault();
			const bounds = modal.getBoundingClientRect();
			const offsetX = event.clientX - bounds.left;
			const offsetY = event.clientY - bounds.top;
			modal.classList.add('is-dragging');
			if (typeof card.setPointerCapture === 'function') card.setPointerCapture(event.pointerId);
			const move = function (moveEvent) {
				const left = Math.max(8, Math.min(window.innerWidth - bounds.width - 8, moveEvent.clientX - offsetX));
				const top = Math.max(8, Math.min(window.innerHeight - bounds.height - 8, moveEvent.clientY - offsetY));
				modal.style.left = left + 'px';
				modal.style.top = top + 'px';
				modal.style.right = 'auto';
				modal.style.bottom = 'auto';
			};
			const stop = function () {
				modal.classList.remove('is-dragging');
				const current = modal.getBoundingClientRect();
				window.localStorage.setItem('kidiaAppBuildDockPosition', JSON.stringify({
					left: Math.round(current.left),
					top: Math.round(current.top)
				}));
				card.removeEventListener('pointermove', move);
				card.removeEventListener('pointerup', stop);
				card.removeEventListener('pointercancel', stop);
			};
			card.addEventListener('pointermove', move);
			card.addEventListener('pointerup', stop);
			card.addEventListener('pointercancel', stop);
		});
	}

	function setActionState(root, status, progress, downloadReady) {
		const formAction = root.querySelector('[data-build-form-action]');
		const button = root.querySelector('[data-build-action]');
		const buttonLabel = root.querySelector('[data-build-action-label]');
		const icon = root.querySelector('[data-build-action-icon]');
		const cancelButton = root.querySelector('[data-build-cancel]');
		const modal = root.querySelector('[data-build-modal]');
		const canBuild = root.dataset.canBuild === '1';
		const ready = status === 'ready' && downloadReady;
		const building = isBuilding(status);
		const cancellable = !['idle', 'cancelled'].includes(status);

		if (formAction) {
			formAction.value = ready ? 'kidia_mobile_download_apk' : 'kidia_mobile_build_app';
		}
		if (button) {
			button.disabled = !ready && !building && !canBuild;
			button.classList.toggle('is-loading', building);
			button.hidden = false;
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
			cancelButton.hidden = !cancellable;
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
			const messages = root.querySelectorAll('[data-build-message]');
			const meter = root.querySelector('[data-build-progress]');
			const value = root.querySelector('[data-build-progress-value]');
			const ring = root.querySelector('[data-build-progress-ring]');
			const progressLabel = root.querySelector('[data-build-progress-label]');
			const stage = root.querySelector('[data-build-stage]');
			const buildMeta = root.querySelector('[data-build-meta]');
			const modal = progressModal(root);
			const downloadReady = status === 'ready' && state.downloadReady !== false;

			root.dataset.status = status;
			messages.forEach(function (message) {
				message.textContent = state.message || label(status);
			});
			if (meter) meter.hidden = !isBuilding(status);
			if (value) {
				value.style.width = progress + '%';
				value.setAttribute('aria-valuenow', String(progress));
			}
			if (ring) ring.style.setProperty('--kidia-ai-progress', progress);
			if (progressLabel) progressLabel.textContent = progress + '%';
			if (stage) stage.textContent = state.stage || (
				status === 'queued'
					? label('queued', 'Waiting for the build provider…')
					: label(status, 'Preparing the Android application…')
			);
			if (buildMeta) {
				const parts = [];
				if (state.buildId) parts.push('Build ID: ' + state.buildId);
				if (state.updatedAt) {
					parts.push('Last update: ' + new Date(Number(state.updatedAt) * 1000).toLocaleTimeString());
				}
				buildMeta.textContent = parts.join(' · ');
				buildMeta.hidden = parts.length === 0;
			}
			setActionState(root, status, progress, downloadReady);
			if (status === 'cancelled') {
				closeProgress(root);
			} else if (modal && modal.classList.contains('is-global')) {
				modal.hidden = false;
			}
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
			pollFailures = 0;
			render(state);
			if (isBuilding(state.status)) schedulePoll(4000);
		} catch (error) {
			pollFailures += 1;
			roots.forEach(function (root) {
				root.querySelectorAll('[data-build-message]').forEach(function (message) {
					message.textContent = (error.message || label('failed')) + ' — retrying automatically…';
				});
			});
			// A temporary WordPress/API/network failure must never freeze a
			// genuine Codemagic build at its last percentage. Keep polling until
			// the server reports a terminal state or the user presses Cancel.
			schedulePoll(Math.min(15000, 4000 + (pollFailures * 2000)));
		}
	}

	async function startBuild(root) {
		if (root.dataset.starting === '1' || isBuilding(root.dataset.status)) {
			openProgress(root);
			schedulePoll(0);
			return;
		}
		root.dataset.starting = '1';
		const nonce = root.querySelector('[name="kidia_mobile_build_nonce"]');
		const body = new URLSearchParams({
			action: 'kidia_mobile_app_build_start',
			nonce: nonce ? nonce.value : ''
		});

		autoDownload.add(root);
		openProgress(root);
		render({
			status: 'building',
			progress: 2,
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
		} finally {
			root.dataset.starting = '0';
		}
	}

	async function cancelBuild(root) {
		if (['idle', 'cancelled'].includes(root.dataset.status)) return;

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
			closeProgress(root);
		} catch (error) {
			if (cancelButton) cancelButton.disabled = false;
			root.querySelectorAll('[data-build-message]').forEach(function (message) {
				message.textContent = error.message || label('cancelFailed', 'The build could not be cancelled.');
			});
			schedulePoll(4000);
		}
	}

	roots.forEach(function (root) {
		const form = root.querySelector('[data-build-form]');
		if (root.dataset.autoDownload === '1') autoDownload.add(root);
		if (form) {
			form.addEventListener('submit', function (event) {
				if (root.dataset.status === 'ready') return;

				event.preventDefault();
				if (isBuilding(root.dataset.status)) {
					openProgress(root);
					schedulePoll(0);
					return;
				}
				if (root.dataset.canBuild !== '1') return;
				startBuild(root);
			});
		}

		const backgroundButton = root.querySelector('[data-build-background]');
		if (backgroundButton) {
			backgroundButton.addEventListener('click', function () {
				dockProgress(root);
			});
		}
		bindDockDrag(root);

		const cancelButton = root.querySelector('[data-build-cancel]');
		if (cancelButton) {
			cancelButton.addEventListener('click', function () {
				cancelBuild(root);
			});
		}
		persistProgress(root);
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
