const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'includes/class-kidia-mobile-setup-wizard.php'), 'utf8');
const plugin = fs.readFileSync(path.join(root, 'kidia-mobile-cms.php'), 'utf8');

assert.match(source, /'amazon_marketplace'\s*=>\s*self::theme/);
assert.match(source, /'layout_profile'\s*=>\s*'amazon_marketplace'/);
assert.match(source, /'blocks'\s*=>\s*array\(\s*'promo_strip',\s*'quick_links',\s*'hero_slider',\s*'category_grid',\s*'countdown',\s*'product_carousel',\s*'banner_grid',\s*'product_grid',\s*'brand_carousel'/);
assert.match(source, /'amazon_marketplace'\s*=>\s*array\(\s*\$row[\s\S]*?'search_bar'[\s\S]*?'cart'[\s\S]*?'account'[\s\S]*?'orders'/);
assert.match(source, /'amazon_marketplace'\s*===\s*\$profile\s*&&\s*'promo_strip'\s*===\s*\$type[\s\S]*Deliver to your saved address[\s\S]*'addresses'/);
assert.match(source, /'amazon_marketplace'\s*=>\s*array\([\s\S]{0,5000}'chrome'\s*=>\s*array[\s\S]*?'catalog'\s*=>\s*array[\s\S]*?'product'\s*=>\s*array[\s\S]*?'wishlist'\s*=>\s*array[\s\S]*?'account'\s*=>\s*array/);
assert.match(source, /preview fallbacks only[\s\S]*connected store logo and brand palette/);
assert.match(plugin, /Version:\s+1\.46\.42/);

console.log('Amazon marketplace preset contract passed.');
