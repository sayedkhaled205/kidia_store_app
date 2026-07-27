(function () {
	'use strict';
	const form = document.querySelector('.kidia-setup-form');
	if (!form) return;
	const steps = Array.from(form.querySelectorAll('.kidia-setup-step'));
	const progress = document.querySelector('.kidia-setup-progress');
	const next = form.querySelector('.kidia-setup-next');
	const back = form.querySelector('.kidia-setup-back');
	const apply = form.querySelector('.kidia-setup-apply');
	let current = 0;

	function pageEnabled(page) {
		const toggle = form.querySelector('[data-page-toggle="' + page + '"]');
		return !toggle || toggle.checked;
	}

	function activeSteps() {
		return steps.filter(function (step) {
			const page = step.getAttribute('data-theme-page');
			return !page || pageEnabled(page);
		});
	}

	function syncPageSteps() {
		steps.forEach(function (step) {
			const page = step.getAttribute('data-theme-page');
			if (!page) return;
			const enabled = pageEnabled(page);
			step.hidden = !enabled;
			step.querySelectorAll('input[type="radio"]').forEach(function (input) {
				input.disabled = !enabled;
				input.required = enabled;
			});
		});
		form.querySelectorAll('[data-review-page]').forEach(function (tag) {
			tag.hidden = !pageEnabled(tag.getAttribute('data-review-page'));
		});
	}

	function renderProgress(visibleSteps) {
		if (!progress) return;
		progress.innerHTML = '';
		visibleSteps.forEach(function (step, index) {
			const dot = document.createElement('span');
			dot.textContent = String(index + 1);
			dot.classList.toggle('is-active', index <= current);
			progress.appendChild(dot);
			if (index < visibleSteps.length - 1) progress.appendChild(document.createElement('i'));
			const number = step.querySelector('[data-step-number]');
			if (number) number.textContent = String(index + 1).padStart(2, '0');
		});
	}

	function updateActionTheme() {
		const activeStep = activeSteps()[current];
		const selected = activeStep && activeStep.querySelector('.kidia-theme-card input:checked');
		const card = selected && selected.closest('.kidia-theme-card');
		const brand = form.querySelector('[name="setup[primary_color]"]');
		const primary = card
			? window.getComputedStyle(card).getPropertyValue('--theme-primary').trim()
			: (brand ? brand.value : '');
		form.style.setProperty('--kidia-setup-theme-color', primary || '#2f806e');
	}

	function show(index, shouldScroll) {
		syncPageSteps();
		const visibleSteps = activeSteps();
		current = Math.max(0, Math.min(visibleSteps.length - 1, index));
		const activeStep = visibleSteps[current];
		steps.forEach((step) => step.classList.toggle('is-active', step === activeStep));
		renderProgress(visibleSteps);
		back.hidden = current === 0;
		next.hidden = current === visibleSteps.length - 1;
		apply.hidden = current !== visibleSteps.length - 1;
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
		const activeStep = activeSteps()[current];
		const required = activeStep.querySelectorAll('[required]:not(:disabled)');
		for (const input of required) {
			if (!input.reportValidity()) return;
		}
		show(current + 1);
	});
	back.addEventListener('click', function () { show(current - 1); });
	form.addEventListener('change', function (event) {
		if (event.target.matches('[data-page-toggle]')) {
			syncPageSteps();
			show(current, false);
		}
		if (event.target.matches('.kidia-theme-card input, [name="setup[primary_color]"], [name="setup[secondary_color]"]')) {
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
