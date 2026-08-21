(function (global) {
	'use strict';

	const definitions = {
		dashboard: ['Overview', 'Store and application health', [['Store products', 'products'], ['Categories', 'categories'], ['Orders', 'orders'], ['Customers', 'customers']], [['Quick start', 'Review connection, content and build readiness.'], ['Application status', 'Monitor the shared builder and publishing pipeline.']]],
		setup: ['Setup', 'Brand, theme and first-run configuration', [], [['Brand identity', 'Application name, colors, logo and icon.'], ['Theme', 'Select the visual foundation used by every platform.'], ['Regional settings', 'Language, currency and content direction.']]],
		'category-builder': ['Category', 'Design category discovery and navigation', [], [['Category header', 'Title, search, hero and category navigation.'], ['Category cards', 'Grid density, image ratio, labels and ordering.'], ['Empty state', 'Message and action displayed when no products match.']]],
		'catalog-builder': ['Catalog', 'Configure product discovery and listing', [], [['Catalog toolbar', 'Search, filters, sorting and view controls.'], ['Product cards', 'Price, sale badge, rating, wishlist and add-to-cart.'], ['Pagination', 'Infinite scroll, page size and loading behavior.']]],
		'product-builder': ['Product', 'Build the product detail experience', [], [['Gallery', 'Images, zoom, video and thumbnails.'], ['Product information', 'Title, price, variants, stock and description.'], ['Commerce actions', 'Quantity, cart, buy now and recommendations.']]],
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

	function field(section, name, value, type) {
		const label = el('label', 'mobishop-workspace-field');
		label.append(el('span', '', name));
		const input = el(type === 'textarea' ? 'textarea' : 'input');
		input.name = section.toLowerCase().replace(/[^a-z0-9]+/g, '_') + '__' + name.toLowerCase().replace(/[^a-z0-9]+/g, '_');
		if (input.tagName === 'INPUT') input.type = type || 'text';
		input.value = value || '';
		label.append(input);
		return label;
	}

	async function renderWorkspace(root, payload, api, screen) {
		const def = definitions[screen];
		const settings = payload.settings || {};
		root.replaceChildren();
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
			card.append(enabled, field(item[0], 'Title', settings[item[0].toLowerCase().replace(/[^a-z0-9]+/g, '_') + '__title'] || item[0]), field(item[0], 'Description', settings[item[0].toLowerCase().replace(/[^a-z0-9]+/g, '_') + '__description'] || item[1], 'textarea'));
			grid.append(card);
		});
		page.append(grid);
		root.append(page);

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

