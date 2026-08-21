(function (global) {
	'use strict';

	const definitions = {
		dashboard: ['Overview', 'From website connection to a ready mobile app', [['Store products', 'products'], ['Categories', 'categories'], ['Orders', 'orders'], ['Customers', 'customers']], [
			['Connection & License', 'Connect the store and activate the MobiShop license.', [['License key', 'password', ''], ['Connection status', 'text', 'Not connected']]],
			['Application journey', 'Connect, customize, build and publish from one workspace.', [['Website connected', 'checkbox', true], ['Store data ready', 'checkbox', true], ['Design complete', 'checkbox', false]]],
			['Recent build', 'Download a successful build or create a new version.', [['Build channel', 'select', 'production', ['Production', 'Testing']], ['Release notes', 'textarea', '']]]
		]],
		setup: ['Setup & Themes', 'Build your application with the same guided WordPress setup', [], [
			['General Settings', 'Application identity and regional behavior.', [['Application name', 'text', ''], ['Language', 'select', 'en', ['English', 'العربية']], ['Direction', 'select', 'ltr', ['LTR', 'RTL']], ['Application icon shape', 'select', 'rounded_square', ['Rounded square', 'Circle', 'Square']], ['Font collection', 'select', 'system', ['System font', 'Poppins', 'Roboto', 'Noto Sans Arabic', 'Serif', 'Monospace']], ['Primary color', 'color', '#2F806E'], ['Secondary color', 'color', '#172033'], ['Logo URL', 'url', '']]],
			['Choose application pages', 'Required store pages are always included.', [['Catalog page', 'checkbox', true], ['Product page', 'checkbox', true], ['Wishlist page', 'checkbox', true], ['Account page', 'checkbox', true], ['Checkout page', 'checkbox', true]]],
			['Choose a complete store theme', 'Apply one visual system across every application page.', [['Theme', 'select', 'fashion', ['Fashion', 'Studio Fashion', 'Kids & Baby', 'Grocery', 'Electronics', 'Beauty', 'Jewelry', 'Coffee', 'Luxury', 'Multi Store']]]],
			['Review and apply', 'A snapshot is created before the new theme is applied.', [['Create snapshot before apply', 'checkbox', true]]]
		]],
		'category-builder': ['Category', 'Design categories and subcategories with the original WordPress controls', [], [
			['Layout & Spacing', 'Category card geometry and navigation.', [['Layout', 'select', 'grid', ['Grid', 'Horizontal']], ['Open categories', 'select', 'page', ['New page', 'Expand subcategories']], ['Grid columns', 'number', '3'], ['Card height', 'number', '0'], ['Card radius', 'number', '12'], ['Card spacing', 'number', '12'], ['Card width', 'number', '100'], ['Show arrow', 'checkbox', true], ['Merge up', 'number', '0'], ['Merge down', 'number', '0'], ['Space up', 'number', '0'], ['Space down', 'number', '0']]],
			['Image size & shape', 'Control category image presentation.', [['Size', 'number', '72'], ['Shape', 'select', 'rounded', ['Square', 'Rounded', 'Circle']], ['Round amount', 'number', '16'], ['Image fit', 'select', 'cover', ['Show complete image', 'Fill and crop']], ['Effect', 'select', 'none', ['None', 'Shadow', 'Black and white']], ['Zoom', 'number', '100'], ['Position', 'select', 'center', ['Center', 'Top', 'Bottom', 'Right', 'Left']], ['Border width', 'number', '0'], ['Border color', 'color', '#FFFFFF'], ['Image background', 'color', '#FFFFFF']]],
			['Text and spacing', 'Category title style.', [['Image–text gap', 'number', '10'], ['Font size', 'number', '14'], ['Font color', 'color', '#1F2933'], ['Font weight', 'select', '600', ['Regular', 'Medium', 'Semi bold', 'Bold', 'Extra bold']], ['Text alignment', 'select', 'center', ['Start', 'Center', 'End']], ['Maximum lines', 'select', '2', ['1', '2', '3']], ['Line height', 'number', '140']]],
			['Categories & Subcategories', 'Drag to reorder and customize app names, images and visibility.', [['Show categories', 'checkbox', true], ['Use store category images', 'checkbox', true]]]
		]],
		'catalog-builder': ['Catalog', 'Configure the catalog using the original page-builder elements', [], [
			['Filter and Sort Bar', 'Sticky filtering and sorting controls.', [['Sticky', 'checkbox', true], ['Show filter button', 'checkbox', true], ['Show sort', 'checkbox', true], ['Show result count', 'checkbox', false], ['Filter: Price', 'checkbox', true], ['Filter: On sale', 'checkbox', true], ['Filter: Brand', 'checkbox', true], ['Filter: Size', 'checkbox', true], ['Filter: Color', 'checkbox', false], ['Button style', 'select', 'outlined', ['Outlined', 'Flat labels']], ['Block width', 'number', '100'], ['Block height', 'number', '56'], ['Button radius', 'number', '12'], ['Background', 'color', '#FFFFFF'], ['Icon color', 'color', '#1F2933'], ['Border color', 'color', '#DDE3E8']]],
			['Product Grid', 'Product card and grid presentation.', [['Columns', 'number', '2'], ['Products per page', 'number', '20'], ['Image ratio', 'number', '0.82'], ['Show product name', 'checkbox', true], ['Show price', 'checkbox', true], ['Show rating', 'checkbox', true], ['Show wishlist', 'checkbox', true], ['Show quick add', 'checkbox', true], ['Card radius', 'number', '12'], ['Card background', 'color', '#FFFFFF']]]
		]],
		'product-builder': ['Product', 'Build the product page with all original WordPress elements', [], [
			['Product Tabs', 'Overview, reviews and recommendation tabs.', [['Keep tabs visible while scrolling', 'checkbox', true], ['Visible tabs', 'text', 'Overview, Reviews, Recommend'], ['Active tab color', 'color', '#1D1D1D'], ['Inactive tab color', 'color', '#6B6B6B'], ['Indicator width', 'number', '96'], ['Tabs height', 'number', '64']]],
			['Product Gallery', 'Images, counter, thumbnails and zoom.', [['Image ratio', 'number', '0.75'], ['Image fit', 'select', 'contain', ['Contain', 'Cover']], ['Gallery background', 'color', '#FFFFFF'], ['Show thumbnails', 'checkbox', false], ['Show indicators', 'checkbox', false], ['Show image counter', 'checkbox', true], ['Enable zoom', 'checkbox', false]]],
			['Product Information', 'Name, price, rating, stock and badge.', [['Show name', 'checkbox', true], ['Show price', 'checkbox', true], ['Show regular price', 'checkbox', true], ['Show rating', 'checkbox', true], ['Show review count', 'checkbox', true], ['Show SKU', 'checkbox', false], ['Show stock', 'checkbox', false], ['Show badge', 'checkbox', false], ['Show selected color', 'checkbox', true], ['Price size', 'number', '25'], ['Product name size', 'number', '18']]],
			['Variations', 'Size, color and option controls.', [['Selector style', 'select', 'chips', ['Chips', 'Dropdown']], ['Show size chart link', 'checkbox', true], ['Size chart label', 'text', 'Size chart'], ['Option radius', 'number', '22'], ['Option height', 'number', '38']]],
			['Quantity', 'Purchase quantity control.', [['Show quantity', 'checkbox', false]]],
			['Description and Details', 'Description and attributes.', [['Use compact accordion rows', 'checkbox', true], ['Details label', 'text', 'Product Details'], ['Show description', 'checkbox', true], ['Show attributes', 'checkbox', true]]],
			['Reviews', 'Rating and size-and-fit summary.', [['Reviews title', 'text', 'Reviews'], ['Show rating summary', 'checkbox', true], ['Show size and fit summary', 'checkbox', true], ['Small (%)', 'number', '1'], ['True to size (%)', 'number', '99'], ['Large (%)', 'number', '0']]],
			['Related Products', 'Recommendation grid.', [['Section title', 'text', 'You may also like'], ['Columns', 'number', '2'], ['Gap', 'number', '2'], ['Image ratio', 'number', '0.75'], ['Show price', 'checkbox', true], ['Show quick add', 'checkbox', true]]]
		]],
		'wishlist-builder': ['Wishlist', 'Configure saved-product behavior', [], [['Wishlist header', 'Title, sharing and item count.'], ['Saved item cards', 'Price changes, stock state and cart action.'], ['Empty state', 'Message and continue-shopping action.']]],
		'account-builder': ['Account', 'Configure the customer account area', [], [['Profile', 'Customer details and preferences.'], ['Orders and returns', 'History, tracking, invoices and returns.'], ['Addresses and security', 'Saved addresses, password and sign-out.']]],
		'checkout-builder': ['Checkout', 'Configure conversion and checkout fields', [], [['Customer details', 'Contact, address and custom checkout fields.'], ['Delivery and payment', 'Shipping methods, payment methods and validation.'], ['Order review', 'Items, discounts, totals and place-order action.']]],
		'saved-themes': ['Saved Themes', 'Reuse and manage complete visual systems', [], [['Theme library', 'Saved themes and reusable presets.'], ['Current theme', 'Capture the current application appearance.'], ['Import and export', 'Move a theme between installations.']]],
		'store-data': ['Store Data', 'Inspect commerce data exposed to the application', [['Products', 'products'], ['Categories', 'categories'], ['Orders', 'orders'], ['Customers', 'customers']], [['Products and inventory', 'Published products, prices and availability.'], ['Orders and customers', 'Application orders and customer records.'], ['Discounts', 'Coupons and application promotions.']]],
		'ai-insights': ['AI Insights', 'Operational recommendations and offer planning', [], [['Opportunity feed', 'Prioritized merchandising and retention opportunities.'], ['Offer workspace', 'Create offers from live store signals.'], ['Measurement', 'Track accepted actions and results.']]],
		'push-notifications': ['Push Notifications', 'Create, schedule and measure customer messages', [], [['Campaign composer', 'Audience, title, message, image and deep link.'], ['Schedule', 'Send now or select a customer timezone.'], ['Performance', 'Delivery, opens and conversions.']]],
		'website-app-promotion': ['Website Promotion', 'Promote the mobile application on the storefront', [], [['Smart banner', 'Mobile website banner and install action.'], ['QR and download links', 'Store badges, QR code and device routing.'], ['Display rules', 'Pages, timing, frequency and dismissal.']]],
		'build-and-publish': ['Build & Publish', 'Validate, build and release the mobile application', [], [['Readiness', 'Connection, branding, store data and content checks.'], ['Build', 'Generate Android and iOS application packages.'], ['Publishing', 'Version, release notes and store submission status.']]],
	};

	function el(tag, cls, text) {
		const node = document.createElement(tag);
		if (cls) node.className = cls;
		if (text !== undefined) node.textContent = text;
		return node;
	}

	function field(section, name, value, type, options) {
		const label = el('label', 'mobishop-workspace-field');
		label.append(el('span', '', name));
		const input = el(type === 'textarea' ? 'textarea' : type === 'select' ? 'select' : 'input');
		input.name = section.toLowerCase().replace(/[^a-z0-9]+/g, '_') + '__' + name.toLowerCase().replace(/[^a-z0-9]+/g, '_');
		if (input.tagName === 'INPUT') input.type = type || 'text';
		if (input.tagName === 'SELECT') {
			(options || []).forEach(function (option) {
				const node = el('option', '', option);
				node.value = String(option).toLowerCase().replace(/[^a-z0-9]+/g, '_');
				input.append(node);
			});
		}
		if (type !== 'checkbox') input.value = value === undefined || value === null ? '' : value;
		label.append(input);
		return label;
	}

	async function renderWorkspace(root, payload, api, screen) {
		const def = definitions[screen];
		const settings = payload.settings || {};
		root.replaceChildren();
		const layout = el('div', 'mobishop-workspace-layout');
		const page = el('section', 'mobishop-workspace-page');
		const header = el('header', 'mobishop-workspace-header');
		const titleBox = el('div');
		titleBox.append(el('h1', '', def[0]), el('p', '', def[1]));
		const actions = el('div', 'mobishop-workspace-actions');
		const save = el('button', 'button button-primary', 'Save changes');
		save.type = 'button';
		actions.append(save);
		if (screen === 'build-and-publish') {
			const build = el('button', 'button', 'Start build');
			build.type = 'button';
			build.addEventListener('click', async function () {
				try { await api.startBuild({ platform: api.platform }); } catch (error) { root.dispatchEvent(new CustomEvent('mobishop:screen-error', { detail: { screen, message: error.message } })); }
			});
			actions.prepend(build);
		}
		header.append(titleBox, actions);
		page.append(header);

		if (def[2].length) {
			const stats = el('div', 'mobishop-workspace-stats');
			def[2].forEach(function (item) {
				const card = el('article', 'mobishop-workspace-stat');
				card.append(el('span', '', item[0]), el('strong', '', String((payload.store || {})[item[1]] || 0)));
				stats.append(card);
			});
			page.append(stats);
		}

		const grid = el('form', 'mobishop-workspace-grid');
		def[3].forEach(function (item) {
			const card = el('article', 'mobishop-workspace-card');
			card.append(el('h2', '', item[0]), el('p', '', item[1]));
			const enabled = field(item[0], 'Enabled', '', 'checkbox');
			enabled.querySelector('input').checked = settings[enabled.querySelector('input').name] !== false;
			card.append(enabled);
			const configuredFields = item[2] && item[2].length ? item[2] : [['Title', 'text', item[0]], ['Description', 'textarea', item[1]]];
			configuredFields.forEach(function (definition) {
				const key = item[0].toLowerCase().replace(/[^a-z0-9]+/g, '_') + '__' + definition[0].toLowerCase().replace(/[^a-z0-9]+/g, '_');
				const control = field(item[0], definition[0], settings[key] !== undefined ? settings[key] : definition[2], definition[1], definition[3]);
				if (definition[1] === 'checkbox') control.querySelector('input').checked = settings[key] !== undefined ? Boolean(settings[key]) : Boolean(definition[2]);
				card.append(control);
			});
			grid.append(card);
		});
		page.append(grid);
		const preview = el('aside', 'mobishop-workspace-preview');
		preview.setAttribute('aria-label', 'Live mobile preview');
		preview.append(el('strong', 'mobishop-workspace-preview__label', 'Live Preview'));
		const phone = el('div', 'mobishop-workspace-phone');
		const phoneBar = el('div', 'mobishop-workspace-phone__bar');
		phoneBar.append(el('span', '', '9:41'), el('b', '', '●  Wi‑Fi  ▰'));
		const phoneHeader = el('div', 'mobishop-workspace-phone__header', def[0]);
		const phoneBody = el('div', 'mobishop-workspace-phone__body');
		def[3].forEach(function (item, index) {
			const block = el('article', 'mobishop-workspace-phone__block');
			block.dataset.previewIndex = String(index);
			block.append(el('strong', '', item[0]), el('small', '', item[1]));
			phoneBody.append(block);
		});
		phone.append(phoneBar, phoneHeader, phoneBody);
		preview.append(phone);
		layout.append(page, preview);
		root.append(layout);

		grid.addEventListener('input', function (event) {
			const card = event.target.closest('.mobishop-workspace-card');
			if (!card) return;
			const index = Array.from(grid.children).indexOf(card);
			const block = phoneBody.querySelector('[data-preview-index="' + index + '"]');
			if (!block) return;
			const title = card.querySelector('input[name$="__title"]');
			const description = card.querySelector('textarea[name$="__description"]');
			const enabledControl = card.querySelector('input[name$="__enabled"]');
			if (title) block.querySelector('strong').textContent = title.value;
			if (description) block.querySelector('small').textContent = description.value;
			if (enabledControl) block.hidden = !enabledControl.checked;
		});

		save.addEventListener('click', async function () {
			const next = {};
			grid.querySelectorAll('input, textarea, select').forEach(function (input) { next[input.name] = input.type === 'checkbox' ? input.checked : input.value; });
			await api.save(screen, next);
		});
	}

	global.MobiShopSharedRenderers = global.MobiShopSharedRenderers || {};
	Object.keys(definitions).forEach(function (screen) {
		global.MobiShopSharedRenderers[screen] = function (root, payload, api) { return renderWorkspace(root, payload, api, screen); };
	});
})(window);

