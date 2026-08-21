(function (global) {
	'use strict';

	function createWordPressAdapter(config) {
		const options = config || {};
		const endpoint = options.endpoint || '/wp-json/mobishop/v1/builder/home';
		const headers = { 'Content-Type': 'application/json', 'X-WP-Nonce': options.nonce || '' };
		let home = null;

		async function request(method, body) {
			const response = await fetch(endpoint, {
				method,
				headers,
				credentials: 'same-origin',
				body: body === undefined ? undefined : JSON.stringify(body)
			});
			const payload = await response.json();
			if (!response.ok) throw new Error(payload.message || 'MobiShop request failed.');
			return payload;
		}

		return global.MobiShopPlatformAdapter.assert({
			platform: 'wordpress',
			async bootstrap() {
				home = await request('GET');
				return { ...home, initialScreen: 'home-builder' };
			},
			async loadScreen(screen) {
				if (screen !== 'home-builder') throw new Error('Unsupported shared screen: ' + screen);
				return home || request('GET');
			},
			async saveScreen(screen, payload) {
				if (screen !== 'home-builder') throw new Error('Unsupported shared screen: ' + screen);
				const result = await request('POST', payload);
				home = { ...home, ...payload };
				return result;
			},
			navigate(target) { global.location.assign(target); },
			uploadMedia() { throw new Error('Use the WordPress media library.'); },
			startBuild(requestPayload) {
				return fetch(options.buildEndpoint, { method: 'POST', headers, credentials: 'same-origin', body: JSON.stringify(requestPayload) }).then((response) => response.json());
			}
		});
	}

	global.MobiShopWordPressAdapter = Object.freeze({ create: createWordPressAdapter });
})(window);

