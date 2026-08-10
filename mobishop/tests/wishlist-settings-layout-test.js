"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.join(__dirname, "..");
const script = fs.readFileSync(path.join(pluginRoot, "admin/assets/settings-sections.js"), "utf8");
const css = fs.readFileSync(path.join(pluginRoot, "admin/assets/admin-theme.css"), "utf8");
const pageCss = fs.readFileSync(path.join(pluginRoot, "admin/assets/page-builder.css"), "utf8");
const toolbar = fs.readFileSync(path.join(pluginRoot, "admin/pages/builder-toolbar.php"), "utf8");
const page = fs.readFileSync(path.join(pluginRoot, "admin/pages/page-builder.php"), "utf8");

assert.ok(
  page.indexOf("mobishop-wishlist-access-mode") < page.indexOf("$chrome_part = 'header'"),
  "Wishlist access mode must render before Fixed Header.",
);
assert.match(
  pageCss,
  /\.mobishop-page-settings-card \+ \.mobishop-wishlist-access-mode\s*\{\s*margin-top:10px;\s*\}/,
  "Wishlist Page Settings and access mode cards must keep the same 10px gap as the other page cards.",
);
const home = fs.readFileSync(path.join(pluginRoot, "admin/pages/home-builder.php"), "utf8");
const category = fs.readFileSync(path.join(pluginRoot, "admin/pages/category-builder.php"), "utf8");

const field = (key, type = "text", extraClass = "") => `<div class="mobishop-page-field ${extraClass}"><label>${key}<input type="${type}" name="layout[elements][0][settings][${key}]" value="1"></label></div>`;
const position = (key) => `<div class="mobishop-page-field"><label>${key}<select name="layout[elements][0][settings][${key}]"><option value="top_start">Top</option><option value="bottom_end">Bottom</option></select></label></div>`;
const dom = new JSDOM(`<!doctype html><body><div class="mobishop-page-builder"><section data-element="wishlist_grid"><div class="mobishop-page-card__body"><div class="mobishop-page-fields">
  ${field("image_ratio")}${field("gap")}${field("card_radius")}${field("products_per_page")}
  ${field("quick_add_enabled", "checkbox")}${position("quick_add_position")}${field("quick_add_icon_variant")}${field("quick_add_icon_style")}${field("quick_add_icon_size")}${field("quick_add_icon_color")}${field("quick_add_background_size")}${field("quick_add_radius")}${field("quick_add_background_color")}${field("quick_add_show_background", "checkbox")}
  ${field("show_wishlist", "checkbox")}${position("product_wishlist_position")}${field("product_wishlist_icon_variant")}${field("product_wishlist_icon_style")}${field("product_wishlist_icon_size")}${field("product_wishlist_icon_color")}${field("product_wishlist_background_size")}${field("product_wishlist_radius")}${field("product_wishlist_background_color")}${field("product_wishlist_show_background", "checkbox")}
</div></div></section></div></body>`, { runScripts: "outside-only" });
dom.window.eval(script);
dom.window.document.dispatchEvent(new dom.window.Event("DOMContentLoaded"));

const document = dom.window.document;
assert.equal(document.querySelectorAll(".mobishop-settings-section-title--wishlist_products").length, 1, "The four Wishlist Products groups must become one section.");
assert.equal(document.querySelectorAll(".mobishop-settings-section-title--image,.mobishop-settings-section-title--layout,.mobishop-settings-section-title--colors,.mobishop-settings-section-title--products").length, 0, "Wishlist Products must not keep the four old headings.");
assert.equal(document.querySelector(".mobishop-product-icon-panel--quick_add > .mobishop-settings-section-title").textContent.trim().startsWith("Cart Settings"), true, "Wishlist cart controls must use one Cart Settings panel.");
assert.equal(document.querySelector(".mobishop-product-icon-panel--carousel_wishlist > .mobishop-settings-section-title").textContent.trim().startsWith("Wishlist Settings"), true, "Wishlist icon controls must use one Wishlist Settings panel.");
assert.match(css, /:is\(\[data-element="product_grid"\], \[data-element="wishlist_grid"\]\).*mobishop-product-icon-panel__body/, "Wishlist panels must reuse the approved three-column Product Grid arrangement.");

