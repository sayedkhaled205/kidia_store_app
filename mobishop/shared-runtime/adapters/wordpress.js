(function (global) {
	'use strict';

	function createWordPressAdapter(config) {
		const options = config || {};
		const endpoint = options.endpoint || '/wp-json/mobishop/v1/builder/home';
		const screenEndpoint = options.screenEndpoint || '/wp-json/mobishop/v1/builder/screen/';
		const headers = { 'Content-Type': 'application/json', 'X-WP-Nonce': options.nonce || '' };
		let home = null;

		async function request(method, body, url) {
			const response = await fetch(url || endpoint, {
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
				if (screen !== 'home-builder') {
					const payload = await request('GET', undefined, screenEndpoint + encodeURIComponent(screen));
					return { settings: payload.settings || {}, build: payload.build || {}, store: home && home.store || {}, license: home && home.license || { active: false } };
				}
				return home || request('GET');
			},
			async saveScreen(screen, payload) {
				if (screen !== 'home-builder') return request('POST', { settings: payload || {} }, screenEndpoint + encodeURIComponent(screen));
				const result = await request('POST', payload);
				home = { ...home, ...payload };
				return result;
			},
			navigate(target) { global.location.assign(target === 'connection' && options.connectionUrl ? options.connectionUrl : target); },
			uploadMedia() { throw new Error('Use the WordPress media library.'); },
			async startBuild(requestPayload) {
				if (options.buildEndpoint) return request('POST', requestPayload || {}, options.buildEndpoint);
				const body = new URLSearchParams();
				body.set('action', 'mobishop_app_build_start');
				body.set('nonce', options.buildNonce || '');
				body.set('settings', JSON.stringify(requestPayload || {}));
				const response = await fetch(options.ajaxUrl || '/wp-admin/admin-ajax.php', {
					method: 'POST', credentials: 'same-origin',
					headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
					body: body.toString()
				});
				const payload = await response.json();
				if (!response.ok || !payload.success) throw new Error(payload.data && payload.data.message || 'The MobiShop build could not be started.');
				return { ok: true, build: payload.data || {} };
			}
		});
	}

	global.MobiShopWordPressAdapter = Object.freeze({ create: createWordPressAdapter });
})(window);

