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
		const selected = (activeStep && activeStep.querySelector('.kidia-theme-card input:checked'))
			|| form.querySelector('input[name="setup[theme]"]:checked');
		const card = selected && selected.closest('.kidia-theme-card');
		const brand = form.querySelector('[name="setup[primary_color]"]');
		const primary = card
			? window.getComputedStyle(card).getPropertyValue('--theme-primary').trim()
			: (brand ? brand.value : '');
		form.style.setProperty('--kidia-setup-theme-color', primary || '#2f806e');
	}

	function selectedThemeCard() {
		const selected = form.querySelector('input[name="setup[theme]"]:checked');
		return selected ? selected.closest('.kidia-theme-card') : null;
	}

	function updateThemeReview() {
		const card = selectedThemeCard();
		const review = form.querySelector('[data-review-theme]');
		if (card && review) review.textContent = card.dataset.themeName || '';
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
		updateThemeReview();
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
		if (event.target.matches('input[name="setup[theme]"]')) {
			const card = event.target.closest('.kidia-theme-card');
			const primary = form.querySelector('[name="setup[primary_color]"]');
			const secondary = form.querySelector('[name="setup[secondary_color]"]');
			if (card && primary && secondary) {
				const styles = window.getComputedStyle(card);
				primary.value = styles.getPropertyValue('--theme-primary').trim() || primary.value;
				secondary.value = styles.getPropertyValue('--theme-soft').trim() || secondary.value;
			}
			updateThemeReview();
		}
		if (event.target.matches('.kidia-theme-card input, [name="setup[primary_color]"], [name="setup[secondary_color]"]')) {
			updateActionTheme();
		}
	});

	const modal = document.querySelector('.kidia-theme-modal');
	let previewedCard = null;
	function closeThemeModal() {
		if (!modal) return;
		modal.hidden = true;
		document.body.classList.remove('kidia-theme-preview-open');
	}
	function openThemeModal(card) {
		if (!modal || !card) return;
		previewedCard = card;
		const copy = JSON.parse(card.dataset.themeCopy || '[]');
		modal.querySelector('[data-theme-modal-name]').textContent = card.dataset.themeName || '';
		modal.querySelectorAll('[data-theme-modal-copy]').forEach(function (node) {
			node.textContent = copy[Number(node.dataset.themeModalCopy)] || '';
		});
		modal.querySelectorAll('[data-theme-modal-hero]').forEach(function (node) {
			node.style.backgroundImage = "linear-gradient(0deg,rgba(0,0,0,.34),rgba(0,0,0,.02)),url('" + (card.dataset.themeHero || '') + "')";
		});
		const styles = window.getComputedStyle(card);
		for (const property of ['--theme-primary', '--theme-soft', '--theme-ink', '--theme-surface']) {
			modal.style.setProperty(property, styles.getPropertyValue(property).trim());
		}
		modal.hidden = false;
		document.body.classList.add('kidia-theme-preview-open');
		modal.querySelector('.kidia-theme-modal__close').focus();
	}
	form.querySelectorAll('.kidia-theme-preview-button').forEach(function (button) {
		button.addEventListener('click', function (event) {
			event.preventDefault();
			event.stopPropagation();
			openThemeModal(button.closest('.kidia-theme-card'));
		});
	});
	if (modal) {
		modal.querySelectorAll('[data-theme-modal-close]').forEach(function (button) {
			button.addEventListener('click', closeThemeModal);
		});
		modal.querySelector('.kidia-theme-modal__select').addEventListener('click', function () {
			const input = previewedCard && previewedCard.querySelector('input[name="setup[theme]"]');
			if (input) {
				input.checked = true;
				input.dispatchEvent(new Event('change', { bubbles: true }));
			}
			closeThemeModal();
		});
		document.addEventListener('keydown', function (event) {
			if (event.key === 'Escape' && !modal.hidden) closeThemeModal();
		});
	}

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
