(function (global) {
	'use strict';

	function event(name, detail) {
		return new CustomEvent('mobishop:' + name, { detail: detail || {} });
	}

	function createRuntime(options) {
		const config = options || {};
		const root = config.root;
		const adapter = global.MobiShopPlatformAdapter.assert(config.adapter);
		const renderers = config.renderers || {};
		let state = null;

		if (!(root instanceof Element)) {
			throw new TypeError('MobiShop runtime requires a root element.');
		}

		async function open(screen, params) {
			const payload = await adapter.loadScreen(screen, params || {});
			const renderer = renderers[screen];
			if (typeof renderer !== 'function') {
				throw new Error('MobiShop has no shared renderer for ' + screen + '.');
			}
			await renderer(root, payload, api);
			root.dataset.mobishopScreen = screen;
			root.dispatchEvent(event('screen-opened', { screen: screen, platform: adapter.platform }));
			return payload;
		}

		async function save(screen, payload) {
			const result = await adapter.saveScreen(screen, payload);
			root.dispatchEvent(event('screen-saved', { screen: screen, result: result }));
			return result;
		}

		const api = Object.freeze({
			get platform() { return adapter.platform; },
			get state() { return state; },
			open: open,
			save: save,
			navigate: function (target, params) { return adapter.navigate(target, params || {}); },
			uploadMedia: function (file, context) { return adapter.uploadMedia(file, context || {}); },
			startBuild: function (request) { return adapter.startBuild(request || {}); }
		});

		return Object.freeze({
			api: api,
			async mount() {
				state = await adapter.bootstrap();
				root.classList.add('mobishop-shared-runtime');
				root.dataset.mobishopPlatform = adapter.platform;
				root.dispatchEvent(event('mounted', { platform: adapter.platform, state: state }));
				return open(config.initialScreen || state.initialScreen || 'dashboard');
			}
		});
	}

	global.MobiShopBuilderRuntime = Object.freeze({ create: createRuntime });
})(window);

