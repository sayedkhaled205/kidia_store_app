(function () {
	'use strict';

	const dialog = document.querySelector('[data-saved-theme-dialog]');
	const dialogPhone = dialog && dialog.querySelector('[data-saved-theme-dialog-phone]');
	const dialogTitle = dialog && dialog.querySelector('[data-saved-theme-dialog-title]');

	document.querySelectorAll('[data-saved-theme-preview]').forEach(function (button) {
		button.addEventListener('click', function () {
			if (!dialog || !dialogPhone || !dialogTitle) return;
			const card = button.closest('[data-saved-theme-card]');
			const phone = card && card.querySelector('[data-saved-theme-phone]');
			if (!phone) return;

			const preview = phone.cloneNode(true);
			preview.removeAttribute('data-saved-theme-phone');
			preview.classList.add('is-large-preview');
			dialogPhone.replaceChildren(preview);
			dialogTitle.textContent = button.getAttribute('data-theme-name') || '';

			if (typeof dialog.showModal === 'function') {
				dialog.showModal();
			} else {
				dialog.setAttribute('open', '');
			}
		});
	});

	if (dialog) {
		const close = dialog.querySelector('[data-saved-theme-dialog-close]');
		if (close) {
			close.addEventListener('click', function () {
				if (typeof dialog.close === 'function') dialog.close();
				else dialog.removeAttribute('open');
			});
		}
		dialog.addEventListener('click', function (event) {
			if (event.target !== dialog) return;
			const bounds = dialog.getBoundingClientRect();
			const inside = event.clientX >= bounds.left && event.clientX <= bounds.right
				&& event.clientY >= bounds.top && event.clientY <= bounds.bottom;
			if (!inside) {
				if (typeof dialog.close === 'function') dialog.close();
				else dialog.removeAttribute('open');
			}
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
