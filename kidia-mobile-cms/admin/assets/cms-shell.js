(function () {
	'use strict';
	const shell = document.querySelector('.kidia-cms-shell');

	function syncBuilderScreen(enabled) {
		const active = Boolean(enabled);
		document.body.classList.toggle('kidia-cms-builder-screen', active);
		document.documentElement.classList.toggle('kidia-cms-builder-screen', active);
		if (!active) return;
		if ('scrollRestoration' in history) {
			history.scrollRestoration = 'manual';
		}
		window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
	}

	syncBuilderScreen(document.body.classList.contains('kidia-cms-builder-screen'));

	/* One permanent CMS shell; the server returns view fragments only. */
	function installPersistentCmsNavigation() {
		if (window.kidiaCmsNavigatorInstalled) return;
		window.kidiaCmsNavigatorInstalled = true;
		const config = window.kidiaCMSNavigation || {};
		const viewCache = new Map();
		const currentVersion = String(config.version || '');
		const legacyViews = {
			'kidia-mobile-home-builder': 'home',
			'kidia-mobile-category-builder': 'category',
			'kidia-mobile-catalog-builder': 'catalog',
			'kidia-mobile-product-builder': 'product',
			'kidia-mobile-wishlist-builder': 'wishlist',
			'kidia-mobile-account-builder': 'account',
			'kidia-mobile-splash-screen': 'splash',
			'kidia-mobile-checkout-suggestions': 'checkout',
			'kidia-mobile-setup': 'setup',
			'kidia-mobile-saved-themes': 'saved-themes',
			'kidia-mobile-store-data': 'store-data',
			'kidia-mobile-ai-insights': 'ai-insights',
			'kidia-mobile-push-notifications': 'push',
			'kidia-mobile-website-app-promotion': 'website-promotion'
		};

		const pluginPage = function (url) {
			try {
				const target = new URL(url, window.location.href);
				return target.origin === window.location.origin &&
					target.pathname.endsWith('/wp-admin/admin.php') &&
					(target.searchParams.get('page') === 'kidia-mobile-cms' || Boolean(legacyViews[target.searchParams.get('page')]));
			} catch (_error) {
				return false;
			}
		};
		const keyFor = function (url) {
			const target = new URL(url, window.location.href);
			const legacyView = legacyViews[target.searchParams.get('page')];
			if (legacyView) {
				target.searchParams.set('page', 'kidia-mobile-cms');
				target.searchParams.set('view', legacyView);
			}
			target.hash = '';
			return target.href;
		};
		const appendInline = function (code) {
			if (!code) return;
			const script = document.createElement('script');
			script.textContent = code;
			document.head.appendChild(script);
			script.remove();
		};
		const absoluteAssetUrl = function (src) {
			try {
				return new URL(src, window.location.href).href;
			} catch (_error) {
				return String(src || '');
			}
		};
		const findLoadedAsset = function (asset, type) {
			const expectedUrl = absoluteAssetUrl(asset.src);
			const selector = type === 'css'
				? 'link[rel="stylesheet"][href]'
				: 'script[src]';
			const urlProperty = type === 'css' ? 'href' : 'src';
			const byHandle = document.getElementById(asset.handle + '-' + type);
			const samePath = Array.from(document.querySelectorAll(selector)).filter(function (node) {
				try {
					return new URL(node[urlProperty], window.location.href).pathname ===
						new URL(expectedUrl, window.location.href).pathname;
				} catch (_error) {
					return false;
				}
			});
			const exact = samePath.find(function (node) {
				return absoluteAssetUrl(node[urlProperty]) === expectedUrl;
			});
			const conflict = [byHandle].concat(samePath).filter(Boolean).find(function (node) {
				return absoluteAssetUrl(node[urlProperty]) !== expectedUrl;
			});
			return { exact: exact || null, conflict: conflict || null };
		};
		const hardNavigate = function (url) {
			viewCache.clear();
			if (typeof window.kidiaCmsHardNavigate === 'function') {
				window.kidiaCmsHardNavigate(url);
				return;
			}
			window.location.href = url;
		};
		const loadAssets = async function (payload) {
			for (const asset of (payload.styles || [])) {
				const loaded = findLoadedAsset(asset, 'css');
				if (loaded.conflict) return false;
				if (loaded.exact) continue;
				const link = document.createElement('link');
				link.id = asset.handle + '-css';
				link.rel = 'stylesheet';
				link.href = asset.src;
				await new Promise(function (resolve) {
					link.addEventListener('load', resolve, { once: true });
					link.addEventListener('error', resolve, { once: true });
					document.head.appendChild(link);
				});
			}
			let loadedNewScript = false;
			for (const asset of (payload.scripts || [])) {
				const loaded = findLoadedAsset(asset, 'js');
				if (loaded.conflict) return false;
				if (loaded.exact) continue;
				(asset.before || []).forEach(appendInline);
				const script = document.createElement('script');
				script.id = asset.handle + '-js';
				script.src = asset.src;
				await new Promise(function (resolve) {
					script.addEventListener('load', resolve, { once: true });
					script.addEventListener('error', resolve, { once: true });
					document.body.appendChild(script);
				});
				(asset.after || []).forEach(appendInline);
				loadedNewScript = true;
			}
			if (loadedNewScript) {
				document.dispatchEvent(new Event('DOMContentLoaded'));
			}
			return true;
		};
		const updateNavigation = function (payload) {
			const sidebar = document.querySelector('[data-kidia-cms-sidebar]');
			const shell = document.querySelector('[data-kidia-cms-shell]');
			sidebar.querySelectorAll('[data-kidia-sidebar-view]').forEach(function (link) {
				link.classList.toggle('is-active', link.dataset.kidiaSidebarView === payload.activeSidebar);
			});
			shell.hidden = !payload.showPageTabs;
			shell.querySelectorAll('[data-kidia-page-view]').forEach(function (link) {
				link.classList.toggle('is-active', link.dataset.kidiaPageView === (payload.view === 'pages' ? 'splash' : payload.view));
			});
		};
		const loadPage = async function (url, pushState) {
			const sidebar = document.querySelector('[data-kidia-cms-sidebar]');
			const shell = document.querySelector('[data-kidia-cms-shell]');
			const currentContent = document.querySelector('#wpbody-content');
			if (!sidebar || !shell || !currentContent) {
				return;
			}
			const cacheKey = keyFor(url);
			if (window.kidiaCmsNavigationController) window.kidiaCmsNavigationController.abort();
			const controller = new AbortController();
			window.kidiaCmsNavigationController = controller;
			currentContent.classList.add('is-kidia-page-loading');
			try {
				let payload;
				if (viewCache.has(cacheKey)) {
					payload = viewCache.get(cacheKey);
				} else {
					const body = new URLSearchParams({
						action: 'kidia_mobile_cms_view',
						nonce: String(config.nonce || ''),
						version: currentVersion,
						target: cacheKey
					});
					const response = await fetch(config.ajaxUrl || window.ajaxurl || '', {
						method: 'POST',
					credentials: 'same-origin',
					cache: 'no-store',
						headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
						body: body.toString(),
					signal: controller.signal
				});
				if (!response.ok) throw new Error('CMS page request failed');
					const result = await response.json();
					if (!result.success || !result.data || typeof result.data.html !== 'string') throw new Error('CMS view is missing');
					payload = result.data;
					if (
						currentVersion &&
						payload.version &&
						String(payload.version) !== currentVersion
					) {
						hardNavigate(cacheKey);
						return;
					}
					const template = document.createElement('template');
					template.innerHTML = payload.html;
					payload.nodes = Array.from(template.content.childNodes);
					if (!await loadAssets(payload)) {
						hardNavigate(cacheKey);
						return;
					}
					viewCache.set(cacheKey, payload);
				}
				syncBuilderScreen(payload.builderScreen);
				updateNavigation(payload);
				document.dispatchEvent(new CustomEvent('kidia:cms-before-page-change', {
					detail: { url: cacheKey }
				}));
				Array.from(currentContent.childNodes).forEach(function (node) {
					if (node !== sidebar && node !== shell) node.remove();
				});
				payload.nodes.forEach(function (node) { currentContent.appendChild(node); });
				if (pushState) history.pushState({ kidiaCmsPage: true }, '', cacheKey);
				document.dispatchEvent(new CustomEvent('kidia:cms-page-ready', { detail: { url: window.location.href } }));
			} catch (error) {
				if (error.name === 'AbortError') return;
				const message = document.createElement('div');
				message.className = 'notice notice-error kidia-cms-navigation-error';
				message.setAttribute('role', 'alert');
				message.textContent = 'The requested Woo Mobile CMS view could not be loaded. Please try again.';
				Array.from(currentContent.childNodes).forEach(function (node) {
					if (node !== sidebar && node !== shell) node.remove();
				});
				currentContent.appendChild(message);
			} finally {
				currentContent.classList.remove('is-kidia-page-loading');
			}
		};

		document.addEventListener('click', function (event) {
			const link = event.target.closest('#wpbody-content a');
			if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
			if (!pluginPage(link.href)) return;
			event.preventDefault();
			void loadPage(link.href, true);
		});
		window.addEventListener('popstate', function () {
			if (pluginPage(window.location.href)) void loadPage(window.location.href, false);
		});
	}

	installPersistentCmsNavigation();

	function initThemeModal() {
		const saveForm = document.querySelector('[data-kidia-save-theme]');
		const modal = document.querySelector('[data-kidia-theme-modal]');
		if (!saveForm || !modal) return;
		const input = modal.querySelector('[data-kidia-theme-name]');
		const error = modal.querySelector('[data-kidia-theme-error]');
		const close = function () { modal.hidden = true; document.body.classList.remove('kidia-modal-open'); };
		saveForm.addEventListener('submit', function (event) {
			if (saveForm.dataset.confirmed === '1') return;
			event.preventDefault();
			modal.hidden = false;
			document.body.classList.add('kidia-modal-open');
			input.value = '';
			error.hidden = true;
			window.setTimeout(function () { input.focus(); }, 30);
		});
		modal.querySelectorAll('[data-kidia-theme-cancel]').forEach(function (button) { button.addEventListener('click', close); });
		modal.querySelector('[data-kidia-theme-confirm]').addEventListener('click', function () {
			const name = input.value.trim();
			if (!name) { error.hidden = false; input.focus(); return; }
			const editorAction = document.querySelector('input[name="action"][value^="kidia_mobile_save_"]');
			const editorForm = editorAction ? editorAction.form : null;
			if (editorForm && editorForm !== saveForm) {
				const field = document.createElement('input');
				field.type = 'hidden'; field.name = 'kidia_save_theme_name'; field.value = name;
				editorForm.appendChild(field);
				close();
				if (typeof editorForm.requestSubmit === 'function') editorForm.requestSubmit(); else editorForm.submit();
				return;
			}
			saveForm.elements.theme_name.value = name;
			saveForm.dataset.confirmed = '1';
			close();
			if (typeof saveForm.requestSubmit === 'function') saveForm.requestSubmit(); else saveForm.submit();
		});
		input.addEventListener('keydown', function (event) {
			if (event.key === 'Enter') { event.preventDefault(); modal.querySelector('[data-kidia-theme-confirm]').click(); }
		});
	}

	function syncPreviewOffset() {
		if (!shell) return;
		const style = window.getComputedStyle(shell);
		const stickyTop = parseFloat(style.top) || 0;
		const shellHeight = Math.ceil(shell.getBoundingClientRect().height);
		document.documentElement.style.setProperty(
			'--kidia-preview-sticky-top',
			Math.ceil(stickyTop + shellHeight + 14) + 'px'
		);
	}

	syncPreviewOffset();
	window.addEventListener('resize', syncPreviewOffset);
	if (shell && typeof window.ResizeObserver === 'function') {
		new window.ResizeObserver(syncPreviewOffset).observe(shell);
	}
	initThemeModal();
	document.querySelectorAll('.kidia-theme-file input[type="file"]').forEach(function (input) {
		input.addEventListener('change', function () {
			const name = input.closest('.kidia-theme-file').querySelector('[data-theme-file-name]');
			if (name) name.textContent = input.files && input.files[0] ? input.files[0].name : 'No file selected';
		});
	});
	const pushTitle = document.querySelector('[data-push-title]');
	const pushMessage = document.querySelector('[data-push-message]');
	const previewTitle = document.querySelector('[data-push-preview-title]');
	const previewMessage = document.querySelector('[data-push-preview-message]');
	const syncPushPreview = function () {
		if (pushTitle && previewTitle) previewTitle.textContent = pushTitle.value.trim() || 'Your notification title';
		if (pushMessage && previewMessage) previewMessage.textContent = pushMessage.value.trim() || 'Your message will appear here.';
	};
	if (pushTitle) pushTitle.addEventListener('input', syncPushPreview);
	if (pushMessage) pushMessage.addEventListener('input', syncPushPreview);
	syncPushPreview();
	const pushTypeInputs = document.querySelectorAll('[data-push-type]');
	const pushDestination = document.querySelector('[data-push-destination]');
	const recommendedDestinations = {
		broadcast: 'home',
		offer: 'offers',
		order: 'order',
		restock: 'product',
		abandoned_cart: 'cart',
		welcome: 'home',
		custom: 'home'
	};
	const syncPushType = function () {
		const checked = document.querySelector('[data-push-type]:checked');
		const type = checked ? checked.value : 'broadcast';
		document.querySelectorAll('[data-push-field]').forEach(function (field) {
			field.hidden = !field.dataset.pushField.split(/\s+/).includes(type);
		});
		if (pushDestination && pushDestination.dataset.userChanged !== '1') {
			pushDestination.value = recommendedDestinations[type] || 'home';
		}
	};
	pushTypeInputs.forEach(function (input) { input.addEventListener('change', syncPushType); });
	if (pushDestination) {
		pushDestination.addEventListener('change', function () {
			pushDestination.dataset.userChanged = '1';
		});
	}
	syncPushType();
	const pushAudience = document.querySelector('[data-push-audience]');
	const pushSegment = document.querySelector('[data-push-segment]');
	if (pushAudience && pushSegment) {
		const syncAudience = function () { pushSegment.hidden = pushAudience.value !== 'segment'; };
		pushAudience.addEventListener('change', syncAudience); syncAudience();
	}
	const pushDelivery = document.querySelector('[data-push-delivery]');
	const pushSchedule = document.querySelector('[data-push-schedule]');
	const pushAutomation = document.querySelector('[data-push-automation]');
	const pushSubmitLabel = document.querySelector('[data-push-submit-label]');
	if (pushDelivery) {
		const syncDelivery = function () {
			if (pushSchedule) pushSchedule.hidden = pushDelivery.value !== 'scheduled';
			if (pushAutomation) pushAutomation.hidden = pushDelivery.value !== 'automation';
			if (pushSubmitLabel) {
				pushSubmitLabel.textContent = pushDelivery.value === 'scheduled'
					? 'Schedule notification'
					: (pushDelivery.value === 'automation' ? 'Save automation' : 'Send notification');
			}
		};
		pushDelivery.addEventListener('change', syncDelivery); syncDelivery();
	}
	const pushActionStyle = document.querySelector('[data-push-action-style]');
	const pushButtonLabel = document.querySelector('[data-push-button-label]');
	if (pushActionStyle && pushButtonLabel) {
		const syncPushActionStyle = function () {
			pushButtonLabel.hidden = pushActionStyle.value !== 'button';
		};
		pushActionStyle.addEventListener('change', syncPushActionStyle);
		syncPushActionStyle();
	}
	const datePreset = document.querySelector('.kidia-date-filter select[name="date_preset"]');
	if (datePreset) {
		const customDates = document.querySelectorAll('.kidia-date-filter input[type="date"]');
		const syncCustomDates = function () {
			const enabled = datePreset.value === 'custom';
			customDates.forEach(function (input) { input.disabled = !enabled; });
		};
		datePreset.addEventListener('change', syncCustomDates);
		syncCustomDates();
	}
	const aiGenerateForm = document.querySelector('[data-ai-generate-form]');
	const aiBackgroundConfig = window.kidiaCMSBackground || {};
	const aiDockPositionKey = 'kidia_ai_progress_position_v1';
	const aiRequest = async function (action, values) {
		const nonce = aiGenerateForm
			? aiGenerateForm.dataset.aiAnalysisNonce || ''
			: aiBackgroundConfig.aiNonce || '';
		const body = new URLSearchParams(Object.assign({action: action, nonce: nonce}, values || {}));
		const response = await window.fetch(aiBackgroundConfig.ajaxUrl || window.ajaxurl || '', {
			method: 'POST',
			credentials: 'same-origin',
			headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
			body: body.toString()
		});
		const json = await response.json();
		if (!response.ok || !json.success) {
			throw new Error((json.data && json.data.message) || 'The analysis could not be completed.');
		}
		return json.data;
	};
	const createAiDock = function () {
		const current = document.querySelector('[data-ai-progress-overlay]');
		if (current) return current;
		const dock = document.createElement('div');
		dock.className = 'kidia-ai-progress-overlay is-docked is-global';
		dock.dataset.aiProgressOverlay = '';
		dock.setAttribute('aria-live', 'polite');
		dock.innerHTML =
			'<div class="kidia-ai-progress-card">' +
			'<div class="kidia-ai-progress-ring" data-ai-progress-ring style="--kidia-ai-progress:0"><strong data-ai-progress-value>0%</strong></div>' +
			'<h2>Store analysis</h2><p data-ai-progress-stage>Reading store data in the background…</p>' +
			'<strong class="kidia-ai-progress-count" data-ai-progress-count>Checking progress…</strong>' +
			'<div class="kidia-ai-progress-track"><i data-ai-progress-bar></i></div>' +
			'<small data-ai-progress-note>You can continue using every CMS page while this runs.</small>' +
			'<div class="kidia-ai-progress-actions">' +
			'<a class="button button-primary" data-ai-view-results hidden>View results</a>' +
			'<button class="button kidia-ai-cancel-button" type="button" data-ai-cancel-button>Cancel analysis</button>' +
			'</div></div>';
		document.body.appendChild(dock);
		return dock;
	};
	const resetAiProgressVersion = function (overlay, jobId) {
		if (!overlay) return;
		overlay.dataset.aiProgressJob = String(jobId || '');
		overlay.dataset.aiProgressRevision = '-1';
		overlay.dataset.aiProgressProcessed = '-1';
	};
	const positionAiDock = function (overlay, left, top, remember) {
		if (!overlay || !overlay.classList.contains('is-docked')) return;
		const width = Math.max(1, overlay.offsetWidth || 380);
		const height = Math.max(1, overlay.offsetHeight || 180);
		const maxLeft = Math.max(8, window.innerWidth - width - 8);
		const maxTop = Math.max(8, window.innerHeight - height - 8);
		const safeLeft = Math.max(8, Math.min(maxLeft, Number(left) || 8));
		const safeTop = Math.max(8, Math.min(maxTop, Number(top) || 8));
		overlay.style.left = safeLeft + 'px';
		overlay.style.top = safeTop + 'px';
		overlay.style.right = 'auto';
		overlay.style.bottom = 'auto';
		if (remember) {
			try {
				window.localStorage.setItem(aiDockPositionKey, JSON.stringify({left: safeLeft, top: safeTop}));
			} catch (error) {}
		}
	};
	const restoreAiDockPosition = function (overlay) {
		if (!overlay || !overlay.classList.contains('is-docked')) return;
		try {
			const saved = JSON.parse(window.localStorage.getItem(aiDockPositionKey) || 'null');
			if (saved && Number.isFinite(Number(saved.left)) && Number.isFinite(Number(saved.top))) {
				positionAiDock(overlay, saved.left, saved.top, false);
			}
		} catch (error) {}
	};
	const bindAiDockDrag = function (overlay) {
		if (!overlay || overlay.dataset.aiDragBound === '1') return;
		const card = overlay.querySelector('.kidia-ai-progress-card');
		if (!card) return;
		overlay.dataset.aiDragBound = '1';
		card.addEventListener('pointerdown', function (event) {
			if (
				!overlay.classList.contains('is-docked') ||
				event.button !== 0 ||
				event.target.closest('button,a,input,select,textarea')
			) return;
			event.preventDefault();
			const start = overlay.getBoundingClientRect();
			const offsetX = event.clientX - start.left;
			const offsetY = event.clientY - start.top;
			overlay.classList.add('is-dragging');
			if (typeof card.setPointerCapture === 'function') card.setPointerCapture(event.pointerId);
			const move = function (moveEvent) {
				positionAiDock(overlay, moveEvent.clientX - offsetX, moveEvent.clientY - offsetY, false);
			};
			const stop = function () {
				overlay.classList.remove('is-dragging');
				const current = overlay.getBoundingClientRect();
				positionAiDock(overlay, current.left, current.top, true);
				card.removeEventListener('pointermove', move);
				card.removeEventListener('pointerup', stop);
				card.removeEventListener('pointercancel', stop);
			};
			card.addEventListener('pointermove', move);
			card.addEventListener('pointerup', stop);
			card.addEventListener('pointercancel', stop);
		});
	};
	const persistAiProgressAcrossNavigation = function (overlay, jobId) {
		if (
			!overlay ||
			!jobId ||
			overlay.hidden ||
			overlay.dataset.aiComplete === '1'
		) return false;
		overlay.classList.add('is-docked', 'is-global');
		document.body.appendChild(overlay);
		restoreAiDockPosition(overlay);
		bindAiDockDrag(overlay);
		document.body.classList.remove('kidia-ai-is-generating');
		return true;
	};
	const renderAiProgress = function (overlay, payload) {
		if (!overlay) return;
		const payloadJob = String(payload.job_id || '');
		const currentJob = String(overlay.dataset.aiProgressJob || '');
		if (currentJob && payloadJob && currentJob !== payloadJob) return;
		if (!currentJob && payloadJob) overlay.dataset.aiProgressJob = payloadJob;
		const revision = Number(payload.revision || 0);
		const processed = Number(payload.processed || 0);
		const currentRevision = Number(overlay.dataset.aiProgressRevision || -1);
		const currentProcessed = Number(overlay.dataset.aiProgressProcessed || -1);
		if (
			!payload.done &&
			!payload.cancelled &&
			(payload.busy || revision < currentRevision || (revision === currentRevision && processed < currentProcessed))
		) return;
		overlay.dataset.aiProgressRevision = String(revision);
		overlay.dataset.aiProgressProcessed = String(processed);
		const progress = Math.max(0, Math.min(100, Number(payload.progress || 0)));
		const progressLabel = Number.isInteger(progress) ? progress.toFixed(0) : progress.toFixed(1);
		const value = overlay.querySelector('[data-ai-progress-value]');
		const ring = overlay.querySelector('[data-ai-progress-ring]');
		const bar = overlay.querySelector('[data-ai-progress-bar]');
		const stage = overlay.querySelector('[data-ai-progress-stage]');
		const count = overlay.querySelector('[data-ai-progress-count]');
		if (value) value.textContent = progressLabel + '%';
		if (ring) ring.style.setProperty('--kidia-ai-progress', progress);
		if (bar) bar.style.width = progress + '%';
		if (stage && payload.stage) stage.textContent = payload.stage;
		if (count) {
			count.setAttribute('dir', 'ltr');
			count.textContent =
				Number(payload.processed || 0).toLocaleString() + ' / ' +
				Number(payload.total || 0).toLocaleString() + ' records completed';
		}
		const view = overlay.querySelector('[data-ai-view-results]');
		const cancel = overlay.querySelector('[data-ai-cancel-button]');
		const background = overlay.querySelector('[data-ai-background-button]');
		if (payload.cancelled) {
			overlay.setAttribute('aria-busy', 'false');
			overlay.hidden = true;
			document.body.classList.remove('kidia-ai-is-generating');
			return;
		}
		if (payload.done) {
			overlay.setAttribute('aria-busy', 'false');
			if (stage) stage.textContent = 'Completed. Loading your results…';
			if (view) view.hidden = true;
			if (background) background.hidden = true;
			if (cancel) cancel.innerHTML = '<span class="dashicons dashicons-no-alt"></span>Dismiss';
			overlay.dataset.aiComplete = '1';
			const resultUrl = payload.result_url || aiBackgroundConfig.aiUrl || '';
			if (resultUrl && overlay.dataset.aiResultOpening !== '1') {
				overlay.dataset.aiResultOpening = '1';
				window.setTimeout(function () {
					window.location.assign(resultUrl);
				}, 250);
			}
		}
	};
	if (window.__KIDIA_AI_PROGRESS_TEST__) {
		window.KidiaAiProgressTest = {
			render: renderAiProgress,
			reset: resetAiProgressVersion,
			position: positionAiDock,
			bindDrag: bindAiDockDrag,
			persistAcrossNavigation: persistAiProgressAcrossNavigation
		};
	}
	const pollBackgroundJob = async function (jobId, overlay) {
		let active = true;
		let failures = 0;
		overlay.dataset.aiPollingJob = jobId;
		while (active && document.body.contains(overlay) && overlay.dataset.aiPollingJob === jobId) {
			try {
				const payload = await aiRequest('kidia_mobile_ai_analysis_status', {job_id: jobId, advance: '1'});
				if (overlay.dataset.aiPollingJob !== jobId) return;
				renderAiProgress(overlay, payload);
				active = !payload.done && !payload.cancelled;
				failures = 0;
				if (active) {
					await new Promise(function (resolve) { window.setTimeout(resolve, 1200); });
				}
			} catch (error) {
				const note = overlay.querySelector('[data-ai-progress-note]');
				failures += 1;
				if (note) note.textContent = failures < 4
					? 'The server paused this batch. Retrying without losing completed records…'
					: (error && error.message ? error.message : 'Background status is unavailable.');
				active = failures < 4;
				if (active) {
					await new Promise(function (resolve) { window.setTimeout(resolve, 1800); });
				}
			}
		}
	};
	const bindAiOverlayActions = function (overlay, getJobId, setForeground) {
		if (!overlay || overlay.dataset.aiActionsBound === '1') return;
		overlay.dataset.aiActionsBound = '1';
		const background = overlay.querySelector('[data-ai-background-button]');
		const cancel = overlay.querySelector('[data-ai-cancel-button]');
		if (background) {
			background.addEventListener('click', async function () {
				const jobId = getJobId();
				if (!jobId) return;
				background.disabled = true;
				try {
					const payload = await aiRequest('kidia_mobile_background_ai_analysis', {job_id: jobId});
					setForeground(false);
					overlay.classList.add('is-docked');
					restoreAiDockPosition(overlay);
					document.body.classList.remove('kidia-ai-is-generating');
					background.innerHTML = '<span class="dashicons dashicons-yes-alt"></span>Running in background';
					renderAiProgress(overlay, payload);
					pollBackgroundJob(jobId, overlay);
				} catch (error) {
					background.disabled = false;
					const note = overlay.querySelector('[data-ai-progress-note]');
					if (note) note.textContent = error && error.message ? error.message : 'Could not move the analysis to the background.';
				}
			});
		}
		if (cancel) {
			cancel.addEventListener('click', async function () {
				const jobId = getJobId();
				if (!jobId) {
					overlay.hidden = true;
					return;
				}
				cancel.disabled = true;
				try {
					if (overlay.dataset.aiComplete === '1') {
						await aiRequest('kidia_mobile_dismiss_ai_analysis', {job_id: jobId});
					} else {
						setForeground(false);
						await aiRequest('kidia_mobile_cancel_ai_analysis', {job_id: jobId});
					}
					if (overlay.classList.contains('is-global')) {
						overlay.remove();
					} else {
						overlay.hidden = true;
						overlay.classList.remove('is-docked');
						delete overlay.dataset.aiComplete;
						cancel.disabled = false;
						const backgroundButton = overlay.querySelector('[data-ai-background-button]');
						if (backgroundButton) {
							backgroundButton.hidden = false;
							backgroundButton.disabled = false;
							backgroundButton.innerHTML = '<span class="dashicons dashicons-migrate"></span>Continue in background';
						}
						const generateButton = document.querySelector('[data-ai-generate-button]');
						const generateLabel = document.querySelector('[data-ai-generate-label]');
						if (generateButton) {
							generateButton.disabled = false;
							generateButton.classList.remove('is-generating');
						}
						if (generateLabel) generateLabel.textContent = 'Generate offers from store data';
					}
					document.body.classList.remove('kidia-ai-is-generating');
				} catch (error) {
					cancel.disabled = false;
				}
			});
		}
	};
	if (aiGenerateForm) {
		let activeJobId = String(aiBackgroundConfig.activeAiJob || '');
		let foreground = true;
		const overlay = document.querySelector('[data-ai-progress-overlay]');
		bindAiOverlayActions(overlay, function () { return activeJobId; }, function (value) { foreground = value; });
		document.addEventListener('kidia:cms-before-page-change', function () {
			if (!persistAiProgressAcrossNavigation(overlay, activeJobId)) return;
			foreground = false;
			if (overlay.dataset.aiPollingJob !== activeJobId) {
				pollBackgroundJob(activeJobId, overlay);
			}
			aiRequest('kidia_mobile_background_ai_analysis', {job_id: activeJobId})
				.then(function (payload) { renderAiProgress(overlay, payload); })
				.catch(function (error) {
					const note = overlay.querySelector('[data-ai-progress-note]');
					if (note) {
						note.textContent = error && error.message
							? error.message
							: 'The analysis is still running. Reconnecting to its progress…';
					}
				});
		});
		aiGenerateForm.addEventListener('submit', async function (event) {
			event.preventDefault();
			const button = aiGenerateForm.querySelector('[data-ai-generate-button]');
			const label = aiGenerateForm.querySelector('[data-ai-generate-label]');
			const note = overlay && overlay.querySelector('[data-ai-progress-note]');
			const count = overlay && overlay.querySelector('[data-ai-progress-count]');
			const stage = overlay && overlay.querySelector('[data-ai-progress-stage]');
			if (!button) return;
			foreground = true;
			activeJobId = '';
			resetAiProgressVersion(overlay, '');
			if (overlay) overlay.dataset.aiPollingJob = 'foreground';
			button.disabled = true;
			button.classList.add('is-generating');
			if (label) label.textContent = 'Generating offers from store data...';
			if (overlay) {
				overlay.hidden = false;
				overlay.setAttribute('aria-busy', 'true');
				overlay.classList.remove('is-docked');
				delete overlay.dataset.aiComplete;
				document.body.classList.add('kidia-ai-is-generating');
			}
			try {
				const source = aiGenerateForm.querySelector('[name="ai_source"]');
				const preset = aiGenerateForm.querySelector('[name="date_preset"]');
				const from = aiGenerateForm.querySelector('[name="date_from"]');
				const to = aiGenerateForm.querySelector('[name="date_to"]');
				let payload = await aiRequest('kidia_mobile_start_ai_analysis', {
					source: source ? source.value : 'all',
					date_preset: preset ? preset.value : 'all_time',
					date_from: from ? from.value : '',
					date_to: to ? to.value : ''
				});
				activeJobId = payload.job_id;
				resetAiProgressVersion(overlay, activeJobId);
				renderAiProgress(overlay, payload);
				let failures = 0;
				while (!payload.done && foreground) {
					try {
						payload = await aiRequest('kidia_mobile_ai_analysis_status', {job_id: activeJobId, advance: '1'});
						renderAiProgress(overlay, payload);
						failures = 0;
					} catch (stepError) {
						failures += 1;
						if (failures >= 4) throw stepError;
						if (note) note.textContent = 'The server paused this batch. Retrying without losing completed records…';
						await new Promise(function (resolve) { window.setTimeout(resolve, 1800); });
					}
					if (!payload.done && foreground) {
						await new Promise(function (resolve) { window.setTimeout(resolve, 350); });
					}
				}
				if (payload.cancelled || !foreground) return;
				window.location.assign(payload.result_url || window.location.href);
			} catch (error) {
				if (!foreground) return;
				if (stage) stage.textContent = error && error.message ? error.message : 'The analysis could not be completed.';
				if (note) note.textContent = 'No incomplete result was published. You can retry safely.';
				if (count) count.textContent = 'Analysis stopped';
				button.disabled = false;
				button.classList.remove('is-generating');
				if (label) label.textContent = 'Retry offer generation';
			}
		});
	}
	const configuredJob = String(aiBackgroundConfig.activeAiJob || '');
	const viewingAiResult = new URL(window.location.href).searchParams.get('ai_ready') === '1';
	if (configuredJob && !viewingAiResult) {
		const dock = createAiDock();
		dock.hidden = false;
		dock.classList.add('is-docked');
		resetAiProgressVersion(dock, configuredJob);
		restoreAiDockPosition(dock);
		bindAiOverlayActions(dock, function () { return configuredJob; }, function () {});
		pollBackgroundJob(configuredJob, dock);
	} else if (configuredJob && viewingAiResult) {
		aiRequest('kidia_mobile_dismiss_ai_analysis', {job_id: configuredJob}).catch(function () {});
	}
	document.querySelectorAll('[data-ai-progress-overlay]').forEach(bindAiDockDrag);
	window.addEventListener('resize', function () {
		document.querySelectorAll('[data-ai-progress-overlay].is-docked').forEach(function (overlay) {
			const current = overlay.getBoundingClientRect();
			positionAiDock(overlay, current.left, current.top, false);
		});
	});
	const aiWorkspaceTabs = document.querySelectorAll('[data-ai-workspace-tab]');
	const aiWorkspacePanels = document.querySelectorAll('[data-ai-workspace-panel]');
	if (aiWorkspaceTabs.length && aiWorkspacePanels.length) {
		aiWorkspaceTabs.forEach(function (tab) {
			tab.addEventListener('click', function () {
				const target = tab.dataset.aiWorkspaceTab;
				aiWorkspaceTabs.forEach(function (item) { item.classList.toggle('is-active', item === tab); });
				aiWorkspacePanels.forEach(function (panel) { panel.hidden = panel.dataset.aiWorkspacePanel !== target; });
			});
		});
	}
	const aiPlaybookButtons = document.querySelectorAll('[data-ai-playbook-kind]');
	const aiDecisionCards = document.querySelectorAll('[data-ai-decision-kind]');
	if (aiPlaybookButtons.length && aiDecisionCards.length) {
		aiPlaybookButtons.forEach(function (button) {
			button.addEventListener('click', function () {
				const wasActive = button.classList.contains('is-active');
				const kinds = String(button.dataset.aiPlaybookKind || 'all').split(',');
				aiPlaybookButtons.forEach(function (item) { item.classList.remove('is-active'); });
				if (!wasActive) button.classList.add('is-active');
				aiDecisionCards.forEach(function (card) {
					card.hidden = !wasActive && !kinds.includes('all') && !kinds.includes(card.dataset.aiDecisionKind);
				});
			});
		});
	}
	const recoveryDelivery = document.querySelector('[data-recovery-delivery]');
	const recoverySchedule = document.querySelector('[data-recovery-schedule]');
	if (recoveryDelivery && recoverySchedule) {
		const syncRecoveryDelivery = function () { recoverySchedule.hidden = recoveryDelivery.value !== 'scheduled'; };
		recoveryDelivery.addEventListener('change', syncRecoveryDelivery);
		syncRecoveryDelivery();
	}
	const recoveryActionStyle = document.querySelector('[data-recovery-action-style]');
	const recoveryButtonLabel = document.querySelector('[data-recovery-button-label]');
	if (recoveryActionStyle && recoveryButtonLabel) {
		const syncRecoveryAction = function () {
			recoveryButtonLabel.hidden = recoveryActionStyle.value !== 'button';
		};
		recoveryActionStyle.addEventListener('change', syncRecoveryAction);
		syncRecoveryAction();
	}
	const selectAllCarts = document.querySelector('[data-select-all-carts]');
	if (selectAllCarts) {
		selectAllCarts.addEventListener('change', function () {
			document.querySelectorAll('input[name="cart_ids[]"]:not(:disabled)').forEach(function (input) {
				input.checked = selectAllCarts.checked;
			});
		});
	}
	document.addEventListener('click', async function (event) {
		const button = event.target.closest('[data-abandoned-cart-details]');
		if (!button) return;
		const cartId = String(button.dataset.abandonedCartDetails || '');
		const row = document.querySelector('[data-abandoned-cart-details-row="' + CSS.escape(cartId) + '"]');
		const content = row ? row.querySelector('.kidia-cart-details-content') : null;
		if (!row || !content) return;
		if (button.getAttribute('aria-expanded') === 'true') {
			row.hidden = true;
			button.setAttribute('aria-expanded', 'false');
			return;
		}
		row.hidden = false;
		button.setAttribute('aria-expanded', 'true');
		if (content.dataset.loaded === '1' || content.dataset.loading === '1') return;
		content.dataset.loading = '1';
		content.innerHTML = '<p class="kidia-cart-details-loading">Loading order details…</p>';
		const escapeHtml = function (value) {
			const node = document.createElement('span');
			node.textContent = String(value == null ? '' : value);
			return node.innerHTML;
		};
		try {
			const config = window.kidiaCMSBackground || {};
			const body = new URLSearchParams({
				action: 'kidia_mobile_abandoned_cart_details',
				nonce: String(config.cartNonce || ''),
				cart_id: cartId
			});
			const response = await fetch(config.ajaxUrl || window.ajaxurl || '', {
				method: 'POST',
				credentials: 'same-origin',
				headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
				body: body.toString()
			});
			const payload = await response.json();
			if (!response.ok || !payload.success) {
				throw new Error(payload.data && payload.data.message ? payload.data.message : 'Order details could not be loaded.');
			}
			const insight = payload.data || {};
			const cart = insight.cart || {};
			const orders = Array.isArray(insight.orders) ? insight.orders : [];
			const alternative = insight.alternative || null;
			const items = Array.isArray(cart.items) ? cart.items : [];
			const itemHtml = items.length
				? '<ul>' + items.map(function (item) {
					return '<li><strong>' + escapeHtml(item.name || 'Product') + '</strong><span>× ' + escapeHtml(item.quantity || 1) + '</span></li>';
				}).join('') + '</ul>'
				: '<p>No cart items are available.</p>';
			const historyHtml = orders.length
				? '<ul>' + orders.map(function (order) {
					return '<li><strong>#' + escapeHtml(order.id) + '</strong><span>' + escapeHtml(order.date) + '</span><em>' + escapeHtml(order.status) + ' · ' + escapeHtml(order.total) + ' ' + escapeHtml(order.currency) + '</em></li>';
				}).join('') + '</ul>'
				: '<p>No previous orders were found for this customer.</p>';
			const alternativeHtml = alternative
				? '<div class="kidia-cart-alternative-order"><strong>#' + escapeHtml(alternative.id) + '</strong><span>' + escapeHtml(alternative.date) + '</span><em>' + escapeHtml(alternative.total) + ' ' + escapeHtml(alternative.currency) + '</em></div>'
				: '<p>No order was placed within 10 days before or after this cart.</p>';
			content.innerHTML =
				'<section><h4>1. Cart order</h4>' + itemHtml + '</section>' +
				'<section><h4>2. Customer order history</h4>' + historyHtml + '</section>' +
				'<section><h4>3. Possible alternative order <small>±10 days</small></h4>' + alternativeHtml + '</section>';
			content.dataset.loaded = '1';
			const segment = String(insight.customer_segment || 'first_time');
			const marker = document.querySelector('[data-abandoned-cart-row="' + CSS.escape(cartId) + '"] .kidia-cart-segment');
			if (marker) marker.className = 'kidia-cart-segment is-' + segment;
		} catch (error) {
			content.innerHTML = '<p class="kidia-cart-details-error">' + escapeHtml(error.message || 'Order details could not be loaded.') + '</p>';
		} finally {
			delete content.dataset.loading;
		}
	});
	const liveStoreRegions = Array.from(document.querySelectorAll('[data-kidia-live-store-data]'));
	if (liveStoreRegions.length) {
		let liveTimer = 0;
		let liveRequest = null;
		const scheduleLiveRefresh = function () {
			window.clearTimeout(liveTimer);
			liveTimer = window.setTimeout(refreshLiveStoreData, 5000);
		};
		const refreshLiveStoreData = async function () {
			if (document.visibilityState !== 'visible' || !window.navigator.onLine) {
				scheduleLiveRefresh();
				return;
			}
			const active = document.activeElement;
			if (
				active &&
				/^(INPUT|SELECT|TEXTAREA)$/.test(active.tagName) &&
				!liveStoreRegions.some(function (region) { return region.contains(active); })
			) {
				scheduleLiveRefresh();
				return;
			}
			liveRequest = new AbortController();
			const timeout = window.setTimeout(function () { liveRequest.abort(); }, 12000);
			try {
				const url = new URL(window.location.href);
				url.searchParams.set('kidia_live', String(Date.now()));
				const response = await fetch(url.toString(), {
					credentials: 'same-origin',
					cache: 'no-store',
					headers: {'X-Kidia-Live-Data': '1'},
					signal: liveRequest.signal
				});
				if (!response.ok) throw new Error('Live Store Data request failed');
				const page = new DOMParser().parseFromString(await response.text(), 'text/html');
				const freshRegions = Array.from(page.querySelectorAll('[data-kidia-live-store-data]'));
				liveStoreRegions.forEach(function (region) {
					const key = region.dataset.kidiaLiveStoreData;
					const fresh = freshRegions.find(function (candidate) {
						return candidate.dataset.kidiaLiveStoreData === key;
					});
					if (!fresh || fresh.innerHTML === region.innerHTML) return;

					const selectedCartIds = Array.from(
						region.querySelectorAll('input[name="cart_ids[]"]:checked')
					).map(function (input) { return input.value; });
					region.innerHTML = fresh.innerHTML;
					selectedCartIds.forEach(function (cartId) {
						const checkbox = Array.from(
							region.querySelectorAll('input[name="cart_ids[]"]')
						).find(function (input) { return input.value === cartId; });
						if (checkbox && !checkbox.disabled) checkbox.checked = true;
					});
				});
			} catch (_error) {
				// Keep the last verified values and retry without blanking the report.
			} finally {
				window.clearTimeout(timeout);
				liveRequest = null;
				scheduleLiveRefresh();
			}
		};
		document.addEventListener('visibilitychange', function () {
			if (document.visibilityState === 'visible') {
				window.clearTimeout(liveTimer);
				void refreshLiveStoreData();
			}
		});
		window.addEventListener('online', function () {
			window.clearTimeout(liveTimer);
			void refreshLiveStoreData();
		});
		scheduleLiveRefresh();
	}
	document.addEventListener('click', function (event) {
		const button = event.target.closest('[data-copy-link],[data-copy-text]');
		if (!button) return;
		const value = button.dataset.copyLink || button.dataset.copyText || '';
		if (!value || !navigator.clipboard) return;
		const original = button.textContent;
		navigator.clipboard.writeText(value).then(function () {
			button.textContent = 'Copied';
			window.setTimeout(function () { button.textContent = original; }, 1400);
		});
	});
	document.querySelectorAll('.wrap > .notice-success').forEach(function (notice) {
		notice.classList.add('kidia-global-save-toast');
		window.setTimeout(function () { notice.classList.add('is-leaving'); }, 2600);
		window.setTimeout(function () { notice.remove(); }, 3100);
	});

})();
