(function () {
	'use strict';
	const form = document.querySelector('.kidia-setup-form');
	if (!form) return;
	const steps = Array.from(form.querySelectorAll('.kidia-setup-step'));
	const dots = Array.from(document.querySelectorAll('.kidia-setup-progress span'));
	const next = form.querySelector('.kidia-setup-next');
	const back = form.querySelector('.kidia-setup-back');
	const apply = form.querySelector('.kidia-setup-apply');
	let current = 0;

	function show(index) {
		current = Math.max(0, Math.min(steps.length - 1, index));
		steps.forEach((step, i) => step.classList.toggle('is-active', i === current));
		dots.forEach((dot, i) => dot.classList.toggle('is-active', i <= current));
		back.hidden = current === 0;
		next.hidden = current === steps.length - 1;
		apply.hidden = current !== steps.length - 1;
		const name = form.querySelector('[name="setup[app_name]"]');
		const review = form.querySelector('[data-review-name]');
		if (name && review) review.textContent = name.value || name.placeholder;
		window.scrollTo({ top: Math.max(0, form.getBoundingClientRect().top + window.scrollY - 90), behavior: 'smooth' });
	}
	next.addEventListener('click', function () {
		const required = steps[current].querySelectorAll('[required]');
		for (const input of required) {
			if (!input.reportValidity()) return;
		}
		show(current + 1);
	});
	back.addEventListener('click', function () { show(current - 1); });

	const chooseLogo = form.querySelector('.kidia-setup-choose-logo');
	if (chooseLogo && window.wp && wp.media) {
		chooseLogo.addEventListener('click', function () {
			const frame = wp.media({ title: chooseLogo.textContent, library: { type: 'image' }, multiple: false });
			frame.on('select', function () {
				const image = frame.state().get('selection').first().toJSON();
				form.querySelector('[name="setup[logo_id]"]').value = image.id || 0;
				form.querySelector('[name="setup[logo_url]"]').value = image.url || '';
				form.querySelector('.kidia-setup-logo-preview').innerHTML = image.url ? '<img src="' + image.url + '" alt="">' : '';
			});
			frame.open();
		});
	}
	show(0);
})();
