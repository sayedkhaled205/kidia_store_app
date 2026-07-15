(function () {
	'use strict';

	const builder = document.getElementById('kidia-home-builder');
	const form = document.getElementById('kidia-home-builder-form');

	if (!builder || !form) {
		return;
	}

	const config = window.kidiaHomeBuilder || {};
	const labels = config.labels || {};
	const editorPages = config.editorPages || {};
	const picker = document.getElementById('kidia-element-picker');
	const createModal = document.getElementById('kidia-create-element-modal');
	const searchInput = document.getElementById('kidia-element-picker-search');
	const createNameInput = document.getElementById('kidia-create-element-name');
	const createError = document.getElementById('kidia-create-element-error');
	const createTitle = document.getElementById('kidia-create-element-title');
	const editAfterSaveType = document.getElementById('kidia-edit-after-save-type');
	const editAfterSaveId = document.getElementById('kidia-edit-after-save-id');

	let currentCreateType = '';
	let draggedBlock = null;
	let isDirty = false;

	function getBlocks() {
		return Array.from(builder.querySelectorAll('.kidia-builder-block'));
	}

	function generateId(type) {
		return (
			type +
			'_' +
			Date.now().toString(36) +
			'_' +
			Math.random().toString(36).slice(2, 8)
		);
	}

	function markDirty() {
		isDirty = true;
	}

	function updateIndexes() {
		getBlocks().forEach(function (block, index) {
			block.querySelectorAll('[name^="blocks["]').forEach(function (input) {
				input.name = input.name.replace(
					/blocks\[[^\]]+]/,
					'blocks[' + index + ']'
				);
			});

			const orderInput = block.querySelector('.kidia-block-order');

			if (orderInput) {
				orderInput.value = String(index + 1);
			}
		});
	}

	function setCollapsed(block, collapsed) {
		block.classList.toggle('is-collapsed', collapsed);

		const toggle = block.querySelector('.kidia-toggle-block-settings');

		if (toggle) {
			toggle.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
		}
	}

	function collapseAll(collapsed) {
		getBlocks().forEach(function (block) {
			setCollapsed(block, collapsed);
		});
	}

	function openPicker() {
		if (!picker) {
			return;
		}

		picker.hidden = false;
		picker.setAttribute('aria-hidden', 'false');
		document.body.classList.add('kidia-picker-open');
		window.setTimeout(function () {
			searchInput?.focus();
		}, 40);
	}

	function closePicker() {
		if (!picker) {
			return;
		}

		picker.hidden = true;
		picker.setAttribute('aria-hidden', 'true');
		document.body.classList.remove('kidia-picker-open');
	}

	function openCreateModal(type, label) {
		if (!createModal) {
			return;
		}

		currentCreateType = type;

		if (createTitle) {
			createTitle.textContent =
				(labels.createPrefix || 'Create') + ' ' + label;
		}

		if (createNameInput) {
			createNameInput.value = '';
		}

		if (createError) {
			createError.hidden = true;
		}

		createModal.hidden = false;
		createModal.setAttribute('aria-hidden', 'false');
		document.body.classList.add('kidia-modal-open');
		window.setTimeout(function () {
			createNameInput?.focus();
		}, 40);
	}

	function closeCreateModal() {
		if (!createModal) {
			return;
		}

		createModal.hidden = true;
		createModal.setAttribute('aria-hidden', 'true');
		document.body.classList.remove('kidia-modal-open');
		currentCreateType = '';
	}

	function removeEmptyState() {
		document.getElementById('kidia-builder-empty')?.remove();
	}

	function ensureEmptyState() {
		if (getBlocks().length || document.getElementById('kidia-builder-empty')) {
			return;
		}

		const empty = document.createElement('div');
		empty.id = 'kidia-builder-empty';
		empty.className = 'kidia-builder-empty';
		empty.innerHTML =
			'<span class="dashicons dashicons-screenoptions"></span>' +
			'<h2></h2><p></p><button type="button" class="button button-primary" ' +
			'data-kidia-open-picker></button>';
		empty.querySelector('h2').textContent = labels.noElements || 'No elements';
		empty.querySelector('p').textContent =
			labels.noElementsDescription || 'Add an element to build the Home Page.';
		empty.querySelector('button').textContent = labels.addFirst || 'Add First Element';
		builder.appendChild(empty);
	}

	function findBlockByReference(type, libraryId) {
		return (
			getBlocks().find(function (block) {
				return (
					block.dataset.type === type &&
					block.dataset.libraryId === libraryId
				);
			}) || null
		);
	}

	function appendTemplate(templateId, type, libraryId, name, isNew) {
		const template = document.getElementById(templateId);

		if (!template) {
			return null;
		}

		const existing = findBlockByReference(type, libraryId);

		if (existing) {
			closePicker();
			existing.scrollIntoView({ behavior: 'smooth', block: 'center' });
			existing.classList.add('is-highlighted');
			window.setTimeout(function () {
				existing.classList.remove('is-highlighted');
			}, 1000);
			return existing;
		}

		const index = getBlocks().length;
		const blockId = generateId(type);
		const resolvedLibraryId = libraryId || blockId;
		const html = template.innerHTML
			.replaceAll('__INDEX__', String(index))
			.replaceAll('__ORDER__', String(index + 1))
			.replaceAll('__BLOCK_ID__', blockId)
			.replaceAll('__LIBRARY_ID__', resolvedLibraryId)
			.replaceAll('__BLOCK_NAME__', '');

		removeEmptyState();
		builder.insertAdjacentHTML('beforeend', html);

		const block = getBlocks().at(-1) || null;

		if (block) {
			const nameInput = block.querySelector('.kidia-block-name-input');
			const nameLabel = block.querySelector('.kidia-block-name');

			if (nameInput) {
				nameInput.value = name || '';
			}

			if (nameLabel) {
				nameLabel.textContent = name || labels.untitled || 'Untitled Element';
			}

			block.dataset.isNew = isNew ? 'true' : 'false';
			block.draggable = false;
			setCollapsed(block, true);
			block.scrollIntoView({ behavior: 'smooth', block: 'center' });
		}

		updateIndexes();
		markDirty();
		closePicker();

		return block;
	}

	function createElement() {
		const name = createNameInput ? createNameInput.value.trim() : '';

		if (!name) {
			if (createError) {
				createError.hidden = false;
			}
			return;
		}

		if (!currentCreateType) {
			return;
		}

		const type = currentCreateType;
		const libraryId = generateId(type);

		appendTemplate(
			'tmpl-kidia-block-' + type,
			type,
			libraryId,
			name,
			true
		);
		closeCreateModal();
	}

	function setDraftStatus(block) {
		const statusInput = block.querySelector('.kidia-block-status');
		const statusBadge = block.querySelector('.kidia-builder-status');

		if (statusInput) {
			statusInput.value = 'draft';
		}

		if (statusBadge) {
			statusBadge.classList.remove('kidia-builder-status--published');
			statusBadge.classList.add('kidia-builder-status--draft');
			statusBadge.textContent = labels.draft || 'Draft';
		}
	}

	function duplicateBlock(block) {
		const clone = block.cloneNode(true);
		const type = clone.querySelector('.kidia-block-type')?.value || 'block';
		const newId = generateId(type);
		const idInput = clone.querySelector('.kidia-block-id');
		const libraryInput = clone.querySelector('.kidia-block-library-id');
		const sourceLibraryInput = clone.querySelector('.kidia-block-source-library-id');
		const editButton = clone.querySelector('.kidia-edit-library-item');
		const nameInput = clone.querySelector('.kidia-block-name-input');
		const nameLabel = clone.querySelector('.kidia-block-name');

		if (idInput) {
			idInput.value = newId;
		}

		if (libraryInput) {
			if (sourceLibraryInput) {
				sourceLibraryInput.value =
					sourceLibraryInput.value || libraryInput.value;
			}
			libraryInput.value = newId;
		}

		if (editButton) {
			editButton.dataset.libraryId = newId;
		}

		if (nameInput) {
			nameInput.value = nameInput.value + (labels.copySuffix || ' Copy');
			if (nameLabel) {
				nameLabel.textContent = nameInput.value;
			}
		}

		clone.dataset.libraryId = newId;
		clone.dataset.isNew = 'true';
		clone.draggable = false;
		setDraftStatus(clone);
		setCollapsed(clone, true);
		block.insertAdjacentElement('afterend', clone);
		updateIndexes();
		markDirty();
		clone.scrollIntoView({ behavior: 'smooth', block: 'center' });
	}

	function editBlock(block, button) {
		const type = button.dataset.type || '';
		const libraryId = button.dataset.libraryId || '';
		const editorPage = editorPages[type];

		if (!editorPage || !libraryId) {
			return;
		}

		if (block.dataset.isNew === 'true') {
			if (editAfterSaveType && editAfterSaveId) {
				editAfterSaveType.value = type;
				editAfterSaveId.value = libraryId;
			}
			form.requestSubmit();
			return;
		}

		window.location.assign(
			'admin.php?page=' +
				encodeURIComponent(editorPage) +
				'&id=' +
				encodeURIComponent(libraryId)
		);
	}

	document.addEventListener('click', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		if (target.closest('[data-kidia-open-picker]')) {
			openPicker();
			return;
		}

		if (target.closest('[data-kidia-close-picker]')) {
			closePicker();
			return;
		}

		if (target.closest('[data-kidia-close-create-modal]')) {
			closeCreateModal();
		}
	});

	document.getElementById('kidia-add-element')?.addEventListener('click', openPicker);
	document.getElementById('kidia-collapse-all')?.addEventListener('click', function () {
		collapseAll(true);
	});
	document.getElementById('kidia-expand-all')?.addEventListener('click', function () {
		collapseAll(false);
	});
	document.getElementById('kidia-create-element-submit')?.addEventListener(
		'click',
		createElement
	);

	createNameInput?.addEventListener('keydown', function (event) {
		if (event.key === 'Enter') {
			event.preventDefault();
			createElement();
		}
	});

	document.querySelectorAll('.kidia-create-element').forEach(function (button) {
		button.addEventListener('click', function () {
			openCreateModal(
				button.dataset.blockType || '',
				button.dataset.blockLabel || ''
			);
		});
	});

	document.querySelectorAll('.kidia-add-library-element').forEach(function (button) {
		button.addEventListener('click', function () {
			appendTemplate(
				button.dataset.templateId || '',
				button.dataset.blockType || '',
				button.dataset.libraryId || '',
				button.dataset.blockName || '',
				false
			);
		});
	});

	builder.addEventListener('click', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const block = target.closest('.kidia-builder-block');

		if (!block) {
			return;
		}

		if (target.closest('.kidia-toggle-block-settings')) {
			setCollapsed(block, !block.classList.contains('is-collapsed'));
			return;
		}

		if (target.closest('.kidia-delete-block')) {
			const name =
				block.querySelector('.kidia-block-name')?.textContent?.trim() ||
				labels.untitled ||
				'Untitled Element';
			const message =
				labels.deleteConfirm || 'Remove this element from the Home page?';

			if (!window.confirm(message + '\n' + name)) {
				return;
			}

			block.remove();
			updateIndexes();
			ensureEmptyState();
			markDirty();
			return;
		}

		if (target.closest('.kidia-duplicate-block')) {
			duplicateBlock(block);
			return;
		}

		const editButton = target.closest('.kidia-edit-library-item');

		if (editButton) {
			editBlock(block, editButton);
		}
	});

	builder.addEventListener('input', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLInputElement)) {
			return;
		}

		if (target.classList.contains('kidia-block-name-input')) {
			const name = target
				.closest('.kidia-builder-block')
				?.querySelector('.kidia-block-name');

			if (name) {
				name.textContent = target.value.trim() || labels.untitled || 'Untitled Element';
			}
		}

		markDirty();
	});

	builder.addEventListener('pointerdown', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const handle = target.closest('.kidia-builder-drag');
		const block = handle?.closest('.kidia-builder-block');

		if (block) {
			block.draggable = true;
		}
	});

	builder.addEventListener('dragstart', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const block = target.closest('.kidia-builder-block');

		if (!block || !block.draggable) {
			event.preventDefault();
			return;
		}

		draggedBlock = block;
		block.classList.add('is-dragging');

		if (event.dataTransfer) {
			event.dataTransfer.effectAllowed = 'move';
			event.dataTransfer.setData('text/plain', block.dataset.libraryId || '');
		}
	});

	builder.addEventListener('dragover', function (event) {
		if (!draggedBlock) {
			return;
		}

		event.preventDefault();

		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const targetBlock = target.closest('.kidia-builder-block');

		if (!targetBlock || targetBlock === draggedBlock) {
			return;
		}

		const rect = targetBlock.getBoundingClientRect();
		const after = event.clientY > rect.top + rect.height / 2;
		targetBlock.insertAdjacentElement(after ? 'afterend' : 'beforebegin', draggedBlock);
	});

	builder.addEventListener('dragend', function () {
		if (draggedBlock) {
			draggedBlock.classList.remove('is-dragging');
			draggedBlock.draggable = false;
		}

		draggedBlock = null;
		updateIndexes();
		markDirty();
	});

	searchInput?.addEventListener('input', function () {
		const value = searchInput.value.trim().toLocaleLowerCase();
		let visibleGroups = 0;

		document.querySelectorAll('.kidia-element-group').forEach(function (group) {
			const matches = group.textContent.toLocaleLowerCase().includes(value);
			group.hidden = !matches;
			visibleGroups += matches ? 1 : 0;
		});

		const noResults = document.getElementById('kidia-element-picker-no-results');

		if (noResults) {
			noResults.hidden = visibleGroups !== 0;
		}
	});

	document.addEventListener('keydown', function (event) {
		if (event.key !== 'Escape') {
			return;
		}

		closePicker();
		closeCreateModal();
	});

	form.addEventListener('submit', function () {
		updateIndexes();
		isDirty = false;
	});

	window.addEventListener('beforeunload', function (event) {
		if (!isDirty) {
			return;
		}

		event.preventDefault();
		event.returnValue = '';
	});

	getBlocks().forEach(function (block) {
		block.draggable = false;
		setCollapsed(block, true);
	});
	updateIndexes();
})();
