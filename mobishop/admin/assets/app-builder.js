(function () {
	'use strict';

	const config = window.mobishopAppBuilder || {};
	if (!document.querySelector('[data-mobishop-app-build]') || !config.ajaxUrl) return;
	const roots = function () {
		return Array.from(document.querySelectorAll('[data-mobishop-app-build]'));
	};

	const autoDownload = new WeakSet();
	const openedProgress = new WeakSet();
	const completedStorageKey = 'mobishopAppBuildDownloadCompleted';
	const dismissedStorageKey = 'mobishopAppBuildProgressDismissed';
	// Keep successful artifacts available even when later settings changes return the build control to idle.
	const recentBuildWindow = 10 * 24 * 60 * 60;
	let timer = 0;
	let pollFailures = 0;
	const requestTimeout = Math.max(100, Number(config.requestTimeout || 25000));

	function label(status, fallback) {
		return (config.labels && config.labels[status]) || fallback || '';
	}

	function isBuilding(status) {
		return ['queued', 'building'].includes(status);
	}

	function normalizedStatus(status) {
		return ['completed', 'finished'].includes(status) ? 'ready' : status;
	}

	function hasStoredBuild(status) {
		return status && status !== 'idle' && status !== 'cancelled';
	}

	function completedBuildId() {
		try {
			return window.localStorage.getItem(completedStorageKey) || '';
		} catch (_error) {
			return '';
		}
	}

	function rememberDownloadCompleted(buildId) {
		if (!buildId) return;
		try {
			window.localStorage.setItem(completedStorageKey, buildId);
		} catch (_error) {}
	}

	function forgetDownloadCompleted() {
		try {
			window.localStorage.removeItem(completedStorageKey);
		} catch (_error) {}
	}

	function dismissedBuildId() {
		try {
			return window.localStorage.getItem(dismissedStorageKey) || '';
		} catch (_error) {
			return '';
		}
	}

	function rememberProgressDismissed(buildId) {
		if (!buildId) return;
		try {
			window.localStorage.setItem(dismissedStorageKey, buildId);
		} catch (_error) {}
	}

	function forgetProgressDismissed() {
		try {
			window.localStorage.removeItem(dismissedStorageKey);
		} catch (_error) {}
	}

	function progressWasDismissed(root) {
		const buildId = root.dataset.buildId || '';
		return Boolean(buildId && dismissedBuildId() === buildId);
	}

	function progressModal(root) {
		return root.querySelector('[data-build-modal]');
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
		document.body.classList.add('mobishop-ai-is-generating');
	}

	function closeProgress(root) {
		const modal = progressModal(root);
		if (!modal) return;
		openedProgress.delete(root);
		modal.hidden = true;
		modal.classList.remove('is-docked', 'is-dragging');
		document.body.classList.remove('mobishop-ai-is-generating');
	}

	function dockProgress(root) {
		const modal = progressModal(root);
		if (!modal || modal.hidden) return;
		modal.classList.add('is-docked');
		document.body.classList.remove('mobishop-ai-is-generating');
		if (modal.closest('[data-mobishop-background-job-stack]')) {
			modal.style.removeProperty('left');
			modal.style.removeProperty('top');
			modal.style.removeProperty('right');
			modal.style.removeProperty('bottom');
			return;
		}
		const stored = window.localStorage.getItem('mobishopAppBuildDockPosition');
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
			window.localStorage.removeItem('mobishopAppBuildDockPosition');
		}
	}

	function bindDockDrag(root) {
		const modal = progressModal(root);
		const card = modal && modal.querySelector('.mobishop-app-build__modal-card');
		if (!modal || !card || card.dataset.buildDragBound === '1') return;
		card.dataset.buildDragBound = '1';
		card.addEventListener('pointerdown', function (event) {
			if (
				!modal.classList.contains('is-docked') ||
				modal.closest('[data-mobishop-background-job-stack]') ||
				event.target.closest('button, a, input')
			) return;
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
				window.localStorage.setItem('mobishopAppBuildDockPosition', JSON.stringify({
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
		const dismissLabel = root.querySelector('[data-build-dismiss-label]');
		const stage = root.querySelector('[data-build-stage]');
		const modal = root.querySelector('[data-build-modal]');
		const canBuild = root.dataset.canBuild === '1';
		const ready = status === 'ready' && downloadReady;
		const downloaded = status === 'downloaded';
		const building = isBuilding(status);
		const stored = hasStoredBuild(status);

		if (formAction) {
			formAction.value = ready ? 'mobishop_download_apk' : 'mobishop_build_app';
		}
		if (button) {
			button.disabled = building || (!ready && !downloaded && !canBuild);
			button.classList.toggle('is-loading', building);
			button.hidden = false;
			button.setAttribute('aria-busy', building ? 'true' : 'false');
		}
		if (buttonLabel) {
			if (downloaded) {
				buttonLabel.textContent = label('buildDownload', 'Build Your App');
			} else if (ready) {
				buttonLabel.textContent = label('download', 'Download APK');
			} else if (building) {
				const currentStage = root.dataset.stage || label('building', 'Building your APK…');
				const percentage = progress > 0 ? ' ' + progress + '%' : '';
				buttonLabel.textContent = currentStage + percentage;
			} else {
				buttonLabel.textContent = label('buildDownload', 'Build Your App');
			}
		}
		if (cancelButton) {
			cancelButton.hidden = !stored;
			cancelButton.disabled = false;
			cancelButton.classList.toggle('is-confirm', stored && !building);
			const actionIcon = cancelButton.querySelector('.dashicons');
			if (actionIcon) actionIcon.className = 'dashicons ' + (building ? 'dashicons-no-alt' : 'dashicons-yes-alt');
		}
		if (dismissLabel) dismissLabel.textContent = building ? label('cancelBuild', 'Cancel Build') : label('ok', 'OK');
		if (stage) stage.hidden = downloaded;
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

		const form = root.querySelector('[data-build-form]');
		if (!form) return;
		autoDownload.delete(root);
		root.dataset.autoDownload = '0';
		const button = root.querySelector('[data-build-action]');
		if (typeof form.requestSubmit === 'function') {
			form.requestSubmit(button || undefined);
		} else {
			form.submit();
		}
		const buildId = root.dataset.buildId || '';
		rememberDownloadCompleted(buildId);
		render({ status: 'downloaded', progress: 100, buildId: buildId, message: label('downloaded', 'Download Completed'), downloadReady: false });
	}

	function render(state) {
		roots().forEach(function (root) {
			let status = normalizedStatus(state.status || root.dataset.status || 'idle');
			const buildId = String(state.buildId || root.dataset.buildId || '');
			if (status === 'ready' && buildId && completedBuildId() === buildId) status = 'downloaded';
			const progress = Math.max(0, Math.min(100, Number(state.progress || 0)));
			const messages = root.querySelectorAll('[data-build-message]');
			const meter = root.querySelector('[data-build-progress]');
			const value = root.querySelector('[data-build-progress-value]');
			const ring = root.querySelector('[data-build-progress-ring]');
			const progressLabel = root.querySelector('[data-build-progress-label]');
			const stage = root.querySelector('[data-build-stage]');
			const title = root.querySelector('[data-build-title]');
			const buildMeta = root.querySelector('[data-build-meta]');
			const downloadReady = status === 'ready' && state.downloadReady !== false;

			root.dataset.status = status;
			if (buildId) root.dataset.buildId = buildId;
			if (state.completedAt) root.dataset.completedAt = String(state.completedAt);
			else if (isBuilding(status) || ['idle', 'cancelled', 'failed'].includes(status)) delete root.dataset.completedAt;
			root.dataset.stage = state.stage || state.message || '';
			messages.forEach(function (message) {
				message.textContent = state.message || label(status);
			});
			if (meter) meter.hidden = !isBuilding(status);
			if (value) {
				value.style.width = progress + '%';
				value.setAttribute('aria-valuenow', String(progress));
			}
			if (ring) ring.style.setProperty('--mobishop-ai-progress', progress);
			if (progressLabel) progressLabel.textContent = progress + '%';
			if (stage) {
				stage.hidden = status === 'downloaded';
				if (!stage.hidden) {
					stage.textContent = state.stage || state.message || (
						status === 'queued'
							? label('queued', 'Waiting for the build provider…')
							: label(status, 'Preparing the Android application…')
					);
				}
			}
			if (title) title.textContent = status === 'downloaded'
				? label('downloaded', 'Download Completed')
				: label('buildTitle', 'Building your app');
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
			if (state.dismissed) closeProgress(root);
			else if (root.hasAttribute('data-build-persistent') && hasStoredBuild(status) && !progressWasDismissed(root)) {
				openProgress(root);
				dockProgress(root);
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
			action: 'mobishop_app_build_status',
			nonce: config.nonce || ''
		});
		try {
			const state = await request(body);
			pollFailures = 0;
			render(state);
			if (isBuilding(state.status)) schedulePoll(4000);
		} catch (error) {
			pollFailures += 1;
			if (pollFailures >= 3) {
				roots().forEach(function (root) { autoDownload.delete(root); });
				render({
					status: 'failed',
					progress: 0,
					message: error.message || label('failed'),
					downloadReady: false
				});
				return;
			}
			roots().forEach(function (root) {
				root.querySelectorAll('[data-build-message]').forEach(function (message) {
					message.textContent = error.message || label('failed');
				});
			});
			schedulePoll(5000);
		}
	}

	async function startBuild(root) {
		const nonce = root.querySelector('[name="mobishop_build_nonce"]');
		const body = new URLSearchParams({
			action: 'mobishop_app_build_start',
			nonce: nonce ? nonce.value : ''
		});

		forgetDownloadCompleted();
		forgetProgressDismissed();
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
		}
	}

	async function cancelBuild(root) {
		if (!hasStoredBuild(root.dataset.status)) return;

		if (timer) {
			window.clearTimeout(timer);
			timer = 0;
		}
		const cancelButton = root.querySelector('[data-build-cancel]');
		if (cancelButton) cancelButton.disabled = true;
		const body = new URLSearchParams({
			action: 'mobishop_app_build_cancel',
			nonce: config.cancelNonce || '',
			buildId: root.dataset.buildId || ''
		});

		try {
			const state = await request(body);
			autoDownload.delete(root);
			if (normalizedStatus(state.status || '') === 'ready' && state.dismissed) {
				rememberProgressDismissed(state.buildId || root.dataset.buildId || '');
				render(state);
				closeProgress(root);
				return;
			}
			forgetDownloadCompleted();
			forgetProgressDismissed();
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

	function hasRecentCompletedBuild(root) {
		const completedAt = Number(root.dataset.completedAt || 0);
		const status = normalizedStatus(root.dataset.status || '');
		const age = Math.floor(Date.now() / 1000) - completedAt;
		return Boolean(root.dataset.buildId) && !isBuilding(status) && completedAt > 0 && age >= 0 && age < recentBuildWindow;
	}

	function showRecentChoice(root) {
		const choice = root.querySelector('[data-build-recent-choice]');
		if (choice) choice.hidden = false;
	}

	function hideRecentChoice(root) {
		const choice = root.querySelector('[data-build-recent-choice]');
		if (choice) choice.hidden = true;
	}

	function bindDelegatedCancel() {
		const marker = 'mobishopAppBuildCancelDelegated';
		if (document.documentElement.dataset[marker] === '1') return;
		document.documentElement.dataset[marker] = '1';
		document.addEventListener('click', function (event) {
			const recentCancel = event.target.closest('[data-build-recent-cancel]');
			if (recentCancel) {
				const recentRoot = recentCancel.closest('[data-mobishop-app-build]');
				if (recentRoot) hideRecentChoice(recentRoot);
				return;
			}
			const cancelButton = event.target.closest('[data-build-cancel]');
			if (!cancelButton) return;
			const root = cancelButton.closest('[data-mobishop-app-build]');
			if (!root) return;
			const status = normalizedStatus(root.dataset.status || '');
			if (['ready', 'downloaded'].includes(status)) {
				cancelBuild(root);
				return;
			}
			cancelBuild(root);
		});
	}

	function bindRoots() {
		roots().forEach(function (root) {
			if (root.dataset.buildBound === '1') return;
			root.dataset.buildBound = '1';
			const form = root.querySelector('[data-build-form]');
			if (root.dataset.autoDownload === '1' || isBuilding(root.dataset.status)) autoDownload.add(root);
			if (form) form.addEventListener('submit', function (event) {
				if (isBuilding(root.dataset.status)) {
					event.preventDefault();
					openProgress(root);
					schedulePoll(0);
					return;
				}
				if (root.dataset.canBuild !== '1') return;
				if (hasRecentCompletedBuild(root)) {
					event.preventDefault();
					showRecentChoice(root);
					return;
				}
				if (root.dataset.status === 'ready') return;

				event.preventDefault();
				startBuild(root);
			});

			const downloadAgain = root.querySelector('[data-build-download-again]');
			if (downloadAgain) downloadAgain.addEventListener('click', function () {
				hideRecentChoice(root);
				if (config.downloadUrl) window.location.href = config.downloadUrl;
			});

			const buildNewVersion = root.querySelector('[data-build-new-version]');
			if (buildNewVersion) buildNewVersion.addEventListener('click', function () {
				hideRecentChoice(root);
				startBuild(root);
			});

			bindDockDrag(root);

		});
	}
	bindDelegatedCancel();
	bindRoots();
	document.addEventListener('mobishop:cms-page-ready', bindRoots);

	const active = roots().some(function (root) {
		return isBuilding(root.dataset.status);
	});
	if (active) poll();

	roots().forEach(function (root) {
		let initialStatus = normalizedStatus(root.dataset.status || 'idle');
		if (initialStatus === 'ready' && root.dataset.buildId && completedBuildId() === root.dataset.buildId) {
			initialStatus = 'downloaded';
			root.dataset.status = initialStatus;
			root.querySelectorAll('[data-build-message]').forEach(function (message) {
				message.textContent = label('downloaded', 'Download Completed');
			});
			const initialTitle = root.querySelector('[data-build-title]');
			if (initialTitle) initialTitle.textContent = label('downloaded', 'Download Completed');
		}
		const initialMeter = root.querySelector('[data-build-progress-value]');
		const initialProgress = Number(initialMeter ? initialMeter.getAttribute('aria-valuenow') : 0);
		setActionState(root, initialStatus, initialProgress, initialStatus === 'ready');
		if (hasStoredBuild(root.dataset.status) && !progressWasDismissed(root)) {
			openProgress(root);
			dockProgress(root);
		}
		if (initialStatus === 'ready') requestDownload(root);
	});

	window.addEventListener('beforeunload', function () {
		if (timer) window.clearTimeout(timer);
	});
})();
