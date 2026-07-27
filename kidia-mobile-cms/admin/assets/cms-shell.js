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
	if (pushTitle && previewTitle) pushTitle.addEventListener('input', function () { previewTitle.textContent = pushTitle.value.trim() || 'Your notification title'; });
	if (pushMessage && previewMessage) pushMessage.addEventListener('input', function () { previewMessage.textContent = pushMessage.value.trim() || 'Your message will appear here.'; });
	const pushTypeInputs = document.querySelectorAll('[data-push-type]');
	const syncPushType = function () {
		const checked = document.querySelector('[data-push-type]:checked');
		const type = checked ? checked.value : 'broadcast';
		document.querySelectorAll('[data-push-field]').forEach(function (field) {
			field.hidden = !field.dataset.pushField.split(/\s+/).includes(type);
		});
	};
	pushTypeInputs.forEach(function (input) { input.addEventListener('change', syncPushType); });
	syncPushType();
	const pushAudience = document.querySelector('[data-push-audience]');
	const pushSegment = document.querySelector('[data-push-segment]');
	if (pushAudience && pushSegment) {
		const syncAudience = function () { pushSegment.hidden = pushAudience.value !== 'segment'; };
		pushAudience.addEventListener('change', syncAudience); syncAudience();
	}
	const pushDelivery = document.querySelector('[data-push-delivery]');
	const pushSchedule = document.querySelector('[data-push-schedule]');
	if (pushDelivery && pushSchedule) {
		const syncDelivery = function () { pushSchedule.hidden = pushDelivery.value !== 'scheduled'; };
		pushDelivery.addEventListener('change', syncDelivery); syncDelivery();
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
