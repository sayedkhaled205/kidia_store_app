(function () {
	'use strict';

	const builder = document.getElementById('kidia-home-builder');
	const form = document.getElementById('kidia-home-builder-form');

	if (!builder || !form) {
		return;
	}

	const config = window.kidiaHomeBuilder || {};
	const labels = config.labels || {};
	const picker = document.getElementById('kidia-element-picker');
	const createModal = document.getElementById('kidia-create-element-modal');
	const searchInput = document.getElementById('kidia-element-picker-search');
	const createNameInput = document.getElementById('kidia-create-element-name');
	const createError = document.getElementById('kidia-create-element-error');
	const createTitle = document.getElementById('kidia-create-element-title');
	const editAfterSaveType = document.getElementById('kidia-edit-after-save-type');
	const editAfterSaveId = document.getElementById('kidia-edit-after-save-id');
	const blocksPayload = document.getElementById('kidia-home-builder-payload');
	const previewContent = document.getElementById('kidia-mobile-preview-content');

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

	function serializeBlocks() {
		return getBlocks().map(function (block, index) {
			const value = function (selector) {
				return block.querySelector(selector)?.value || '';
			};
			const enabled = block.querySelector('input[name$="[enabled]"]');

			const settings = {};
			block.querySelectorAll('[name*="[settings]"]').forEach(function (input) {
				if (!(input instanceof HTMLInputElement || input instanceof HTMLSelectElement || input instanceof HTMLTextAreaElement)) return;
				if ((input.type === 'checkbox' || input.type === 'radio') && !input.checked) return;
				const match = input.name.match(/\[settings\]((?:\[[^\]]*\])+)/);
				if (!match) return;
				const path = Array.from(match[1].matchAll(/\[([^\]]*)\]/g)).map(function (part) { return part[1]; });
				let cursor = settings;
				path.forEach(function (key, pathIndex) {
					const last = pathIndex === path.length - 1;
					const nextKey = path[pathIndex + 1];
					if (last) {
						if (key === '') {
							if (Array.isArray(cursor)) cursor.push(input.value);
						} else if (Object.prototype.hasOwnProperty.call(cursor, key)) {
							cursor[key] = Array.isArray(cursor[key]) ? cursor[key].concat(input.value) : [cursor[key], input.value];
						} else {
							cursor[key] = input.value;
						}
						return;
					}
					if (!Object.prototype.hasOwnProperty.call(cursor, key)) cursor[key] = /^\d+$/.test(nextKey) || nextKey === '' ? [] : {};
					cursor = cursor[key];
				});
			});

			return {
				id: value('.kidia-block-id'),
				library_id: value('.kidia-block-library-id'),
				source_library_id: value('.kidia-block-source-library-id'),
				create_intent: value('.kidia-block-create-intent'),
				type: value('.kidia-block-type'),
				name: value('.kidia-block-name-input'),
				enabled: enabled?.checked ? '1' : '',
				status: value('.kidia-block-status'),
				order: index + 1,
				settings: settings
			};
		});
	}

	function escapeHtml(value) {
		return String(value ?? '').replace(/[&<>"]/g, function (character) {
			return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[character];
		});
	}

	function safeImage(value) {
		const url = String(value ?? '').trim();
		return /^https?:\/\//i.test(url) ? escapeHtml(url) : '';
	}

	function renderPreview() {
		if (!previewContent) return;
		const blocks = serializeBlocks().filter(function (block) {
			return block.enabled && block.status === 'published';
		});
		if (!blocks.length) {
			previewContent.innerHTML = '<div class="kidia-preview-empty">Add or publish an element to preview the Home Page.</div>';
			return;
		}
		previewContent.innerHTML = blocks.map(function (block) {
			const settings = block.settings || {};
			const name = escapeHtml(block.name || block.type);
			if (block.type === 'app_header') {
				const logo = safeImage(settings.logo_url);
				const title = escapeHtml(settings.title || name || 'Kidia Store');
				return '<div class="kidia-preview-header"><span>♡</span>' + (logo ? '<img src="' + logo + '" alt="">' : '<strong>' + title + '</strong>') + '<span>⌕　♧</span></div>';
			}
			if (block.type === 'hero_slider') {
				const items = Array.isArray(settings.items) ? settings.items : [];
				const image = safeImage(items[0]?.image_url);
				return '<div class="kidia-preview-block">' + (image ? '<img style="aspect-ratio:' + escapeHtml(settings.aspect_ratio || 1.7) + '" src="' + image + '" alt="">' : '<div class="kidia-preview-placeholder">' + name + '</div>') + '</div>';
			}
			if (block.type === 'image_banner' || block.type === 'coupon_banner') {
				const image = safeImage(settings.image_url);
				return '<div class="kidia-preview-block">' + (image ? '<img src="' + image + '" alt="">' : '<div class="kidia-preview-placeholder">' + name + '</div>') + '</div>';
			}
			if (block.type === 'text_block') return '<div class="kidia-preview-block"><div class="kidia-preview-block__label">' + escapeHtml(settings.title || name) + '</div><div style="padding:0 11px 12px;font-size:11px">' + escapeHtml(settings.content || '') + '</div></div>';
			if (block.type === 'spacer') return '<div style="height:' + Math.min(80, Number(settings.height || 20)) + 'px"></div>';
			if (block.type === 'divider') return '<div style="margin:12px;border-top:1px solid #dcdcde"></div>';
			return '<div class="kidia-preview-block"><div class="kidia-preview-block__label">' + escapeHtml(settings.title || name) + '</div><div class="kidia-preview-placeholder">' + escapeHtml(block.type.replaceAll('_', ' ')) + '</div></div>';
		}).join('');
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
			.replaceAll('987654321', String(index))
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
			const createIntentInput = block.querySelector(
				'.kidia-block-create-intent'
			);

			if (nameInput) {
				nameInput.value = name || '';
			}

			if (nameLabel) {
				nameLabel.textContent = name || labels.untitled || 'Untitled Element';
			}

			if (createIntentInput) {
				createIntentInput.value = isNew ? '1' : '0';
			}

			block.dataset.isNew = isNew ? 'true' : 'false';
			block.draggable = false;
			setCollapsed(block, false);
			block.scrollIntoView({ behavior: 'smooth', block: 'center' });
		}

		updateIndexes();
		markDirty();
		renderPreview();
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
		const createIntentInput = clone.querySelector('.kidia-block-create-intent');
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

		if (createIntentInput) {
			createIntentInput.value = '1';
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
		renderPreview();
		clone.scrollIntoView({ behavior: 'smooth', block: 'center' });
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
			renderPreview();
			return;
		}

		if (target.closest('.kidia-duplicate-block')) {
			duplicateBlock(block);
			return;
		}

		if (target.closest('.kidia-select-banner-image, .kidia-select-media, .kidia-select-app-header-logo')) {
			if (!window.wp?.media) return;
			const frame = window.wp.media({ title: 'Choose image', button: { text: 'Use image' }, multiple: false });
			frame.on('select', function () {
				const attachment = frame.state().get('selection').first()?.toJSON();
				if (!attachment?.url) return;
				const field = target.closest('.kidia-builder-field');
				const input = field?.querySelector('.kidia-banner-image-url, .kidia-media-url, .kidia-app-header-logo-url');
				const preview = field?.querySelector('.kidia-banner-image-preview, .kidia-media-preview');
				if (input) input.value = attachment.url;
				if (preview) { preview.src = attachment.url; preview.hidden = false; preview.style.display = ''; }
				markDirty(); renderPreview();
			});
			frame.open();
			return;
		}

		if (target.closest('.kidia-hero-gallery__select')) {
			if (!window.wp?.media) return;
			const frame = window.wp.media({ title: 'Choose slider images', button: { text: 'Add slides' }, multiple: true });
			frame.on('select', function () {
				const gallery = block.querySelector('.kidia-hero-gallery__items');
				if (!gallery) return;
				const blockIndex = getBlocks().indexOf(block);
				frame.state().get('selection').each(function (model) {
					const attachment = model.toJSON();
					if (!attachment?.url) return;
					const itemIndex = gallery.querySelectorAll('.kidia-hero-gallery__item').length;
					const item = document.createElement('div');
					item.className = 'kidia-hero-gallery__item';
					const fields = { id: 'slide_' + Date.now().toString(36) + '_' + itemIndex, enabled: '1', image_url: attachment.url, title: attachment.title || '', subtitle: '', action_type: '', action_value: '' };
					const image = document.createElement('img'); image.src = attachment.url; image.alt = '';
					item.appendChild(image);
					Object.keys(fields).forEach(function (fieldName) {
						const input = document.createElement('input'); input.type = 'hidden'; input.dataset.heroField = fieldName;
						input.name = 'blocks[' + blockIndex + '][settings][items][' + itemIndex + '][' + fieldName + ']'; input.value = fields[fieldName]; item.appendChild(input);
					});
					const remove = document.createElement('button'); remove.type = 'button'; remove.className = 'button-link-delete kidia-hero-gallery__remove'; remove.textContent = 'Remove'; item.appendChild(remove);
					gallery.appendChild(item);
				});
				updateIndexes(); markDirty(); renderPreview();
			});
			frame.open();
			return;
		}

		if (target.closest('.kidia-hero-gallery__remove')) {
			target.closest('.kidia-hero-gallery__item')?.remove();
			updateIndexes(); markDirty(); renderPreview();
			return;
		}

	});

	builder.addEventListener('change', function (event) {
		const target = event.target;
		if (!(target instanceof HTMLElement)) return;
		if (target.classList.contains('kidia-block-status-select')) {
			const block = target.closest('.kidia-builder-block');
			const hidden = block?.querySelector('.kidia-block-status');
			const badge = block?.querySelector('.kidia-builder-status');
			if (hidden) hidden.value = target.value;
			if (badge) {
				badge.textContent = target.value === 'published' ? (labels.published || 'Published') : (labels.draft || 'Draft');
				badge.className = 'kidia-builder-status kidia-builder-status--' + target.value;
			}
		}
		markDirty();
		renderPreview();
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
		renderPreview();
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
		renderPreview();
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
		if (blocksPayload) {
			blocksPayload.value = JSON.stringify(serializeBlocks());
		}
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
	renderPreview();
})();
