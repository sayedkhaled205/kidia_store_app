(function (global) {
	'use strict';

	function showError(root, message) {
		let notice = root.querySelector('.mobishop-shared-builder-error');
		if (!notice) {
			notice = document.createElement('div');
			notice.className = 'notice notice-error mobishop-shared-builder-error';
			root.prepend(notice);
		}
		notice.textContent = message;
	}

	document.addEventListener('DOMContentLoaded', async function () {
		const root = document.getElementById('mobishop-shared-builder-root');
		if (!root) return;
		const config = global.mobishopSharedBuilder || {};
		root.addEventListener('mobishop:screen-error', function (event) {
			showError(root, event.detail && event.detail.message || 'MobiShop could not complete this action.');
		});
		try {
			const adapter = global.MobiShopWordPressAdapter.create(config);
			const runtime = global.MobiShopBuilderRuntime.create({
				root,
				adapter,
				renderers: global.MobiShopSharedRenderers,
				shell: global.MobiShopSharedShell,
				initialScreen: 'home-builder'
			});
			await runtime.mount();
			global.mobishopSharedBuilderRuntime = runtime;
		} catch (error) {
			showError(root, error && error.message || 'MobiShop could not start the shared Builder.');
		}
	});
})(window);

