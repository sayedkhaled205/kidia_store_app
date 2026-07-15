(function () {
	'use strict';

	const config = window.kidiaEditor || {};
	const labels = config.labels || {};
	const editorForm = document.getElementById('kidia-editor-form');
	let formIsDirty = false;
	let draggedSlide = null;

	function label(key, fallback) {
		return typeof labels[key] === 'string' && labels[key]
			? labels[key]
			: fallback;
	}

	function activateTab(tabId) {
		document.querySelectorAll('.kidia-editor-tab-button').forEach(function (button) {
			const isActive = button.dataset.tab === tabId;
			button.classList.toggle('is-active', isActive);
			button.setAttribute('aria-selected', isActive ? 'true' : 'false');
		});

		document.querySelectorAll('.kidia-editor-tab-panel').forEach(function (panel) {
			const isActive = panel.dataset.tabPanel === tabId;
			panel.classList.toggle('is-active', isActive);
			panel.hidden = !isActive;
		});
	}

	function openMediaFrame(options, onSelect) {
		if (typeof window.wp === 'undefined' || !window.wp.media) {
			return;
		}

		const frame = window.wp.media({
			title: options.title || label('selectMedia', 'Select media'),
			button: {
				text: options.buttonText || label('useMedia', 'Use media')
			},
			library: options.library || undefined,
			multiple: Boolean(options.multiple)
		});

		frame.on('select', function () {
			const selection = frame.state().get('selection');
			const attachments = [];

			selection.each(function (model) {
				attachments.push(model.toJSON());
			});

			onSelect(attachments);
		});

		frame.open();
	}

	function updateGenericMedia(targetId, url) {
		const input = document.getElementById(targetId);

		if (!input) {
			return;
		}

		input.value = url || '';

		const preview = document.querySelector('[data-preview-for="' + targetId + '"]');

		if (preview) {
			preview.src = url || '';
			preview.hidden = !url;
		}

		input.dispatchEvent(new Event('change', { bubbles: true }));
	}

	function reindexGallery(gallery) {
		const key = gallery.dataset.fieldKey || 'items';

		gallery.querySelectorAll('.kidia-editor-gallery__item').forEach(function (item, index) {
			const input = item.querySelector('input[type="hidden"]');

			if (input) {
				input.name = 'settings[' + key + '][' + index + '][image_url]';
			}
		});
	}

	function createGalleryItem(url) {
		const item = document.createElement('div');
		item.className = 'kidia-editor-gallery__item';

		const image = document.createElement('img');
		image.src = url;
		image.alt = '';

		const input = document.createElement('input');
		input.type = 'hidden';
		input.value = url;

		const remove = document.createElement('button');
		remove.type = 'button';
		remove.className = 'button-link-delete kidia-editor-gallery__remove';
		remove.textContent = label('remove', 'Remove');

		item.append(image, input, remove);
		return item;
	}

	function makeButton(className, text, ariaLabel) {
		const button = document.createElement('button');
		button.type = 'button';
		button.className = className;
		button.textContent = text;

		if (ariaLabel) {
			button.setAttribute('aria-label', ariaLabel);
		}

		return button;
	}

	function makeLabel(text, control) {
		const fieldLabel = document.createElement('label');
		const caption = document.createElement('span');
		caption.textContent = text;
		fieldLabel.append(caption, control);
		return fieldLabel;
	}

	function makeSlideId() {
		if (window.crypto && typeof window.crypto.randomUUID === 'function') {
			return 'hero_slide_' + window.crypto.randomUUID().replace(/-/g, '');
		}

		return 'hero_slide_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 10);
	}

	function createSlide(url) {
		const slide = document.createElement('article');
		slide.className = 'kidia-editor-slide';
		slide.draggable = true;

		const header = document.createElement('header');
		header.className = 'kidia-editor-slide__header';

		const handle = document.createElement('span');
		handle.className = 'dashicons dashicons-move kidia-editor-slide__handle';
		handle.setAttribute('aria-hidden', 'true');

		const number = document.createElement('strong');
		number.className = 'kidia-editor-slide__number';

		const headerActions = document.createElement('div');
		headerActions.className = 'kidia-editor-slide__header-actions';
		headerActions.append(
			makeButton('button-link kidia-editor-slide__move-up', '↑', label('moveUp', 'Move slide up')),
			makeButton('button-link kidia-editor-slide__move-down', '↓', label('moveDown', 'Move slide down')),
			makeButton('button-link-delete kidia-editor-slide__remove', label('remove', 'Remove'))
		);
		header.append(handle, number, headerActions);

		const grid = document.createElement('div');
		grid.className = 'kidia-editor-slide__grid';

		const media = document.createElement('div');
		media.className = 'kidia-editor-slide__media';

		const image = document.createElement('img');
		image.dataset.slidePreview = '';
		image.src = url;
		image.alt = '';

		const placeholder = document.createElement('div');
		placeholder.className = 'kidia-editor-slide__placeholder';
		placeholder.hidden = true;
		const placeholderIcon = document.createElement('span');
		placeholderIcon.className = 'dashicons dashicons-format-image';
		placeholderIcon.setAttribute('aria-hidden', 'true');
		placeholder.append(placeholderIcon);

		const imageInput = document.createElement('input');
		imageInput.type = 'hidden';
		imageInput.dataset.slideField = 'image_url';
		imageInput.value = url;

		const idInput = document.createElement('input');
		idInput.type = 'hidden';
		idInput.dataset.slideField = 'id';
		idInput.value = makeSlideId();

		const mediaActions = document.createElement('div');
		mediaActions.className = 'kidia-editor-slide__media-actions';
		mediaActions.append(
			makeButton('button kidia-editor-slide__select-media', label('chooseImage', 'Choose image')),
			makeButton('button-link-delete kidia-editor-slide__remove-media', label('clearImage', 'Clear image'))
		);
		media.append(image, placeholder, imageInput, idInput, mediaActions);

		const fields = document.createElement('div');
		fields.className = 'kidia-editor-slide__fields';

		const titleInput = document.createElement('input');
		titleInput.type = 'text';
		titleInput.dataset.slideField = 'title';

		const subtitleInput = document.createElement('textarea');
		subtitleInput.rows = 2;
		subtitleInput.dataset.slideField = 'subtitle';

		const actionType = document.createElement('select');
		actionType.dataset.slideField = 'action_type';
		[
			['', label('noAction', 'No action')],
			['product', label('product', 'Product')],
			['category', label('category', 'Category')],
			['collection', label('collection', 'Collection')],
			['brand', label('brand', 'Brand')],
			['brands', label('allBrands', 'All brands')],
			['search', label('search', 'Search')],
			['external', label('externalUrl', 'External URL')]
		].forEach(function (optionData) {
			const option = document.createElement('option');
			option.value = optionData[0];
			option.textContent = optionData[1];
			actionType.append(option);
		});

		const actionValue = document.createElement('input');
		actionValue.type = 'text';
		actionValue.dataset.slideField = 'action_value';
		actionValue.placeholder = label('actionValuePlaceholder', 'ID, search term or URL');

		const actionRow = document.createElement('div');
		actionRow.className = 'kidia-editor-slide__action-row';
		actionRow.append(
			makeLabel(label('tapAction', 'Tap action'), actionType),
			makeLabel(label('actionValue', 'Action value'), actionValue)
		);

		const enabledLabel = document.createElement('label');
		enabledLabel.className = 'kidia-editor-slide__enabled';
		const enabledFallback = document.createElement('input');
		enabledFallback.type = 'hidden';
		enabledFallback.dataset.slideField = 'enabled';
		enabledFallback.value = '0';
		const enabled = document.createElement('input');
		enabled.type = 'checkbox';
		enabled.dataset.slideField = 'enabled';
		enabled.value = '1';
		enabled.checked = true;
		const enabledText = document.createElement('span');
		enabledText.textContent = label('showSlide', 'Show this slide');
		enabledLabel.append(enabledFallback, enabled, enabledText);

		fields.append(
			makeLabel(label('title', 'Title'), titleInput),
			makeLabel(label('subtitle', 'Subtitle'), subtitleInput),
			actionRow,
			enabledLabel
		);
		grid.append(media, fields);
		slide.append(header, grid);
		return slide;
	}

	function updateSlideImage(slide, url) {
		const input = slide.querySelector('[data-slide-field="image_url"]');
		const preview = slide.querySelector('[data-slide-preview]');
		const placeholder = slide.querySelector('.kidia-editor-slide__placeholder');

		if (input) {
			input.value = url || '';
		}

		if (preview) {
			preview.src = url || '';
			preview.hidden = !url;
		}

		if (placeholder) {
			placeholder.hidden = Boolean(url);
		}

		formIsDirty = true;
	}

	function reindexSlides(slides) {
		const key = slides.dataset.fieldKey || 'items';
		const slideItems = slides.querySelectorAll('.kidia-editor-slide');

		slideItems.forEach(function (slide, index) {
			slide.querySelectorAll('[data-slide-field]').forEach(function (control) {
				control.name = 'settings[' + key + '][' + index + '][' + control.dataset.slideField + ']';
			});

			const number = slide.querySelector('.kidia-editor-slide__number');
			if (number) {
				number.textContent = label('slide', 'Slide') + ' ' + (index + 1);
			}

			const moveUp = slide.querySelector('.kidia-editor-slide__move-up');
			const moveDown = slide.querySelector('.kidia-editor-slide__move-down');
			if (moveUp) {
				moveUp.disabled = index === 0;
			}
			if (moveDown) {
				moveDown.disabled = index === slideItems.length - 1;
			}
		});
	}

	function moveSlide(slide, direction) {
		const sibling = direction < 0 ? slide.previousElementSibling : slide.nextElementSibling;

		if (!sibling) {
			return;
		}

		if (direction < 0) {
			slide.parentElement.insertBefore(slide, sibling);
		} else {
			slide.parentElement.insertBefore(sibling, slide);
		}

		reindexSlides(slide.closest('.kidia-editor-slides'));
		formIsDirty = true;
	}

	document.addEventListener('click', function (event) {
		const target = event.target;

		if (!(target instanceof Element)) {
			return;
		}

		const tabButton = target.closest('.kidia-editor-tab-button');
		if (tabButton) {
			activateTab(tabButton.dataset.tab);
			return;
		}

		const genericSelect = target.closest('.kidia-editor-select-media');
		if (genericSelect) {
			openMediaFrame({ multiple: false }, function (attachments) {
				const attachment = attachments[0] || {};
				updateGenericMedia(genericSelect.dataset.target, attachment.url || '');
			});
			return;
		}

		const genericRemove = target.closest('.kidia-editor-remove-media');
		if (genericRemove) {
			updateGenericMedia(genericRemove.dataset.target, '');
			return;
		}

		const galleryRemove = target.closest('.kidia-editor-gallery__remove');
		if (galleryRemove) {
			const gallery = galleryRemove.closest('.kidia-editor-gallery');
			galleryRemove.closest('.kidia-editor-gallery__item').remove();
			reindexGallery(gallery);
			formIsDirty = true;
			return;
		}

		const gallerySelect = target.closest('.kidia-editor-gallery__select');
		if (gallerySelect) {
			const gallery = gallerySelect.closest('.kidia-editor-gallery');
			const items = gallery.querySelector('.kidia-editor-gallery__items');

			openMediaFrame({
				title: label('selectImages', 'Select images'),
				buttonText: label('addImages', 'Add images'),
				library: { type: 'image' },
				multiple: true
			}, function (attachments) {
				attachments.forEach(function (attachment) {
					if (attachment.url) {
						items.append(createGalleryItem(attachment.url));
					}
				});
				reindexGallery(gallery);
				formIsDirty = true;
			});
			return;
		}

		const addSlides = target.closest('.kidia-editor-slides__add');
		if (addSlides) {
			const slides = addSlides.closest('.kidia-editor-slides');
			const items = slides.querySelector('.kidia-editor-slides__items');

			openMediaFrame({
				title: label('selectImages', 'Select images'),
				buttonText: label('addSlides', 'Add slides'),
				library: { type: 'image' },
				multiple: true
			}, function (attachments) {
				attachments.forEach(function (attachment) {
					if (attachment.url) {
						items.append(createSlide(attachment.url));
					}
				});
				reindexSlides(slides);
				formIsDirty = true;
			});
			return;
		}

		const slide = target.closest('.kidia-editor-slide');
		if (!slide) {
			return;
		}

		if (target.closest('.kidia-editor-slide__remove')) {
			const slides = slide.closest('.kidia-editor-slides');
			slide.remove();
			reindexSlides(slides);
			formIsDirty = true;
			return;
		}

		if (target.closest('.kidia-editor-slide__move-up')) {
			moveSlide(slide, -1);
			return;
		}

		if (target.closest('.kidia-editor-slide__move-down')) {
			moveSlide(slide, 1);
			return;
		}

		if (target.closest('.kidia-editor-slide__select-media')) {
			openMediaFrame({ library: { type: 'image' }, multiple: false }, function (attachments) {
				const attachment = attachments[0] || {};
				updateSlideImage(slide, attachment.url || '');
			});
			return;
		}

		if (target.closest('.kidia-editor-slide__remove-media')) {
			updateSlideImage(slide, '');
		}
	});

	document.addEventListener('dragstart', function (event) {
		const slide = event.target instanceof Element
			? event.target.closest('.kidia-editor-slide')
			: null;

		if (!slide) {
			return;
		}

		draggedSlide = slide;
		slide.classList.add('is-dragging');
		event.dataTransfer.effectAllowed = 'move';
	});

	document.addEventListener('dragover', function (event) {
		const targetSlide = event.target instanceof Element
			? event.target.closest('.kidia-editor-slide')
			: null;

		if (!draggedSlide || !targetSlide || targetSlide === draggedSlide) {
			return;
		}

		if (targetSlide.parentElement !== draggedSlide.parentElement) {
			return;
		}

		event.preventDefault();
		const bounds = targetSlide.getBoundingClientRect();
		const after = event.clientY > bounds.top + (bounds.height / 2);
		targetSlide.parentElement.insertBefore(draggedSlide, after ? targetSlide.nextSibling : targetSlide);
	});

	document.addEventListener('dragend', function () {
		if (!draggedSlide) {
			return;
		}

		const slides = draggedSlide.closest('.kidia-editor-slides');
		draggedSlide.classList.remove('is-dragging');
		draggedSlide = null;
		reindexSlides(slides);
		formIsDirty = true;
	});

	if (editorForm) {
		editorForm.addEventListener('input', function () {
			formIsDirty = true;
		});
		editorForm.addEventListener('change', function () {
			formIsDirty = true;
		});
		editorForm.addEventListener('submit', function () {
			formIsDirty = false;
		});
	}

	window.addEventListener('beforeunload', function (event) {
		if (!formIsDirty) {
			return;
		}

		event.preventDefault();
		event.returnValue = '';
	});

	document.querySelectorAll('.kidia-editor-gallery').forEach(reindexGallery);
	document.querySelectorAll('.kidia-editor-slides').forEach(reindexSlides);
})();