assert.match(toolbar, /mobishop-collapse-all[\s\S]*mobishop-expand-all/, "The shared toolbar must provide Collapse All and Expand All.");
[home, page, category].forEach((template) => assert.match(template, /admin\/pages\/builder-toolbar\.php/, "Every builder must render the same toolbar template."));
assert.match(toolbar, /name="layout\[enabled\]"/, "Every shared page builder toolbar must expose a page-level On/Off value.");
assert.match(toolbar, /mobishop-page-availability/, "The page-level On/Off control must have one shared visual contract.");
assert.match(home, /\$mobishop_toolbar_page_toggle\s*=\s*false;/, "Home must not expose Page status because it is always required.");
assert.match(page, /\$mobishop_toolbar_page_toggle\s*=\s*true;/, "Every optional shared page must expose Page status in its toolbar.");
assert.match(category, /\$mobishop_toolbar_page_toggle\s*=\s*true;/, "Category must expose Page status in its toolbar.");
assert.match(pageCss, /\.mobishop-shared-builder-toolbar \.mobishop-page-availability\{[^}]*width:138px;[^}]*height:34px;[^}]*grid-template-columns:38px minmax\(82px,1fr\);/, "Page status must use the same height as the other toolbar controls and only the compact switch and copy columns.");
assert.match(pageCss, /\.mobishop-shared-builder-toolbar \.mobishop-page-availability__copy\{[^}]*display:grid;[^}]*gap:1px;[^}]*white-space:nowrap/, "Page status and Active or Disabled must remain readable in the compact two-column control.");
assert.doesNotMatch(toolbar, /mobishop-page-availability__icon|dashicons-visibility/, "The compact Page status control must not keep the redundant eye icon.");
assert.doesNotMatch(toolbar, /mobishop-builder-toolbar__context/, "The shared toolbar must not repeat the current page title.");
assert.match(css, /\.mobishop-shared-builder-toolbar :is\([\s\S]*?\.mobishop-builder-toolbar__actions,[\s\S]*?\.mobishop-builder-toolbar__save,[\s\S]*?\)\s*\{[^}]*flex-wrap:\s*nowrap;/, "Desktop builder toolbar controls must stay on one row.");

console.log("Shared builder toolbar and Wishlist Products settings layout: ok");

const relatedDom = new JSDOM(`<!doctype html><body><div class="mobishop-page-builder"><section data-element="related_products"><div class="mobishop-page-card__body"><div class="mobishop-page-fields">
  ${field("title")}${field("columns")}${field("gap")}${field("image_ratio")}${field("show_price", "checkbox")}${field("show_quick_add", "checkbox")}
  ${field("margin_top", "number", "mobishop-section-layout-field")}${field("margin_bottom", "number", "mobishop-section-layout-field")}${field("space_up", "number", "mobishop-section-layout-field")}${field("space_down", "number", "mobishop-section-layout-field")}${field("background_color", "color", "mobishop-section-layout-field")}
</div></div></section></div></body>`, { runScripts: "outside-only" });
relatedDom.window.eval(script);
relatedDom.window.document.dispatchEvent(new relatedDom.window.Event("DOMContentLoaded"));
const relatedDocument = relatedDom.window.document;
assert.equal(relatedDocument.querySelectorAll(".mobishop-settings-section-title--related_products").length, 1, "Related Products must merge every content section into one.");
assert.equal(relatedDocument.querySelectorAll(".mobishop-section-layout-panel").length, 1, "Related Products must keep one isolated standard Section Layout Settings panel.");
assert.equal(relatedDocument.querySelectorAll(".mobishop-section-layout-panel .mobishop-page-field").length, 5, "The standard Related Products layout panel must contain only the five canonical layout fields.");
