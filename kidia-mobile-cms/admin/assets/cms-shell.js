(function () {
	'use strict';
	document.documentElement.classList.add('kidia-cms-js');
	const shell = document.querySelector('.kidia-cms-shell');
	const completedNoticeStorageKey = 'kidiaCompletedBackgroundJobNotices';
	const backgroundJobStackPositionKey = 'kidiaBackgroundJobStackPositionV1';
	const backgroundJobStackSafeInset = 8;

	function backgroundJobStack() {
		return document.querySelector('[data-kidia-background-job-stack]');
	}

	function backgroundJobStackBounds(stack) {
		const rect = stack.getBoundingClientRect();
		return {
			left: Number.isFinite(Number(rect.left)) ? Number(rect.left) : backgroundJobStackSafeInset,
			top: Number.isFinite(Number(rect.top)) ? Number(rect.top) : backgroundJobStackSafeInset,
			width: Math.max(1, Number(rect.width) || stack.offsetWidth || 380),
			height: Math.max(1, Number(rect.height) || stack.offsetHeight || 1)
		};
	}

	function positionBackgroundJobStack(stack, left, top, remember) {
		if (!stack) return;
		const bounds = backgroundJobStackBounds(stack);
		const viewportWidth = Math.max(
			bounds.width + (backgroundJobStackSafeInset * 2),
			Number(window.innerWidth) || document.documentElement.clientWidth || 0
		);
		const viewportHeight = Math.max(
			bounds.height + (backgroundJobStackSafeInset * 2),
			Number(window.innerHeight) || document.documentElement.clientHeight || 0
		);
		const maxLeft = Math.max(backgroundJobStackSafeInset, viewportWidth - bounds.width - backgroundJobStackSafeInset);
		const maxTop = Math.max(backgroundJobStackSafeInset, viewportHeight - bounds.height - backgroundJobStackSafeInset);
		const safeLeft = Math.max(backgroundJobStackSafeInset, Math.min(maxLeft, Number(left) || backgroundJobStackSafeInset));
		const safeTop = Math.max(backgroundJobStackSafeInset, Math.min(maxTop, Number(top) || backgroundJobStackSafeInset));

		stack.style.left = safeLeft + 'px';
		stack.style.top = safeTop + 'px';
		stack.style.right = 'auto';
		stack.style.bottom = 'auto';
		stack.dataset.kidiaStackPositioned = '1';

		if (remember) {
			try {
				window.localStorage.setItem(backgroundJobStackPositionKey, JSON.stringify({
					left: Math.round(safeLeft),
					top: Math.round(safeTop)
				}));
			} catch (_error) {}
		}
	}

	function restoreBackgroundJobStackPosition(stack) {
		if (!stack || stack.dataset.kidiaStackPositioned === '1') return;
		try {
			const saved = JSON.parse(window.localStorage.getItem(backgroundJobStackPositionKey) || 'null');
			if (saved && Number.isFinite(Number(saved.left)) && Number.isFinite(Number(saved.top))) {
				positionBackgroundJobStack(stack, saved.left, saved.top, false);
			}
		} catch (_error) {
			try { window.localStorage.removeItem(backgroundJobStackPositionKey); } catch (_storageError) {}
		}
	}

	function keepBackgroundJobStackOnScreen(stack) {
		if (!stack || stack.dataset.kidiaStackPositioned !== '1') return;
		const bounds = backgroundJobStackBounds(stack);
		positionBackgroundJobStack(stack, bounds.left, bounds.top, false);
	}

	function bindBackgroundJobStackDrag(stack) {
		if (!stack || stack.dataset.kidiaStackDragBound === '1') return;
		stack.dataset.kidiaStackDragBound = '1';
		restoreBackgroundJobStackPosition(stack);

		stack.addEventListener('pointerdown', function (event) {
			const eventTarget = event.target && typeof event.target.closest === 'function' ? event.target : null;
			const card = eventTarget ? eventTarget.closest('[data-kidia-background-job]') : null;
			if (
				!card ||
				!stack.contains(card) ||
				stack.classList.contains('is-dragging') ||
				(event.button !== undefined && event.button !== 0) ||
				eventTarget.closest('button,a,input,select,textarea,label,[contenteditable="true"]')
			) return;

			const start = backgroundJobStackBounds(stack);
			const startX = Number(event.clientX) || 0;
			const startY = Number(event.clientY) || 0;
			const offsetX = startX - start.left;
			const offsetY = startY - start.top;
			const pointerId = event.pointerId;
			let moved = false;

			const move = function (moveEvent) {
				if (pointerId !== undefined && moveEvent.pointerId !== undefined && moveEvent.pointerId !== pointerId) return;
				const nextX = Number(moveEvent.clientX) || 0;
				const nextY = Number(moveEvent.clientY) || 0;
				if (!moved && Math.hypot(nextX - startX, nextY - startY) < 4) return;
				moved = true;
				stack.classList.add('is-dragging');
				moveEvent.preventDefault();
				positionBackgroundJobStack(stack, nextX - offsetX, nextY - offsetY, false);
			};

			const stop = function (stopEvent) {
				if (pointerId !== undefined && stopEvent.pointerId !== undefined && stopEvent.pointerId !== pointerId) return;
				window.removeEventListener('pointermove', move);
				window.removeEventListener('pointerup', stop);
				window.removeEventListener('pointercancel', stop);
				window.removeEventListener('blur', stop);
				if (!moved) return;
				stack.classList.remove('is-dragging');
				const current = backgroundJobStackBounds(stack);
				positionBackgroundJobStack(stack, current.left, current.top, true);
				stack.dataset.kidiaSuppressDragClick = '1';
				window.setTimeout(function () { delete stack.dataset.kidiaSuppressDragClick; }, 0);
			};

			window.addEventListener('pointermove', move, { passive: false });
			window.addEventListener('pointerup', stop);
			window.addEventListener('pointercancel', stop);
			window.addEventListener('blur', stop);
		});

		stack.addEventListener('click', function (event) {
			if (stack.dataset.kidiaSuppressDragClick !== '1') return;
			const eventTarget = event.target && typeof event.target.closest === 'function' ? event.target : null;
			if (!eventTarget || !eventTarget.closest('[data-kidia-background-job]')) return;
			event.preventDefault();
			event.stopPropagation();
		}, true);

		if (typeof window.ResizeObserver === 'function') {
			const observer = new window.ResizeObserver(function () {
				keepBackgroundJobStackOnScreen(stack);
			});
			observer.observe(stack);
			stack.kidiaBackgroundJobResizeObserver = observer;
		}
	}

	function appendBackgroundJobCard(card) {
		const stack = backgroundJobStack();
		if (!card) return card;
		if (!stack) {
			document.body.appendChild(card);
			return card;
		}
		bindBackgroundJobStackDrag(stack);
		const job = String(card.dataset.kidiaBackgroundJob || '');
		const existing = job
			? Array.from(stack.querySelectorAll('[data-kidia-background-job]')).find(function (candidate) {
				return candidate !== card && String(candidate.dataset.kidiaBackgroundJob || '') === job;
			})
			: null;
		if (existing) {
			card.remove();
			return existing;
		}
		stack.appendChild(card);
		initCompletedBackgroundJobNotices(card);
		keepBackgroundJobStackOnScreen(stack);
		return card;
	}

	bindBackgroundJobStackDrag(backgroundJobStack());
	window.addEventListener('resize', function () {
		keepBackgroundJobStackOnScreen(backgroundJobStack());
	});

	function completedNoticeKeys() {
		try {
			const saved = JSON.parse(window.localStorage.getItem(completedNoticeStorageKey) || '[]');
			return Array.isArray(saved) ? saved.filter(function (key) { return typeof key === 'string'; }) : [];
		} catch (_error) {
			return [];
		}
	}

	function rememberCompletedNotice(key) {
		if (!key) return;
		try {
			const saved = completedNoticeKeys().filter(function (candidate) { return candidate !== key; });
			saved.push(key);
			window.localStorage.setItem(completedNoticeStorageKey, JSON.stringify(saved.slice(-20)));
		} catch (_error) {}
	}

	function completedNoticeKey(card) {
		const job = String(card.dataset.kidiaBackgroundJob || 'background-job');
		const completion = String(card.dataset.completionKey || '');
		return completion ? job + ':' + completion : '';
	}

	function dismissCompletedNotice(card, key) {
		if (!card || !card.isConnected || card.dataset.completeDismissed === '1') return;
		card.dataset.completeDismissed = '1';
		card.classList.add('is-leaving');
		rememberCompletedNotice(key);
		window.setTimeout(function () { card.remove(); }, 350);
	}

	function initCompletedBackgroundJobNotices(root) {
		const cards = root && root.matches && root.matches('[data-complete-auto-dismiss]')
			? [root]
			: Array.from((root || document).querySelectorAll('[data-complete-auto-dismiss]'));
		cards.forEach(function (card) {
			if (card.dataset.completeDismissBound === '1') return;
			card.dataset.completeDismissBound = '1';
			const key = completedNoticeKey(card);
			if (key && completedNoticeKeys().includes(key)) {
				card.remove();
				return;
			}
			const delay = Math.max(1000, Number(card.dataset.completeAutoDismiss || 5000));
			window.setTimeout(function () { dismissCompletedNotice(card, key); }, delay);
		});
	}

	initCompletedBackgroundJobNotices(document);
	document.addEventListener('kidia:cms-page-ready', function () {
		initCompletedBackgroundJobNotices(document);
	});

	function resetDocumentScroll() {
		if ('scrollRestoration' in history) {
			history.scrollRestoration = 'manual';
		}
		const documentScroll = document.scrollingElement || document.documentElement;
		documentScroll.scrollTop = 0;
		documentScroll.scrollLeft = 0;
		document.body.scrollTop = 0;
		document.body.scrollLeft = 0;
		if (window.scrollX !== 0 || window.scrollY !== 0) {
			window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
		}
	}

	function resetWorkspaceScroll() {
		resetDocumentScroll();
		const workspace = document.querySelector('#wpbody');
		if (!workspace) return;
		workspace.scrollTop = 0;
		workspace.scrollLeft = 0;
	}

	function syncBuilderScreen(enabled) {
		const active = Boolean(enabled);
		document.body.classList.toggle('kidia-cms-builder-screen', active);
		document.documentElement.classList.toggle('kidia-cms-builder-screen', active);
		resetDocumentScroll();
	}

	syncBuilderScreen(document.body.classList.contains('kidia-cms-builder-screen'));
	window.addEventListener('pageshow', resetDocumentScroll);

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
			'kidia-mobile-bundles': 'bundles',
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
		const pluginAsset = function (asset) {
			if (/^kidia-mobile(?:-|$)/.test(String(asset.handle || ''))) {
				return true;
			}
			try {
				return new URL(asset.src, window.location.href).pathname.indexOf('/plugins/kidia-mobile-cms/') !== -1;
			} catch (_error) {
				return false;
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
			const compatible = byHandle || samePath[0] || null;
			const conflict = pluginAsset(asset)
				? [byHandle].concat(samePath).filter(Boolean).find(function (node) {
					return absoluteAssetUrl(node[urlProperty]) !== expectedUrl;
				})
				: null;
			return {
				exact: exact || (!pluginAsset(asset) ? compatible : null),
				conflict: conflict || null
			};
		};
		const hardNavigate = function (url) {
			viewCache.clear();
			if (typeof window.kidiaCmsHardNavigate === 'function') {
				window.kidiaCmsHardNavigate(url);
				return;
			}
			window.location.href = url;
		};
		const waitForAsset = function (node, parent) {
			return new Promise(function (resolve) {
				let timer = 0;
				let settled = false;
				const finish = function () {
					if (settled) return;
					settled = true;
					if (timer) window.clearTimeout(timer);
					resolve();
				};
				node.addEventListener('load', finish, { once: true });
				node.addEventListener('error', finish, { once: true });
				parent.appendChild(node);
				/* A blocked optional asset must never leave navigation waiting forever. */
				timer = window.setTimeout(finish, 8000);
			});
		};
		const assetsCompatible = function (payload) {
			return (payload.styles || []).every(function (asset) {
				return !findLoadedAsset(asset, 'css').conflict;
			}) && (payload.scripts || []).every(function (asset) {
				return !findLoadedAsset(asset, 'js').conflict;
			});
		};
		const loadStyles = async function (payload) {
			const pending = [];
			for (const asset of (payload.styles || [])) {
				const loaded = findLoadedAsset(asset, 'css');
				if (loaded.exact) continue;
				const link = document.createElement('link');
				link.id = asset.handle + '-css';
				link.rel = 'stylesheet';
				link.href = asset.src;
				pending.push(waitForAsset(link, document.head));
			}
			await Promise.all(pending);
		};
		const loadScripts = async function (payload) {
			let loadedNewScript = false;
			for (const asset of (payload.scripts || [])) {
				const loaded = findLoadedAsset(asset, 'js');
				if (loaded.exact) continue;
				(asset.before || []).forEach(appendInline);
				const script = document.createElement('script');
				script.id = asset.handle + '-js';
				script.src = asset.src;
				await waitForAsset(script, document.body);
				(asset.after || []).forEach(appendInline);
				loadedNewScript = true;
			}
			return loadedNewScript;
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
		const persistentShellNode = function (node, sidebar, shell) {
			return node === sidebar ||
				node === shell ||
				(node.nodeType === 1 && (
					node.matches('[data-kidia-background-job-stack]') ||
					node.matches('[data-kidia-background-job]') ||
					node.matches('.kidia-ai-progress-overlay.is-global')
				));
		};
		const promoteBackgroundJobCards = function (content) {
			Array.from(content.querySelectorAll('[data-kidia-background-job]')).forEach(function (card) {
				if (card.closest('[data-kidia-background-job-stack]')) return;
				appendBackgroundJobCard(card);
			});
		};
		const loadPage = async function (url, pushState, navigationOptions) {
			const sidebar = document.querySelector('[data-kidia-cms-sidebar]');
			const shell = document.querySelector('[data-kidia-cms-shell]');
			const currentContent = document.querySelector('#wpbody-content');
			if (!sidebar || !shell || !currentContent) {
				return;
			}
			const options = navigationOptions || {};
			const cacheKey = keyFor(url);
			const targetUrl = new URL(cacheKey, window.location.href);
			const isStoreDataView = targetUrl.searchParams.get('view') === 'store-data';
			const canUseCache = !isStoreDataView && !options.fresh;
			const workspace = document.querySelector('#wpbody');
			const scrollState = options.preserveScroll && workspace
				? { top: workspace.scrollTop, left: workspace.scrollLeft }
				: null;
			const activeElement = document.activeElement;
			const focusState = options.preserveFocus && activeElement && currentContent.contains(activeElement) && activeElement.name
				? {
					name: activeElement.name,
					start: typeof activeElement.selectionStart === 'number' ? activeElement.selectionStart : null,
					end: typeof activeElement.selectionEnd === 'number' ? activeElement.selectionEnd : null
				}
				: null;
			if (window.kidiaCmsNavigationController) window.kidiaCmsNavigationController.abort();
			const controller = new AbortController();
			window.kidiaCmsNavigationController = controller;
			try {
				let payload;
				if (canUseCache && viewCache.has(cacheKey)) {
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
					if (!assetsCompatible(payload)) {
						hardNavigate(cacheKey);
						return;
					}
				}
				if (!assetsCompatible(payload)) {
					hardNavigate(cacheKey);
					return;
				}
				const stylesReady = loadStyles(payload);
				if (canUseCache && !viewCache.has(cacheKey)) viewCache.set(cacheKey, payload);
				syncBuilderScreen(payload.builderScreen);
				updateNavigation(payload);
				document.dispatchEvent(new CustomEvent('kidia:cms-before-page-change', {
					detail: { url: cacheKey }
				}));
				promoteBackgroundJobCards(currentContent);
				Array.from(currentContent.childNodes).forEach(function (node) {
					if (!persistentShellNode(node, sidebar, shell)) node.remove();
				});
				payload.nodes.forEach(function (node) { currentContent.appendChild(node); });
				if (scrollState && workspace) {
					resetDocumentScroll();
					workspace.scrollTop = scrollState.top;
					workspace.scrollLeft = scrollState.left;
				} else {
					resetWorkspaceScroll();
				}
				if (pushState) {
					if (options.replaceState) {
						history.replaceState({ kidiaCmsPage: true }, '', cacheKey);
					} else {
						history.pushState({ kidiaCmsPage: true }, '', cacheKey);
					}
				}
				if (focusState) {
					const matchingField = Array.from(currentContent.querySelectorAll('[name]')).find(function (field) {
						return field.name === focusState.name;
					});
					if (matchingField) {
						matchingField.focus({ preventScroll: true });
						if (focusState.start !== null && typeof matchingField.setSelectionRange === 'function') {
							matchingField.setSelectionRange(focusState.start, focusState.end);
						}
					}
				}
				/* Display the requested view before Media and Builder JavaScript finish.
				 * Page scripts now execute against markup that already exists instead of
				 * holding the old page on screen until every asset has downloaded. */
				const assetResults = await Promise.all([loadScripts(payload), stylesReady]);
				const loadedNewScript = assetResults[0];
				if (controller.signal.aborted) return;
				if (loadedNewScript) {
					document.dispatchEvent(new Event('DOMContentLoaded'));
				}
				document.dispatchEvent(new CustomEvent('kidia:cms-page-ready', { detail: { url: window.location.href } }));
			} catch (error) {
				if (error.name === 'AbortError') return;
				const message = document.createElement('div');
				message.className = 'notice notice-error kidia-cms-navigation-error';
				message.setAttribute('role', 'alert');
				message.textContent = 'The requested Woo Mobile CMS view could not be loaded. Please try again.';
				Array.from(currentContent.childNodes).forEach(function (node) {
					if (!persistentShellNode(node, sidebar, shell)) node.remove();
				});
				currentContent.appendChild(message);
			} finally {
				currentContent.classList.remove('is-kidia-page-loading');
			}
		};
		window.kidiaCmsNavigate = function (url, options) {
			const navigationOptions = options || {};
			return loadPage(url, navigationOptions.pushState !== false, navigationOptions);
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
	const initCustomDateFilters = function (root) {
		(root || document).querySelectorAll('.kidia-date-filter').forEach(function (filter) {
			const datePreset = filter.querySelector('select[name="date_preset"]');
			if (!datePreset) return;
			const customDates = filter.querySelectorAll('input[type="date"]');
			const syncCustomDates = function () {
				const enabled = datePreset.value === 'custom';
				customDates.forEach(function (input) { input.disabled = !enabled; });
			};
			if (datePreset.dataset.kidiaCustomDatesBound !== '1') {
				datePreset.dataset.kidiaCustomDatesBound = '1';
				datePreset.addEventListener('change', syncCustomDates);
			}
			syncCustomDates();
		});
	};
	initCustomDateFilters(document);
	document.addEventListener('kidia:cms-page-ready', function () {
		initCustomDateFilters(document);
	});
	const instantFilterTimers = new WeakMap();
	const storeDataUrlFromForm = function (form) {
		const url = new URL(form.getAttribute('action') || window.location.href, window.location.href);
		url.search = '';
		new FormData(form).forEach(function (value, key) {
			if (typeof value === 'string') url.searchParams.append(key, value);
		});
		return url.href;
	};
	const navigateFreshStoreData = function (url, options) {
		if (typeof window.kidiaCmsNavigate === 'function') {
			return window.kidiaCmsNavigate(url, Object.assign({
				fresh: true,
				replaceState: true,
				preserveScroll: true
			}, options || {}));
		}
		window.location.href = url;
		return Promise.resolve();
	};
	const customDateRangeReady = function (form) {
		const preset = form.querySelector('select[name="date_preset"]');
		if (!preset || preset.value !== 'custom') return true;
		const from = form.querySelector('input[name="date_from"]');
		const to = form.querySelector('input[name="date_to"]');
		return Boolean(from && to && from.value && to.value && from.value <= to.value);
	};
	const applyInstantFilter = function (form, trigger) {
		const pending = instantFilterTimers.get(form);
		if (pending) window.clearTimeout(pending);
		instantFilterTimers.delete(form);
		if (!customDateRangeReady(form)) return Promise.resolve();
		form.classList.add('is-kidia-loading');
		form.setAttribute('aria-busy', 'true');
		const preserveFocus = Boolean(trigger && trigger.matches && trigger.matches('input[type="search"]'));
		return Promise.resolve(navigateFreshStoreData(storeDataUrlFromForm(form), {
			preserveFocus: preserveFocus
		})).finally(function () {
			if (!form.isConnected) return;
			form.classList.remove('is-kidia-loading');
			form.removeAttribute('aria-busy');
		});
	};
	const scheduleInstantFilter = function (form, trigger, delay) {
		const pending = instantFilterTimers.get(form);
		if (pending) window.clearTimeout(pending);
		const timer = window.setTimeout(function () {
			instantFilterTimers.delete(form);
			void applyInstantFilter(form, trigger);
		}, delay);
		instantFilterTimers.set(form, timer);
	};
	document.addEventListener('input', function (event) {
		const search = event.target.closest('form[data-kidia-instant-filter] input[type="search"]');
		if (!search) return;
		scheduleInstantFilter(search.form, search, 350);
	});
	document.addEventListener('change', function (event) {
		const field = event.target.closest('form[data-kidia-instant-filter] select, form[data-kidia-instant-filter] input[type="date"]');
		if (!field) return;
		scheduleInstantFilter(field.form, field, 0);
	});
	document.addEventListener('submit', function (event) {
		const form = event.target.closest('form[data-kidia-instant-filter]');
		if (!form) return;
		event.preventDefault();
		void applyInstantFilter(form, document.activeElement);
	});
	const setInstantActionBusy = function (form, busy) {
		form.classList.toggle('is-kidia-loading', busy);
		if (busy) {
			form.setAttribute('aria-busy', 'true');
		} else {
			form.removeAttribute('aria-busy');
		}
		form.querySelectorAll('button,select').forEach(function (control) {
			if (busy) {
				control.dataset.kidiaWasDisabled = control.disabled ? '1' : '0';
				control.disabled = true;
			} else if (control.dataset.kidiaWasDisabled !== '1') {
				control.disabled = false;
			}
			if (!busy) delete control.dataset.kidiaWasDisabled;
		});
	};
	document.addEventListener('change', function (event) {
		const channel = event.target.closest('form[data-kidia-instant-action="coupon-channel"] select[name="coupon_channel"]');
		if (!channel || !channel.form || channel.form.getAttribute('aria-busy') === 'true') return;
		if (typeof channel.form.requestSubmit === 'function') {
			channel.form.requestSubmit();
		} else {
			channel.form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
		}
	});
	document.addEventListener('submit', async function (event) {
		const form = event.target.closest('form[data-kidia-instant-action]');
		if (!form) return;
		event.preventDefault();
		if (form.getAttribute('aria-busy') === 'true') return;
		const requestBody = new FormData(form);
		const channel = form.querySelector('select[name="coupon_channel"]');
		setInstantActionBusy(form, true);
		try {
			const response = await window.fetch(form.action, {
				method: String(form.method || 'post').toUpperCase(),
				credentials: 'same-origin',
				cache: 'no-store',
				body: requestBody
			});
			if (!response.ok) throw new Error('Store Data update failed');
			await navigateFreshStoreData(window.location.href, { preserveFocus: false });
		} catch (_error) {
			if (channel && channel.dataset.kidiaSavedValue) {
				channel.value = channel.dataset.kidiaSavedValue;
			}
			form.classList.add('is-kidia-error');
			window.setTimeout(function () { form.classList.remove('is-kidia-error'); }, 1800);
		} finally {
			if (form.isConnected) setInstantActionBusy(form, false);
		}
	});
	const aiBackgroundConfig = window.kidiaCMSBackground || {};
	const aiDockPositionKey = 'kidia_ai_progress_position_v1';
	const aiRequest = async function (action, values) {
		const currentAiForm = document.querySelector('[data-ai-generate-form]');
		const nonce = currentAiForm
			? currentAiForm.dataset.aiAnalysisNonce || ''
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
		const current = document.querySelector('[data-ai-progress-overlay].is-global');
		if (current) return current;
		const dock = document.createElement('div');
		dock.className = 'kidia-ai-progress-overlay is-docked is-global';
		dock.dataset.aiProgressOverlay = '';
		dock.dataset.kidiaBackgroundJob = 'generate-offers';
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
		return appendBackgroundJobCard(dock);
	};
	const resetAiProgressVersion = function (overlay, jobId) {
		if (!overlay) return;
		overlay.dataset.aiProgressJob = String(jobId || '');
		overlay.dataset.aiProgressRevision = '-1';
		overlay.dataset.aiProgressProcessed = '-1';
	};
	const positionAiDock = function (overlay, left, top, remember) {
		if (!overlay || !overlay.classList.contains('is-docked')) return;
		if (overlay.closest('[data-kidia-background-job-stack]')) {
			overlay.style.removeProperty('left');
			overlay.style.removeProperty('top');
			overlay.style.removeProperty('right');
			overlay.style.removeProperty('bottom');
			return;
		}
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
				overlay.closest('[data-kidia-background-job-stack]') ||
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
			overlay.hidden
		) return false;
		overlay.dataset.kidiaBackgroundJob = 'generate-offers';
		overlay.classList.add('is-docked', 'is-global');
		overlay = appendBackgroundJobCard(overlay);
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
		if (cancel) cancel.classList.toggle('is-confirm', Boolean(payload.done));
		if (payload.cancelled) {
			overlay.setAttribute('aria-busy', 'false');
			overlay.hidden = true;
			document.body.classList.remove('kidia-ai-is-generating');
			return;
		}
		if (payload.done) {
			overlay.setAttribute('aria-busy', 'false');
			if (stage) stage.textContent = 'Completed';
			if (view) view.hidden = true;
			if (background) background.hidden = true;
			if (cancel) cancel.innerHTML = '<span class="dashicons dashicons-yes-alt"></span>OK';
			overlay.dataset.aiComplete = '1';
		}
	};
	if (window.__KIDIA_AI_PROGRESS_TEST__) {
		window.KidiaAiProgressTest = {
			createDock: createAiDock,
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
	let activeJobId = String(aiBackgroundConfig.activeAiJob || '');
	let foreground = true;
	let overlay = document.querySelector('[data-ai-progress-overlay]');
	if (overlay) {
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
	}
	document.addEventListener('submit', async function (event) {
		const aiGenerateForm = event.target.closest('[data-ai-generate-form]');
		if (!aiGenerateForm) return;
			event.preventDefault();
			overlay = aiGenerateForm.nextElementSibling && aiGenerateForm.nextElementSibling.matches('[data-ai-progress-overlay]')
				? aiGenerateForm.nextElementSibling
				: document.querySelector('[data-ai-progress-overlay]:not(.is-global)');
			bindAiOverlayActions(overlay, function () { return activeJobId; }, function (value) { foreground = value; });
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
				const cancelButton = overlay.querySelector('[data-ai-cancel-button]');
				if (cancelButton) {
					cancelButton.classList.remove('is-confirm');
					cancelButton.disabled = false;
					cancelButton.innerHTML = '<span class="dashicons dashicons-no-alt"></span>Cancel analysis';
				}
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
				persistAiProgressAcrossNavigation(overlay, activeJobId);
				button.disabled = false;
				button.classList.remove('is-generating');
				if (label) label.textContent = 'Refresh offers from store data';
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
	const syncRecoveryControls = function (root) {
		const recoveryDelivery = (root || document).querySelector('[data-recovery-delivery]');
		const recoverySchedule = (root || document).querySelector('[data-recovery-schedule]');
		if (recoveryDelivery && recoverySchedule) recoverySchedule.hidden = recoveryDelivery.value !== 'scheduled';
		const recoveryActionStyle = (root || document).querySelector('[data-recovery-action-style]');
		const recoveryButtonLabel = (root || document).querySelector('[data-recovery-button-label]');
		if (recoveryActionStyle && recoveryButtonLabel) recoveryButtonLabel.hidden = recoveryActionStyle.value !== 'button';
	};
	syncRecoveryControls(document);
	document.addEventListener('kidia:cms-page-ready', function () { syncRecoveryControls(document); });
	document.addEventListener('change', function (event) {
		if (event.target.matches('[data-recovery-delivery],[data-recovery-action-style]')) {
			syncRecoveryControls(document);
			return;
		}
		const selectAllCarts = event.target.closest('[data-select-all-carts]');
		if (selectAllCarts) {
			document.querySelectorAll('input[name="cart_ids[]"]:not(:disabled)').forEach(function (input) {
				input.checked = selectAllCarts.checked;
			});
			return;
		}
		const cartPerPage = event.target.closest('[data-cart-per-page]');
		if (cartPerPage) {
			const url = new URL(window.location.href);
			url.searchParams.set('cart_per_page', cartPerPage.value);
			url.searchParams.set('cart_page', '1');
			void navigateFreshStoreData(url.toString(), { preserveFocus: false });
		}
	});
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
			const customer = insight.customer || {};
			const items = Array.isArray(cart.items) ? cart.items : [];
			const itemHtml = items.length
				? '<ul>' + items.map(function (item) {
					return '<li><strong>' + escapeHtml(item.name || 'Product') + '</strong><span>× ' + escapeHtml(item.quantity || 1) + '</span></li>';
				}).join('') + '</ul>'
				: '<p>No cart items are available.</p>';
			const historyHtml = orders.length
				? '<ul>' + orders.map(function (order) {
					const openOrder = order.edit_url
						? '<a class="button kidia-open-order-button" href="' + escapeHtml(order.edit_url) + '" target="_blank" rel="noopener">Open order</a>'
						: '';
					return '<li><strong>#' + escapeHtml(order.id) + '</strong><span>' + escapeHtml(order.date) + '</span><em>' + escapeHtml(order.status) + ' · ' + escapeHtml(order.total) + ' ' + escapeHtml(order.currency) + '</em>' + openOrder + '</li>';
				}).join('') + '</ul>'
				: '<p>No previous orders were found for this customer.</p>';
			const alternativeHtml = alternative
				? '<div class="kidia-cart-alternative-order"><strong>#' + escapeHtml(alternative.id) + '</strong><span>' + escapeHtml(alternative.date) + '</span><em>' + escapeHtml(alternative.total) + ' ' + escapeHtml(alternative.currency) + '</em>' + (alternative.edit_url ? '<a class="button kidia-open-order-button" href="' + escapeHtml(alternative.edit_url) + '" target="_blank" rel="noopener">Open order</a>' : '') + '</div>'
				: '<p>No order was placed within 10 days before or after this cart.</p>';
			const customerPhones = Array.isArray(customer.phones) ? customer.phones : [];
			const customerHtml =
				'<dl class="kidia-customer-summary">' +
					'<div><dt>Name</dt><dd>' + escapeHtml(customer.name || cart.customer_name || '—') + '</dd></div>' +
					'<div><dt>Phone</dt><dd>' + escapeHtml(customerPhones.length ? customerPhones.join(' / ') : '—') + '</dd></div>' +
					'<div><dt>Province</dt><dd>' + escapeHtml(customer.province || '—') + '</dd></div>' +
				'</dl>';
			content.innerHTML =
				'<section><h4>1. Cart order</h4>' + itemHtml + '</section>' +
				'<section><h4>2. Customer order history</h4>' + historyHtml + '</section>' +
				'<div class="kidia-cart-details-stack">' +
					'<section><h4>3. Possible alternative order <small>±10 days</small></h4>' + alternativeHtml + '</section>' +
					'<section><h4>Customer details</h4>' + customerHtml + '</section>' +
				'</div>';
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
	let liveStoreSession = null;
	const stopLiveStoreData = function () {
		if (!liveStoreSession) return;
		liveStoreSession.stop();
		liveStoreSession = null;
	};
	const initLiveStoreData = function (root) {
		stopLiveStoreData();
		const liveStoreRegions = Array.from((root || document).querySelectorAll('[data-kidia-live-store-data]'));
		if (!liveStoreRegions.length) return;
		let liveTimer = 0;
		let liveRequest = null;
		let stopped = false;
		const scheduleLiveRefresh = function () {
			if (stopped) return;
			window.clearTimeout(liveTimer);
			liveTimer = window.setTimeout(refreshLiveStoreData, 5000);
		};
		const refreshLiveStoreData = async function () {
			if (stopped) return;
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
			const controller = new AbortController();
			liveRequest = controller;
			const timeout = window.setTimeout(function () { controller.abort(); }, 12000);
			try {
				const url = new URL(window.location.href);
				url.searchParams.set('kidia_live', String(Date.now()));
				const response = await fetch(url.toString(), {
					credentials: 'same-origin',
					cache: 'no-store',
					headers: {'X-Kidia-Live-Data': '1'},
					signal: controller.signal
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
					const expandedCartDetails = Array.from(
						region.querySelectorAll('[data-abandoned-cart-details][aria-expanded="true"]')
					).map(function (button) {
						const cartId = String(button.dataset.abandonedCartDetails || '');
						const detailsRow = region.querySelector('[data-abandoned-cart-details-row="' + CSS.escape(cartId) + '"]');
						const detailsContent = detailsRow ? detailsRow.querySelector('.kidia-cart-details-content') : null;
						return {
							cartId: cartId,
							html: detailsContent ? detailsContent.innerHTML : '',
							loaded: detailsContent ? detailsContent.dataset.loaded : '',
							loading: detailsContent ? detailsContent.dataset.loading : ''
						};
					});
					region.innerHTML = fresh.innerHTML;
					selectedCartIds.forEach(function (cartId) {
						const checkbox = Array.from(
							region.querySelectorAll('input[name="cart_ids[]"]')
						).find(function (input) { return input.value === cartId; });
						if (checkbox && !checkbox.disabled) checkbox.checked = true;
					});
					expandedCartDetails.forEach(function (details) {
						const button = region.querySelector('[data-abandoned-cart-details="' + CSS.escape(details.cartId) + '"]');
						const detailsRow = region.querySelector('[data-abandoned-cart-details-row="' + CSS.escape(details.cartId) + '"]');
						const detailsContent = detailsRow ? detailsRow.querySelector('.kidia-cart-details-content') : null;
						if (!button || !detailsRow || !detailsContent) return;
						button.setAttribute('aria-expanded', 'true');
						detailsRow.hidden = false;
						detailsContent.innerHTML = details.html;
						if (details.loaded) detailsContent.dataset.loaded = details.loaded;
						if (details.loading) detailsContent.dataset.loading = details.loading;
					});
				});
			} catch (_error) {
				// Keep the last verified values and retry without blanking the report.
			} finally {
				window.clearTimeout(timeout);
				if (liveRequest === controller) {
					liveRequest = null;
					scheduleLiveRefresh();
				}
			}
		};
		liveStoreSession = {
			refresh: function () {
				window.clearTimeout(liveTimer);
				if (liveRequest) liveRequest.abort();
				void refreshLiveStoreData();
			},
			stop: function () {
				stopped = true;
				window.clearTimeout(liveTimer);
				if (liveRequest) liveRequest.abort();
			}
		};
		scheduleLiveRefresh();
	};
	document.addEventListener('kidia:cms-before-page-change', stopLiveStoreData);
	document.addEventListener('kidia:cms-page-ready', function () { initLiveStoreData(document); });
	document.addEventListener('visibilitychange', function () {
		if (document.visibilityState === 'visible' && liveStoreSession) liveStoreSession.refresh();
	});
	window.addEventListener('online', function () {
		if (liveStoreSession) liveStoreSession.refresh();
	});
	initLiveStoreData(document);
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
