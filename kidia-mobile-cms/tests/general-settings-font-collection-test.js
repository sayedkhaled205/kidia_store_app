const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), 'utf8');

const setupPage = read('admin', 'pages', 'setup-wizard.php');
const wizard = read('includes', 'class-kidia-mobile-setup-wizard.php');
const pageStore = read('includes', 'class-kidia-mobile-page-layout-store.php');
const exporter = read('includes', 'class-kidia-mobile-app-exporter.php');
const chrome = read('..', 'lib', 'features', 'page_builder', 'presentation', 'widgets', 'cms_page_chrome.dart');

assert.match(setupPage, /General Settings/);
for (const setting of ['primary_color', 'secondary_color', 'language', 'direction', 'app_icon_shape', 'font_family']) {
  assert.match(setupPage, new RegExp(`setup\\[${setting}\\]`));
}
for (const font of ['system', 'poppins', 'roboto', 'noto_sans_arabic', 'serif', 'monospace']) {
  assert.match(setupPage, new RegExp(`value="${font}"`));
  assert.match(pageStore, new RegExp(`['"]${font}['"]`));
}
assert.match(wizard, /app_icon_shape[\s\S]*font_family/);
assert.match(wizard, /apply_pages\([\s\S]*\$font_family/);
assert.match(exporter, /appIconShape[\s\S]*fontFamily/);
assert.match(chrome, /configuredFont[\s\S]*noto_sans_arabic/);

console.log('General Settings and font collection contract passed.');
