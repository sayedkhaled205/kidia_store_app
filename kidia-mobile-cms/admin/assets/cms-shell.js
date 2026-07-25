(function () {
	'use strict';
	const more = document.querySelector('.kidia-cms-more');
	const shell = document.querySelector('.kidia-cms-shell');

	function syncPreviewOffset() {
		if (!shell) return;
		const style = window.getComputedStyle(shell);
		const stickyTop = parseFloat(style.top) || 0;
		const shellHeight = Math.ceil(shell.getBoundingClientRect().height);
		const previewTop = Math.ceil(stickyTop + shellHeight + 14);
		document.documentElement.style.setProperty(
			'--kidia-preview-sticky-top',
			previewTop + 'px'
		);
		document.documentElement.style.setProperty(
			'--kidia-builder-viewport-height',
			Math.max(420, Math.floor(window.innerHeight - previewTop - 12)) + 'px'
		);
	}

	syncPreviewOffset();
	window.addEventListener('resize', syncPreviewOffset);
	if (shell && typeof window.ResizeObserver === 'function') {
		new window.ResizeObserver(syncPreviewOffset).observe(shell);
	}

	if (more) {
		const button = more.querySelector('button');
		button.addEventListener('click', function () {
			const open = more.classList.toggle('is-open');
			button.setAttribute('aria-expanded', open ? 'true' : 'false');
		});
		document.addEventListener('click', function (event) {
			if (!more.contains(event.target)) {
				more.classList.remove('is-open');
				button.setAttribute('aria-expanded', 'false');
			}
		});
	}
})();
