(function () {
	'use strict';

	const config = window.kidiaCMSEntry || {};
	const currentVersion = String(config.version || '');

	function pluginPage(url) {
		try {
			const target = new URL(url, window.location.href);
			return target.origin === window.location.origin &&
				target.pathname.endsWith('/wp-admin/admin.php') &&
				target.searchParams.get('page') === 'kidia-mobile-cms';
		} catch (_error) {
			return false;
		}
	}

	function appendInline(code) {
		if (!code) return;
		const script = document.createElement('script');
		script.textContent = code;
		document.head.appendChild(script);
		script.remove();
	}

	function absoluteAssetUrl(src) {
		try {
			return new URL(src, window.location.href).href;
		} catch (_error) {
			return String(src || '');
		}
	}

	function loadedAsset(asset, type) {
		const expected = absoluteAssetUrl(asset.src);
		const selector = type === 'css' ? 'link[rel="stylesheet"][href]' : 'script[src]';
		const property = type === 'css' ? 'href' : 'src';
		return Array.from(document.querySelectorAll(selector)).some(function (node) {
			return absoluteAssetUrl(node[property]) === expected || node.id === asset.handle + '-' + type;
		});
	}

	function waitForAsset(node, parent) {
		return new Promise(function (resolve) {
			let settled = false;
			let timer = 0;
			const finish = function () {
				if (settled) return;
				settled = true;
				if (timer) window.clearTimeout(timer);
				resolve();
			};
			node.addEventListener('load', finish, { once: true });
			node.addEventListener('error', finish, { once: true });
			parent.appendChild(node);
			timer = window.setTimeout(finish, 8000);
		});
	}

	function loadStyles(payload) {
		return Promise.all((payload.styles || []).map(function (asset) {
			if (loadedAsset(asset, 'css')) return Promise.resolve();
			const link = document.createElement('link');
			link.id = asset.handle + '-css';
			link.rel = 'stylesheet';
			link.href = asset.src;
			return waitForAsset(link, document.head);
		}));
	}

	async function loadScripts(payload) {
		let loadedNewScript = false;
		for (const asset of (payload.scripts || [])) {
			if (loadedAsset(asset, 'js')) continue;
			(asset.before || []).forEach(appendInline);
			const script = document.createElement('script');
			script.id = asset.handle + '-js';
			script.src = asset.src;
			await waitForAsset(script, document.body);
			(asset.after || []).forEach(appendInline);
			loadedNewScript = true;
		}
		return loadedNewScript;
	}

	function applyCmsClasses(payload) {
		(payload.bodyClasses || []).forEach(function (className) {
			if (className) document.body.classList.add(className);
		});
		document.body.classList.add('kidia-cms-plugin-page', 'kidia-mobile-cms');
		document.body.classList.toggle('kidia-cms-builder-screen', Boolean(payload.builderScreen));
		document.documentElement.classList.toggle('kidia-cms-builder-screen', Boolean(payload.builderScreen));
	}

	async function enterCms(url) {
		if (window.kidiaCmsEntryInFlight) return;
		const content = document.querySelector('#wpbody-content');
		if (!content || !config.ajaxUrl || !config.nonce) {
			window.location.href = url;
			return;
		}

		window.kidiaCmsEntryInFlight = true;
		const target = new URL(url, window.location.href);
		target.hash = '';
		try {
			const body = new URLSearchParams({
				action: 'kidia_mobile_cms_view',
				nonce: String(config.nonce),
				version: currentVersion,
				target: target.href,
				include_shell: '1'
			});
			const response = await window.fetch(String(config.ajaxUrl), {
				method: 'POST',
				credentials: 'same-origin',
				cache: 'no-store',
				headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
				body: body.toString()
			});
			if (!response.ok) throw new Error('CMS entry request failed');
			const result = await response.json();
			if (!result.success || !result.data || typeof result.data.html !== 'string') {
				throw new Error('CMS entry payload is missing');
			}
			const payload = result.data;
			if (currentVersion && payload.version && String(payload.version) !== currentVersion) {
				throw new Error('CMS entry version changed');
			}

			const stylesReady = loadStyles(payload);
			const template = document.createElement('template');
			template.innerHTML = payload.html;
			applyCmsClasses(payload);
			content.replaceChildren(...Array.from(template.content.childNodes));
			history.pushState({ kidiaCmsPage: true }, '', target.href);
			const loadedNewScript = await loadScripts(payload);
			await stylesReady;
			if (loadedNewScript) document.dispatchEvent(new Event('DOMContentLoaded'));
			document.dispatchEvent(new CustomEvent('kidia:cms-page-ready', { detail: { url: target.href } }));
		} catch (_error) {
			window.location.href = target.href;
		} finally {
			window.kidiaCmsEntryInFlight = false;
		}
	}

	document.addEventListener('click', function (event) {
		if (document.body.classList.contains('kidia-cms-plugin-page')) return;
		const link = event.target.closest('a[href]');
		if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
		if (!pluginPage(link.href)) return;
		event.preventDefault();
		void enterCms(link.href);
	});

	window.addEventListener('popstate', function () {
		if (document.body.classList.contains('kidia-cms-plugin-page') && !pluginPage(window.location.href)) {
			window.location.reload();
		}
	});
}());
