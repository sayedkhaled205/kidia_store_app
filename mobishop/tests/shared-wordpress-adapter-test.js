const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');

const pluginRoot = path.resolve(__dirname, '..');
const endpoint = fs.readFileSync(path.join(pluginRoot, 'api', 'class-home-layout-endpoint.php'), 'utf8');
const registry = fs.readFileSync(path.join(pluginRoot, 'includes', 'class-mobishop-block-registry.php'), 'utf8');
assert.match(endpoint, /\/builder\/home/);
assert.match(endpoint, /get_builder_home/);
assert.match(endpoint, /save_builder_home/);
assert.match(endpoint, /\/builder\/screen\/\(\?P<screen>/);
assert.match(endpoint, /get_builder_screen/);
assert.match(endpoint, /save_builder_screen/);
assert.match(endpoint, /SHARED_BUILDER_SCREENS/);
assert.match(endpoint, /MobiShop_Block_Registry::schemas\(\)/);
assert.match(endpoint, /builder_store_stats/);
assert.match(endpoint, /wc_orders_count/);
assert.match(endpoint, /is_active\(\)/);
assert.match(registry, /public static function schemas\(\): array/);

const dom = new JSDOM('<!doctype html><div id="app"></div>', { runScripts: 'outside-only', url: 'https://store.example/wp-admin/' });
const calls = [];
dom.window.fetch = async (url, options = {}) => {
	calls.push({ url, options });
	return { ok: true, json: async () => options.method === 'POST' ? { ok: true } : String(url).includes('/builder/screen/') ? { settings: { ready: true } } : { blocks: [], blockSchema: { blocks: {} } } };
};
['shared-runtime/platform-adapter.js', 'shared-runtime/adapters/wordpress.js'].forEach((file) => dom.window.eval(fs.readFileSync(path.join(pluginRoot, file), 'utf8')));

(async () => {
	const adapter = dom.window.MobiShopWordPressAdapter.create({ nonce: 'test-nonce', buildEndpoint: '/build' });
	const state = await adapter.bootstrap();
	assert.equal(adapter.platform, 'wordpress');
	assert.equal(state.initialScreen, 'home-builder');
	await adapter.saveScreen('home-builder', { blocks: [] });
	const product = await adapter.loadScreen('product-builder');
	assert.equal(product.settings.ready, true);
	await adapter.saveScreen('product-builder', { product_tabs__enabled: true });
	assert.equal(calls[0].options.headers['X-WP-Nonce'], 'test-nonce');
	assert.equal(calls[1].options.method, 'POST');
	assert.equal(calls[2].url, '/wp-json/mobishop/v1/builder/screen/product-builder');
	assert.equal(calls[3].options.method, 'POST');
	assert.deepEqual(JSON.parse(calls[3].options.body), { settings: { product_tabs__enabled: true } });
	console.log('Shared WordPress adapter and Builder REST contract passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });

