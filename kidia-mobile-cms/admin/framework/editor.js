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

                })();