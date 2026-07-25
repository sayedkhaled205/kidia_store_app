(function () {
	'use strict';
	const more = document.querySelector('.kidia-cms-more');
	const shell = document.querySelector('.kidia-cms-shell');
	const fixedBuilder = document.body.classList.contains('kidia-cms-builder-screen');

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
