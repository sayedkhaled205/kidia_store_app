"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.join(__dirname, "..");
const script = fs.readFileSync(path.join(pluginRoot, "admin/assets/settings-sections.js"), "utf8");
const css = fs.readFileSync(path.join(pluginRoot, "admin/assets/admin-theme.css"), "utf8");
const toolbar = fs.readFileSync(path.join(pluginRoot, "admin/pages/builder-toolbar.php"), "utf8");
const page = fs.readFileSync(path.join(pluginRoot, "admin/pages/page-builder.php"), "utf8");
const home = fs.readFileSync(path.join(pluginRoot, "admin/pages/home-builder.php"), "utf8");
const category = fs.readFileSync(path.join(pluginRoot, "admin/pages/category-builder.php"), "utf8");

const field = (key, type = "text") => `<div class="kidia-page-field"><label>${key}<input type="${type}" name="layout[elements][0][settings][${key}]" value="1"></label></div>`;
const position = (key) => `<div class="kidia-page-field"><label>${key}<select name="layout[elements][0][settings][${key}]"><option value="top_start">Top</option><option value="bottom_end">Bottom</option></select></label></div>`;
const dom = new JSDOM(`<!doctype html><body><div class="kidia-page-builder"><section data-element="wishlist_grid"><div class="kidia-page-card__body"><div class="kidia-page-fields">
  ${field("image_ratio")}${field("gap")}${field("card_radius")}${field("products_per_page")}
  ${field("quick_add_enabled", "checkbox")}${position("quick_add_position")}${field("quick_add_icon_variant")}${field("quick_add_icon_style")}${field("quick_add_icon_size")}${field("quick_add_icon_color")}${field("quick_add_background_size")}${field("quick_add_radius")}${field("quick_add_background_color")}${field("quick_add_show_background", "checkbox")}
  ${field("show_wishlist", "checkbox")}${position("product_wishlist_position")}${field("product_wishlist_icon_variant")}${field("product_wishlist_icon_style")}${field("product_wishlist_icon_size")}${field("product_wishlist_icon_color")}${field("product_wishlist_background_size")}${field("product_wishlist_radius")}${field("product_wishlist_background_color")}${field("product_wishlist_show_background", "checkbox")}
</div></div></section></div></body>`, { runScripts: "outside-only" });
dom.window.eval(script);
dom.window.document.dispatchEvent(new dom.window.Event("DOMContentLoaded"));

const document = dom.window.document;
assert.equal(document.querySelectorAll(".kidia-settings-section-title--wishlist_products").length, 1, "The four Wishlist Products groups must become one section.");
assert.equal(document.querySelectorAll(".kidia-settings-section-title--image,.kidia-settings-section-title--layout,.kidia-settings-section-title--colors,.kidia-settings-section-title--products").length, 0, "Wishlist Products must not keep the four old headings.");
assert.equal(document.querySelector(".kidia-product-icon-panel--quick_add > .kidia-settings-section-title").textContent.trim().startsWith("Cart Settings"), true, "Wishlist cart controls must use one Cart Settings panel.");
assert.equal(document.querySelector(".kidia-product-icon-panel--carousel_wishlist > .kidia-settings-section-title").textContent.trim().startsWith("Wishlist Settings"), true, "Wishlist icon controls must use one Wishlist Settings panel.");
assert.match(css, /:is\(\[data-element="product_grid"\], \[data-element="wishlist_grid"\]\).*kidia-product-icon-panel__body/, "Wishlist panels must reuse the approved three-column Product Grid arrangement.");

assert.match(toolbar, /kidia-collapse-all[\s\S]*kidia-expand-all/, "The shared toolbar must provide Collapse All and Expand All.");
[home, page, category].forEach((template) => assert.match(template, /admin\/pages\/builder-toolbar\.php/, "Every builder must render the same toolbar template."));

console.log("Shared builder toolbar and Wishlist Products settings layout: ok");
