const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const pluginRoot = path.resolve(__dirname, "..");
const template = fs.readFileSync(
  path.join(pluginRoot, "admin", "pages", "fixed-chrome-card.php"),
  "utf8",
);
const css = fs.readFileSync(
  path.join(pluginRoot, "admin", "assets", "chrome-layout.css"),
  "utf8",
);

const expectedItems = {
  standard: [["logo"], ["search"], ["wishlist", "cart"]],
  centered: [["menu"], ["logo"], ["cart"]],
  page: [["back"], ["title"], ["cart"]],
  actions: [["menu", "search"], ["logo"], ["account", "cart"]],
};

for (const [preset, columns] of Object.entries(expectedItems)) {
  const presetStart = template.indexOf(`'${preset}'`);
  assert.notEqual(presetStart, -1, `${preset} must exist.`);
  const definition = template.slice(presetStart, template.indexOf("\n", presetStart));
  for (const items of columns) {
    assert.match(
      definition,
      new RegExp(`array\\( ${items.map((item) => `'${item}'`).join(", ")} \\)`),
      `${preset} thumbnail must include ${items.join(" + ")}.`,
    );
  }
}

assert.match(
  template,
  /'search'[\s\S]*array\( array\( 'logo' \), array\( 'cart' \) \), array\( array\( 'search_bar' \) \)/,
  "Search first must show the real Logo/Cart row and full-width Search row.",
);
assert.match(
  template,
  /mobishop-header-preset__row[\s\S]*mobishop-header-preset__column[\s\S]*mobishop-header-preset__item--/,
  "Preset previews must render real rows, columns, and items.",
);
assert.match(
  css,
  /\.mobishop-header-presets\s*\{[^}]*box-sizing:border-box;[^}]*width:100%;[^}]*max-width:100%;[^}]*overflow:hidden;/,
  "The preset section must contain its grid.",
);
assert.match(
  css,
  /\.mobishop-header-presets__grid\s*\{[^}]*repeat\(auto-fit,minmax\(min\(142px,100%\),1fr\)\)/,
  "Preset cards must wrap responsively without overflowing.",
);
assert.match(
  css,
  /@media\(max-width:480px\)\{\.mobishop-header-presets__grid\{grid-template-columns:1fr\}\}/,
  "Preset cards must reduce to one contained column on narrow screens.",
);

console.log("Quick Header Presets previews and responsive containment passed.");
