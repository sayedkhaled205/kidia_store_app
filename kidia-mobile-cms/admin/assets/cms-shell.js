(function () {
	'use strict';
	const shell = document.querySelector('.kidia-cms-shell');
	const fixedBuilder = document.body.classList.contains('kidia-cms-builder-screen');

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

	if (fixedBuilder) {
		if ('scrollRestoration' in history) {
			history.scrollRestoration = 'manual';
		}
		window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
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
	if (pushDelivery) {
		const syncDelivery = function () {
			if (pushSchedule) pushSchedule.hidden = pushDelivery.value !== 'scheduled';
			if (pushAutomation) pushAutomation.hidden = pushDelivery.value !== 'automation';
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
	const pushProvider = document.querySelector('[data-push-provider]');
	if (pushProvider) {
		const syncPushProvider = function () {
			document.querySelectorAll('[data-provider-fields]').forEach(function (field) {
				field.hidden = field.dataset.providerFields !== pushProvider.value;
			});
		};
		pushProvider.addEventListener('change', syncPushProvider);
		syncPushProvider();
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
	if (aiGenerateForm) {
		aiGenerateForm.addEventListener('submit', function () {
			const button = aiGenerateForm.querySelector('[data-ai-generate-button]');
			const label = aiGenerateForm.querySelector('[data-ai-generate-label]');
			const overlay = document.querySelector('[data-ai-progress-overlay]');
			const value = overlay && overlay.querySelector('[data-ai-progress-value]');
			const ring = overlay && overlay.querySelector('[data-ai-progress-ring]');
			const bar = overlay && overlay.querySelector('[data-ai-progress-bar]');
			const stage = overlay && overlay.querySelector('[data-ai-progress-stage]');
			if (!button) return;
			button.disabled = true;
			button.classList.add('is-generating');
			if (label) label.textContent = 'Analyzing data & generating offers...';
			if (overlay) {
				overlay.hidden = false;
				document.body.classList.add('kidia-ai-is-generating');
				let progress = 2;
				const renderProgress = function () {
					if (value) value.textContent = progress + '%';
					if (ring) ring.style.setProperty('--kidia-ai-progress', progress);
					if (bar) bar.style.width = progress + '%';
					if (!stage) return;
					if (progress < 22) stage.textContent = 'Reading all paid orders and available products…';
					else if (progress < 48) stage.textContent = 'Measuring stock rotation and sales velocity…';
					else if (progress < 70) stage.textContent = 'Finding product relationships and funnel opportunities…';
					else stage.textContent = 'Building ranked offers and executable decisions…';
				};
				renderProgress();
				window.setInterval(function () {
					if (progress >= 94) return;
					progress += progress < 24 ? 3 : (progress < 68 ? 2 : 1);
					progress = Math.min(94, progress);
					renderProgress();
				}, 420);
			}
		});
	}
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
