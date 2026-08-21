(function (global) {
	'use strict';

	const requiredMethods = [
		'bootstrap',
		'loadScreen',
		'saveScreen',
		'navigate',
		'uploadMedia',
		'startBuild'
	];

	function assertPlatformAdapter(adapter) {
		if (!adapter || typeof adapter !== 'object') {
			throw new TypeError('MobiShop requires a platform adapter.');
		}
		requiredMethods.forEach(function (method) {
			if (typeof adapter[method] !== 'function') {
				throw new TypeError('MobiShop platform adapter is missing ' + method + '().');
			}
		});
		if (!adapter.platform || typeof adapter.platform !== 'string') {
			throw new TypeError('MobiShop platform adapter requires a platform name.');
		}
		return adapter;
	}

	global.MobiShopPlatformAdapter = Object.freeze({
		requiredMethods: requiredMethods.slice(),
		assert: assertPlatformAdapter
	});
})(window);

