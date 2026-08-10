(function () {
	'use strict';

	const form = document.getElementById(
		'mobishop-library-action-form'
	);

	if (!form) {
		return;
	}

	const createModal = document.getElementById(
		'mobishop-library-create-modal'
	);

	const deleteModal = document.getElementById(
		'mobishop-library-delete-modal'
	);

	const searchInput = document.getElementById(
		'mobishop-library-search'
	);

	const cards = Array.from(
		document.querySelectorAll(
			'.mobishop-library-card'
		)
	);

	const noResults = document.getElementById(
		'mobishop-library-no-results'
	);

	const createButtons = document.querySelectorAll(
		'.mobishop-library__new'
	);

	const createInput = document.getElementById(
		'mobishop-library-new-name'
	);

	const createSubmit = document.getElementById(
		'mobishop-library-create-submit'
	);

	const createError = document.getElementById(
		'mobishop-library-create-error'
	);

	const deleteName = document.getElementById(
		'mobishop-library-delete-name'
	);

	const deleteSubmit = document.getElementById(
		'mobishop-library-delete-submit'
	);

	const actionInput = document.getElementById(
		'mobishop-library-form-action'
	);

	const idInput = document.getElementById(
		'mobishop-library-form-id'
	);

	const nameInput = document.getElementById(
		'mobishop-library-form-name'
	);

	let deleteAction = '';

	let deleteId = '';

	function openModal(modal) {

		if (!modal) {
			return;
		}

		modal.hidden = false;

		document.body.classList.add(
			'mobishop-modal-open'
		);

	}

	function closeModal(modal) {

		if (!modal) {
			return;
		}

		modal.hidden = true;

		document.body.classList.remove(
			'mobishop-modal-open'
		);

	}

	createButtons.forEach(function (button) {

		button.addEventListener(
			'click',
			function () {

				if (createInput) {
					createInput.value = '';
					createInput.focus();
				}

				if (createError) {
					createError.hidden = true;
				}

				openModal(
					createModal
				);

			}
		);

	});

	document.querySelectorAll(
		'[data-mobishop-close-modal]'
	).forEach(function (button) {

		button.addEventListener(
			'click',
			function () {

				closeModal(
					createModal
				);

			}
		);

	});

	document.querySelectorAll(
		'[data-mobishop-close-delete-modal]'
	).forEach(function (button) {

		button.addEventListener(
			'click',
			function () {

				closeModal(
					deleteModal
				);

			}
		);

	});

		createSubmit?.addEventListener(
    		'click',
    		function () {

    			const name =
    				createInput
    					? createInput.value.trim()
    					: '';

    			if (!name) {

    				if (createError) {
    					createError.hidden = false;
    				}

    				return;
    			}

    			actionInput.value =
    				createSubmit.dataset.action || '';

    			nameInput.value = name;

    			idInput.value = '';

    			form.submit();

    		}
    	);

    	document.querySelectorAll(
    		'.mobishop-library-delete'
    	).forEach(function (button) {

    		button.addEventListener(
    			'click',
    			function () {

    				deleteAction =
    					button.dataset.action || '';

    				deleteId =
    					button.dataset.id || '';

    				if (deleteName) {

    					deleteName.textContent =
    						button.dataset.name || '';

    				}

    				openModal(
    					deleteModal
    				);

    			}
    		);

    	});

    	deleteSubmit?.addEventListener(
    		'click',
    		function () {

    			actionInput.value =
    				deleteAction;

    			idInput.value =
    				deleteId;

    			nameInput.value = '';

    			form.submit();

    		}
    	);

    	document.querySelectorAll(
    		'.mobishop-library-status-toggle'
    	).forEach(function (button) {

    		button.addEventListener(
    			'click',
    			function () {

    				actionInput.value =
    					button.dataset.action || '';

    				idInput.value =
    					button.dataset.id || '';

    				nameInput.value = '';

    				form.submit();

    			}
    		);

    	});

    	document.querySelectorAll(
    		'.mobishop-library-duplicate'
    	).forEach(function (button) {

    		button.addEventListener(
    			'click',
    			function () {

    				actionInput.value =
    					button.dataset.action || '';

    				idInput.value =
    					button.dataset.id || '';

    				nameInput.value = '';

    				form.submit();

    			}
    		);

    	});

    	searchInput?.addEventListener(
    		'input',
    		function () {

    			const value =
    				searchInput.value
    					.trim()
    					.toLowerCase();

    			let visible = 0;

    			cards.forEach(function (card) {

    				const name =
    					card.dataset.name || '';

    				const match =
    					name.includes(value);

    				card.hidden = !match;

    				if (match) {
    					visible++;
    				}

    			});

    			if (noResults) {

    				noResults.hidden =
    					visible !== 0;

    			}

    		}
    	);

    	document.addEventListener(
    		'keydown',
    		function (event) {

    			if (
    				event.key !== 'Escape'
    			) {
    				return;
    			}

    			closeModal(
    				createModal
    			);

    			closeModal(
    				deleteModal
    			);

    		}
    	);

    })();