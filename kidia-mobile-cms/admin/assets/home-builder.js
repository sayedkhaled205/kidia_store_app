(function () {
	'use strict';

	const builder =
		document.getElementById(
			'kidia-home-builder'
		);

	if (!builder) {
		return;
	}

	const picker =
		document.getElementById(
			'kidia-element-picker'
		);

	const createModal =
		document.getElementById(
			'kidia-create-element-modal'
		);

	const searchInput =
		document.getElementById(
			'kidia-element-picker-search'
		);

	const addButton =
		document.getElementById(
			'kidia-add-element'
		);

	const collapseButton =
		document.getElementById(
			'kidia-collapse-all'
		);

	const expandButton =
		document.getElementById(
			'kidia-expand-all'
		);

	let currentCreateType = '';
	function reindexHeroGallery(gallery) {
		const block = gallery.closest('.kidia-builder-block');
		if (!block) {
			return;
		}
		const blocks = Array.from(
			builder.querySelectorAll('.kidia-builder-block')
		);
		const blockIndex = blocks.indexOf(block);
		gallery.querySelectorAll('.kidia-hero-gallery__item').forEach(
			function (item, itemIndex) {
				const input = item.querySelector('input[type="hidden"]');
				if (input) {
					input.name = 'blocks[' + blockIndex + '][settings][items][' + itemIndex + '][image_url]';
				}
			}
		);
	}

	builder.addEventListener('click', function (event) {
		const target = event.target;
		if (!(target instanceof HTMLElement)) {
			return;
		}
		const remove = target.closest('.kidia-hero-gallery__remove');
		if (remove) {
			const gallery = remove.closest('.kidia-hero-gallery');
			remove.closest('.kidia-hero-gallery__item')?.remove();
			if (gallery) {
				reindexHeroGallery(gallery);
			}
			return;
		}
		const select = target.closest('.kidia-hero-gallery__select');
		if (!select || typeof wp === 'undefined' || !wp.media) {
			return;
		}
		const gallery = select.closest('.kidia-hero-gallery');
		const items = gallery?.querySelector('.kidia-hero-gallery__items');
		if (!gallery || !items) {
			return;
		}
		const frame = wp.media({
			title: 'Select Slider Images',
			button: { text: 'Add Images' },
			library: { type: 'image' },
			multiple: true
		});
		frame.on('select', function () {
			frame.state().get('selection').each(function (model) {
				const attachment = model.toJSON();
				if (!attachment.url) {
					return;
				}
				const item = document.createElement('div');
				item.className = 'kidia-hero-gallery__item';
				const image = document.createElement('img');
				image.src = attachment.url;
				image.alt = '';
				const input = document.createElement('input');
				input.type = 'hidden';
				input.value = attachment.url;
				const button = document.createElement('button');
				button.type = 'button';
				button.className = 'button-link-delete kidia-hero-gallery__remove';
				button.textContent = 'Remove';
				item.append(image, input, button);
				items.appendChild(item);
			});
			reindexHeroGallery(gallery);
		});
		frame.open();
	});


	function generateId(type) {

		return (
			type +
			'_' +
			Date.now() +
			'_' +
			Math.random()
				.toString(36)
				.substring(2, 8)
		);

	}

	function updateIndexes() {

		builder
			.querySelectorAll(
				'.kidia-builder-block'
			)
			.forEach(function (
				block,
				index
			) {

				block
					.querySelectorAll(
						'[name^="blocks["]'
					)
					.forEach(function (
						input
					) {

						input.name =
							input.name.replace(
								/blocks\[\d+]/,
								'blocks[' +
									index +
									']'
							);

					});

				const order =
					block.querySelector(
						'.kidia-block-order'
					);

				if (order) {
					order.value =
						index + 1;
				}

			});

	}

	function collapseAll() {

		builder
			.querySelectorAll(
				'.kidia-builder-block'
			)
			.forEach(function (
				block
			) {

				block.classList.add(
					'is-collapsed'
				);

			});

	}

	function expandAll() {

		builder
			.querySelectorAll(
				'.kidia-builder-block'
			)
			.forEach(function (
				block
			) {

				block.classList.remove(
					'is-collapsed'
				);

			});

	}

	function openPicker() {

		if (!picker) {
			return;
		}

		picker.hidden = false;

		document.body.classList.add(
			'kidia-picker-open'
		);

	}

	function closePicker() {

		if (!picker) {
			return;
		}

		picker.hidden = true;

		document.body.classList.remove(
			'kidia-picker-open'
		);

	}

	addButton?.addEventListener(
		'click',
		openPicker
	);

	document
		.querySelectorAll(
			'[data-kidia-open-picker]'
		)
		.forEach(function (
			button
		) {

			button.addEventListener(
				'click',
				openPicker
			);

		});

	document
		.querySelectorAll(
			'[data-kidia-close-picker]'
		)
		.forEach(function (
			button
		) {

			button.addEventListener(
				'click',
				closePicker
			);

		});

	collapseButton?.addEventListener(
		'click',
		collapseAll
	);

	expandButton?.addEventListener(
		'click',
		expandAll
	);
		function closeCreateModal() {

    		if (!createModal) {
    			return;
    		}

    		createModal.hidden = true;

    		createModal.setAttribute(
    			'aria-hidden',
    			'true'
    		);

    		currentCreateType = '';

    		document.body.classList.remove(
    			'kidia-modal-open'
    		);

    	}

    	function openCreateModal(
    		type,
    		label
    	) {

    		if (!createModal) {
    			return;
    		}

    		currentCreateType = type;

    		const title =
    			document.getElementById(
    				'kidia-create-element-title'
    			);

    		const nameInput =
    			document.getElementById(
    				'kidia-create-element-name'
    			);

    		const error =
    			document.getElementById(
    				'kidia-create-element-error'
    			);

    		if (title) {
    			title.textContent =
    				'Create ' + label;
    		}

    		if (nameInput) {

    			nameInput.value = '';

    			window.setTimeout(
    				function () {
    					nameInput.focus();
    				},
    				50
    			);

    		}

    		if (error) {
    			error.hidden = true;
    		}

    		createModal.hidden = false;

    		createModal.setAttribute(
    			'aria-hidden',
    			'false'
    		);

    		document.body.classList.add(
    			'kidia-modal-open'
    		);

    	}

    	document
    		.querySelectorAll(
    			'.kidia-create-element'
    		)
    		.forEach(function (
    			button
    		) {

    			button.addEventListener(
    				'click',
    				function () {

    					openCreateModal(
    						button.dataset.blockType || '',
    						button.dataset.blockLabel || ''
    					);

    				}
    			);

    		});

    	document
    		.querySelectorAll(
    			'[data-kidia-close-create-modal]'
    		)
    		.forEach(function (
    			button
    		) {

    			button.addEventListener(
    				'click',
    				closeCreateModal
    			);

    		});

    	function removeEmptyState() {

    		const empty =
    			document.getElementById(
    				'kidia-builder-empty'
    			);

    		if (empty) {
    			empty.remove();
    		}

    	}

    	function appendTemplate(
    		templateId,
    		type,
    		libraryId,
    		name
    	) {

    		const template =
    			document.getElementById(
    				templateId
    			);

    		if (!template) {
    			return null;
    		}

    		const index =
    			builder.querySelectorAll(
    				'.kidia-builder-block'
    			).length;

    		const blockId =
    			generateId(type);

    		const html =
    			template.innerHTML
    				.replaceAll(
    					'__INDEX__',
    					String(index)
    				)
    				.replaceAll(
    					'__ORDER__',
    					String(index + 1)
    				)
    				.replaceAll(
    					'__BLOCK_ID__',
    					blockId
    				)
    				.replaceAll(
    					'__LIBRARY_ID__',
    					libraryId || blockId
    				)
    				.replaceAll(
    					'__BLOCK_NAME__',
    					name || ''
    				);

    		removeEmptyState();

    		builder.insertAdjacentHTML(
    			'beforeend',
    			html
    		);

    		updateIndexes();

    		const blocks =
    			builder.querySelectorAll(
    				'.kidia-builder-block'
    			);

    		const newBlock =
    			blocks[
    				blocks.length - 1
    			];

    		if (newBlock) {

    			newBlock.classList.add(
    				'is-collapsed'
    			);

    			newBlock.scrollIntoView({
    				behavior: 'smooth',
    				block: 'center',
    			});

    		}

    		closePicker();

    		return newBlock || null;

    	}

    	document
    		.querySelectorAll(
    			'.kidia-add-library-element'
    		)
    		.forEach(function (
    			button
    		) {

    			button.addEventListener(
    				'click',
    				function () {

    					appendTemplate(
    						button.dataset.templateId || '',
    						button.dataset.blockType || '',
    						button.dataset.libraryId || '',
    						button.dataset.blockName || ''
    					);

    				}
    			);

    		});

    	const createSubmit =
    		document.getElementById(
    			'kidia-create-element-submit'
    		);

    	createSubmit?.addEventListener(
    		'click',
    		function () {

    			const nameInput =
    				document.getElementById(
    					'kidia-create-element-name'
    				);

    			const error =
    				document.getElementById(
    					'kidia-create-element-error'
    				);

    			const name =
    				nameInput
    					? nameInput.value.trim()
    					: '';

    			if (!name) {

    				if (error) {
    					error.hidden = false;
    				}

    				return;
    			}

    			if (!currentCreateType) {
    				return;
    			}

    			const templateId =
    				'tmpl-kidia-block-' +
    				currentCreateType;

    			const libraryId =
    				generateId(
    					currentCreateType
    				);

    			appendTemplate(
    				templateId,
    				currentCreateType,
    				libraryId,
    				name
    			);

    			closeCreateModal();

    		}
    	);

    	document.addEventListener(
    		'keydown',
    		function (event) {

    			if (event.key !== 'Escape') {
    				return;
    			}

    			closePicker();

    			closeCreateModal();

    		}
    	);
    		builder.addEventListener(
        		'click',
        		function (event) {

        			const target = event.target;

        			if (
        				!(target instanceof HTMLElement)
        			) {
        				return;
        			}

        			const block =
        				target.closest(
        					'.kidia-builder-block'
        				);

        			if (!block) {
        				return;
        			}

        			if (
        				target.closest(
        					'.kidia-toggle-block-settings'
        				)
        			) {

        				block.classList.toggle(
        					'is-collapsed'
        				);

        				return;
        			}

        			if (
        				target.closest(
        					'.kidia-delete-block'
        				)
        			) {

        				const label =
        					block.querySelector(
        						'.kidia-block-name'
        					)?.textContent?.trim()
        					|| 'this element';

        				const message =
        					window.kidiaHomeBuilder
        					?.labels
        					?.deleteConfirm
        					|| 'Delete this element?';

        				if (
        					!window.confirm(
        						message + '\n' + label
        					)
        				) {
        					return;
        				}

        				block.remove();

        				updateIndexes();

        				return;
        			}

        			if (
        				target.closest(
        					'.kidia-duplicate-block'
        				)
        			) {

        				const clone =
        					block.cloneNode(true);

        				const typeInput =
        					clone.querySelector(
        						'.kidia-block-type'
        					);

        				const idInput =
        					clone.querySelector(
        						'.kidia-block-id'
        					);

        				const libraryInput =
        					clone.querySelector(
        						'.kidia-block-library-id'
        					);

        				const type =
        					typeInput
        						? typeInput.value
        						: 'block';

        				const newId =
        					generateId(type);

        				if (idInput) {
        					idInput.value = newId;
        				}

        				if (libraryInput) {
        					libraryInput.value = newId;
        				}

        				clone.dataset.libraryId =
        					newId;

        				const nameInput =
        					clone.querySelector(
        						'.kidia-block-name-input'
        					);

        				const nameLabel =
        					clone.querySelector(
        						'.kidia-block-name'
        					);

        				if (nameInput) {

        					const copyName =
        						nameInput.value +
        						' Copy';

        					nameInput.value =
        						copyName;

        					if (nameLabel) {
        						nameLabel.textContent =
        							copyName;
        					}

        				}

        				clone.classList.add(
        					'is-collapsed'
        				);

        				block.insertAdjacentElement(
        					'afterend',
        					clone
        				);

        				updateIndexes();

        				return;
        			}

        			const editButton =
        				target.closest(
        					'.kidia-edit-library-item'
        				);

        			if (editButton) {

        				const type =
        					editButton.dataset.type
        					|| '';

        				const libraryId =
        					editButton.dataset.libraryId
        					|| '';

        				const pageMap = {
        					hero_slider:
        						'kidia-mobile-hero-sliders',
        					image_banner:
        						'kidia-mobile-image-banners',
        					product_carousel:
        						'kidia-mobile-product-carousels',
        					brand_carousel:
        						'kidia-mobile-brand-carousels',
        					category_grid:
        						'kidia-mobile-category-grids',
        					product_grid:
        						'kidia-mobile-product-grids',
        					section_header:
        						'kidia-mobile-section-headers',
        					promo_strip:
        						'kidia-mobile-promo-strips',
        					coupon_banner:
        						'kidia-mobile-coupon-banners',
        					countdown:
        						'kidia-mobile-countdowns',
        					video_banner:
        						'kidia-mobile-video-banners',
        					text_block:
        						'kidia-mobile-text-blocks',
        					divider:
        						'kidia-mobile-dividers',
        					spacer:
        						'kidia-mobile-spacers',
        				};

        				if (
        					!pageMap[type]
        					|| !libraryId
        				) {
        					return;
        				}

        				window.location.href =
        					'admin.php?page=' +
        					encodeURIComponent(
        						pageMap[type]
        					) +
        					'&id=' +
        					encodeURIComponent(
        						libraryId
        					);

        			}

        		}
        	);

        	builder.addEventListener(
        		'input',
        		function (event) {

        			const target = event.target;

        			if (
        				!(
        					target instanceof
        					HTMLInputElement
        				)
        				|| !target.classList.contains(
        					'kidia-block-name-input'
        				)
        			) {
        				return;
        			}

        			const block =
        				target.closest(
        					'.kidia-builder-block'
        				);

        			const label =
        				block?.querySelector(
        					'.kidia-block-name'
        				);

        			if (label) {

        				label.textContent =
        					target.value.trim()
        					|| (
        						window.kidiaHomeBuilder
        							?.labels
        							?.untitled
        						|| 'Untitled Element'
        					);

        			}

        		}
        	);

        	let draggedBlock = null;

        	builder.addEventListener(
        		'dragstart',
        		function (event) {

        			const target = event.target;

        			if (
        				!(target instanceof HTMLElement)
        			) {
        				return;
        			}

        			const block =
        				target.closest(
        					'.kidia-builder-block'
        				);

        			if (!block) {
        				return;
        			}

        			draggedBlock = block;

        			block.classList.add(
        				'is-dragging'
        			);

        			if (event.dataTransfer) {

        				event.dataTransfer.effectAllowed =
        					'move';

        				event.dataTransfer.setData(
        					'text/plain',
        					''
        				);

        			}

        		}
        	);

        	builder.addEventListener(
        		'dragover',
        		function (event) {

        			event.preventDefault();

        			if (!draggedBlock) {
        				return;
        			}

        			const target = event.target;

        			if (
        				!(target instanceof HTMLElement)
        			) {
        				return;
        			}

        			const targetBlock =
        				target.closest(
        					'.kidia-builder-block'
        				);

        			if (
        				!targetBlock
        				|| targetBlock === draggedBlock
        			) {
        				return;
        			}

        			const rect =
        				targetBlock
        					.getBoundingClientRect();

        			const after =
        				event.clientY >
        				rect.top +
        					rect.height / 2;

        			targetBlock.insertAdjacentElement(
        				after
        					? 'afterend'
        					: 'beforebegin',
        				draggedBlock
        			);

        		}
        	);

        	builder.addEventListener(
        		'dragend',
        		function () {

        			if (draggedBlock) {

        				draggedBlock.classList.remove(
        					'is-dragging'
        				);

        			}

        			draggedBlock = null;

        			updateIndexes();

        		}
        	);

        	searchInput?.addEventListener(
        		'input',
        		function () {

        			const value =
        				searchInput.value
        					.trim()
        					.toLowerCase();

        			let visibleGroups = 0;

        			document
        				.querySelectorAll(
        					'.kidia-element-group'
        				)
        				.forEach(function (group) {

        					const matches =
        						group.textContent
        							.toLowerCase()
        							.includes(value);

        					group.hidden = !matches;

        					if (matches) {
        						visibleGroups++;
        					}

        				});

        			const noResults =
        				document.getElementById(
        					'kidia-element-picker-no-results'
        				);

        			if (noResults) {

        				noResults.hidden =
        					visibleGroups !== 0;

        			}

        		}
        	);

        	updateIndexes();

        	collapseAll();

        })();