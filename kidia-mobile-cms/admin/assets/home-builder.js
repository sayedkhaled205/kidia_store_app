(function () {
	'use strict';

	const builder = document.getElementById('kidia-home-builder');
	const addButton = document.getElementById('kidia-add-element');
	const elementPicker = document.getElementById(
		'kidia-element-picker'
	);

	if (!builder) {
		return;
	}

	let draggedElement = null;

	function generateId(type) {
		const randomPart = Math.random()
			.toString(36)
			.slice(2, 12);

		return `${type}_${Date.now()}_${randomPart}`;
	}

	function updateIndexes() {
		const blocks = builder.querySelectorAll(
			'.kidia-builder-block'
		);

		blocks.forEach(function (block, index) {
			block.dataset.index = String(index);

			const orderInput = block.querySelector(
				'.kidia-block-order'
			);

			if (orderInput) {
				orderInput.value = String(index + 1);
			}

			block.querySelectorAll(
				'[name^="blocks["]'
			).forEach(function (input) {
				input.name = input.name.replace(
					/blocks\[\d+\]/,
					`blocks[${index}]`
				);
			});
		});
	}

	function setCollapsed(block, collapsed) {
		block.classList.toggle(
			'is-collapsed',
			collapsed
		);
	}

	function duplicateBlock(block) {
		const clone = block.cloneNode(true);
		const typeInput = clone.querySelector(
			'.kidia-block-type'
		);
		const idInput = clone.querySelector(
			'.kidia-block-id'
		);

		if (idInput && typeInput) {
			idInput.value = generateId(typeInput.value);
		}

		clone.querySelectorAll(
			'input, textarea, select'
		).forEach(function (input) {
			if (
				input instanceof HTMLInputElement &&
				input.type === 'checkbox'
			) {
				input.checked = input.checked;
			}
		});

		block.insertAdjacentElement(
			'afterend',
			clone
		);

		updateIndexes();
	}

	function removeBlock(block) {
		const label =
			block.dataset.label || 'this element';

		const confirmed = window.confirm(
			`Delete ${label}?`
		);

		if (!confirmed) {
			return;
		}

		block.remove();
		updateIndexes();
	}

	builder.addEventListener('click', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const block = target.closest(
			'.kidia-builder-block'
		);

		if (!block) {
			return;
		}

		if (
			target.closest('.kidia-toggle-block-settings')
		) {
			setCollapsed(
				block,
				!block.classList.contains('is-collapsed')
			);

			return;
		}

		if (target.closest('.kidia-duplicate-block')) {
			duplicateBlock(block);
			return;
		}

		if (target.closest('.kidia-delete-block')) {
			removeBlock(block);
		}
	});

	builder.addEventListener('dragstart', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const block = target.closest(
			'.kidia-builder-block'
		);

		if (!block) {
			return;
		}

		draggedElement = block;
		block.classList.add('is-dragging');

		if (event.dataTransfer) {
			event.dataTransfer.effectAllowed = 'move';
		}
	});

	builder.addEventListener('dragend', function () {
		if (draggedElement) {
			draggedElement.classList.remove(
				'is-dragging'
			);
		}

		draggedElement = null;
		updateIndexes();
	});

	builder.addEventListener('dragover', function (event) {
		event.preventDefault();

		if (!draggedElement) {
			return;
		}

		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const targetBlock = target.closest(
			'.kidia-builder-block'
		);

		if (
			!targetBlock ||
			targetBlock === draggedElement
		) {
			return;
		}

		const rectangle =
			targetBlock.getBoundingClientRect();

		const insertAfter =
			event.clientY >
			rectangle.top + rectangle.height / 2;

		if (insertAfter) {
			targetBlock.insertAdjacentElement(
				'afterend',
				draggedElement
			);
		} else {
			targetBlock.insertAdjacentElement(
				'beforebegin',
				draggedElement
			);
		}
	});

	if (addButton && elementPicker) {
		addButton.addEventListener('click', function () {
			elementPicker.hidden = false;
			elementPicker.classList.add('is-open');
		});

		elementPicker.addEventListener(
			'click',
			function (event) {
				const target = event.target;

				if (!(target instanceof HTMLElement)) {
					return;
				}

				const elementButton = target.closest(
					'[data-block-type]'
				);

				if (!elementButton) {
					return;
				}

				const type =
					elementButton.dataset.blockType;

				const template = document.getElementById(
					`tmpl-kidia-block-${type}`
				);

				if (!template) {
					return;
				}

				const index =
					builder.querySelectorAll(
						'.kidia-builder-block'
					).length;

				const id = generateId(type);

				const html = template.innerHTML
					.replaceAll('__INDEX__', String(index))
					.replaceAll('__BLOCK_ID__', id);

				builder.insertAdjacentHTML(
					'beforeend',
					html
				);

				elementPicker.hidden = true;
				elementPicker.classList.remove('is-open');

				updateIndexes();

				const blocks = builder.querySelectorAll(
					'.kidia-builder-block'
				);

				const newBlock =
					blocks[blocks.length - 1];

				if (newBlock) {
					newBlock.scrollIntoView({
						behavior: 'smooth',
						block: 'center',
					});
				}
			}
		);
	}

	updateIndexes();
})();