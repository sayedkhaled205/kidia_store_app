(function () {
	'use strict';
	const more = document.querySelector('.kidia-cms-more');
	if (!more) return;
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
})();
