(function (global) {
	'use strict';

	const categories = {
		visual: ['app_header', 'hero_slider', 'image_banner', 'banner_grid', 'video_banner'],
		products: ['category_grid', 'product_carousel', 'product_grid', 'brand_carousel', 'bundle_collection'],
		content: ['section_header', 'text_block', 'quick_links'],
		'marketing-layout': ['promo_strip', 'coupon_banner', 'countdown', 'divider', 'spacer']
	};
	const categoryLabels = {
		visual: 'Visual', products: 'Products', content: 'Content', 'marketing-layout': 'Marketing & Layout'
	};

	function node(tag, className, text) {
		const element = document.createElement(tag);
		if (className) element.className = className;
		if (text !== undefined) element.textContent = text;
		return element;
	}
	function categoryFor(type) {
		return Object.keys(categories).find((key) => categories[key].includes(type)) || 'content';
	}
	function setAttributes(element, attributes) {
		Object.entries(attributes || {}).forEach(([key, value]) => {
			if (value === undefined || value === null) return;
			if (key === 'checked') element.checked = Boolean(value);
			else element.setAttribute(key, String(value));
		});
		return element;
	}
	function fieldControl(field, value, name) {
		let control;
		if (field.type === 'select') {
			control = document.createElement('select');
			Object.entries(field.options || {}).forEach(([optionValue, label]) => {
				const option = new Option(String(label), optionValue);
				option.selected = String(value ?? '') === String(optionValue);
				control.appendChild(option);
			});
		} else {
			control = document.createElement('input');
			control.type = field.type === 'image' ? 'url' : (field.type || 'text');
			if (field.type === 'checkbox') {
				control.value = '1';
				control.checked = Boolean(value);
			} else {
				control.value = value ?? '';
			}
			['min', 'max', 'step'].forEach((attribute) => {
				if (field[attribute] !== undefined) control.setAttribute(attribute, field[attribute]);
			});
		}
		control.name = name;
		control.dataset.setting = field.key;
		return control;
	}
	function settingsField(field, value, name) {
		const wrapper = node('div', 'mobishop-builder-field');
		if (field.full_width) wrapper.classList.add('mobishop-builder-field--full');
		const label = node('label', '', field.label || field.key.replaceAll('_', ' '));
		const control = fieldControl(field, value, name);
		if (field.type === 'checkbox') {
			label.textContent = '';
			label.append(control, document.createTextNode(field.label || field.key.replaceAll('_', ' ')));
			wrapper.append(label);
		} else {
			wrapper.append(label, control);
		}
		return wrapper;
	}
	function hidden(name, value, className) {
		return setAttributes(node('input', className), { type: 'hidden', name, value: value ?? '' });
	}
	function actionButton(className, icon, label) {
		const button = setAttributes(node('button', 'button ' + className), { type: 'button' });
		button.append(node('span', 'dashicons ' + icon), document.createTextNode(label || ''));
		return button;
	}
	function fixedChrome(part, payload) {
		const card = node('section', 'mobishop-fixed-chrome-card is-collapsed');
		card.dataset.chromePart = part;
		const header = node('div', 'mobishop-fixed-chrome-card__header');
		header.append(node('strong', '', part === 'header' ? 'Application Header' : 'Application Footer'));
		const actions = node('div', 'mobishop-card-actions');
		actions.append(actionButton('mobishop-fixed-chrome-expand mobishop-card-action mobishop-card-action--expand', 'dashicons-arrow-down-alt2', ''));
		header.append(actions);
		const body = node('div', 'mobishop-fixed-chrome-card__body');
		body.append(node('p', '', 'Shared ' + part + ' settings'));
		card.append(header, body);
		if (payload && payload.enabled === false) card.classList.add('is-disabled');
		return card;
	}
	function blockCard(block, index, schemas) {
		const definition = schemas[block.type] || { title: block.type, fields: [], defaults: {} };
		const settings = { ...(definition.defaults || {}), ...(block.settings || {}) };
		const card = node('div', 'mobishop-builder-block is-collapsed');
		card.draggable = true;
		card.dataset.type = block.type;
		card.dataset.libraryId = block.library_id || block.id;
		card.dataset.label = definition.title;
		card.dataset.elementCategory = categoryFor(block.type);
		const header = node('div', 'mobishop-builder-block__header');
		const left = node('div', 'mobishop-builder-block__left');
		left.append(node('span', 'dashicons dashicons-move mobishop-builder-drag'));
		const icon = node('span', 'mobishop-builder-block__icon');
		icon.append(node('span', 'dashicons ' + (definition.icon || 'dashicons-screenoptions')));
		const title = node('div', 'mobishop-builder-block__title');
		title.append(node('strong', 'mobishop-block-name', block.name || definition.title));
		left.append(icon, title);
		const actions = node('div', 'mobishop-builder-block__actions mobishop-card-actions');
		actions.append(
			actionButton('mobishop-duplicate-block mobishop-card-action mobishop-card-action--primary', 'dashicons-admin-page', 'Duplicate'),
			actionButton('mobishop-delete-block mobishop-card-action mobishop-card-action--secondary', 'dashicons-trash', 'Remove'),
			actionButton('mobishop-toggle-block-settings mobishop-card-action mobishop-card-action--expand', 'dashicons-arrow-down-alt2', '')
		);
		const toggle = node('label', 'mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle');
		toggle.append(
			setAttributes(node('input'), { type: 'checkbox', name: `blocks[${index}][enabled]`, value: 1, checked: block.enabled !== false }),
			node('span', 'mobishop-builder-switch__track'), node('span', 'mobishop-builder-switch__state')
		);
		actions.append(toggle);
		header.append(left, actions);

		const body = node('div', 'mobishop-builder-block__body');
		body.append(
			hidden(`blocks[${index}][id]`, block.id, 'mobishop-block-id'),
			hidden(`blocks[${index}][library_id]`, block.library_id || block.id, 'mobishop-block-library-id'),
			hidden(`blocks[${index}][type]`, block.type, 'mobishop-block-type'),
			hidden(`blocks[${index}][order]`, index + 1, 'mobishop-block-order'),
			hidden(`blocks[${index}][status]`, block.status || 'draft', 'mobishop-block-status')
		);
		const essentials = node('div', 'mobishop-builder-essentials');
		const nameField = node('div', 'mobishop-builder-field mobishop-builder-field--name');
		nameField.append(node('label', '', 'Element Name'), setAttributes(node('input', 'mobishop-block-name-input'), { type: 'text', name: `blocks[${index}][name]`, value: block.name || definition.title }));
		const visibility = node('div', 'mobishop-builder-field mobishop-builder-field--visibility');
		const status = setAttributes(document.createElement('select'), { class: 'mobishop-block-status-select' });
		['published', 'draft'].forEach((value) => { const option = new Option(value === 'published' ? 'Published' : 'Draft', value); option.selected = value === (block.status || 'draft'); status.append(option); });
		visibility.append(node('label', '', 'Visibility'), status);
		essentials.append(nameField, visibility);
		const inline = node('div', 'mobishop-builder-inline-settings');
		const heading = node('div', 'mobishop-builder-settings-heading');
		heading.append(node('span', 'dashicons dashicons-admin-generic'), node('strong', '', 'Element Settings'));
		const content = node('div', 'mobishop-builder-settings-content');
		[
			{ key: 'margin_top', label: 'Merge up', type: 'number', min: 0, max: 80, default: 0 },
			{ key: 'margin_bottom', label: 'Merge down', type: 'number', min: 0, max: 80, default: 0 },
			{ key: 'space_up', label: 'Space up', type: 'number', min: 0, max: 80, default: 0 },
			{ key: 'space_down', label: 'Space down', type: 'number', min: 0, max: 80, default: 0 },
			{ key: 'block_background', label: 'Background color', type: 'color', default: '#FFFFFF' }
		].concat(definition.fields || []).forEach((field) => {
			content.append(settingsField(field, settings[field.key] ?? field.default, `blocks[${index}][settings][${field.key}]`));
		});
		inline.append(heading, content);
		body.append(essentials, inline);
		card.append(header, body);
		return card;
	}

	async function renderHomeBuilder(root, payload, api) {
		const schema = payload.blockSchema || { blocks: {} };
		const schemas = schema.blocks || {};
		const state = { blocks: Array.isArray(payload.blocks) ? payload.blocks.map((block) => structuredClone(block)) : [] };
		root.replaceChildren();
		const wrap = node('div', 'wrap mobishop-builder-wrap');
		const workspace = node('div', 'mobishop-builder-workspace');
		const preview = setAttributes(node('aside', 'mobishop-preview'), { 'aria-label': 'Live mobile preview' });
		const device = node('div', 'mobishop-preview__device');
		const screen = node('div', 'mobishop-preview__screen');
		if (payload.previewUrl) screen.append(setAttributes(node('iframe', 'mobishop-flutter-preview'), { id: 'mobishop-flutter-preview', title: 'Flutter mobile preview', src: payload.previewUrl }));
		screen.append(setAttributes(node('div', 'mobishop-preview__content mobishop-legacy-preview-fallback'), { id: 'mobishop-preview-content' }));
		device.append(screen); preview.append(device);
		const editor = node('div', 'mobishop-builder-editor');
		const form = setAttributes(node('form'), { id: 'mobishop-home-builder-form', novalidate: '' });
		form.append(hidden('blocks_payload', '', 'mobishop-home-builder-payload'));
		form.lastChild.id = 'mobishop-home-builder-payload';
		const toolbar = node('div', 'mobishop-builder-toolbar mobishop-shared-builder-toolbar mobishop-builder-toolbar--home');
		toolbar.append(actionButton('button-primary mobishop-builder-toolbar__save', 'dashicons-saved', 'Save Home Layout'));
		toolbar.lastChild.type = 'submit';
		const add = actionButton('mobishop-builder-toolbar__add', 'dashicons-plus-alt2', 'Add Element'); add.id = 'mobishop-add-element'; toolbar.append(add);
		toolbar.append(actionButton('mobishop-collapse-all', 'dashicons-arrow-up-alt2', 'Collapse All'), actionButton('mobishop-expand-all', 'dashicons-arrow-down-alt2', 'Expand All'));
		const scroll = node('div', 'mobishop-builder-cards-scroll'); scroll.dataset.mobishopBuilderCardsScroll = '';
		const list = node('div', 'mobishop-builder-list'); list.id = 'mobishop-home-builder';
		function paintBlocks() {
			list.replaceChildren();
			if (!state.blocks.length) {
				const empty = node('div', 'mobishop-builder-empty'); empty.id = 'mobishop-builder-empty';
				empty.append(node('span', 'dashicons dashicons-screenoptions'), node('h2', '', 'No elements on the Home Page'), node('p', '', 'Add an element to start building the application Home Page.'));
				const first = actionButton('button-primary', '', 'Add First Element'); first.dataset.mobishopOpenPicker = ''; empty.append(first); list.append(empty); return;
			}
			state.blocks.forEach((block, index) => list.append(blockCard(block, index, schemas)));
		}
		scroll.append(fixedChrome('header', payload.chrome && payload.chrome.header), list, fixedChrome('footer', payload.chrome && payload.chrome.footer));
		form.append(toolbar, scroll); editor.append(form); workspace.append(preview, editor); wrap.append(workspace); root.append(wrap);

		const picker = setAttributes(node('div', 'mobishop-element-picker'), { id: 'mobishop-element-picker', hidden: '', 'aria-hidden': 'true' });
		const panel = setAttributes(node('div', 'mobishop-element-picker__panel'), { role: 'dialog', 'aria-modal': 'true' });
		const filter = node('nav', 'mobishop-element-category-filter');
		[['all', 'All'], ...Object.entries(categoryLabels)].forEach(([key, label], index) => { const button = actionButton(index ? '' : 'is-active', '', label); button.dataset.mobishopElementCategory = key; filter.append(button); });
		const pickerHeader = node('div', 'mobishop-element-picker__header'); pickerHeader.append(node('h2', '', 'Add Element'));
		const close = actionButton('button-link mobishop-element-picker__close', 'dashicons-no-alt', ''); close.dataset.mobishopClosePicker = ''; pickerHeader.append(close);
		const search = setAttributes(node('input', 'regular-text'), { type: 'search', id: 'mobishop-element-picker-search', placeholder: 'Search elements...' });
		const pickerContent = node('div', 'mobishop-element-picker__content');
		Object.entries(schemas).forEach(([type, definition]) => {
			const choice = setAttributes(node('button', 'mobishop-element-group'), { type: 'button' });
			choice.dataset.elementGroup = type; choice.dataset.elementCategory = categoryFor(type); choice.dataset.blockType = type; choice.dataset.blockLabel = definition.title;
			const identity = node('span', 'mobishop-element-group__identity'); identity.append(node('span', 'dashicons ' + definition.icon), node('strong', '', definition.title), node('small', '', categoryLabels[categoryFor(type)])); choice.append(identity); pickerContent.append(choice);
		});
		panel.append(filter, pickerHeader, node('div', 'mobishop-element-picker__toolbar'), pickerContent); panel.children[2].append(search); picker.append(node('div', 'mobishop-element-picker__overlay'), panel); root.append(picker);

		function showPicker(show) { picker.hidden = !show; picker.setAttribute('aria-hidden', show ? 'false' : 'true'); }
		root.addEventListener('click', (event) => {
			if (event.target.closest('#mobishop-add-element,[data-mobishop-open-picker]')) return showPicker(true);
			if (event.target.closest('[data-mobishop-close-picker],.mobishop-element-picker__overlay')) return showPicker(false);
			const choice = event.target.closest('[data-block-type]');
			if (choice) {
				const type = choice.dataset.blockType; const definition = schemas[type];
				state.blocks.push({ id: `${type}_${crypto.randomUUID()}`, type, name: definition.title, enabled: true, order: state.blocks.length + 1, status: 'draft', settings: structuredClone(definition.defaults || {}) });
				paintBlocks(); showPicker(false); return;
			}
			const card = event.target.closest('.mobishop-builder-block'); if (!card) return;
			const cards = Array.from(list.querySelectorAll('.mobishop-builder-block')); const index = cards.indexOf(card);
			if (event.target.closest('.mobishop-toggle-block-settings')) card.classList.toggle('is-collapsed');
			if (event.target.closest('.mobishop-delete-block')) { state.blocks.splice(index, 1); paintBlocks(); }
			if (event.target.closest('.mobishop-duplicate-block')) { const copy = structuredClone(state.blocks[index]); copy.id = `${copy.type}_${crypto.randomUUID()}`; copy.name += ' Copy'; state.blocks.splice(index + 1, 0, copy); paintBlocks(); }
		});
		search.addEventListener('input', () => {
			const query = search.value.trim().toLowerCase();
			pickerContent.querySelectorAll('[data-block-type]').forEach((choice) => { choice.hidden = !choice.textContent.toLowerCase().includes(query); });
		});
		form.addEventListener('submit', async (event) => {
			event.preventDefault();
			const formData = new FormData(form);
			state.blocks.forEach((block, index) => {
				block.name = formData.get(`blocks[${index}][name]`) || block.name;
				block.enabled = formData.has(`blocks[${index}][enabled]`);
				(schema.blocks[block.type].fields || []).forEach((field) => {
					const key = `blocks[${index}][settings][${field.key}]`; const raw = formData.get(key);
					block.settings[field.key] = field.type === 'checkbox' ? formData.has(key) : field.type === 'number' ? Number(raw) : raw;
				});
			});
			await api.save('home-builder', { blocks: state.blocks, chrome: payload.chrome || {} });
		});
		paintBlocks();
	}

	global.MobiShopSharedRenderers = global.MobiShopSharedRenderers || {};
	global.MobiShopSharedRenderers['home-builder'] = renderHomeBuilder;
})(window);

