(function (global) {
	'use strict';

	const defaultSections = [
		['dashboard', 'Overview', 'dashicons-dashboard'],
		['setup', 'Setup', 'dashicons-admin-settings'],
		['home-builder', 'Home', 'dashicons-admin-home'],
		['category-builder', 'Category', 'dashicons-category'],
		['catalog-builder', 'Catalog', 'dashicons-grid-view'],
		['product-builder', 'Product', 'dashicons-products'],
		['wishlist-builder', 'Wishlist', 'dashicons-heart'],
		['account-builder', 'Account', 'dashicons-admin-users'],
		['checkout-builder', 'Checkout', 'dashicons-cart'],
		['saved-themes', 'Saved Themes', 'dashicons-art'],
		['store-data', 'Store Data', 'dashicons-database'],
		['ai-insights', 'AI Insights', 'dashicons-lightbulb'],
		['push-notifications', 'Push Notifications', 'dashicons-megaphone'],
		['website-app-promotion', 'Website Promotion', 'dashicons-smartphone'],
		['build-and-publish', 'Build & Publish', 'dashicons-download']
	];

	function renderShell(root, state, api) {
		root.replaceChildren();
		const sidebar = document.createElement('aside');
		sidebar.className = 'mobishop-cms-sidebar';
		sidebar.dataset.mobishopCmsSidebar = '';
		const brand = document.createElement('div');
		brand.className = 'mobishop-cms-shell__brand';
		brand.innerHTML = '<span class="dashicons dashicons-smartphone"></span><div><strong>MobiShop</strong><small>Application workspace</small></div>';
		const nav = document.createElement('nav');
		nav.className = 'mobishop-cms-sidebar__nav';
		nav.setAttribute('aria-label', 'MobiShop sections');
		const sections = Array.isArray(state.sections) ? state.sections : defaultSections.map(([key, label, icon]) => ({ key, label, icon }));
		sections.forEach((section) => {
			const link = document.createElement('a');
			link.href = '#mobishop-' + section.key;
			link.dataset.mobishopSidebarView = section.key;
			link.innerHTML = `<span class="dashicons ${section.icon || 'dashicons-admin-generic'}"></span><span></span>`;
			link.lastElementChild.textContent = section.label;
			link.addEventListener('click', (event) => {
				event.preventDefault();
				nav.querySelectorAll('a').forEach((item) => item.classList.toggle('is-active', item === link));
				api.open(section.key);
			});
			nav.append(link);
		});
		sidebar.append(brand, nav);
		const frame = document.createElement('div');
		frame.className = 'mobishop-cms-workspace-frame';
		frame.dataset.mobishopCmsWorkspaceFrame = '';
		const content = document.createElement('main');
		content.className = 'mobishop-cms-content';
		content.dataset.mobishopCmsContent = '';
		frame.append(content);
		root.append(sidebar, frame);
		return content;
	}

	global.MobiShopSharedShell = renderShell;
})(window);

