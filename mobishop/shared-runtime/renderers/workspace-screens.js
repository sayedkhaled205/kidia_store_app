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
		'wishlist-builder': ['Wishlist', 'Edit every signed-out, empty and saved-product state from the original page builder', [], [
			['Wishlist Access', 'Choose whether guests can save products.', [['Access mode', 'select', 'sign_in_required', ['Guest wishlist', 'Sign in required']], ['Preview state', 'select', 'products', ['Sign-in Wishlist', 'Empty Wishlist Settings', 'Product Wishlist']]]],
			['Sign-in Wishlist', 'Screen shown to signed-out customers.', [['Title', 'text', 'Sign in to view your wishlist'], ['Description', 'textarea', ''], ['Button label', 'text', 'Sign In'], ['Button action', 'select', 'sign_in', ['Sign in', 'Shopping']]]],
			['Sign-in Recommendations', 'Products suggested below the sign-in state.', [['Section title', 'text', 'Recommended for you'], ['Columns', 'number', '2'], ['Show price', 'checkbox', true], ['Show quick add', 'checkbox', true]]],
			['Empty Wishlist', 'Screen shown before products are saved.', [['Title', 'text', 'Your wishlist is empty'], ['Description', 'textarea', 'Add items here by clicking the little heart!'], ['Button label', 'text', 'Go Shopping'], ['Button action', 'select', 'shopping', ['Shopping', 'Sign in']]]],
			['Empty Wishlist Recommendations', 'Products suggested in the empty state.', [['Section title', 'text', 'You may also like'], ['Columns', 'number', '2'], ['Show price', 'checkbox', true], ['Show quick add', 'checkbox', true]]],
			['Wishlist Products', 'Grid of products saved by the customer.', [['Columns', 'number', '2'], ['Gap', 'number', '8'], ['Card style', 'select', 'minimal', ['Minimal', 'No shadow', 'Outlined', 'Elevated']], ['Image ratio', 'number', '0.82'], ['Show price', 'checkbox', true], ['Show wishlist', 'checkbox', true], ['Show quick add', 'checkbox', true]]],
			['Wishlist Product Recommendations', 'Recommendations shown after saved products.', [['Section title', 'text', 'Recommended for you'], ['Columns', 'number', '2'], ['Show price', 'checkbox', true], ['Show quick add', 'checkbox', true]]]
		]],
		'account-builder': ['Account', 'Configure the original customer account page elements', [], [
			['Account Summary', 'Avatar, identity and guest presentation.', [['Avatar size', 'number', '66'], ['Show email', 'checkbox', true], ['Guest title', 'text', 'Sign in / Create account'], ['Card style', 'select', 'elevated', ['Minimal', 'No shadow', 'Outlined', 'Elevated']]]],
			['Account Menu', 'Choose which account destinations are visible.', [['Show orders', 'checkbox', true], ['Show addresses', 'checkbox', true], ['Show profile', 'checkbox', true], ['Show support', 'checkbox', true]]],
			['Logout Button', 'Customer sign-out action.', [['Button label', 'text', 'Log out'], ['Background color', 'color', '#FFFFFF']]]
		]],
		'checkout-builder': ['Checkout', 'Use the same checkout design and live field schema as the WordPress builder', [], [
			['Checkout Design', 'Choose the real mobile checkout layout.', [['Layout', 'select', 'classic', ['Classic', 'Summary First', 'Compact']], ['Show progress', 'checkbox', true], ['Card radius', 'number', '12'], ['Page background', 'color', '#F5F7FB']]],
			['Checkout Fields', 'Drag-compatible billing, shipping and order fields.', [['Field label', 'text', 'Email address'], ['Field key', 'text', 'billing_email'], ['Group', 'select', 'billing', ['Billing', 'Shipping', 'Order']], ['Field type', 'select', 'email', ['Text', 'Email', 'Phone', 'Select', 'Textarea', 'Checkbox', 'Hidden', 'Country', 'State']], ['Placeholder', 'text', ''], ['Autocomplete', 'text', 'email'], ['Default value', 'text', ''], ['Required', 'checkbox', true]]],
			['Order Review', 'Items, discounts, shipping, totals and place-order action.', [['Show product images', 'checkbox', true], ['Show coupon', 'checkbox', true], ['Show shipping methods', 'checkbox', true], ['Place order label', 'text', 'Place order']]]
		]],
		'saved-themes': ['Saved Themes', 'Preview, apply, import and export the same complete theme snapshots', [], [
			['Your Saved Themes', 'Preview and apply reusable app appearance snapshots.', [['Theme name', 'text', 'My application theme'], ['Preview page', 'select', 'splash', ['Splash', 'Home', 'Category', 'Catalog', 'Product', 'Wishlist', 'Account']]]],
			['Save Current Theme', 'Capture the current application appearance.', [['Theme name', 'text', 'New theme'], ['Include page layouts', 'checkbox', true], ['Include application chrome', 'checkbox', true]]],
			['Import & Export', 'Move one theme or the complete library between installations.', [['Import JSON', 'textarea', ''], ['Export scope', 'select', 'theme', ['Selected theme', 'All themes']]]]
		]],
		'store-data': ['Store Data', 'Live commerce data, reports, analytics and recovery tools from the original product', [['Products', 'products'], ['Categories', 'categories'], ['Orders', 'orders'], ['Customers', 'customers']], [
			['Products & Inventory', 'Published products, prices, stock and availability.', [['Source', 'select', 'all', ['All', 'Website', 'Application']], ['Stock state', 'select', 'all', ['All', 'In stock', 'Low stock', 'Out of stock']], ['Rows per page', 'select', '20', ['20', '50', '100']]]],
			['Orders & Reports', 'Orders, net sales, average order value and best sellers.', [['Period', 'select', '30_days', ['Today', '7 days', '30 days', 'Custom']], ['Channel', 'select', 'all', ['All', 'Website', 'Application']], ['Generate indexed reports', 'checkbox', true]]],
			['Analytics', 'Sales funnel, registration, searches and category demand.', [['Period', 'select', '30_days', ['Today', '7 days', '30 days', 'Custom']], ['Channel', 'select', 'all', ['All', 'Website', 'Application']], ['Include unique visitors', 'checkbox', true]]],
			['Abandoned Carts & Recovery', 'Create personal coupons and send recovery messages.', [['Discount type', 'select', 'percent', ['Percentage', 'Fixed cart amount']], ['Discount value', 'number', '10'], ['Expires after (hours)', 'number', '48'], ['Minimum spend', 'number', '0'], ['Notification title', 'text', 'Your cart is waiting'], ['Message', 'textarea', 'Complete your order with code {coupon} before your personal offer expires.'], ['Delivery', 'select', 'now', ['Send now', 'Schedule']]]]
		]],
		'ai-insights': ['AI Insights', 'Operational recommendations and offer planning', [], [
			['Opportunity Feed', 'Prioritized merchandising and retention opportunities.', [['Channel', 'select', 'all', ['All', 'Website', 'Application']], ['Period', 'select', '30_days', ['7 days', '30 days', '90 days']], ['Minimum confidence', 'number', '70']]],
			['Offer Workspace', 'Create an offer from live store signals.', [['Offer name', 'text', ''], ['Audience', 'select', 'all', ['All customers', 'Abandoned carts', 'Returning customers']], ['Discount type', 'select', 'percent', ['Percentage', 'Fixed amount']], ['Discount value', 'number', '10']]],
			['Measurement', 'Track accepted recommendations and commercial results.', [['Show revenue impact', 'checkbox', true], ['Show conversion impact', 'checkbox', true], ['Comparison period', 'select', 'previous', ['Previous period', 'Previous year']]]]
		]],
		'push-notifications': ['Push Notifications', 'Create, schedule and measure customer messages', [], [
			['Campaign Composer', 'Audience, message, media and app destination.', [['Audience', 'select', 'all', ['All customers', 'Registered customers', 'Selected segment']], ['Notification title', 'text', ''], ['Message', 'textarea', ''], ['Image URL', 'url', ''], ['Destination URL', 'url', '']]],
			['Delivery', 'Send immediately or choose a future time.', [['Delivery', 'select', 'now', ['Send now', 'Schedule']], ['Send date and time', 'text', ''], ['Use customer timezone', 'checkbox', true]]],
			['Performance', 'Delivery, opens and conversions.', [['Track opens', 'checkbox', true], ['Track destination visits', 'checkbox', true], ['Track conversions', 'checkbox', true]]]
		]],
		'website-app-promotion': ['Website Promotion', 'Promote the mobile application on the storefront', [], [
			['Smart Banner', 'Mobile website banner with native install routing.', [['Enabled', 'checkbox', true], ['Headline', 'text', 'Shop faster in our app'], ['Description', 'textarea', 'Download the app for the best shopping experience.'], ['Button label', 'text', 'Get the app'], ['Logo URL', 'url', '']]],
			['Store Links & QR', 'Device-aware App Store and Google Play destinations.', [['Apple App Store URL', 'url', ''], ['Google Play URL', 'url', ''], ['Show QR code', 'checkbox', true], ['Show store badges', 'checkbox', true]]],
			['Display Rules', 'Pages, timing, frequency and dismissal behavior.', [['Show on mobile only', 'checkbox', true], ['Delay (seconds)', 'number', '2'], ['Dismiss for (days)', 'number', '7'], ['Position', 'select', 'bottom', ['Top', 'Bottom']]]]
		]],
		'build-and-publish': ['Build & Publish', 'Validate, build and release the mobile application', [], [
			['Readiness', 'Connection, license, branding, store data and content checks.', [['Connection ready', 'checkbox', true], ['License active', 'checkbox', false], ['Branding complete', 'checkbox', false], ['Store data ready', 'checkbox', true], ['Required pages ready', 'checkbox', false]]],
			['Build', 'Generate Android and iOS application packages.', [['Platform', 'select', 'both', ['Android & iOS', 'Android', 'iOS']], ['Build channel', 'select', 'production', ['Production', 'Testing']], ['Version', 'text', '1.0.0']]],
			['Publishing', 'Release notes, store submission and latest status.', [['Release notes', 'textarea', ''], ['Submit to stores', 'checkbox', false], ['Notify when complete', 'checkbox', true]]]
		]],
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

