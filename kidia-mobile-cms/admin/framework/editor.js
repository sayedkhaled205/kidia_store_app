(function () {
	'use strict';

	const tabs = document.querySelectorAll(
		'.kidia-editor-tab-button'
	);

	const panels = document.querySelectorAll(
		'.kidia-editor-tab-panel'
	);

	function updateConditionalFields() {
		document.querySelectorAll('[data-show-if-key]').forEach(function (field) {
			const source = document.getElementById(
				'kidia-editor-field-' + (field.dataset.showIfKey || '')
			);
			const visible = !!source && String(source.value) === String(field.dataset.showIfValue || '');
			field.hidden = !visible;
			field.setAttribute('aria-hidden', visible ? 'false' : 'true');
		});
	}

	document.addEventListener('change', updateConditionalFields);

	function syncEntityPicker(picker) {
		const value = picker.querySelector('.kidia-entity-picker__value');
		const ids = Array.from(
			picker.querySelectorAll('.kidia-entity-picker__selected [data-id]')
		).map(function (item) {
			return item.dataset.id || '';
		}).filter(Boolean);

		if (value) {
			value.value = ids.join(',');
		}
	}

	document.addEventListener('click', function (event) {
		const target = event.target;

		if (!(target instanceof HTMLElement)) {
			return;
		}

		const addButton = target.closest('.kidia-entity-picker__add');
		if (addButton) {
			const picker = addButton.closest('.kidia-entity-picker');
			const select = picker?.querySelector('.kidia-entity-picker__select');
			const list = picker?.querySelector('.kidia-entity-picker__selected');

			if (!picker || !select || !list || !select.value) {
				return;
			}

			if (picker.dataset.multiple !== '1') {
				list.replaceChildren();
			}

			if (!list.querySelector('[data-id="' + CSS.escape(select.value) + '"]')) {
				const item = document.createElement('li');
				item.dataset.id = select.value;

				const label = document.createElement('span');
				label.textContent = select.options[select.selectedIndex]?.textContent || select.value;

				const remove = document.createElement('button');
				remove.type = 'button';
				remove.className = 'button-link-delete kidia-entity-picker__remove';
				remove.setAttribute('aria-label', 'Remove');
				remove.textContent = '×';

				item.append(label, remove);
				list.appendChild(item);
			}

			select.value = '';
			syncEntityPicker(picker);
			return;
		}

		const removeButton = target.closest('.kidia-entity-picker__remove');
		if (removeButton) {
			const picker = removeButton.closest('.kidia-entity-picker');
			removeButton.closest('[data-id]')?.remove();

			if (picker) {
				syncEntityPicker(picker);
			}
		}
	});

	function activateTab(tabId) {

		tabs.forEach(function (button) {

			const active =
				button.dataset.tab === tabId;

			button.classList.toggle(
				'is-active',
				active
			);

			button.setAttribute(
				'aria-selected',
				active ? 'true' : 'false'
			);

		});

		panels.forEach(function (panel) {

			const active =
				panel.dataset.tabPanel === tabId;

			panel.classList.toggle(
				'is-active',
				active
			);

			panel.hidden = !active;

		});

	}

	updateConditionalFields();

	tabs.forEach(function (button) {

		button.addEventListener(
			'click',
			function () {

				activateTab(
					button.dataset.tab
				);

			}
		);

	});

	const mediaButtons =
		document.querySelectorAll(
			'.kidia-editor-select-media'
		);

	mediaButtons.forEach(function (button) {

		button.addEventListener(
			'click',
			function () {

				if (
					typeof wp === 'undefined'
					|| !wp.media
				) {
					return;
				}

				const target =
					document.getElementById(
						button.dataset.target
					);

				if (!target) {
					return;
				}

				const mediaType = button.dataset.mediaType || '';

				const frame = wp.media({

					title: 'Select Media',

					button: {
						text: 'Use'
					},

					multiple: false,

					library: mediaType ? { type: mediaType } : undefined

				});
								frame.on(
                					'select',
                					function () {

                						const attachment =
                							frame
                								.state()
                								.get('selection')
                								.first()
                								.toJSON();

                						target.value =
                							attachment.url || '';

                						const preview =
                							document.querySelector(
                								'[data-preview-for="' +
                								button.dataset.target +
                								'"]'
                							);

                						if (preview) {

                							preview.src =
                								attachment.url || '';

                							preview.hidden =
                								!attachment.url;

                						}

                					}
                				);

                				frame.open();

                			}
                		);

                	});

                	document.querySelectorAll(
                		'.kidia-editor-remove-media'
                	).forEach(function (button) {

                		button.addEventListener(
                			'click',
                			function () {

                				const target =
                					document.getElementById(
                						button.dataset.target
                					);

                				if (!target) {
                					return;
                				}

                				target.value = '';

                				const preview =
                					document.querySelector(
                						'[data-preview-for="' +
                						button.dataset.target +
                						'"]'
                					);

                				if (preview) {

                					preview.src = '';

                					preview.hidden = true;

                				}

                			}
                		);

                	});



                function reindexGallery(gallery) {
                	const key = gallery.dataset.fieldKey || 'items';
                	gallery.querySelectorAll(
                		'.kidia-editor-gallery__item'
                	).forEach(function (item, index) {
                		const input = item.querySelector('input[type="hidden"]');
                		if (input) {
                			input.name =
                				'settings[' + key + '][' + index + '][image_url]';
                		}
                	});
                }

				let draggedGalleryItem = null;

				document.addEventListener('dragstart', function (event) {
					const target = event.target;
					if (!(target instanceof HTMLElement)) {
						return;
					}

					draggedGalleryItem = target.closest('.kidia-editor-gallery__item');
					if (!draggedGalleryItem) {
						return;
					}

					draggedGalleryItem.classList.add('is-dragging');
					if (event.dataTransfer) {
						event.dataTransfer.effectAllowed = 'move';
						event.dataTransfer.setData('text/plain', '');
					}
				});

				document.addEventListener('dragover', function (event) {
					if (!draggedGalleryItem) {
						return;
					}

					const target = event.target;
					if (!(target instanceof HTMLElement)) {
						return;
					}

					const over = target.closest('.kidia-editor-gallery__item');
					if (!over || over === draggedGalleryItem || over.parentElement !== draggedGalleryItem.parentElement) {
						return;
					}

					event.preventDefault();
					const rect = over.getBoundingClientRect();
					const after = event.clientX > rect.left + rect.width / 2;
					over.insertAdjacentElement(after ? 'afterend' : 'beforebegin', draggedGalleryItem);
				});

				document.addEventListener('dragend', function () {
					if (!draggedGalleryItem) {
						return;
					}

					const gallery = draggedGalleryItem.closest('.kidia-editor-gallery');
					draggedGalleryItem.classList.remove('is-dragging');
					draggedGalleryItem = null;
					if (gallery) {
						reindexGallery(gallery);
					}
				});

                document.addEventListener('click', function (event) {
                	const target = event.target;

                	if (!(target instanceof HTMLElement)) {
                		return;
                	}

                	const removeButton = target.closest(
                		'.kidia-editor-gallery__remove'
                	);

                	if (removeButton) {
                		const gallery = removeButton.closest(
                			'.kidia-editor-gallery'
                		);
                		removeButton.closest(
                			'.kidia-editor-gallery__item'
                		)?.remove();
                		if (gallery) {
                			reindexGallery(gallery);
                		}
                		return;
                	}

                	const selectButton = target.closest(
                		'.kidia-editor-gallery__select'
                	);

                	if (!selectButton || typeof wp === 'undefined' || !wp.media) {
                		return;
                	}

                	const gallery = selectButton.closest(
                		'.kidia-editor-gallery'
                	);

                	if (!gallery) {
                		return;
                	}

                	const items = gallery.querySelector(
                		'.kidia-editor-gallery__items'
                	);

                	const frame = wp.media({
                		title: 'Select Images',
                		button: { text: 'Add Images' },
                		library: { type: 'image' },
                		multiple: true
                	});

                	frame.on('select', function () {
                		frame.state().get('selection').each(function (model) {
                			const attachment = model.toJSON();
                			if (!attachment.url || !items) {
                				return;
                			}

                			const item = document.createElement('div');
							item.className = 'kidia-editor-gallery__item';
							item.draggable = true;

							const drag = document.createElement('span');
							drag.className = 'dashicons dashicons-move kidia-editor-gallery__drag';
							drag.setAttribute('aria-hidden', 'true');

                			const image = document.createElement('img');
                			image.src = attachment.url;
                			image.alt = '';

                			const input = document.createElement('input');
                			input.type = 'hidden';
                			input.value = attachment.url;

                			const remove = document.createElement('button');
                			remove.type = 'button';
                			remove.className =
                				'button-link-delete kidia-editor-gallery__remove';
                			remove.textContent = 'Remove';

							item.append(drag, image, input, remove);
                			items.appendChild(item);
                		});

                		reindexGallery(gallery);
                	});

                	frame.open();
                });
                })();
