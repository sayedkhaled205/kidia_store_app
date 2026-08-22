(function (global) {
	'use strict';

	function event(name, detail) {
		return new CustomEvent('mobishop:' + name, { detail: detail || {} });
	}

	function resetScrollPosition(element) {
		let current = element;
		while (current && current !== document.body) {
			if (current.scrollHeight > current.clientHeight) current.scrollTop = 0;
			current = current.parentElement;
		}
		if (document.scrollingElement) document.scrollingElement.scrollTop = 0;
	}

	function createRuntime(options) {
		const config = options || {};
		const root = config.root;
		const adapter = global.MobiShopPlatformAdapter.assert(config.adapter);
		const renderers = config.renderers || {};
		let state = null;
		let screenRoot = root;

		if (!(root instanceof Element)) {
			throw new TypeError('MobiShop runtime requires a root element.');
		}

		async function open(screen, params) {
			try {
				const payload = await adapter.loadScreen(screen, params || {});
				const renderer = renderers[screen];
				if (typeof renderer !== 'function') {
					throw new Error('This MobiShop section is still being connected to the shared builder.');
				}
				await renderer(screenRoot, payload, api);
				resetScrollPosition(screenRoot);
				root.dataset.mobishopScreen = screen;
				root.dispatchEvent(event('screen-opened', { screen: screen, platform: adapter.platform }));
				return payload;
			} catch (error) {
				const message = error && error.message ? error.message : 'MobiShop could not open this section.';
				root.dispatchEvent(event('screen-error', { screen: screen, message: message }));
				if (typeof config.onError === 'function') config.onError(message, error);
				return { ok: false, error: message };
			}
		}

		async function save(screen, payload) {
			try {
				const result = await adapter.saveScreen(screen, payload);
				root.dispatchEvent(event('screen-saved', { screen: screen, result: result }));
				return result;
			} catch (error) {
				const message = error && error.message ? error.message : 'MobiShop could not save this screen.';
				root.dispatchEvent(event('screen-error', { screen: screen, message: message }));
				if (typeof config.onError === 'function') config.onError(message, error);
				return { ok: false, error: message };
			}
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
				if (typeof config.shell === 'function') {
					screenRoot = await config.shell(root, state, api);
					if (!(screenRoot instanceof Element)) throw new TypeError('MobiShop shell must return its screen root element.');
				}
				root.dispatchEvent(event('mounted', { platform: adapter.platform, state: state }));
				return open(config.initialScreen || state.initialScreen || 'dashboard');
			}
		});
	}

	global.MobiShopBuilderRuntime = Object.freeze({ create: createRuntime });
})(window);

