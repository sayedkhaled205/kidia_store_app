const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');

const pluginRoot = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(pluginRoot, 'shared-runtime', 'manifest.json'), 'utf8'));
const dom = new JSDOM('<!doctype html><div id="app"></div>', { runScripts: 'outside-only' });
const scripts = ['platform-adapter.js', 'runtime.js'];
scripts.forEach((file) => dom.window.eval(fs.readFileSync(path.join(pluginRoot, 'shared-runtime', file), 'utf8')));

assert.deepEqual(Array.from(dom.window.MobiShopPlatformAdapter.requiredMethods), manifest.adapterContract);
manifest.canonicalAssets.forEach((asset) => {
	assert.ok(fs.existsSync(path.join(pluginRoot, asset)), `Canonical shared asset must exist: ${asset}`);
});

const calls = [];
const adapter = {
	platform: 'contract-test',
	async bootstrap() { calls.push('bootstrap'); return { initialScreen: 'dashboard' }; },
	async loadScreen(screen) { calls.push(`load:${screen}`); return { screen }; },
	async saveScreen(screen) { calls.push(`save:${screen}`); return { ok: true }; },
	async navigate(target) { calls.push(`navigate:${target}`); },
	async uploadMedia() { calls.push('uploadMedia'); },
	async startBuild() { calls.push('startBuild'); }
};
const root = dom.window.document.getElementById('app');
const runtime = dom.window.MobiShopBuilderRuntime.create({
	root,
	adapter,
	renderers: {
		dashboard(target, payload) { target.textContent = payload.screen; }
	}
});

(async () => {
	await runtime.mount();
	assert.equal(root.dataset.mobishopPlatform, 'contract-test');
	assert.equal(root.dataset.mobishopScreen, 'dashboard');
	assert.equal(root.textContent, 'dashboard');
	await runtime.api.save('dashboard', {});
	assert.deepEqual(calls, ['bootstrap', 'load:dashboard', 'save:dashboard']);
	console.log('Shared MobiShop runtime and platform adapter contract passed.');
})().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});

