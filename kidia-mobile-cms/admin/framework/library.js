(function () {
	'use strict';

	const form = document.getElementById(
		'kidia-library-action-form'
	);

	if (!form) {
		return;
	}

	const createModal = document.getElementById(
		'kidia-library-create-modal'
	);

	const deleteModal = document.getElementById(
		'kidia-library-delete-modal'
	);

	const searchInput = document.getElementById(
		'kidia-library-search'
	);

	const cards = Array.from(
		document.querySelectorAll(
			'.kidia-library-card'
		)
	);

	const noResults = document.getElementById(
		'kidia-library-no-results'
	);

	const createButtons = document.querySelectorAll(
		'.kidia-library__new'
	);

	const createInput = document.getElementById(
		'kidia-library-new-name'
	);

	const createSubmit = document.getElementById(
		'kidia-library-create-submit'
	);

	const createError = document.getElementById(
		'kidia-library-create-error'
	);

	const deleteName = document.getElementById(
		'kidia-library-delete-name'
	);

	const deleteSubmit = document.getElementById(
		'kidia-library-delete-submit'
	);

	const actionInput = document.getElementById(
		'kidia-library-form-action'
	);

	const idInput = document.getElementById(
		'kidia-library-form-id'
	);

	const nameInput = document.getElementById(
		'kidia-library-form-name'
	);

	let deleteAction = '';

	let deleteId = '';

	function openModal(modal) {

		if (!modal) {
			return;
		}

		modal.hidden = false;

		document.body.classList.add(
			'kidia-modal-open'
		);

	}

	function closeModal(modal) {

		if (!modal) {
			return;
		}

		modal.hidden = true;

		document.body.classList.remove(
			'kidia-modal-open'
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
		'[data-kidia-close-modal]'
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
		'[data-kidia-close-delete-modal]'
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
    		'.kidia-library-delete'
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
    		'.kidia-library-status-toggle'
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
    		'.kidia-library-duplicate'
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