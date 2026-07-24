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

	function updateActionTheme() {
		const activeStep = steps[current];
		const selected = activeStep && activeStep.querySelector('.kidia-theme-card input:checked');
		const card = selected && selected.closest('.kidia-theme-card');
		const brand = form.querySelector('[name="setup[primary_color]"]');
		const primary = card
			? window.getComputedStyle(card).getPropertyValue('--theme-primary').trim()
			: (brand ? brand.value : '');
		form.style.setProperty('--kidia-setup-theme-color', primary || '#2f806e');
	}

	function show(index, shouldScroll) {
		current = Math.max(0, Math.min(steps.length - 1, index));
		steps.forEach((step, i) => step.classList.toggle('is-active', i === current));
		dots.forEach((dot, i) => dot.classList.toggle('is-active', i <= current));
		back.hidden = current === 0;
		next.hidden = current === steps.length - 1;
		apply.hidden = current !== steps.length - 1;
		const name = form.querySelector('[name="setup[app_name]"]');
		const review = form.querySelector('[data-review-name]');
		if (name && review) review.textContent = name.value || name.placeholder;
		updateActionTheme();
		if (shouldScroll !== false) {
			const hero = document.querySelector('.kidia-setup-hero');
			const target = hero || form;
			window.scrollTo({ top: Math.max(0, target.getBoundingClientRect().top + window.scrollY - 90), behavior: 'smooth' });
		}
	}
	next.addEventListener('click', function () {
		const required = steps[current].querySelectorAll('[required]');
		for (const input of required) {
			if (!input.reportValidity()) return;
		}
		show(current + 1);
	});
	back.addEventListener('click', function () { show(current - 1); });
	form.addEventListener('change', function (event) {
		if (event.target.matches('.kidia-theme-card input, [name="setup[primary_color]"]')) {
			updateActionTheme();
		}
	});

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
	if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
	show(0, false);
	const resetScroll = function () {
		window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
	};
	if (window.requestAnimationFrame) {
		window.requestAnimationFrame(resetScroll);
	} else {
		resetScroll();
	}
})();
