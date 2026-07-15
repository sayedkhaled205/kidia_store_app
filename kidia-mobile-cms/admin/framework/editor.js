(function () {
	'use strict';

	const tabs = document.querySelectorAll(
		'.kidia-editor-tab-button'
	);

	const panels = document.querySelectorAll(
		'.kidia-editor-tab-panel'
	);

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

				const frame = wp.media({

					title: 'Select Media',

					button: {
						text: 'Use'
					},

					multiple: false

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

                			item.append(image, input, remove);
                			items.appendChild(item);
                		});

                		reindexGallery(gallery);
                	});

                	frame.open();
                });
                })();