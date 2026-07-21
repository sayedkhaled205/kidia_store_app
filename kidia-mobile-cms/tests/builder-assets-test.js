"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");
const createJQuery = require("jquery");

const pluginRoot = path.resolve(__dirname, "..");

function readAsset(name) {
  return fs.readFileSync(path.join(pluginRoot, "admin", "assets", name), "utf8");
}

function input(name, value, extra = "") {
  return `<input name="blocks[0][settings][${name}]" value="${value}" ${extra}>`;
}

function mediaField(name, value, inputClass, buttonClass, previewClass) {
  return `<div class="kidia-builder-field kidia-builder-field--media">
    <input type="url" class="${inputClass}" name="blocks[0][settings][${name}]" value="${value}">
    <button type="button" class="${buttonClass}">Select image</button>
    <img class="${previewClass}" src="${value}" alt="">
  </div>`;
}

function homeBlock(type, index, settings, name = type) {
  return `
    <div class="kidia-builder-block is-collapsed" data-type="${type}" data-library-id="${type}_${index}">
      <div class="kidia-builder-block__header">
        <span class="kidia-builder-drag"></span>
        <strong class="kidia-block-name">${name}</strong>
        <span class="kidia-builder-status kidia-builder-status--published">Published</span>
        <button type="button" class="kidia-toggle-block-settings">Toggle</button>
        <button type="button" class="kidia-duplicate-block">Duplicate</button>
        <button type="button" class="kidia-delete-block">Remove</button>
      </div>
      <div class="kidia-builder-block__body">
        <input class="kidia-block-id" name="blocks[${index}][id]" value="${type}_${index}">
        <input class="kidia-block-library-id" name="blocks[${index}][library_id]" value="${type}_${index}">
        <input class="kidia-block-source-library-id" name="blocks[${index}][source_library_id]" value="">
        <input class="kidia-block-create-intent" name="blocks[${index}][create_intent]" value="0">
        <input class="kidia-block-type" name="blocks[${index}][type]" value="${type}">
        <input class="kidia-block-order" name="blocks[${index}][order]" value="${index + 1}">
        <input class="kidia-block-status" name="blocks[${index}][status]" value="published">
        <div class="kidia-builder-essentials">
          <div class="kidia-builder-field kidia-builder-field--name"><input class="kidia-block-name-input" name="blocks[${index}][name]" value="${name}"></div>
          <div class="kidia-builder-field kidia-builder-field--enabled"><input type="checkbox" name="blocks[${index}][enabled]" value="1" checked></div>
          <div class="kidia-builder-field kidia-builder-field--visibility"><select class="kidia-block-status-select"><option value="published" selected>Published</option><option value="draft">Draft</option></select></div>
        </div>
        <div class="kidia-builder-inline-settings">
          <div class="kidia-builder-settings-heading">Element Settings</div>
          <div class="kidia-builder-settings-content">${settings.replaceAll("blocks[0]", `blocks[${index}]`)}</div>
        </div>
      </div>
    </div>`;
}

function homeMarkup() {
  const heroItem = `
    <div class="kidia-hero-block-item">
      <input name="blocks[0][settings][items][0][id]" value="slide_1">
      <input type="checkbox" name="blocks[0][settings][items][0][enabled]" value="1" checked>
      <input class="kidia-hero-block-image-url" name="blocks[0][settings][items][0][image_url]" value="https://example.com/hero.jpg">
      <input name="blocks[0][settings][items][0][title]" value="Summer">
      <input name="blocks[0][settings][items][0][subtitle]" value="New collection">
      <button type="button" class="kidia-select-hero-block-image">Select</button>
      <button type="button" class="kidia-remove-hero-block-item">Remove slide</button>
      <img class="kidia-hero-block-image-preview" alt="">
    </div>`;
  const heroTemplate = heroItem
    .replaceAll("[0][id]", "[__ITEM_INDEX__][id]")
    .replaceAll("[0][enabled]", "[__ITEM_INDEX__][enabled]")
    .replaceAll("[0][image_url]", "[__ITEM_INDEX__][image_url]")
    .replaceAll("[0][title]", "[__ITEM_INDEX__][title]")
    .replaceAll("[0][subtitle]", "[__ITEM_INDEX__][subtitle]")
    .replace("slide_1", "");
  const repeatableItem = `
    <div class="kidia-repeatable-item">
      <div class="kidia-builder-field kidia-builder-field--media">
        <input class="kidia-media-url" name="blocks[0][settings][items][0][image_url]" value="https://example.com/tile.jpg">
        <button type="button" class="kidia-select-media">Select</button>
        <img class="kidia-media-preview" src="https://example.com/tile.jpg" alt="">
      </div>
      <input name="blocks[0][settings][items][0][label]" value="Kids">
      <input name="blocks[0][settings][items][0][title]" value="Summer">
      <button type="button" class="kidia-remove-repeatable-item">Remove item</button>
    </div>`;
  const repeatableTemplate = repeatableItem.replaceAll("[items][0]", "[items][__ITEM_INDEX__]");

  const blocks = [
    homeBlock("app_header", 0, `${mediaField("logo_url", "https://example.com/logo.png", "kidia-app-header-logo-url", "kidia-select-app-header-logo", "kidia-media-preview kidia-app-header-logo-preview")}${input("title", "Kidia")}${input("subtitle", "Kids store")}${input("height", "64")}${input("logo_height", "38")}${input("title_color", "#1F2933")}${input("icon_color", "#1F2933")}<input type="checkbox" name="blocks[0][settings][show_search]" value="1" checked><input type="checkbox" name="blocks[0][settings][show_cart]" value="1" checked><input type="checkbox" name="blocks[0][settings][show_account]" value="1">`),
    homeBlock("hero_slider", 1, `${input("aspect_ratio", "1.8")}<div class="kidia-hero-block-items">${heroItem}</div><button type="button" class="kidia-add-hero-block-item">Add Slide</button><script type="text/html" class="tmpl-kidia-hero-block-item">${heroTemplate}</script>`),
    homeBlock("category_grid", 2, `${input("title", "Categories")}${input("columns", "4")}${input("limit", "4")}${input("margin_top", "0")}${input("margin_bottom", "0")}${input("margin_horizontal", "0")}${input("padding_vertical", "0")}${input("padding_horizontal", "0")}${input("block_radius", "0")}${input("content_scale", "100")}<input type="color" name="blocks[0][settings][block_background]" value="#ffffff"><input type="checkbox" name="blocks[0][settings][show_names]" value="1" checked>`),
    homeBlock("image_banner", 3, `${mediaField("image_url", "https://example.com/banner.jpg", "kidia-banner-image-url", "kidia-select-banner-image", "kidia-banner-image-preview")}${input("aspect_ratio", "2.4")}${input("border_radius", "18")}<div class="kidia-builder-field"><select name="blocks[0][settings][action_type]"><option value="product" selected>Product</option><option value="category">Category</option></select></div><div class="kidia-builder-field"><label>Action Value</label>${input("action_value", "12")}</div>`),
    homeBlock("product_carousel", 4, `${input("title", "Latest")}${input("limit", "3")}`),
    homeBlock("product_grid", 5, `${input("title", "Offers")}${input("columns", "2")}${input("limit", "4")}`),
    homeBlock("section_header", 6, `${input("title", "Featured")}${input("subtitle", "Chosen for you")}${input("view_all_label", "View all")}<input type="checkbox" name="blocks[0][settings][show_view_all]" value="1" checked>`),
    homeBlock("brand_carousel", 7, `${input("title", "Brands")}${input("limit", "4")}`),
    homeBlock("promo_strip", 8, `${input("text", "Free delivery", 'class="promo-text"')}${input("background_color", "#4f9f8f")}${input("text_color", "#ffffff")}`),
    homeBlock("coupon_banner", 9, `${input("title", "Save now")}${input("description", "Special offer")}${input("coupon_code", "KIDIA20")}${mediaField("image_url", "https://example.com/coupon.jpg", "kidia-media-url", "kidia-select-media", "kidia-media-preview")}`),
    homeBlock("countdown", 10, `${input("title", "Ends soon")}${input("ends_at", "2030-01-01T00:00")}`),
    homeBlock("video_banner", 11, `${input("video_url", "https://example.com/video.mp4")}${mediaField("poster_url", "https://example.com/poster.jpg", "kidia-media-url", "kidia-select-media", "kidia-media-preview")}${input("aspect_ratio", "1.8")}`),
    homeBlock("text_block", 12, `${input("title", "Welcome")}<textarea name="blocks[0][settings][content]">Hello families</textarea>${input("alignment", "right")}${input("background", "#ffffff")}${input("text_color", "#111111")}`),
    homeBlock("divider", 13, `${input("color", "#e5e7eb")}${input("thickness", "1")}${input("margin", "12")}`),
    homeBlock("spacer", 14, input("height", "24")),
    homeBlock("quick_links", 15, `${input("title", "Shop by age")}${input("layout", "carousel")}${input("columns", "4")}<div class="kidia-repeatable-items">${repeatableItem}</div><button type="button" class="kidia-add-repeatable-item">Add Link</button><script type="text/html" class="tmpl-kidia-repeatable-item">${repeatableTemplate}</script>`),
    homeBlock("banner_grid", 16, `${input("title", "Collections")}${input("layout", "featured")}${input("columns", "2")}${input("aspect_ratio", "1")}<div class="kidia-repeatable-items">${repeatableItem}</div><button type="button" class="kidia-add-repeatable-item">Add Banner</button><script type="text/html" class="tmpl-kidia-repeatable-item">${repeatableTemplate}</script>`),
  ].join("");

  const createTemplate = homeBlock("spacer", 987654321, input("height", "32"), "__BLOCK_NAME__")
    .replaceAll("spacer_987654321", "__BLOCK_ID__")
    .replaceAll("987654322", "__ORDER__")
    .replaceAll("987654321", "__INDEX__");

  return `<!doctype html><html><body>
    <button id="kidia-add-element" type="button">Add Element</button>
    <button id="kidia-collapse-all" type="button">Collapse All</button>
    <button id="kidia-expand-all" type="button">Expand All</button>
    <div id="kidia-element-picker" hidden aria-hidden="true"><button type="button" class="kidia-create-element" data-block-type="spacer" data-block-label="Spacer">Create Spacer</button></div>
    <div id="kidia-create-element-modal" hidden aria-hidden="true"><h2 id="kidia-create-element-title"></h2><input id="kidia-create-element-name"><span id="kidia-create-element-error" hidden></span><button id="kidia-create-element-submit" type="button">Create</button></div>
    <input id="kidia-element-picker-search"><div id="kidia-element-picker-no-results" hidden></div>
    <div class="kidia-element-group">Layout</div>
    <form id="kidia-home-builder-form"><input id="kidia-home-builder-payload"><div id="kidia-home-builder">${blocks}</div></form>
    <div id="kidia-mobile-preview-content"></div>
    <script type="text/html" id="tmpl-kidia-block-spacer">${createTemplate}</script>
  </body></html>`;
}

function click(window, element) {
  element.dispatchEvent(new window.MouseEvent("click", { bubbles: true, cancelable: true }));
}

function runHomeBuilderTest() {
  const dom = new JSDOM(homeMarkup(), { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
  const { window } = dom;
  const builderCss = readAsset("home-builder.css");
  const adminThemeCss = readAsset("admin-theme.css");
  const adminPhp = fs.readFileSync(path.join(pluginRoot, "admin", "class-kidia-mobile-cms-admin.php"), "utf8");
  let mediaOpenCount = 0;
  window.HTMLElement.prototype.scrollIntoView = function () {};
  window.confirm = () => true;
  window.wp = {
    media() {
      let selectCallback = function () {};
      return {
        on(event, callback) { if (event === "select") selectCallback = callback; },
        open() { mediaOpenCount += 1; selectCallback(); },
        state() {
          return { get() { return { first() { return { toJSON() { return { url: `https://example.com/selected-${mediaOpenCount}.jpg` }; } }; } }; } };
        },
      };
    },
  };
  window.kidiaHomeBuilder = {
    labels: { copySuffix: " Copy" },
    actionChoices: {
      product: [{ value: "11", label: "Pink Kids Set" }, { value: "12", label: "Blue Kids Set" }],
      category: [{ value: "1", label: "Clothes" }, { value: "2", label: "Toys" }],
    },
    previewBlocks: [
      {
        id: "category_grid_2",
        type: "category_grid",
        data: {
          title: "Categories",
          items: [
            { id: 1, name: "Clothes", image_url: "https://example.com/clothes.jpg" },
            { id: 2, name: "Toys", image_url: "https://example.com/toys.jpg" },
            { id: 3, name: "Shoes", image_url: "https://example.com/shoes.jpg" },
            { id: 4, name: "Baby", image_url: "https://example.com/baby.jpg" },
          ],
        },
      },
      {
        id: "product_carousel_4",
        type: "product_carousel",
        data: {
          title: "Latest",
          show_view_all: true,
          items: [
            { id: 11, name: "Pink Kids Set", image_url: "https://example.com/product-1.jpg", price: "450", regular_price: "520", currency_symbol: "ج.م", in_stock: true, badge: "Sale" },
            { id: 12, name: "Blue Kids Set", image_url: "https://example.com/product-2.jpg", price: "390", regular_price: null, currency_symbol: "ج.م", in_stock: true, badge: null },
            { id: 13, name: "Baby Dress", image_url: "https://example.com/product-3.jpg", price: "300", regular_price: null, currency_symbol: "ج.م", in_stock: false, badge: null },
          ],
        },
      },
      {
        id: "product_grid_5",
        type: "product_grid",
        data: {
          title: "Offers",
          items: [
            { id: 21, name: "Summer Outfit", image_url: "https://example.com/product-4.jpg", price: "275", regular_price: "350", currency_symbol: "ج.م", in_stock: true, badge: "Sale" },
            { id: 22, name: "Cotton T-shirt", image_url: "https://example.com/product-5.jpg", price: "220", regular_price: null, currency_symbol: "ج.م", in_stock: true, badge: null },
          ],
        },
      },
      {
        id: "brand_carousel_7",
        type: "brand_carousel",
        data: {
          title: "Brands",
          item_width: 92,
          items: [
            { id: 31, name: "Kidia", logo_url: "https://example.com/brand-1.jpg" },
            { id: 32, name: "Mini", logo_url: "https://example.com/brand-2.jpg" },
          ],
        },
      },
    ],
  };
  window.eval(readAsset("home-builder.js"));

  assert.equal(window.kidiaHomeBuilderBooted, true, "Home Builder must boot.");
  assert.equal(window.document.querySelectorAll(".kidia-builder-block").length, 17, "All 17 element editors must load.");
  assert.equal(window.document.querySelectorAll(".kidia-builder-essentials").length, 17, "Every editor must use the compact essentials panel.");
  assert.equal(window.document.querySelectorAll(".kidia-builder-settings-content").length, 17, "Every editor must use the shared settings panel.");
  const actionType = window.document.querySelector('[name="blocks[3][settings][action_type]"]');
  let actionValue = window.document.querySelector('[name="blocks[3][settings][action_value]"]');
  assert.equal(actionValue.tagName, "SELECT", "Product actions must replace Action Value with a product selector.");
  assert.equal(actionValue.value, "12", "The contextual selector must preserve the saved destination.");
  assert.equal(actionValue.closest(".kidia-builder-field").querySelector("label").textContent, "Product ID", "Product actions must identify the destination as a Product ID.");
  assert.match(actionType.textContent, /Products on sale/, "Every action selector must expose discounted products directly.");
  actionType.value = "category";
  actionType.dispatchEvent(new window.Event("change", { bubbles: true }));
  actionValue = window.document.querySelector('[name="blocks[3][settings][action_value]"]');
  assert.match(actionValue.textContent, /Clothes/, "Category actions must load WooCommerce category choices.");
  assert.match(builderCss, /\.kidia-builder-wrap\s*\{[\s\S]*?max-width:\s*1380px;/, "The full Builder workspace must keep its original desktop width.");
  assert.match(builderCss, /grid-template-columns:\s*300px minmax\(0, 1fr\)/, "The editor must reserve the five-percent wider phone preview without crowding the settings.");
	assert.match(builderCss, /\.kidia-mobile-preview__device\s*\{[\s\S]*?width:\s*283\.5px;[\s\S]*?margin-inline-start:\s*auto;/, "The Home phone must be five percent wider and shifted toward the element editor.");
	assert.match(builderCss, /\.kidia-mobile-preview\s*\{[\s\S]*?transform:\s*translateX\(clamp\(35px,\s*calc\(11\.5cqw - 30px\),\s*130px\)\)/, "The Home phone must remain centered inside the real blank space beside the cards.");
	assert.match(builderCss, /\.kidia-builder-block__header\s*\{[\s\S]*?direction:\s*rtl;/, "Every Home element header must keep its identity on the right.");
	assert.match(builderCss, /\.kidia-builder-block__actions\s*\{[\s\S]*?direction:\s*rtl;/, "Every Home element must keep Remove, Duplicate, expand, and On/Off in one stable order.");
	assert.doesNotMatch(builderCss, /data-type="product_carousel"[^\{]*\.kidia-builder-block__actions\s*\{[^}]*direction:\s*ltr;/, "Product Carousel must not reverse the shared element action order.");
  assert.match(builderCss, /\.kidia-builder-block\s*\{[\s\S]*?width:\s*77%;/, "Element cards must be 10% wider than their previous 70% width.");
  assert.match(builderCss, /\.kidia-builder-block__header\s*\{[\s\S]*?min-height:\s*70px;/, "Collapsed element cards must use the requested 70px height.");
  assert.match(builderCss, /\.kidia-builder-grid\s*\{[\s\S]*?repeat\(3, minmax\(0, 1fr\)\)/, "Element settings must keep the original three-column layout.");
  assert.match(builderCss, /--kidia-field-width:\s*64\.9351%;/, "The wider 77% card must preserve controls at 50% of their original width.");
  assert.match(builderCss, /input\[type="text"\],[\s\S]*?width:\s*var\(--kidia-field-width\);/, "Settings controls must use the calculated half-original width.");
  assert.match(builderCss, /input\[type="color"\]\s*\{[\s\S]*?width:\s*var\(--kidia-field-width\);/, "Color controls must use the calculated half-original width.");
  assert.match(adminThemeCss, /--kidia-settings-control-width:\s*150px;/, "Every Builder must use the shared 150px value-control width.");
  assert.match(adminThemeCss, /--kidia-settings-control-height:\s*35px;/, "Every Builder must use the shared 35px value-control height.");
  assert.match(adminThemeCss, /@media\s*\(max-width:\s*782px\)[\s\S]*?--kidia-settings-control-width:\s*100%;/, "Value controls must remain responsive on narrow screens.");
  assert.match(builderCss, /\.kidia-banner-image-preview,[\s\S]*?height:\s*150px;/, "Large media must be constrained to a compact preview.");
  assert.match(adminPhp, /rest_url\(\s*'woo-mobile\/v1\/home-layout'\s*\)/, "Home Builder must load preview items from the same Home Layout API used by Flutter.");

  const previewSelectors = [
    ".kidia-preview-header", ".kidia-preview-hero", ".kidia-preview-category-grid",
    ".kidia-preview-banner", ".kidia-preview-product-row", ".kidia-preview-product-grid",
    ".kidia-preview-section-heading--standalone", ".kidia-preview-brand-row", ".kidia-preview-promo",
    ".kidia-preview-coupon", ".kidia-preview-countdown", ".kidia-preview-video",
    ".kidia-preview-text", ".kidia-preview-divider", ".kidia-preview-spacer",
    ".kidia-preview-quick-links", ".kidia-preview-banner-grid",
  ];
  previewSelectors.forEach((selector) => assert.ok(window.document.querySelector(selector), `${selector} must render in the phone preview.`));
  assert.equal(window.document.querySelectorAll(".kidia-preview-product-row .kidia-preview-product-card img").length, 3, "Product Carousel must render real API product images.");
  assert.match(window.document.querySelector(".kidia-preview-product-row .kidia-preview-product-card").textContent, /Pink Kids Set/, "Product Carousel must render real API product names.");
  assert.match(window.document.querySelector(".kidia-preview-product-row .kidia-preview-product-card").textContent, /450 ج\.م/, "Product Carousel must render the same price and currency data as Flutter.");
  assert.equal(window.document.querySelectorAll(".kidia-preview-product-row .kidia-preview-sample-image").length, 0, "Product Carousel must not use empty placeholder squares when API items exist.");
  assert.ok(window.document.querySelector(".kidia-preview-product-grid .kidia-preview-product-card img"), "Product Grid must render real API product cards.");
  assert.ok(window.document.querySelector(".kidia-preview-category-card img"), "Category Grid must render real API category images.");
  assert.ok(window.document.querySelector(".kidia-preview-brand-card img"), "Brand Carousel must render real API brand logos.");

  const categoryBlock = window.document.querySelector('[data-type="category_grid"]');
  const categoryFrame = () => window.document.querySelector('[data-preview-block="category_grid_2"]');
  const presentationCases = [
    ["margin_horizontal", "9", "marginLeft", "9px"],
    ["padding_vertical", "11", "paddingTop", "11px"],
    ["padding_horizontal", "7", "paddingLeft", "7px"],
    ["block_radius", "15", "borderRadius", "15px"],
  ];
  presentationCases.forEach(([fieldName, value, styleName, expected]) => {
    const field = categoryBlock.querySelector(`[name$="[settings][${fieldName}]"]`);
    field.value = value;
    field.dispatchEvent(new window.Event("input", { bubbles: true }));
    assert.equal(categoryFrame().style[styleName], expected, `${fieldName} must update the Home preview instantly.`);
  });
  const mergeUp = categoryBlock.querySelector('[name$="[settings][margin_top]"]');
  const mergeDown = categoryBlock.querySelector('[name$="[settings][margin_bottom]"]');
  mergeUp.value = "13";
  mergeUp.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.equal(categoryFrame().style.transform, "translateY(-13px)", "Merge up must pull the Home element toward the section above.");
  mergeDown.value = "17";
  mergeDown.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.equal(categoryFrame().style.transform, "translateY(4px)", "Merge down must pull the Home element toward the section below.");
  const backgroundField = categoryBlock.querySelector('[name$="[settings][block_background]"]');
  backgroundField.value = "#eaf6f2";
  backgroundField.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.equal(categoryFrame().style.backgroundColor, "rgb(234, 246, 242)", "Block background must update the Home preview instantly.");
  presentationCases.forEach(([fieldName]) => {
    const field = categoryBlock.querySelector(`[name$="[settings][${fieldName}]"]`);
    field.value = "0";
    field.dispatchEvent(new window.Event("input", { bubbles: true }));
  });
  mergeUp.value = "0";
  mergeDown.value = "0";
  assert.equal(categoryFrame().style.marginTop, "0px", "Zero space above must join adjacent sections without a separator.");
  assert.equal(categoryFrame().style.marginBottom, "0px", "Zero space below must join adjacent sections without a separator.");

  click(window, window.document.getElementById("kidia-expand-all"));
  assert.equal(window.document.querySelectorAll(".kidia-builder-block.is-collapsed").length, 0, "Expand All must open every element.");
  click(window, window.document.getElementById("kidia-collapse-all"));
  assert.equal(window.document.querySelectorAll(".kidia-builder-block.is-collapsed").length, 17, "Collapse All must close every element.");

  const firstBlock = window.document.querySelector(".kidia-builder-block");
  click(window, firstBlock.querySelector(".kidia-duplicate-block"));
  assert.equal(window.document.querySelectorAll(".kidia-builder-block").length, 18, "Duplicate must clone an element.");
  click(window, firstBlock.nextElementSibling.querySelector(".kidia-delete-block"));
  assert.equal(window.document.querySelectorAll(".kidia-builder-block").length, 17, "Remove must delete the selected element.");

  const hero = window.document.querySelector('[data-type="hero_slider"]');
  click(window, hero.querySelector(".kidia-add-hero-block-item"));
  assert.equal(hero.querySelectorAll(".kidia-hero-block-item").length, 2, "Add Slide must add a real Hero item.");
  assert.match(hero.querySelectorAll(".kidia-hero-block-item")[1].querySelector("input").name, /\[items\]\[1\]/, "New Hero fields must be reindexed.");
  click(window, hero.querySelectorAll(".kidia-remove-hero-block-item")[1]);
  assert.equal(hero.querySelectorAll(".kidia-hero-block-item").length, 1, "Remove Slide must remove only that slide.");

  const quickLinks = window.document.querySelector('[data-type="quick_links"]');
  click(window, quickLinks.querySelector(".kidia-add-repeatable-item"));
  assert.equal(quickLinks.querySelectorAll(".kidia-repeatable-item").length, 2, "Add Quick Link must add a real item.");
  assert.match(quickLinks.querySelectorAll(".kidia-repeatable-item")[1].querySelector("input").name, /\[items\]\[1\]/, "New repeatable fields must be reindexed.");
  click(window, quickLinks.querySelectorAll(".kidia-remove-repeatable-item")[1]);
  assert.equal(quickLinks.querySelectorAll(".kidia-repeatable-item").length, 1, "Remove Quick Link must remove only that item.");

  const mediaCases = [
    ["app_header", ".kidia-select-app-header-logo", ".kidia-media-preview", ".kidia-app-header-logo-url"],
    ["hero_slider", ".kidia-select-hero-block-image", ".kidia-hero-block-image-preview", ".kidia-hero-block-image-url"],
    ["image_banner", ".kidia-select-banner-image", ".kidia-banner-image-preview", ".kidia-banner-image-url"],
    ["coupon_banner", ".kidia-select-media", ".kidia-media-preview", ".kidia-media-url"],
    ["video_banner", ".kidia-select-media", ".kidia-media-preview", ".kidia-media-url"],
    ["quick_links", ".kidia-select-media", ".kidia-media-preview", ".kidia-media-url"],
    ["banner_grid", ".kidia-select-media", ".kidia-media-preview", ".kidia-media-url"],
  ];
  mediaCases.forEach(([type, buttonSelector, previewSelector, inputSelector]) => {
    const mediaBlock = window.document.querySelector(`[data-type="${type}"]`);
    const button = mediaBlock.querySelector(buttonSelector);
    const preview = mediaBlock.querySelector(previewSelector);
    const field = mediaBlock.querySelector(inputSelector);
    click(window, button);
    assert.match(field.value, /selected-\d+\.jpg$/, `${type} button must select an image from WordPress media.`);
    assert.equal(preview.src, field.value, `${type} button must update its settings preview.`);
    click(window, preview);
    assert.match(field.value, /selected-\d+\.jpg$/, `${type} preview must reopen WordPress media.`);
    assert.equal(preview.src, field.value, `${type} preview selection must update immediately.`);
  });
  assert.equal(mediaOpenCount, 14, "Every manual image button and preview must open WordPress media.");
  assert.match(window.document.querySelector(".kidia-preview-coupon img").src, /selected-\d+\.jpg$/, "Media selection must update the mobile preview immediately.");

  const promoInput = window.document.querySelector(".promo-text");
  promoInput.value = "Live preview updated";
  promoInput.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.match(window.document.querySelector(".kidia-preview-promo").textContent, /Live preview updated/, "Input changes must update the Home preview instantly.");

  const appHeader = window.document.querySelector('[data-type="app_header"]');
  const cartToggle = appHeader.querySelector('[name$="[show_cart]"]');
  cartToggle.checked = false;
  cartToggle.dispatchEvent(new window.Event("change", { bubbles: true }));
  window.document.getElementById("kidia-home-builder-form").dispatchEvent(new window.Event("submit", { bubbles: true, cancelable: true }));
  const saved = JSON.parse(Buffer.from(window.document.getElementById("kidia-home-builder-payload").value, "base64").toString("utf8"));
  assert.equal(saved.find((block) => block.type === "app_header").settings.show_cart, "", "Unchecked settings must be saved as false.");
  actionType.value = "on_sale";
  actionType.dispatchEvent(new window.Event("change", { bubbles: true }));
  window.document.getElementById("kidia-home-builder-form").dispatchEvent(new window.Event("submit", { bubbles: true, cancelable: true }));
  const savedAgain = JSON.parse(Buffer.from(window.document.getElementById("kidia-home-builder-payload").value, "base64").toString("utf8"));
  const savedBanner = savedAgain.find((block) => block.type === "image_banner");
  assert.equal(savedBanner.settings.action_type, "collection", "The discounted-products action must save through the compatible collection route.");
  assert.equal(savedBanner.settings.action_value, "on_sale", "A second save must rebuild the payload with the latest action change.");

  const dragHandle = firstBlock.querySelector(".kidia-builder-drag");
  dragHandle.dispatchEvent(new window.Event("pointerdown", { bubbles: true }));
  const dragStart = new window.Event("dragstart", { bubbles: true, cancelable: true });
  Object.defineProperty(dragStart, "dataTransfer", { value: { effectAllowed: "", setData() {} } });
  firstBlock.dispatchEvent(dragStart);
  const targetBlock = hero;
  targetBlock.getBoundingClientRect = () => ({ top: 0, height: 10 });
  const dragOver = new window.Event("dragover", { bubbles: true, cancelable: true });
  Object.defineProperty(dragOver, "clientY", { value: 9 });
  targetBlock.dispatchEvent(dragOver);
  firstBlock.dispatchEvent(new window.Event("dragend", { bubbles: true }));
  assert.equal(window.document.querySelector(".kidia-builder-block").dataset.type, "hero_slider", "Drag and drop must reorder elements.");

  click(window, window.document.getElementById("kidia-add-element"));
  assert.equal(window.document.getElementById("kidia-element-picker").hidden, false, "Add Element must open the picker.");
  click(window, window.document.querySelector(".kidia-create-element"));
  assert.equal(window.document.getElementById("kidia-create-element-modal").hidden, false, "Choosing a type must open the create dialog.");
  window.document.getElementById("kidia-create-element-name").value = "Extra Space";
  click(window, window.document.getElementById("kidia-create-element-submit"));
  assert.equal(window.document.querySelectorAll(".kidia-builder-block").length, 18, "Creating an element must append its template.");

  console.log("Home Builder: all 17 previews and toolbar/editor interactions passed.");
}

function runMergeControlsContractTest() {
	const homePage = fs.readFileSync(path.join(pluginRoot, "admin", "pages", "home-builder.php"), "utf8");
  const template = fs.readFileSync(path.join(pluginRoot, "admin", "templates", "block-template.php"), "utf8");
  const registry = fs.readFileSync(path.join(pluginRoot, "includes", "class-kidia-mobile-block-registry.php"), "utf8");
  const pageStore = fs.readFileSync(path.join(pluginRoot, "includes", "class-kidia-mobile-page-layout-store.php"), "utf8");
  const pageBuilder = fs.readFileSync(path.join(pluginRoot, "admin", "pages", "page-builder.php"), "utf8");
  const categoryBuilder = fs.readFileSync(path.join(pluginRoot, "admin", "pages", "category-builder.php"), "utf8");
  const chromeTemplate = fs.readFileSync(path.join(pluginRoot, "admin", "pages", "fixed-chrome-card.php"), "utf8");
  const heroBlockSource = fs.readFileSync(path.join(pluginRoot, "includes", "blocks", "class-kidia-mobile-hero-slider-block.php"), "utf8");
  const bannerBlockSource = fs.readFileSync(path.join(pluginRoot, "includes", "blocks", "class-kidia-mobile-banner-grid-block.php"), "utf8");
  const categoryGridBlockSource = fs.readFileSync(path.join(pluginRoot, "includes", "blocks", "class-kidia-mobile-category-grid-block.php"), "utf8");
  const homePreview = readAsset("home-builder.js");
  const pagePreview = fs.readFileSync(path.join(pluginRoot, "admin", "assets", "page-builder.js"), "utf8");
  const categoryPreview = fs.readFileSync(path.join(pluginRoot, "admin", "assets", "category-builder.js"), "utf8");
  const settingsSections = readAsset("settings-sections.js");
	const schemaMap = registry.match(/private const SCHEMA_FILES = array\(([\s\S]*?)\n\t\);/);
	assert.ok(schemaMap, "The Home registry schema map must remain discoverable by the coverage contract.");
	const homeTypes = Array.from(schemaMap[1].matchAll(/^\s*'([a-z_]+)'\s*=>\s*'[a-z-]+',?$/gm), function (match) { return match[1]; });

	assert.equal(homeTypes.length, 17, "The Section Layout contract must cover all 17 registered Home element types.");
	assert.equal((homePage.match(/id="kidia-add-element"/g) || []).length, 1, "Add Element must render exactly once.");
	const addElementIndex = homePage.indexOf('id="kidia-add-element"');
	const renderedBlockIndex = homePage.indexOf("admin/templates/block-template.php");
	assert.ok(addElementIndex < renderedBlockIndex, "Add Element must remain in the original top toolbar.");
	assert.match(heroBlockSource, /kidia-repeatable-item-actions[\s\S]*kidia-remove-hero-block-item[\s\S]*kidia-add-hero-block-item/, "Each Slide header must place Remove beside Add Slide.");
	assert.match(bannerBlockSource, /kidia-repeatable-item-actions[\s\S]*kidia-remove-repeatable-item[\s\S]*kidia-add-repeatable-item/, "Each Banner header must place Remove beside Add Banner.");
	assert.doesNotMatch(heroBlockSource, /<p>\s*<button[\s\S]*kidia-add-hero-block-item/, "Hero Slider must not keep a separate General Settings add control.");
	assert.doesNotMatch(bannerBlockSource, /<p><button[\s\S]*kidia-add-repeatable-item/, "Banner Grid must not keep a separate General Settings add control.");
	assert.match(heroBlockSource, /kidia-remove-hero-block-item[\s\S]*kidia-add-hero-block-item[\s\S]*kidia-slider-item-toggle[\s\S]*kidia-toggle-state/, "Slide actions must render Remove, Add Slide and the shared On\/Off control together in that order.");
	assert.doesNotMatch(heroBlockSource, /kidia-repeatable-item-toggle[\s\S]*Show/, "Slide cards must not keep the old Show checkbox label.");
	assert.match(heroBlockSource, /kidia-repeatable-field--image-url[\s\S]*kidia-repeatable-field--media[\s\S]*kidia-repeatable-field--title[\s\S]*kidia-repeatable-field--subtitle[\s\S]*kidia-repeatable-field--button-label[\s\S]*kidia-repeatable-field--action-type[\s\S]*kidia-repeatable-field--action-value/, "Slide must expose every field used by the fixed three-column card layout.");
	assert.match(bannerBlockSource, /kidia-repeatable-field--image-url[\s\S]*kidia-repeatable-field--title[\s\S]*kidia-repeatable-field--media[\s\S]*kidia-repeatable-field--subtitle[\s\S]*kidia-repeatable-field--button-label[\s\S]*kidia-repeatable-field--action-value[\s\S]*kidia-repeatable-field--action-type/, "Banner must expose every field used by the same fixed three-column card layout.");
	assert.match(readAsset("home-builder.css"), /\.kidia-slider-editor-item,[\s\S]*\.kidia-banner-editor-item \.kidia-builder-grid\s*\{[\s\S]*grid-template-columns:\s*repeat\(3/, "Slide and Banner cards must share the same three-column editor grid.");
	assert.match(readAsset("home-builder.css"), /\.kidia-repeatable-field--image-url\s*\{\s*grid-column:\s*1;\s*grid-row:\s*1;\s*\}[\s\S]*\.kidia-repeatable-field--action-type\s*\{\s*grid-column:\s*2;\s*grid-row:\s*3;\s*\}/, "The two field columns must follow the approved row order.");
	assert.match(readAsset("home-builder.css"), /\.kidia-slider-editor-item\s*>\s*\.kidia-hero-block-item__header\s*\{[^}]*grid-row:\s*1;[^}]*order:\s*-10;/, "The Slide header must stay in the first row above all card fields.");
	assert.match(readAsset("home-builder.css"), /\.kidia-slider-editor-item\s*>\s*\.kidia-repeatable-field--action-value,[\s\S]*grid-row:\s*4;/, "Slider fields must shift below the protected header row.");
	assert.match(readAsset("home-builder.css"), /\.kidia-banner-editor-item \.kidia-repeatable-field--media\s*\{[\s\S]*grid-column:\s*3;[\s\S]*grid-row:\s*1 \/ 4/, "The image picker and preview must stay in the third column.");
	assert.match(readAsset("home-builder.css"), /\.kidia-repeatable-item-actions \.kidia-repeatable-add\s*\{[\s\S]*color:\s*#fff\s*!important/, "Add Banner and Add Slide labels must remain white.");
	assert.match(homePreview, /repeatableItem = action\.closest\("\.kidia-banner-editor-item"\)[\s\S]*repeatableItem\.querySelector\("\.kidia-media-url"\)/, "The Banner media picker must keep updating the URL after the image controls move to column three.");
	assert.match(heroBlockSource, /kidia-slider-image-setting--aspect-ratio[\s\S]*kidia-slider-image-setting--interval[\s\S]*kidia-slider-image-setting--image-fit[\s\S]*kidia-slider-image-setting--border-radius[\s\S]*kidia-slider-image-setting--horizontal-padding[\s\S]*kidia-slider-image-setting--text-color[\s\S]*kidia-slider-image-setting--text-position[\s\S]*kidia-slider-image-setting--overlay-strength[\s\S]*kidia-slider-image-setting--indicator-position[\s\S]*kidia-slider-image-setting--indicator-style[\s\S]*kidia-slider-image-setting--auto-play[\s\S]*kidia-slider-image-setting--show-indicators/, "Hero Slider Image Settings must follow the approved four-row order.");
	assert.match(settingsSections, /classList\.contains\("kidia-slider-image-setting"\)\)\s*\{\s*return "image";/, "All reordered Hero Slider controls must stay together inside Image Settings.");
	assert.match(categoryGridBlockSource, /kidia-category-grid-image-setting--title[\s\S]*kidia-category-grid-image-setting--subtitle[\s\S]*kidia-category-grid-image-setting--category-ids[\s\S]*kidia-category-grid-image-setting--layout[\s\S]*kidia-category-grid-image-setting--limit[\s\S]*kidia-category-grid-image-setting--columns[\s\S]*kidia-category-grid-image-setting--gap[\s\S]*kidia-category-grid-image-setting--image-size[\s\S]*kidia-category-grid-image-setting--image-shape[\s\S]*kidia-category-grid-image-setting--label-color[\s\S]*kidia-category-grid-image-setting--label-size[\s\S]*kidia-category-grid-image-setting--hide-empty[\s\S]*kidia-category-grid-image-setting--show-names/, "Category Grid Image Settings must follow the approved five-row order.");
	assert.doesNotMatch(categoryGridBlockSource, /Parent Category ID/, "Category Grid must not expose the removed Parent Category ID field.");
	assert.match(categoryGridBlockSource, /kidia-category-grid-image-setting--hide-empty[\s\S]*kidia-page-master-toggle[\s\S]*kidia-toggle-state[\s\S]*kidia-category-grid-image-setting--show-names[\s\S]*kidia-page-master-toggle[\s\S]*kidia-toggle-state/, "Category Grid visibility fields must use the shared On/Off switches in the final row.");
	assert.match(settingsSections, /classList\.contains\("kidia-category-grid-image-setting"\)\)\s*\{\s*return "image";/, "Every reordered Category Grid control must remain inside Image Settings.");
	assert.match(readAsset("home-builder.css"), /\.kidia-category-grid-image-setting--hide-empty\s*\{\s*grid-column-start:\s*1;\s*\}[\s\S]*\.kidia-category-grid-image-setting--show-names\s*\{\s*grid-column-start:\s*2;/, "The two Category Grid On/Off controls must start a dedicated final row.");
	assert.match(readAsset("home-builder.css"), /\.kidia-builder-field input\[type="text"\][\s\S]*width:\s*var\(--kidia-field-width\)/, "Slide and Banner compaction must preserve the standard field width.");
	assert.doesNotMatch(chromeTemplate, /kidia-footer-toggle-row/, "Footer toggles must use the original General Settings grid.");
  assert.match(template, /kidia-builder-settings-content[\s\S]*Merge up[\s\S]*\[settings\]\[margin_top\][\s\S]*Merge down[\s\S]*\[settings\]\[margin_bottom\]/, "Every Home element must expose Merge up/down inside its shared settings section.");
  assert.match(template, /Space up[\s\S]*\[settings\]\[space_up\][\s\S]*Space down[\s\S]*\[settings\]\[space_down\]/, "Every Home element must expose the two independent section spacing controls.");
  assert.doesNotMatch(registry, /self::field\(\s*'margin_(?:top|bottom)'/, "Individual Home element schemas must not duplicate the shared merge controls.");
	assert.match(registry, /'margin_top'\s*=>\s*0,[\s\S]*'margin_bottom'\s*=>\s*0,[\s\S]*'space_up'\s*=>\s*0,[\s\S]*'space_down'\s*=>\s*0/, "The central Home registry must preserve defaults for all four numeric Section Layout values.");
  assert.match(pageStore, /self::field\( 'margin_top', __\( 'Merge up'/, "Every page element must expose Merge up through shared presentation fields.");
  assert.match(pageStore, /self::field\( 'margin_bottom', __\( 'Merge down'/, "Every page element must expose Merge down through shared presentation fields.");
  assert.match(pageStore, /self::field\( 'space_up', __\( 'Space up'/, "Every page element must expose Space up through shared presentation fields.");
  assert.match(pageStore, /self::field\( 'space_down', __\( 'Space down'/, "Every page element must expose Space down through shared presentation fields.");
  assert.match(pageBuilder, /return 'Section Layout Settings'/, "Page elements must group the five shared controls in Section Layout Settings.");
  assert.match(categoryBuilder, /Merge up[\s\S]*Merge down[\s\S]*Space up[\s\S]*Space down[\s\S]*element_background_color/, "Category must expose the same five Section Layout values.");
  assert.match(homePreview, /marginBottom - marginTop/, "Home preview must pull elements together instead of adding positive margins.");
  assert.match(pagePreview, /mergeDown-mergeUp/, "Page preview must pull elements together instead of adding positive margins.");
  assert.match(categoryPreview, /margin_bottom[^\n]+margin_top/, "Category preview must pull elements together instead of adding positive margins.");
	assert.match(settingsSections, /section_layout:\s*"Section Layout Settings"/, "Every element must use the same final Section Layout Settings heading.");
	assert.match(settingsSections, /container\.appendChild\(finalHeading\)/, "Section Layout Settings must always be the final element settings section.");
	assert.match(readAsset("admin-theme.css"), /\.kidia-settings-section-title--section_layout\s*\{[\s\S]*min-height:\s*45px;[\s\S]*background:\s*#edf7f4\s*!important;[\s\S]*font-size:\s*14px\s*!important;/, "Every builder must use the canonical Section Layout heading size and Kidia appearance.");
	assert.match(readAsset("admin-theme.css"), /\.kidia-settings-section-title--section_layout\s*\{[\s\S]*direction:\s*rtl\s*!important;[\s\S]*text-align:\s*right\s*!important;/, "Every Section Layout heading must remain physically aligned to the right.");
	assert.match(readAsset("admin-theme.css"), /\.kidia-section-layout-grid\s*\{[\s\S]*grid-template-columns:\s*repeat\(3,\s*minmax\(150px,\s*1fr\)\);[\s\S]*padding:\s*14px 12px 16px;/, "Every builder must use the same three-column Section Layout dimensions.");
	assert.match(chromeTemplate, /kidia-settings-section-title kidia-settings-section-title--section_layout[\s\S]*kidia-section-layout-grid/, "Header and Footer must use the exact shared Section Layout heading and grid.");
	assert.match(chromeTemplate, /kidia-chrome-item-setting--header-cart/, "Only the Header Cart editor must receive the rebuilt Cart Settings layout.");
	assert.match(readAsset("chrome-layout.css"), /data-setting="cart_badge_background"\]\s*\{\s*grid-column:1;\s*grid-row:3;[\s\S]*data-setting="cart_badge_shape"\]\s*\{\s*grid-column:2;\s*grid-row:3;[\s\S]*data-setting="cart_style"\]\s*\{\s*grid-column:3;\s*grid-row:3;/, "Cart Settings must follow the approved three-column first details row.");
	assert.match(readAsset("chrome-layout.css"), /data-setting="cart_background"\]\s*\{\s*grid-column:1;\s*grid-row:5;[\s\S]*data-setting="cart_color"\]\s*\{\s*grid-column:2;\s*grid-row:5;[\s\S]*data-setting="cart_radius"\]\s*\{\s*grid-column:3;\s*grid-row:5;/, "Cart Settings must follow the approved final color and radius row.");
	assert.doesNotMatch(homePage, /kidia-mobile-preview__status/, "The Home preview must not render a fake operating-system status bar.");
	assert.doesNotMatch(pageBuilder, /kidia-page-phone__status/, "Page previews must not render a fake operating-system status bar.");
	assert.doesNotMatch(categoryBuilder, /kidia-category-phone__status/, "The Category preview must not render a fake operating-system status bar.");
	assert.match(readAsset("page-builder.css"), /\.kidia-page-phone\s*\{[^}]*width:283\.5px;[^}]*margin-inline-start:auto;/, "Every page phone must be five percent wider and closer to its settings.");
	assert.match(readAsset("category-builder.css"), /\.kidia-category-phone\s*\{[^}]*width:\s*275\.1px;[^}]*margin-inline-start:\s*auto;/, "The Category phone must be five percent wider and closer to its settings.");
	assert.match(readAsset("page-builder.css"), /\.kidia-page-preview\s*\{[^}]*transform:translateX\(clamp\(35px,calc\(11\.5cqw - 30px\),130px\)\)/, "Page phones must remain centered in the actual space beside their cards.");
	assert.match(readAsset("category-builder.css"), /\.kidia-category-mobile-preview\s*\{[^}]*transform:translateX\(clamp\(35px,calc\(11\.5cqw - 30px\),130px\)\)/, "The Category phone must remain centered in the actual space beside its cards.");
	assert.match(chromeTemplate, /class="kidia-fixed-chrome-identity"/, "Fixed Header and Footer must expose a stable identity group for physical ordering.");
	assert.match(readAsset("chrome-layout.css"), /\.kidia-fixed-chrome-card > \.kidia-page-card__header \.kidia-chrome-transfer-actions\s*\{\s*order:1;[^}]*direction:ltr;[^}]*\}[\s\S]*\.kidia-fixed-chrome-card > \.kidia-page-card__header \.kidia-fixed-chrome-expand\s*\{\s*order:2;\s*\}[\s\S]*\.kidia-fixed-chrome-card > \.kidia-page-card__header > \.kidia-page-master-toggle\s*\{\s*order:3;/, "Fixed Header and Footer controls must render Copy, Paste, expand, then On/Off from the left.");
	assert.match(readAsset("chrome-layout.css"), /\.kidia-fixed-chrome-card > \.kidia-page-card__header \.kidia-fixed-chrome-identity\s*\{\s*order:4;[^}]*margin-left:auto;/, "Fixed Header and Footer identity must stay on the right.");
	assert.match(readAsset("chrome-layout.css"), /\.kidia-chrome-transfer-actions \.button\s*\{[^}]*min-height:28px;[^}]*padding-inline:8px;[^}]*font-size:12px;/, "Fixed Header and Footer transfer buttons must match the standard element action-button dimensions.");
	assert.match(settingsSections, /keys:\s*\["margin_top",\s*"margin_bottom"\]/, "Merge up and Merge down must share the first vertical column.");
	assert.match(settingsSections, /keys:\s*\["space_up",\s*"space_down"\]/, "Space up and Space down must share the second vertical column.");
	assert.match(settingsSections, /keys:\s*\["block_background",\s*"background_color",\s*"element_background_color"\]/, "The background control must use the final column across all Builder types.");
	assert.match(settingsSections, /\(\(value - min\) \/ \(max - min\)\) \* 100/, "Range progress must derive from the real min, max and value instead of a fixed visual fill.");
	assert.match(settingsSections, /element\.dataset\.element === "filter_bar"/, "Filter and Sort Bar must have an explicit compact section layout.");
	assert.match(settingsSections, /filter_options:\s*"Available Filters"/, "Filter and Sort Bar must group its available filters together.");
	assert.match(settingsSections, /\^\(product_carousel\|product_grid\)\$[\s\S]*content_data[\s\S]*carousel_actions[\s\S]*card_layout[\s\S]*carousel_visibility[\s\S]*quick_add[\s\S]*carousel_wishlist/, "Product Carousel and Product Grid must share the explicit six-section settings map.");
	assert.match(settingsSections, /querySelectorAll\(":scope > \.kidia-builder-grid"\)[\s\S]*insertBefore\(field, grid\)[\s\S]*grid\.remove\(\)/, "Product settings must be flattened before sectioning so no field is hidden inside one generic bucket.");
	assert.match(readAsset("home-builder.css"), /\.kidia-hero-block-item__header\s*\{[\s\S]*direction:\s*rtl;[\s\S]*width:\s*100%;/, "Repeatable Slider and Banner headers must keep their title on the right.");
	assert.match(readAsset("home-builder.css"), /\.kidia-repeatable-item-actions\s*\{[\s\S]*justify-content:\s*flex-start;[\s\S]*direction:\s*ltr;[\s\S]*margin-inline-start:\s*auto;/, "Add, Remove, and On/Off controls must stay together on the left.");
	assert.doesNotMatch(readAsset("home-builder.css"), /\.kidia-banner-editor-item > \.kidia-hero-block-item__header/, "Banner header alignment must remain unchanged.");
	assert.match(readAsset("home-builder.css"), /\.kidia-slider-editor-item\.kidia-hero-block-item \.kidia-repeatable-field--media\s*\{[\s\S]*grid-row:\s*2 \/ 5;/, "Select Image and its preview must start below the Slider item header.");
	assert.match(readAsset("home-builder.css"), /:is\(\[data-type="product_carousel"\], \[data-type="product_grid"\]\) \.kidia-builder-settings-content\s*\{[\s\S]*grid-template-columns:\s*repeat\(3,[\s\S]*direction:\s*rtl;/, "Product Carousel and Product Grid sections must use the same three-field RTL layout.");
	assert.doesNotMatch(readAsset("admin-theme.css"), /data-element="filter_sort"/, "The obsolete Filter and Sort selector must not return.");
	assert.match(pageStore, /'block_height'[^\n]+56/, "Filter and Sort Bar must use the compact 56px default height.");
	assert.match(pagePreview, /checked\(card, "show_result_count", false\)/, "Filter result count must default to hidden in both Flutter and the live preview.");
	assert.match(pagePreview, /filter_icon_offset_y", -2/, "Filter icon vertical position must reach the live preview.");
  assert.match(pageStore, /quick_add_icon_size[^\n]+array\(\), 10, 36/, "Quick Add icons must support compact sizes down to 10px.");
  assert.match(pageStore, /quick_add_background_size[^\n]+array\(\), 20, 64/, "Quick Add backgrounds must support compact sizes down to 20px.");
  assert.match(pageStore, /product_wishlist_icon_size[^\n]+array\(\), 10, 36/, "Wishlist icons must support compact sizes down to 10px.");
  assert.match(pageStore, /product_wishlist_background_size[^\n]+array\(\), 20, 64/, "Wishlist backgrounds must support compact sizes down to 20px.");

	function layoutField(name, label, extraClass = "") {
		return `<div class="kidia-page-field ${extraClass}"><label>${label}</label><input name="layout[elements][0][settings][${name}]" value="0"></div>`;
	}
	const quickKeys = ["quick_add_enabled", "quick_add_icon_style", "quick_add_icon_variant", "quick_add_radius", "quick_add_icon_size", "quick_add_background_size", "quick_add_background_color", "quick_add_icon_color", "quick_add_show_background"];
	const quickMarkup = quickKeys.map(function (key) { return layoutField(key, key); }).join("") + layoutField("quick_add_position", "Quick add position");
	const sharedMarkup = layoutField("margin_top", "Merge up", "kidia-section-layout-field") + layoutField("margin_bottom", "Merge down", "kidia-section-layout-field") + layoutField("space_up", "Space up", "kidia-section-layout-field") + layoutField("space_down", "Space down", "kidia-section-layout-field") + layoutField("background_color", "Background", "kidia-section-layout-field");
	const categoryShared = ["margin_top", "margin_bottom", "space_up", "space_down", "element_background_color"].map(function (key) { return `<label>${key}<input name="category_general[${key}]" value="0"></label>`; }).join("");
	const nestedTitlePair = `<div class="kidia-repeatable-item"><div class="kidia-builder-field"><input name="blocks[0][settings][items][0][title]"></div><div class="kidia-builder-field"><input name="blocks[0][settings][items][0][subtitle]"></div></div>`;
	const carouselKeys = ["title", "subtitle", "source", "limit", "category_id", "product_ids", "show_view_all", "view_all_label", "action_type", "action_value", "card_style", "item_width", "image_ratio", "card_radius", "show_name", "show_price", "show_regular_price", "show_badge", "show_rating", "quick_add_enabled", "quick_add_icon_size", "show_wishlist", "product_wishlist_icon_size"];
	const productGridKeys = carouselKeys.filter(function (key) { return key !== "item_width"; }).concat("columns");
	const carouselMarkup = `<div class="kidia-builder-grid">${carouselKeys.map(function (key) { return `<div class="kidia-builder-field"><label>${key}</label><input name="blocks[0][settings][${key}]" value="0"></div>`; }).join("")}</div>` + sharedMarkup.replaceAll("layout[elements][0]", "blocks[0]");
	const productGridMarkup = `<div class="kidia-builder-grid">${productGridKeys.map(function (key) { return `<div class="kidia-builder-field"><label>${key}</label><input name="blocks[1][settings][${key}]" value="0"></div>`; }).join("")}</div>` + sharedMarkup.replaceAll("layout[elements][0]", "blocks[1]");
	const sectionDom = new JSDOM(`<!doctype html><html><body><div class="kidia-page-builder"><section data-element="product_grid"><div id="product-fields" class="kidia-page-fields">${quickMarkup}${sharedMarkup}</div></section></div><div class="kidia-builder-wrap"><section data-type="product_carousel"><div id="carousel-fields" class="kidia-builder-settings-content">${carouselMarkup}</div></section><section data-type="product_grid"><div id="home-grid-fields" class="kidia-builder-settings-content">${productGridMarkup}</div></section><div class="kidia-builder-settings-content">${nestedTitlePair}</div></div><div class="kidia-category-builder"><div id="category-fields" class="kidia-category-general-fields">${categoryShared}</div></div></body></html>`, { runScripts: "outside-only" });
	sectionDom.window.eval(settingsSections);
	sectionDom.window.document.dispatchEvent(new sectionDom.window.Event("DOMContentLoaded"));
	function sectionFieldCount(container) {
		const heading = container.querySelector(":scope > .kidia-settings-section-title--section_layout");
		assert.ok(heading, "Every tested element must render Section Layout Settings.");
		const grid = heading.nextElementSibling;
		assert.ok(grid && grid.classList.contains("kidia-section-layout-grid"), "Every Section Layout heading must be followed by the shared three-column grid.");
		return grid.querySelectorAll(":scope > .kidia-section-layout-column > .kidia-page-field, :scope > .kidia-section-layout-column > .kidia-builder-field, :scope > .kidia-section-layout-column > label").length;
	}
	assert.equal(sectionFieldCount(sectionDom.window.document.getElementById("product-fields")), 5, "Product Grid must render exactly five fields in Section Layout Settings.");
	assert.equal(sectionDom.window.document.querySelectorAll("#product-fields > .kidia-settings-section-title--general").length, 1, "Product Grid must render one General Settings section.");
	assert.equal(sectionFieldCount(sectionDom.window.document.getElementById("category-fields")), 5, "Category must render exactly five fields in Section Layout Settings.");
	assert.deepEqual(Array.from(sectionDom.window.document.querySelectorAll("#carousel-fields .kidia-settings-section-title"), function (heading) { return heading.childNodes[0].textContent; }), ["Content & Data", "Actions & Navigation", "Card Layout", "Visibility & Display", "Quick Add", "Wishlist", "Section Layout Settings"], "Product Carousel must render the rebuilt sections in the approved order.");
	assert.equal(sectionFieldCount(sectionDom.window.document.getElementById("carousel-fields")), 5, "Product Carousel must preserve all five shared Section Layout controls after regrouping.");
	assert.deepEqual(Array.from(sectionDom.window.document.querySelectorAll("#home-grid-fields .kidia-settings-section-title"), function (heading) { return heading.childNodes[0].textContent; }), ["Content & Data", "Actions & Navigation", "Card Layout", "Visibility & Display", "Quick Add", "Wishlist", "Section Layout Settings"], "Product Grid must render the same rebuilt sections in the approved order.");
	assert.equal(sectionFieldCount(sectionDom.window.document.getElementById("home-grid-fields")), 5, "Product Grid must preserve all five shared Section Layout controls after regrouping.");
	assert.equal(sectionDom.window.document.querySelectorAll("#carousel-fields > .kidia-builder-grid, #home-grid-fields > .kidia-builder-grid").length, 0, "Product fields must not remain trapped in their original unsectioned grid.");
	assert.equal(sectionDom.window.document.querySelectorAll("#carousel-fields input[name]").length, carouselKeys.length + 5, "Product Carousel must preserve every setting exactly once.");
	assert.equal(sectionDom.window.document.querySelectorAll("#home-grid-fields input[name]").length, productGridKeys.length + 5, "Product Grid must preserve every setting exactly once.");
	assert.equal(sectionDom.window.document.querySelectorAll("#carousel-fields > .kidia-product-icon-panel").length, 2, "Product Carousel must render Quick Add and Wishlist as complete panels.");
	assert.equal(sectionDom.window.document.querySelectorAll("#home-grid-fields > .kidia-product-icon-panel").length, 2, "Product Grid must render Quick Add and Wishlist as complete panels.");
	assert.equal(sectionDom.window.document.querySelectorAll("#carousel-fields .kidia-product-icon-panel > .kidia-settings-section-title .kidia-product-icon-field").length, 2, "Each Product Carousel icon panel must keep its enable switch in the section header.");
	assert.equal(sectionDom.window.document.querySelectorAll("#home-grid-fields .kidia-product-icon-panel > .kidia-settings-section-title .kidia-product-icon-field").length, 2, "Each Product Grid icon panel must keep its enable switch in the section header.");
	assert.deepEqual(Array.from(sectionDom.window.document.querySelectorAll("#product-fields > .kidia-section-layout-grid > .kidia-section-layout-column"), function (column) { return Array.from(column.querySelectorAll("input[name]"), function (input) { return input.name.match(/\[([^\]]+)\]$/)[1]; }); }), [["margin_top", "margin_bottom"], ["space_up", "space_down"], ["background_color"]], "Page elements must render Merge, Space, and Background in the requested columns.");
	assert.deepEqual(Array.from(sectionDom.window.document.querySelectorAll("#category-fields > .kidia-section-layout-grid > .kidia-section-layout-column"), function (column) { return Array.from(column.querySelectorAll("input[name]"), function (input) { return input.name.match(/\[([^\]]+)\]$/)[1]; }); }), [["margin_top", "margin_bottom"], ["space_up", "space_down"], ["element_background_color"]], "Category must use the same requested column order.");
	assert.equal(sectionDom.window.document.querySelectorAll(".kidia-quick-add-row").length, 0, "Quick Add must use the original settings grid without injected rows.");
	assert.equal(sectionDom.window.document.querySelectorAll(".kidia-title-subtitle-row").length, 0, "Title and Subtitle fields must use the original settings grid.");

	const promoBlock = fs.readFileSync(path.join(pluginRoot, "includes", "blocks", "class-kidia-mobile-promo-strip-block.php"), "utf8");
	const homeBuilderCss = readAsset("home-builder.css");
	const homeScript = readAsset("home-builder.js");
	const pageScript = readAsset("page-builder.js");
	const liveEndpoint = fs.readFileSync(path.join(pluginRoot, "api", "class-home-layout-endpoint.php"), "utf8");
	const adminSource = fs.readFileSync(path.join(pluginRoot, "admin", "class-kidia-mobile-cms-admin.php"), "utf8");
	assert.match(settingsSections, /classList\.contains\("kidia-promo-action-setting"\)\)\s*\{\s*return "actions";/, "All Promo Strip controls must stay together under Actions & Navigation.");
	assert.match(promoBlock, /kidia-promo-action-setting--text[\s\S]*kidia-promo-action-setting--background[\s\S]*kidia-promo-action-setting--text-color[\s\S]*kidia-promo-action-setting--action-type[\s\S]*kidia-promo-action-setting--action-value/, "Promo Strip must expose the complete approved Actions & Navigation field set.");
	assert.match(homeBuilderCss, /kidia-promo-action-setting--background\s*\{\s*grid-column:\s*1;[\s\S]*kidia-promo-action-setting--text-color\s*\{\s*grid-column:\s*2;[\s\S]*kidia-promo-action-setting--text\s*\{\s*grid-column:\s*3;[\s\S]*kidia-promo-action-setting--action-type\s*\{\s*grid-column:\s*1;[\s\S]*kidia-promo-action-setting--action-value\s*\{\s*grid-column:\s*2;/, "Actions & Navigation must follow the approved two-row map with Action Type on the right.");
	assert.match(homeBuilderCss, /--kidia-picker-accent:\s*#2f806e;[\s\S]*\.kidia-element-group__identity \.dashicons\s*\{\s*color:\s*var\(--kidia-picker-accent\);[\s\S]*\.kidia-element-card:hover,[\s\S]*border-color:\s*var\(--kidia-picker-accent\);/, "Add Element icons, focus, and selection states must use Kidia green.");
	assert.doesNotMatch(homeBuilderCss.slice(homeBuilderCss.indexOf(".kidia-element-picker,"), homeBuilderCss.indexOf(".kidia-create-element-modal__body")), /#2271b1|#f0f6fc|rgba\(34,\s*113,\s*177/, "The Add Element modal must not retain WordPress blue styling.");
	assert.match(homeScript, /settings\.image_size[\s\S]*settings\.item_size/, "Category Grid and Quick Links image sizes must update the live preview.");
	assert.match(homeScript, /product_wishlist_icon_variant[\s\S]*product_wishlist_icon_size[\s\S]*product_wishlist_background_size[\s\S]*product_wishlist_position[\s\S]*product_wishlist_show_background[\s\S]*product_wishlist_background_color[\s\S]*product_wishlist_radius[\s\S]*product_wishlist_icon_color/, "Every product Wishlist appearance control must update the Home preview.");
	assert.match(homeScript, /quick_add_icon_style/, "Quick Add icon style must update the Home preview.");
	assert.match(homeScript, /Date\.parse\(settings\.ends_at[\s\S]*settings\.expired_text[\s\S]*countdownDays[\s\S]*countdownSeconds/, "Countdown must use its real end date and expired label in the preview.");
	assert.match(homeScript, /settings\.video_url[\s\S]*settings\.auto_play[\s\S]*settings\.muted[\s\S]*settings\.loop[\s\S]*playsinline/, "Video URL and every playback switch must update the preview video.");
	assert.match(homeScript, /settings\.auto_play[\s\S]*Date\.now\(\) \/ numberInRange\(settings\.interval_ms/, "Hero Slider autoplay and interval must control its selected preview slide.");
	["shadow", "icon_size", "icon_background", "icon_radius", "search_icon_color", "account_style", "account_label", "account_icon_size"].forEach(function (key) {
		assert.ok(homeScript.slice(homeScript.indexOf("function renderAppHeader"), homeScript.indexOf("function renderBlock")).includes("settings." + key), "App Header " + key + " must update the Home preview.");
	});
	assert.match(liveEndpoint, /home-layout\/preview[\s\S]*preview_home_layout[\s\S]*Kidia_Mobile_Block_Registry::normalize[\s\S]*Kidia_Mobile_Block_Registry::build_api_block/, "Unsaved Home settings must use the same normalized API builder as Flutter.");
	assert.match(adminSource, /livePreviewEndpoint[\s\S]*restNonce/, "The Home Builder must receive its protected live runtime endpoint.");
	assert.match(homeScript, /livePreviewEndpoint[\s\S]*X-WP-Nonce[\s\S]*JSON\.stringify\(\{ blocks: serializeBlocks\(\) \}\)/, "Source and ID changes must refresh real preview data without saving.");
	assert.match(pageScript, /products_per_page[\s\S]*filter_price[\s\S]*filter_sale[\s\S]*filter_brand[\s\S]*show_thumbnails[\s\S]*guest_title[\s\S]*show_addresses[\s\S]*show_profile/, "All previously disconnected page fields must update their live previews.");
}

function categoryGeneralSettings() {
	  const field = (name, value, type = "text") => `<input type="${type}" name="category_general[${name}]" value="${value}">`;
	  return `<section class="kidia-category-general">
	    <select name="category_general[category_layout]"><option value="default" selected>Default Layout</option><option value="visual_grid">Two-column Cards</option><option value="circular_grid">Circular Grid</option><option value="compact_grid">Compact Grid</option><option value="sidebar">Sidebar</option></select>
	    <select name="category_general[grid_columns]"><option value="2" selected>2</option><option value="3">3</option><option value="4">4</option></select>
	    ${field("card_radius", 17, "range")}${field("card_gap", 10, "range")}${field("card_width_percent", 100, "range")}${field("card_height", 0, "range")}${field("margin_top", 0, "range")}${field("margin_bottom", 0, "range")}${field("show_arrow", 1, "checkbox")}
	    ${field("page_background_color", "#F7F8FA", "color")}${field("element_background_color", "#FFFFFF", "color")}${field("card_background_color", "#FFFFFF", "color")}
	    ${field("card_shadow_color", "#000000", "color")}${field("card_shadow_strength", 10, "range")}${field("card_shadow_blur", 12, "range")}${field("card_shadow_offset_y", 4, "number")}
	    <select name="category_general[card_style]"><option value="outlined" selected>Outlined</option><option value="elevated">Elevated</option></select>
	    ${field("image_size", 68, "range")}${field("image_radius", 18, "range")}${field("image_scale", 100, "range")}
	    ${field("border_width", 0, "number")}${field("border_color", "#DDE5E2", "color")}${field("background_color", "#FFFFFF", "color")}
	    ${field("image_text_gap", 10, "range")}${field("font_size", 16, "range")}${field("font_color", "#1F2933", "color")}${field("line_height", 125, "range")}
	    <select name="category_general[image_shape]"><option value="rounded" selected>Rounded</option><option value="circle">Circle</option></select>
	    <select name="category_general[image_fit]"><option value="contain" selected>Contain</option></select>
	    <select name="category_general[image_effect]"><option value="none" selected>None</option></select>
	    <select name="category_general[image_position]"><option value="center" selected>Center</option></select>
	    <select name="category_general[font_weight]"><option value="800" selected>800</option></select>
	    <select name="category_general[text_align]"><option value="start" selected>Start</option></select>
	    <select name="category_general[text_max_lines]"><option value="2" selected>2</option></select>
	  </section>`;
}

function categoryRow(id, name, hasChildren = false) {
  const child = hasChildren ? `<div class="kidia-category-children" hidden><ul class="kidia-category-list">${categoryRow(id + 10, `${name} Child`)}</ul></div>` : "";
	  return `<li class="kidia-category-row" data-term-id="${id}" data-default-name="${name}" data-default-image="https://example.com/default-${id}.jpg">
	    <div class="kidia-category-card">
	      <span class="kidia-category-handle"></span>
	      ${hasChildren ? '<button type="button" class="kidia-category-expand" aria-expanded="false">Expand</button>' : ""}
	      <div class="kidia-category-image"><img src="https://example.com/category-${id}.jpg" alt=""></div>
	      <div class="kidia-category-name"><input class="kidia-category-name-input" name="categories[${id}][name]" value="${name}"></div>
	      <input class="kidia-category-order" name="categories[${id}][order]" value="0">
	      <input class="kidia-category-image-id" name="categories[${id}][image_id]" value="0">
	      <div class="kidia-category-image-actions"><button type="button" class="kidia-category-image-button" aria-pressed="false">Choose image</button><button type="button" class="kidia-category-image-clear is-active" aria-pressed="true">Clear</button></div>
	      <label class="kidia-category-visibility kidia-page-master-toggle"><input type="hidden" name="categories[${id}][hidden]" value="1"><input type="checkbox" name="categories[${id}][hidden]" value="0" checked><span class="kidia-toggle-state"></span></label>
	    </div>${child}
	  </li>`;
}

function runCategoryBuilderTest() {
  const markup = `<!doctype html><html><body><div class="kidia-category-builder">
	    <div class="kidia-category-phone__screen"><div id="kidia-category-live-preview"></div></div>
	    <div class="kidia-category-editor"><form><section class="kidia-category-element"><input class="kidia-category-element-enabled" type="checkbox" checked>${categoryGeneralSettings()}<div class="kidia-category-items"><ul class="kidia-category-list">${categoryRow(1, "Clothes", true)}${categoryRow(2, "Toys")}</ul></div></section></form></div>
  </div></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
  const { window } = dom;
  const $ = createJQuery(window);
  window.$ = window.jQuery = $;
  $.fn.sortable = function (options) {
    return this.each(function () { this.kidiaSortableOptions = options; });
  };

  let mediaSelect;
  window.wp = {
    media() {
      return {
        on(event, callback) { if (event === "select") mediaSelect = callback; },
        open() { mediaSelect(); },
        state() {
          return { get() { return { first() { return { toJSON() { return { id: 99, url: "https://example.com/custom.jpg", sizes: { thumbnail: { url: "https://example.com/custom-thumb.jpg" } } }; } }; } }; } };
        },
      };
    },
  };

  window.eval(readAsset("category-builder.js"));
  assert.equal(window.kidiaCategoryBuilderBooted, true, "Category Builder must boot.");
  assert.equal(window.document.querySelectorAll(".kidia-category-visibility.kidia-page-master-toggle").length, 3, "Every category and subcategory must use the shared On/Off toggle.");
  assert.equal(window.document.querySelectorAll(".kidia-category-visibility .kidia-toggle-state").length, 3, "Every visibility toggle must expose the shared On/Off state label.");
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-branch").length, 2, "Root categories must render as app-style rows.");
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 0, "Subcategories start collapsed.");
  assert.equal(window.document.querySelectorAll(".kidia-category-image-actions button:not([hidden])").length, 6, "Both image-source buttons must remain visible for every category and subcategory.");

	const layout = window.document.querySelector('[name="category_general[category_layout]"]');
	["visual_grid", "circular_grid", "compact_grid", "sidebar", "default"].forEach((value) => {
		layout.value = value;
		layout.dispatchEvent(new window.Event("change", { bubbles: true }));
		assert.ok(window.document.querySelector(`.kidia-category-preview-content.is-layout-${value}`), `${value} must change the live category preview.`);
		assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 0, `${value} must initially show root categories only.`);
		click(window, window.document.querySelector(value === "sidebar" ? ".kidia-category-preview-sidebar-root" : ".kidia-category-preview-expand"));
		assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 1, `${value} must replace roots with only the selected subcategories.`);
		click(window, window.document.querySelector(".kidia-category-preview-back"));
	});
	assert.equal(window.document.querySelectorAll('[name="category_general[category_layout]"] option').length, 5, "Category must expose Default plus four alternative layouts.");

	const elementBackground = window.document.querySelector('[name="category_general[element_background_color]"]');
	elementBackground.value = "#fff4e8";
	elementBackground.dispatchEvent(new window.Event("input", { bubbles: true }));
	assert.equal(window.document.querySelector(".kidia-category-preview-content").style.backgroundColor, "rgb(255, 244, 232)", "Category element background must update the live preview independently.");
	const pageBackground = window.document.querySelector('[name="category_general[page_background_color]"]');
	pageBackground.value = "#eef1f4";
	pageBackground.dispatchEvent(new window.Event("input", { bubbles: true }));
	assert.equal(window.document.getElementById("kidia-category-live-preview").style.backgroundColor, "rgb(238, 241, 244)", "Category page background must remain separate from the element background.");
	const cardWidth = window.document.querySelector('[name="category_general[card_width_percent]"]');
	cardWidth.value = "76";
	cardWidth.dispatchEvent(new window.Event("input", { bubbles: true }));
	assert.equal(window.document.querySelector(".kidia-category-preview-branch").style.width, "76%", "Card width must update the live preview.");
	const cardHeight = window.document.querySelector('[name="category_general[card_height]"]');
	cardHeight.value = "96";
	cardHeight.dispatchEvent(new window.Event("input", { bubbles: true }));
	assert.equal(window.document.querySelector(".kidia-category-preview-root").style.height, "96px", "Card height must update the live preview.");
	const marginTop = window.document.querySelector('[name="category_general[margin_top]"]');
	marginTop.value = "18";
	marginTop.dispatchEvent(new window.Event("input", { bubbles: true }));
	assert.equal(window.document.querySelector(".kidia-category-preview-content").style.transform, "translateY(-18px)", "Merge up must pull Category content toward the section above.");

  click(window, window.document.querySelector(".kidia-category-expand"));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 0, "Editor expansion must not mix subcategories into the mobile root list.");

	  const size = window.document.querySelector('[name="category_general[image_size]"]');
  size.value = "96";
  size.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.equal(window.document.querySelector(".kidia-category-preview-root .kidia-category-preview-image").style.width, "78px", "Preview must clamp category art to the app row width.");
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 0, "The mobile root list must remain root-only when live settings rerender the preview.");

  click(window, window.document.querySelector(".kidia-category-preview-expand"));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 1, "Selecting a root category must replace roots with its subcategories.");
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-branch").length, 0, "Root categories must be hidden while subcategories are displayed.");
  click(window, window.document.querySelector(".kidia-category-preview-back"));
  assert.ok(window.document.querySelector(".kidia-category-preview-branch"), "Back must restore the root category list.");
  click(window, window.document.querySelector(".kidia-category-preview-expand"));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 1, "Preview selection must reopen the matching category detail.");
  click(window, window.document.querySelector(".kidia-category-preview-back"));

	  const appName = window.document.querySelector('[name="categories[1][name]"]');
	  appName.value = "Kids Clothes";
	  appName.dispatchEvent(new window.Event("input", { bubbles: true }));
	  assert.match(window.document.querySelector(".kidia-category-preview-name").textContent, /Kids Clothes/, "App-only names must update the preview instantly.");

  click(window, window.document.querySelector(".kidia-category-image-button"));
  assert.match(window.document.querySelector(".kidia-category-image img").src, /custom-thumb\.jpg$/, "Choosing media must update the editor image.");
  assert.match(window.document.querySelector(".kidia-category-preview-image img").src, /custom-thumb\.jpg$/, "Choosing media must update the phone preview.");
  assert.equal(window.document.querySelector(".kidia-category-image-button").getAttribute("aria-pressed"), "true", "The custom image source button must show its active state.");
  click(window, window.document.querySelector(".kidia-category-image-clear"));
  assert.match(window.document.querySelector(".kidia-category-image img").src, /default-1\.jpg$/, "Clear must restore the WooCommerce image.");
  assert.equal(window.document.querySelector(".kidia-category-image-clear").getAttribute("aria-pressed"), "true", "The WooCommerce image source button must show its active state.");

  const shown = window.document.querySelector('[name="categories[2][hidden]"][type="checkbox"]');
  shown.checked = false;
  shown.dispatchEvent(new window.Event("change", { bubbles: true }));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-branch").length, 1, "Turning Show off must remove the branch from preview.");

	  const rootList = window.document.querySelector(".kidia-category-items > .kidia-category-list");
  const rows = rootList.children;
  rootList.insertBefore(rows[1], rows[0]);
  rootList.kidiaSortableOptions.update.call(rootList);
  assert.equal(rootList.firstElementChild.querySelector(".kidia-category-order").value, "0", "Sorting must recalculate sibling order.");
  assert.equal(rootList.lastElementChild.querySelector(".kidia-category-order").value, "1", "Sorting must keep the next sibling order.");

	  console.log("Category Builder: one element, general settings, app overrides and sorting passed.");
}

function runPageBuilderTest() {
  const storeSource = fs.readFileSync(path.join(pluginRoot, "includes", "class-kidia-mobile-page-layout-store.php"), "utf8");
  assert.match(storeSource, /self::field\( 'background_color', __\( 'Background color'.*'color', '#FFFFFF' \)/, "Every page element must receive one real background color picker.");
  assert.doesNotMatch(storeSource, /Element background \(blank = transparent\)/, "The obsolete duplicate text background field must be removed.");
  assert.match(storeSource, /'no_shadow' => __\( 'No shadow'/, "Card style settings must include an explicit no-shadow option.");
  assert.match(storeSource, /\$quick_add_keys = array\([^\n]*'quick_add_background_size'[^\n]*'product_wishlist_background_size'[^\n]*\)/, "Every product grid must expose complete Quick Add and Wishlist appearance settings.");
  assert.match(storeSource, /\$wishlist_grid_keys = array_merge\( \$quick_add_keys/, "Wishlist must reuse the complete Quick Add settings.");
  assert.doesNotMatch(storeSource, /self::element\( 'account_menu'[\s\S]{0,500}Menu style/, "Account menu must not expose an unimplemented layout control.");
  const wishlistSource = fs.readFileSync(path.join(pluginRoot, "..", "lib", "features", "wishlist", "presentation", "wishlist_screen.dart"), "utf8");
  assert.match(wishlistSource, /settings\s*\.number\('columns', 2\)/, "Wishlist columns must be consumed by the mobile grid.");
  assert.match(wishlistSource, /settings\.string\('title', copy\.emptyTitle\)/, "Wishlist empty-state copy must be consumed by the mobile app.");
  assert.match(wishlistSource, /settings\.boolean\('quick_add_enabled', true\)/, "Wishlist must consume its own Quick Add setting.");
  assert.match(wishlistSource, /quick_add_icon_variant/, "Wishlist must consume Quick Add appearance settings.");
  const catalogCardSource = fs.readFileSync(path.join(pluginRoot, "..", "lib", "features", "catalog", "presentation", "widgets", "catalog_product_card.dart"), "utf8");
  assert.match(catalogCardSource, /settings\?\.boolean\('quick_add_enabled', true\)/, "Catalog Product Grid must consume its own Quick Add setting.");
  assert.match(catalogCardSource, /quick_add_background_color/, "Catalog Product Grid must consume Quick Add appearance settings.");
  assert.match(catalogCardSource, /quick_add_background_size/, "Catalog Product Grid must consume the independent Quick Add background size.");
  assert.match(catalogCardSource, /product_wishlist_background_size/, "Catalog Product Grid must consume the product wishlist appearance settings.");
  assert.match(catalogCardSource, /quick_add_position/, "Catalog Product Grid must apply the saved Quick Add corner.");
  assert.match(catalogCardSource, /product_wishlist_position/, "Catalog Product Grid must apply the saved wishlist corner.");
  const homeBlockSource = fs.readFileSync(path.join(pluginRoot, "..", "lib", "features", "home", "presentation", "widgets", "home_block_widgets.dart"), "utf8");
  assert.match(homeBlockSource, /quickAddProductId: quickAddEnabled \? product\.id : null/, "Home product elements must consume their own Quick Add setting.");
	const pageTemplateSource = fs.readFileSync(path.join(pluginRoot, "admin", "pages", "page-builder.php"), "utf8");
	assert.match(pageTemplateSource, /kidia-product-position/, "Product icon positions must use the visual product-card selector.");
	const settingsSectionsSource = fs.readFileSync(path.join(pluginRoot, "admin", "assets", "settings-sections.js"), "utf8");
	assert.match(settingsSectionsSource, /enhanceProductPositions/, "Home product elements must receive the same visual position selector.");
	const layoutProviderSource = fs.readFileSync(path.join(pluginRoot, "..", "lib", "features", "page_builder", "presentation", "providers", "cms_page_layout_providers.dart"), "utf8");
	assert.match(layoutProviderSource, /Duration\(seconds: 5\)/, "Visible pages must refresh CMS settings promptly without restarting the app.");
	assert.match(pageTemplateSource, /Colors & appearance/, "Page element backgrounds must be grouped in Colors & Appearance.");
	const homeTemplateSource = fs.readFileSync(path.join(pluginRoot, "admin", "templates", "block-template.php"), "utf8");
	assert.equal((homeTemplateSource.match(/\[settings\]\[block_background\]/g) || []).length, 1, "Every Home element must render exactly one shared background control.");
	assert.match(homeTemplateSource, /kidia-builder-settings-content[\s\S]*\[settings\]\[block_background\]/, "The Home element background must live with the sectioned element settings.");
	const registrySource = fs.readFileSync(path.join(pluginRoot, "includes", "class-kidia-mobile-block-registry.php"), "utf8");
	assert.doesNotMatch(registrySource, /'key'\s*=>\s*'block_background'/, "Schema blocks must not duplicate the shared Home element background control.");
	const categoryTemplateSource = fs.readFileSync(path.join(pluginRoot, "admin", "pages", "category-builder.php"), "utf8");
	assert.match(categoryTemplateSource, /Colors & Appearance[\s\S]*Background color[\s\S]*category_general\[element_background_color\]/, "Category element background must use the same label and Colors & Appearance section.");
  assert.doesNotMatch(pageTemplateSource, /Product General Settings/, "Quick add must not live in a separate global section.");
  assert.doesNotMatch(pageTemplateSource, /product_quick_add_enabled/, "The obsolete global quick-add control must be removed.");
  assert.match(storeSource, /\$catalog_grid_keys = array_merge\( \$quick_add_keys/, "Catalog Product Grid must own its quick-add settings.");
  assert.match(storeSource, /\$wishlist_grid_keys = array_merge\( \$quick_add_keys/, "Wishlist Products must own its quick-add settings.");
  const markup = `<!doctype html><html><body>
    <div class="kidia-page-builder" data-page="catalog">
      <div id="kidia-page-live-preview"></div>
      <form><div class="kidia-page-builder-blank"></div><section class="kidia-page-card kidia-page-card--locked" data-element="header">
        <div class="kidia-page-card__header"><button type="button" class="kidia-page-expand">Open</button></div>
        <div class="kidia-page-card__body" hidden><input name="layout[header][height]" value="64"></div>
        <input type="checkbox" name="layout[header][enabled]" checked>
      </section>
      <div id="kidia-page-elements">
        <section class="kidia-page-card" data-element="filter_bar"><input name="layout[elements][0][id]" value="filter_bar"><input type="checkbox" name="layout[elements][0][enabled]" checked><span class="kidia-page-drag"></span></section>
        <section class="kidia-page-card" data-element="product_grid"><input name="layout[elements][1][id]" value="product_grid"><input type="checkbox" name="layout[elements][1][enabled]" checked><input name="layout[elements][1][settings][columns]" value="3"><span class="kidia-page-drag"></span></section>
      </div>
      <section class="kidia-page-card kidia-page-card--locked" data-element="footer"><input type="checkbox" name="layout[footer][enabled]" checked><input name="layout[footer][height]" value="72"></section>
      </form>
    </div></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
  const { window } = dom;
  const $ = createJQuery(window);
  window.$ = window.jQuery = $;
  $.fn.sortable = function (options) { return this.each(function () { this.kidiaSortableOptions = options; }); };
  window.eval(readAsset("page-builder.js"));
  assert.ok(window.document.querySelector(".kidia-page-preview-header"), "The fixed page header must render in preview.");
  assert.ok(window.document.querySelector(".kidia-page-preview-footer"), "The fixed page footer must render in preview.");
  assert.equal(window.document.querySelectorAll(".kidia-page-preview-element").length, 2, "Page-specific elements must render in preview.");
  assert.ok(window.document.querySelectorAll(".kidia-page-preview-product").length >= 3, "Product grids must render realistic product cards instead of empty squares.");
  const list = window.document.getElementById("kidia-page-elements");
  list.insertBefore(list.lastElementChild, list.firstElementChild);
  list.kidiaSortableOptions.update();
  assert.equal(list.firstElementChild.querySelector('input[name$="[id]"]').name, "layout[elements][0][id]", "Reordering must keep submitted indexes valid.");
  assert.equal(window.document.querySelectorAll(".kidia-page-card--locked .kidia-page-drag").length, 0, "Fixed header/footer cards must never expose drag handles.");
  const focusedNumber = window.document.querySelector('[name$="[settings][columns]"]');
  focusedNumber.focus();
  assert.equal(window.document.activeElement, focusedNumber, "The numeric field must accept focus.");
  window.document.querySelector(".kidia-page-builder-blank").dispatchEvent(new window.Event("pointerdown", { bubbles: true }));
  assert.notEqual(window.document.activeElement, focusedNumber, "Clicking empty builder space must release the field so keyboard arrows can scroll.");
  console.log("Page Builders: fixed chrome, page elements, preview and sorting passed.");
}

function runChromeComposerTest() {
  const layout = JSON.stringify({ rows: [{ columns: [{width:25,align:"left",items:["logo"]},{width:50,align:"center",items:[]},{width:25,align:"right",items:["cart"]}] }, { columns: [{width:100,align:"center",items:["search_bar"]}] }] });
  const markup = `<!doctype html><html><body><section class="kidia-fixed-chrome-card" data-element="header"><input type="checkbox" name="layout[header][enabled]" checked><div class="kidia-chrome-composer" data-part="header" data-page="home"><input class="kidia-chrome-layout-json" name="layout[header][settings][layout_json]" value='${layout}'><div class="kidia-chrome-layout"></div><div class="kidia-chrome-palette"><div class="kidia-chrome-palette__items"><button class="kidia-chrome-item" data-item="logo">Logo</button><button class="kidia-chrome-item" data-item="cart">Cart</button><button class="kidia-chrome-item" data-item="search_bar">Search bar</button><button class="kidia-chrome-item" data-item="support">Support</button></div></div><button class="kidia-chrome-reset"></button></div><section data-item-section="logo"></section><section data-item-section="cart"><div class="kidia-chrome-icon-choice"><button class="kidia-chrome-icon-option" data-icon-value="bag">Bag</button><button class="kidia-chrome-icon-option is-selected" data-icon-value="basket">Basket</button><select class="kidia-chrome-icon-select" name="layout[header][settings][cart_icon_variant]"><option value="bag">Bag</option><option value="basket" selected>Basket</option></select></div></section><section data-item-section="search_bar"></section><section data-item-section="support"><div class="kidia-chrome-icon-choice"><button class="kidia-chrome-icon-option" data-icon-value="chat">Chat</button><button class="kidia-chrome-icon-option is-selected" data-icon-value="headset">Headset</button><select class="kidia-chrome-icon-select" name="layout[header][settings][support_icon_variant]"><option value="chat">Chat</option><option value="headset" selected>Headset</option></select></div></section><input name="layout[header][settings][subtitle]" value="Kids"><input name="layout[header][settings][height]" value="112"><input name="layout[header][settings][background_color]" value="#FFFFFF"><input name="layout[header][settings][icon_color]" value="#1F2933"><input name="layout[header][settings][icon_size]" value="24"><select name="layout[header][settings][cart_style]"><option value="circle" selected>Circle</option></select><input name="layout[header][settings][cart_color]" value="#123456"><input name="layout[header][settings][cart_background]" value="#FFFFFF"><input name="layout[header][settings][cart_radius]" value="12"><input name="layout[header][settings][icon_gap]" value="6"><input name="layout[header][settings][row_gap]" value="4"><input name="layout[header][settings][vertical_padding]" value="0"><input name="layout[header][settings][horizontal_padding]" value="16"><input name="layout[header][settings][search_width_percent]" value="100"><input name="layout[header][settings][search_height]" value="40"><input name="layout[header][settings][search_radius]" value="14"><input name="layout[header][settings][search_background]" value="#F1F3F4"><input name="layout[header][settings][search_placeholder]" value="Search products"></section></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
  const { window } = dom;
  window.document.querySelector(".kidia-fixed-chrome-card").insertAdjacentHTML("beforeend", '<input type="checkbox" name="layout[header][settings][show_cart_badge]" checked><select name="layout[header][settings][cart_badge_shape]"><option value="circle">Circle</option><option value="pill" selected>Pill</option></select><input name="layout[header][settings][cart_badge_size]" value="22"><input name="layout[header][settings][cart_badge_background]" value="#C84F6A"><input name="layout[header][settings][cart_badge_text_color]" value="#FFF4E8">');
  window.eval(readAsset("chrome-layout.js"));
  window.document.dispatchEvent(new window.Event("DOMContentLoaded"));
  const card = window.document.querySelector(".kidia-fixed-chrome-card");
  card.insertAdjacentHTML("beforeend", '<input name="layout[header][settings][margin_top]" value="7"><input name="layout[header][settings][margin_bottom]" value="9">');
	card.insertAdjacentHTML("beforeend", '<input name="layout[header][settings][space_up]" value="4"><input name="layout[header][settings][space_down]" value="6">');
  const preview = window.KidiaChromePreview.renderHeader(card, "Home");
  assert.match(preview, /kidia-app-icon--cart-basket/, "The selected cart design must render immediately in preview.");
	assert.match(preview, /kidia-app-icon-badge[^>]+min-width:22px[^>]+border-radius:11px[^>]+background:#C84F6A[^>]+color:#FFF4E8/, "Cart count shape, size and colors must render immediately in preview.");
	assert.match(preview, /is-circle[^>]+border:1px solid #123456/, "Header icon style must visibly affect the live preview.");
	assert.match(preview, /kidia-app-header-brand[\s\S]*Kids/, "The subtitle must render with the logo instead of occupying a separate row item.");
	window.document.querySelector('[data-icon-value="bag"]').dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
	assert.match(window.KidiaChromePreview.renderHeader(card, "Home"), /kidia-app-icon--cart-bag/, "Icon image buttons outside the composer must update the preview immediately.");
	window.document.querySelector('[data-item-section="support"] [data-icon-value="chat"]').dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
	assert.equal(window.document.querySelector('[name$="[support_icon_variant]"]').value, "chat", "Icon choices inside their own item settings section must remain clickable.");
  assert.match(preview, /grid-template-columns:minmax\(0,100fr\)/, "A one-column row must span the header without overflowing when row gaps are present.");
  assert.match(preview, /width:100%/, "Search width must be applied instantly as a percentage.");
	assert.match(preview, /--row-gap:4px/, "The real gap between header rows must be reflected without browser-only scaling.");
	assert.match(preview, /padding:0px 16px!important/, "Zero vertical padding must be reflected immediately instead of falling back to the default.");
	assert.match(preview, /margin:7px 0px 9px/, "Header space above and below must update the preview.");
	assert.match(preview, /padding-top:4px!important;padding-bottom:6px!important/, "Header Section Layout spacing must update the preview.");
	const searchWidth = card.querySelector('[name$="[search_width_percent]"]');
	searchWidth.value = "150";
	assert.match(window.KidiaChromePreview.renderHeader(card, "Home"), /width:100%/, "Search width must clamp to the full available row instead of silently overflowing.");
  assert.equal(window.document.querySelectorAll(".kidia-chrome-row").length, 2, "Home header must support two draggable rows.");
	const addRow = window.document.querySelector(".kidia-chrome-row:last-child .kidia-chrome-row-toolbar .kidia-chrome-add-row");
	assert.ok(addRow, "Add row must render inside the final row toolbar instead of below the row.");
	addRow.dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
	assert.equal(window.document.querySelectorAll(".kidia-chrome-row").length, 3, "Add row must add a third row when clicked.");
	assert.equal(window.document.querySelectorAll(".kidia-chrome-layout > .kidia-chrome-add-row").length, 0, "Add row must never recreate the old space below the rows.");
	assert.match(readAsset("chrome-layout.css"), /\.kidia-chrome-row-toolbar \.kidia-chrome-add-row\s*\{[^}]*margin:\s*0 0 0 auto!important/, "Add row must stay inside the row toolbar and align to its far right edge.");
	assert.match(readAsset("chrome-layout.css"), /kidia-page-text-control \.button\s*\{[^}]*height:34px;[^}]*min-height:34px/, "Use logo text must match the standard logo field height.");
	assert.match(readAsset("chrome-layout.css"), /kidia-page-media \.button\s*\{[^}]*height:34px;[^}]*min-height:34px/, "Choose image must match the standard logo field height.");
	assert.match(readAsset("category-builder.css"), /kidia-category-general-fields input\[type="range"\]\s*\{[^}]*max-width:190px/, "Category sliders must match the adjacent standard field width.");
	assert.match(readAsset("category-builder.css"), /input\[type="range"\]::-webkit-slider-thumb\s*\{[^}]*background:#2f806e/, "Category slider thumbs must use the Kidia color.");
	assert.match(readAsset("chrome-layout.css"), /data-setting="horizontal_padding"\]\s*\{\s*grid-column:1;\s*grid-row:1;\s*\}[\s\S]*data-setting="height"\]\s*\{\s*grid-column:3;\s*grid-row:1;/, "Footer General Settings must follow the approved first-row order.");
	assert.match(readAsset("chrome-layout.css"), /data-setting="show_labels"\]\s*\{\s*grid-column:1;\s*grid-row:6;\s*\}[\s\S]*data-setting="hide_on_scroll"\]\s*\{\s*grid-column:3;\s*grid-row:6;/, "Footer General Settings must keep all three toggles in the final row.");
	assert.match(readAsset("category-builder.css"), /kidia-category-image-button\s*\{\s*width:112px;\s*\}[\s\S]*kidia-category-image-clear\s*\{\s*width:142px;/, "Category and subcategory image buttons must use the compact approved widths.");
	assert.match(readAsset("category-builder.css"), /kidia-category-element \.kidia-category-visibility\s*\{[^}]*transform:translateX\(8px\)/, "Category and subcategory visibility toggles must shift right without overlapping the image buttons.");
	const columnCount = window.document.querySelector(".kidia-row-column-count");
	columnCount.value = "6";
	columnCount.dispatchEvent(new window.Event("change", { bubbles: true }));
	const savedLayout = JSON.parse(window.document.querySelector(".kidia-chrome-layout-json").value);
	assert.equal(savedLayout.rows[0].columns.length, 6, "Every row must independently support up to six columns.");
	assert.equal(Math.round(savedLayout.rows[0].columns.reduce((total, column) => total + column.width, 0)), 100, "Automatically generated column widths must total 100%.");
	const firstWidth = window.document.querySelector('.kidia-column-width[data-row="0"][data-column="0"]');
	firstWidth.value = "40";
	firstWidth.dispatchEvent(new window.Event("input", { bubbles: true }));
	assert.match(window.document.querySelector(".kidia-chrome-row-grid").style.gridTemplateColumns, /minmax\(0, ?40fr\)/, "Column ratios must remain inside the row width instead of adding gaps beyond 100%.");
	assert.match(window.document.querySelector(".kidia-row-total").textContent, /123\.3/, "Edited column percentages must update the row total instantly.");
	assert.equal(window.document.querySelector(".kidia-chrome-composer").classList.contains("has-invalid-layout"), true, "A row whose columns do not total 100% must be visibly invalid.");
  assert.equal(window.document.querySelector('[data-item-section="support"]').hidden, true, "Only settings for placed items must be visible.");
  assert.equal(window.document.querySelector('[data-item-section="cart"]').hidden, false, "Placed item settings must be visible.");
	const transfer = { value: "", setData(type, value) { this.value = value; }, getData() { return this.value; } };
	const activeCart = window.document.querySelector('.kidia-chrome-zone [data-item="cart"]');
	const dragStart = new window.Event("dragstart", { bubbles: true, cancelable: true });
	Object.defineProperty(dragStart, "dataTransfer", { value: transfer });
	activeCart.dispatchEvent(dragStart);
	const dropOutside = new window.Event("drop", { bubbles: true, cancelable: true });
	Object.defineProperty(dropOutside, "dataTransfer", { value: transfer });
	window.document.querySelector(".kidia-chrome-palette").dispatchEvent(dropOutside);
	assert.equal(window.document.querySelector('[data-item-section="cart"]').hidden, true, "Dragging an item back to Available items must remove it from the row and hide its settings.");
  console.log("Header/Footer composer: rows, conditional sections and icon designs passed.");
}

function runCollapsedHeaderToggleTest() {
  const regular = JSON.stringify({ rows: [{ columns: [{ width: 100, align: "center", items: ["title"] }] }] });
  const collapsed = JSON.stringify({ rows: [{ columns: [{ width: 84, align: "left", items: ["search_bar"] }, { width: 16, align: "right", items: ["cart"] }] }] });
  const markup = `<!doctype html><html><body><form><section class="kidia-fixed-chrome-card" data-chrome-part="header">
    <input type="checkbox" name="layout[header][enabled]" value="1" checked>
    <input type="hidden" name="layout[header][settings][collapse_on_scroll]" value="0">
    <input type="checkbox" class="kidia-collapsed-header-enabled" name="layout[header][settings][collapse_on_scroll]" value="1">
    <input name="layout[header][settings][layout_json]" value='${regular}'>
    <input name="layout[header][settings][compact_layout_json]" value='${collapsed}'>
    <input name="layout[header][settings][title]" value="Products">
    <input name="layout[header][settings][height]" value="64">
    <input name="layout[header][settings][row_gap]" value="0">
    <input name="layout[header][settings][vertical_padding]" value="0">
    <input name="layout[header][settings][compact_height]" value="56">
    <input name="layout[header][settings][background_color]" value="#FFFFFF">
    <input name="layout[header][settings][compact_background_color]" value="#F4F5F5">
    <select name="layout[header][settings][collapse_transition]"><option value="fade_slide" selected>Fade + slide</option></select>
    <select name="layout[header][settings][collapse_speed]"><option value="slow" selected>Slow</option></select>
    <div class="kidia-chrome-composer--collapsed"></div>
    <section class="kidia-collapsed-header-settings"></section>
  </section></form></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only" });
  const { window } = dom;
  window.eval(readAsset("chrome-layout.js"));
  const card = window.document.querySelector(".kidia-fixed-chrome-card");
  const toggle = card.querySelector(".kidia-collapsed-header-enabled");
	window.document.dispatchEvent(new window.Event("DOMContentLoaded"));
	assert.equal(card.querySelector(".kidia-chrome-composer--collapsed").hidden, true, "Collapsed layout must be hidden while collapsed header is Off.");
	assert.equal(card.querySelector(".kidia-collapsed-header-settings").hidden, true, "Collapsed settings must be hidden while collapsed header is Off.");

  const regularPreview = window.KidiaChromePreview.renderHeader(card, "Products");
  assert.doesNotMatch(regularPreview, /is-collapsed/, "Off must preview the regular header.");
	assert.match(regularPreview, /height:64px/, "Regular header height must use the exact configured value.");
	assert.match(regularPreview, /padding:0px 16px/, "Vertical padding must update the preview exactly.");
	assert.match(regularPreview, /--row-gap:0px/, "Setting row spacing to zero must remove the preview gap.");
  toggle.checked = true;
	toggle.dispatchEvent(new window.Event("change", { bubbles: true }));
	assert.equal(card.querySelector(".kidia-chrome-composer--collapsed").hidden, false, "Collapsed layout must appear when collapsed header is On.");
	assert.equal(card.querySelector(".kidia-collapsed-header-settings").hidden, false, "Collapsed settings must appear when collapsed header is On.");
	  assert.doesNotMatch(window.KidiaChromePreview.renderHeader(card, "Products"), /is-collapsed/, "On must still show the real regular header while the preview is at the top.");
	  const collapsedPreview = window.KidiaChromePreview.renderHeader(card, "Products", { collapsed: true });
	  assert.match(collapsedPreview, /is-collapsed/, "Scrolling the preview must show the collapsed header.");
  assert.match(collapsedPreview, /height:56px/, "Collapsed height must use the exact configured value.");
  assert.match(collapsedPreview, /kidia-app-header-item--cart/, "The saved compact layout must drive the collapsed preview.");
  assert.match(collapsedPreview, /is-transition-fade_slide/, "The selected collapsed transition must drive the preview.");
	  assert.match(collapsedPreview, /--collapse-duration:420ms/, "The selected transition speed must drive the preview.");
	  card.querySelector('[name$="[collapse_transition]"]').value = "smooth_compact";
	  const halfwayPreview = window.KidiaChromePreview.renderHeader(card, "Products", { collapseProgress: 0.5 });
	  assert.match(halfwayPreview, /kidia-app-header-transition-layer--regular/, "PatPat-style preview must keep the regular header layer while scrolling.");
	  assert.match(halfwayPreview, /kidia-app-header-transition-layer--compact/, "PatPat-style preview must blend in the compact header layer while scrolling.");
  assert.deepEqual(Array.from(new window.FormData(window.document.querySelector("form")).getAll(toggle.name)), ["0", "1"], "On must be included in the submitted form data.");
  toggle.checked = false;
  assert.deepEqual(Array.from(new window.FormData(window.document.querySelector("form")).getAll(toggle.name)), ["0"], "Off must submit an explicit zero value.");
	  console.log("Collapsed header: persistent On/Off toggle and scroll-accurate preview passed.");
}

function runFooterPreviewControlsTest() {
	  const markup = `<!doctype html><html><body><section class="kidia-fixed-chrome-card" data-page="category"><input type="checkbox" name="layout[footer][enabled]" checked><input name="layout[footer][settings][layout_json]" value='{"rows":[{"columns":[{"width":25,"items":["home"]},{"width":25,"items":["categories"]},{"width":25,"items":["wishlist"]},{"width":25,"items":["account","share"]}]}]}'><input name="layout[footer][settings][height]" value="72"><input name="layout[footer][settings][side_spacing_percent]" value="5"><input name="layout[footer][settings][icon_size]" value="26"><input name="layout[footer][settings][label_size]" value="11"><input name="layout[footer][settings][icon_label_gap]" value="4"><input name="layout[footer][settings][active_color]" value="#1F6F61"><input name="layout[footer][settings][inactive_color]" value="#6B7280"><input name="layout[footer][settings][background_color]" value="#FFFFFF"><input name="layout[footer][settings][border_color]" value="#ABCDEF"><input name="layout[footer][settings][border_width]" value="3"><input name="layout[footer][settings][top_radius]" value="12"><select name="layout[footer][settings][shadow]"><option value="strong" selected>Strong</option></select><input type="checkbox" name="layout[footer][settings][show_labels]" checked><select name="layout[footer][settings][home_icon_variant]"><option value="filled" selected>Filled</option></select><select name="layout[footer][settings][wishlist_icon_style]"><option value="filled" selected>Filled</option></select><input name="layout[footer][settings][wishlist_icon_size]" value="30"></section></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only" });
  const { window } = dom;
  window.eval(readAsset("chrome-layout.js"));
	const footerCard = window.document.querySelector("section");
	footerCard.insertAdjacentHTML("beforeend", '<input name="layout[footer][settings][margin_top]" value="6"><input name="layout[footer][settings][margin_bottom]" value="8">');
	footerCard.insertAdjacentHTML("beforeend", '<input name="layout[footer][settings][space_up]" value="5"><input name="layout[footer][settings][space_down]" value="7">');
  const preview = window.KidiaChromePreview.renderFooter(footerCard);
  assert.match(preview, /padding:0 5%/, "Footer outside spacing must use the saved percentage on both sides.");
  assert.match(preview, /kidia-app-icon--home-filled/, "Footer icon design must match the selected visual option.");
	  assert.match(preview, />الرئيسية</, "Footer labels must match the Arabic Flutter footer.");
	assert.match(preview, /border-top:3px solid #ABCDEF/, "Footer border controls must update preview instantly.");
	assert.match(preview, /border-radius:12px/, "Footer corner radius must update preview without browser-only scaling.");
	assert.match(preview, /0 4px 12px/, "Footer shadow must update preview instantly.");
	assert.match(preview, /kidia-app-footer-item--wishlist is-filled/, "Footer icon style must be applied to the preview.");
	assert.match(preview, /kidia-app-footer-item--share/, "Every page preview must render every footer function placed by the merchant.");
	assert.doesNotMatch(preview, /--item-icon-size:30px/, "Per-icon sizes must no longer move one footer icon out of alignment.");
	assert.match(preview, /--item-icon-size:26px/, "Every footer icon must use the same shared size.");
	assert.match(preview, /--label-gap:4px/, "The Category footer must preview its own icon and label spacing.");
	assert.match(preview, /margin:6px 0 8px/, "Footer space above and below must update the preview.");
	assert.match(preview, /padding-top:5px!important;padding-bottom:7px!important/, "Footer Section Layout spacing must update the preview.");
	footerCard.dataset.page = "home";
	const homePreview = window.KidiaChromePreview.renderFooter(footerCard, { page: "home" });
	assert.match(homePreview, /--label-gap:4px/, "Every page footer must preview its own icon and label spacing instead of the Category value.");
	  console.log("Footer preview: equal items, side spacing, labels and icon designs passed.");
}

function runProductFooterButtonPreviewTest() {
	const markup = `<!doctype html><html><body><section class="kidia-fixed-chrome-card" data-page="product">
		<input type="checkbox" name="layout[footer][enabled]" checked>
		<input name="layout[footer][settings][layout_json]" value='{"rows":[{"columns":[{"width":30,"items":["share","like"]},{"width":70,"items":["add_to_cart"]}]}]}'>
		<input name="layout[footer][settings][button_width_percent]" value="60">
		<input name="layout[footer][settings][button_height]" value="48">
		<select name="layout[footer][settings][button_style]"><option value="outline" selected>Outline</option></select>
		<select name="layout[footer][settings][button_shape]"><option value="pill" selected>Pill</option></select>
		<input name="layout[footer][settings][button_color]" value="#112233">
		<input name="layout[footer][settings][button_text_color]" value="#445566">
		<input name="layout[footer][settings][button_border_color]" value="#778899">
		<input name="layout[footer][settings][button_border_width]" value="2">
		<input name="layout[footer][settings][add_to_cart_label]" value="Add to bag">
		<input type="checkbox" name="layout[footer][settings][show_labels]" checked>
	</section></body></html>`;
	const dom = new JSDOM(markup, { runScripts: "outside-only" });
	const { window } = dom;
	window.eval(readAsset("chrome-layout.js"));
	const preview = window.KidiaChromePreview.renderFooter(window.document.querySelector("section"), { page: "product" });
	assert.match(preview, /grid-template-columns:minmax\(0,15fr\) minmax\(0,15fr\) minmax\(0,70fr\)/, "Composer column widths must remain intact and split a shared icon column evenly.");
	assert.match(preview, /kidia-app-footer-add is-outline/, "The selected button style must render in the preview.");
	assert.match(preview, /width:85\.71428571428571%;height:48px/, "A 60% button must be centered inside its wider 70% composer column.");
	assert.match(preview, /background:transparent/, "Outline buttons must preview with a transparent fill.");
	assert.match(preview, /border:2px solid #778899/, "Button border controls must render immediately.");
	assert.match(preview, /border-radius:24px/, "Pill shape must derive its radius from the configured height.");
	window.document.querySelector('[name$="[button_height]"]').value = "80";
	const tallPreview = window.KidiaChromePreview.renderFooter(window.document.querySelector("section"), { page: "product" });
	assert.match(tallPreview, /style="height:80px;/, "A taller product button must grow the footer instead of being clipped by the shared footer height.");
	console.log("Product footer preview: width, height, style and shape controls passed.");
}

function runChromeCopyPasteAndLogoMediaTest() {
	const sourceLayout = JSON.stringify({ rows: [{ columns: [{ width: 100, align: "center", items: ["title"] }] }] });
	const destinationLayout = JSON.stringify({ rows: [{ columns: [{ width: 100, align: "center", items: ["cart"] }] }] });
	function card(id, enabled, layout, title) {
		return `<section id="${id}" class="kidia-fixed-chrome-card" data-chrome-part="header">
			<input type="checkbox" name="${id}[enabled]" ${enabled ? "checked" : ""}>
			<button type="button" data-chrome-copy>Copy</button><button type="button" data-chrome-paste>Paste</button><span class="kidia-chrome-transfer-status"></span>
			<div class="kidia-chrome-composer" data-part="header" data-page="catalog">
				<input class="kidia-chrome-layout-json" name="${id}[settings][layout_json]" value='${layout}'>
				<div class="kidia-chrome-layout"></div>
				<div class="kidia-chrome-palette"><div class="kidia-chrome-palette__items"><button class="kidia-chrome-item" data-item="title">Title</button><button class="kidia-chrome-item" data-item="cart">Cart</button></div></div>
				<button type="button" class="kidia-chrome-reset">Reset</button>
			</div>
			<input name="${id}[settings][title]" value="${title}">
			<input name="${id}[settings][logo_text]" value="${id} logo">
			<div class="kidia-page-field kidia-page-field--image"><div class="kidia-page-media"><input class="kidia-page-media-url" name="${id}[settings][logo_url]" value="https://example.com/${id}.png"><button type="button" class="kidia-page-media-choose">Choose image</button><button type="button" class="kidia-page-media-clear">Use logo text</button></div><img class="kidia-page-media-preview" src="https://example.com/${id}.png"></div>
		</section>`;
	}
	const dom = new JSDOM(`<!doctype html><html><body>${card("source", true, sourceLayout, "Copied title")}${card("destination", false, destinationLayout, "Old title")}</body></html>`, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
	const { window } = dom;
	window.wp = {
		media() {
			let select = () => {};
			return {
				on(event, callback) { if (event === "select") select = callback; },
				open() { select(); },
				state() { return { get() { return { first() { return { toJSON() { return { url: "https://example.com/new-logo.png" }; } }; } }; } }; },
			};
		},
	};
	window.eval(readAsset("chrome-layout.js"));
	window.document.dispatchEvent(new window.Event("DOMContentLoaded"));
	const source = window.document.getElementById("source");
	const destination = window.document.getElementById("destination");
	click(window, source.querySelector("[data-chrome-copy]"));
	click(window, destination.querySelector("[data-chrome-paste]"));
	assert.equal(destination.querySelector('[name$="[enabled]"]').checked, true, "Paste must copy the fixed card On/Off state.");
	assert.equal(destination.querySelector('[name$="[title]"]').value, "Copied title", "Paste must copy settings between page cards.");
	assert.deepEqual(JSON.parse(destination.querySelector(".kidia-chrome-layout-json").value), JSON.parse(sourceLayout), "Paste must copy the exact header/footer layout.");
	assert.ok(destination.querySelector('.kidia-chrome-zone [data-item="title"]'), "The pasted layout must redraw the composer immediately.");
	assert.equal(destination.querySelector(".kidia-chrome-transfer-status").textContent, "Settings pasted", "Paste must show clear feedback.");
	click(window, destination.querySelector(".kidia-page-media-choose"));
	assert.equal(destination.querySelector(".kidia-page-media-url").value, "https://example.com/new-logo.png", "Choose image must update the logo URL on every builder page.");
	assert.equal(destination.querySelector(".kidia-page-media-preview").src, "https://example.com/new-logo.png", "Choose image must update the visible logo preview.");
	click(window, destination.querySelector(".kidia-page-media-clear"));
	assert.equal(destination.querySelector(".kidia-page-media-url").value, "", "Use logo text must clear the selected image.");
	assert.equal(destination.querySelector(".kidia-page-media-preview").hidden, true, "Switching to logo text must hide the old image preview.");
	console.log("Header/Footer transfer and shared logo media picker passed.");
}

function runUnsavedChangesDialogTest() {
	const adminTheme = readAsset("admin-theme.css");
	const pageBuilderTheme = readAsset("page-builder.css");
	assert.match(adminTheme, /--kidia-admin-button-radius:\s*10px/, "CMS buttons must be square or rectangular with lightly rounded corners, never pills.");
	assert.match(pageBuilderTheme, /data-kidia-unsaved-save[^}]+background:#2f806e!important/, "The unsaved Save action must use Kidia green.");
	assert.match(pageBuilderTheme, /kidia-unsaved-modal__icon[^}]+background:#e7f5f1[^}]+color:#2f806e/, "The unsaved dialog icon must use the Kidia palette.");
	const markup = `<!doctype html><html><body><a id="leave" href="/wp-admin/admin.php?page=other">Leave</a><form class="kidia-page-editor"><input id="title" name="layout[title]" value="Before"><button type="submit">Save</button></form></body></html>`;
	const dom = new JSDOM(markup, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php?page=builder" });
	const { window } = dom;
	const form = window.document.querySelector("form");
	let submitted = false;
	form.reportValidity = () => true;
	form.requestSubmit = () => {
		submitted = true;
		form.dispatchEvent(new window.Event("submit", { bubbles: true, cancelable: true }));
	};
	window.eval(readAsset("unsaved-changes.js"));
	const title = window.document.getElementById("title");
	title.value = "After";
	title.dispatchEvent(new window.Event("input", { bubbles: true }));
	click(window, window.document.getElementById("leave"));
	const modal = window.document.querySelector(".kidia-unsaved-modal");
	assert.equal(modal.hidden, false, "Internal navigation with edits must open the centered custom dialog.");
	assert.match(modal.textContent, /Save Changes/);
	assert.match(modal.textContent, /Discard Changes/);
	assert.match(modal.textContent, /Cancel/);
	click(window, modal.querySelector(".kidia-unsaved-modal__actions [data-kidia-unsaved-cancel]"));
	assert.equal(modal.hidden, true, "Cancel must close the dialog and keep the builder open.");
	window.document.dispatchEvent(new window.KeyboardEvent("keydown", { key: "r", ctrlKey: true, bubbles: true, cancelable: true }));
	assert.equal(modal.hidden, false, "Keyboard refresh must use the same custom decision dialog.");
	click(window, modal.querySelector("[data-kidia-unsaved-save]"));
	assert.equal(submitted, true, "Save Changes must submit the current builder form.");
	assert.equal(form.querySelector('[name="kidia_redirect_to"]').value, window.location.href, "Save before refresh must return to the same builder URL.");
	console.log("Unsaved changes: centered Save, Discard and Cancel decision dialog passed.");
}

function runCommercePreviewTest() {
  const markup = `<!doctype html><html><body><div id="kidia-commerce-preview" data-preview-kind="checkout"></div><form class="kidia-commerce-preview-form">
    <input type="hidden" name="suggestions[enabled]" value="0"><input type="checkbox" name="suggestions[enabled]" value="1" checked>
    <input name="suggestions[title]" value="You may also need"><input name="suggestions[columns]" value="2"><input name="suggestions[limit]" value="2">
    <input name="suggestions[card_radius]" value="14"><input name="suggestions[image_ratio]" value="1"><input name="suggestions[button_label]" value="Add">
    <input type="checkbox" name="suggestions[show_price]" checked><input type="checkbox" name="suggestions[show_rating]">
    <input name="suggestions[button_color]" value="#2F806E"><input name="suggestions[button_text_color]" value="#FFFFFF">
  </form></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
  const { window } = dom;
  window.requestAnimationFrame = (callback) => callback();
  window.kidiaCommercePreview = { products: [{ name: "Pink Set", price: "450 EGP", image_url: "https://example.com/pink.jpg" }, { name: "Blue Set", price: "390 EGP", image_url: "https://example.com/blue.jpg" }] };
  window.eval(readAsset("commerce-preview.js"));
  window.document.dispatchEvent(new window.Event("DOMContentLoaded"));
  assert.equal(window.document.querySelectorAll(".kidia-commerce-card").length, 2, "Commerce previews must use real WooCommerce product cards.");
  assert.match(window.document.getElementById("kidia-commerce-preview").textContent, /Pink Set/, "Commerce previews must show real product content.");
  const title = window.document.querySelector('[name="suggestions[title]"]');
  title.value = "Complete your order";
  title.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.match(window.document.getElementById("kidia-commerce-preview").textContent, /Complete your order/, "Commerce previews must update during input without saving.");
  console.log("Commerce previews: real products and instant settings updates passed.");
}

function runUniformChromeSettingsContractTest() {
	const template = fs.readFileSync(path.join(__dirname, "../admin/pages/fixed-chrome-card.php"), "utf8");
	const styles = readAsset("chrome-layout.css");
	const chrome = readAsset("chrome-layout.js");
	const home = readAsset("home-builder.js");
	const page = readAsset("page-builder.js");
	const category = readAsset("category-builder.js");
	assert.doesNotMatch(template, /\$chrome_items\s*=\s*'product'\s*===\s*\$chrome_page_name/, "Footer functions must not change between builder pages.");
	for (const item of ["home", "categories", "search", "cart", "wishlist", "account", "orders", "share", "like", "add_to_cart"]) {
		assert.match(template, new RegExp("'" + item + "'\\s*=>"), `Every footer must expose the ${item} function.`);
	}
	assert.doesNotMatch(template, /Footer height, icon size and label size come from/, "Every footer must own its complete settings instead of borrowing another page's values.");
	assert.doesNotMatch(styles, /data-chrome-part="footer"[^}]+data-setting="height"/, "Footer height must remain visible on every page.");
	assert.match(styles, /kidia-chrome-item-setting--logo[^}]+grid-template-columns:repeat\(3,minmax\(0,1fr\)\)/, "Logo settings must use a compact three-column grid.");
	assert.match(styles, /\.kidia-fixed-chrome-card\[data-chrome-part="header"\]\s*\{[^}]*direction:\s*rtl;[^}]*text-align:\s*right;/, "The shared Header card must always use the same right-to-left settings flow.");
	assert.match(styles, /\.kidia-fixed-chrome-card\[data-chrome-part="header"\] \.kidia-page-fields\s*\{[^}]*grid-auto-flow:\s*row;/, "Header fields must keep a stable row-first order.");
	assert.match(styles, /\.kidia-fixed-chrome-card\[data-chrome-part="header"\] \.kidia-page-field\s*\{[^}]*align-items:\s*flex-start;[^}]*direction:\s*rtl;/, "Every Header field must start from the right like the Home element grids.");
	assert.doesNotMatch(styles, /\.kidia-fixed-chrome-card\[data-chrome-part="footer"\][^{]*\{[^}]*direction:\s*rtl/, "The already-correct Footer field order must remain untouched.");
	assert.match(styles, /\.kidia-fixed-chrome-toggle\s*\{[^}]*width:\s*88px;/, "The fixed card On/Off control must be styled by the shared component rather than Home-only CSS.");
	assert.match(chrome, /closest\("\.kidia-fixed-chrome-expand"\)[\s\S]*card\.classList\.toggle\("is-open",opening\)/, "The shared component must own Header/Footer expand behavior on every page.");
	assert.doesNotMatch(home, /closest\("\.kidia-fixed-chrome-expand"\)/, "Home must not keep a separate Header/Footer expand implementation.");
	assert.doesNotMatch(category, /\.kidia-fixed-chrome-expand, \.kidia-category-element-expand/, "Category must not keep a separate Header/Footer expand implementation.");
	assert.match(page, /button && !button\.closest\("\.kidia-fixed-chrome-card"\)/, "Page builders must defer fixed-card expansion to the shared component.");
	assert.match(styles, /data-setting="logo_url"[^}]+grid-column:span 1/, "Logo image and subtitle must share the first compact row.");
	assert.match(template, /logo_url'\s*=>\s*0,\s*'subtitle'\s*=>\s*1,\s*'logo_text'\s*=>\s*2/, "Subtitle must immediately follow the logo image in the first row.");
	assert.match(styles, /kidia-chrome-item-setting--logo \.kidia-page-field input,[\s\S]*?width:min\(100%,240px\)/, "Logo value controls must remain compact instead of filling empty space.");
	assert.match(chrome, /supported=\["home","categories","search","cart","wishlist","account","orders","share","like","add_to_cart"\]/, "The live preview must support the same footer functions on every page.");
	console.log("Header/Footer settings and functions are uniform across all six page builders.");
}

if (require.main === module) {
  runHomeBuilderTest();
  runMergeControlsContractTest();
  runCategoryBuilderTest();
  runPageBuilderTest();
  runChromeComposerTest();
  runCollapsedHeaderToggleTest();
	runFooterPreviewControlsTest();
	runProductFooterButtonPreviewTest();
	runChromeCopyPasteAndLogoMediaTest();
	runUnsavedChangesDialogTest();
	runCommercePreviewTest();
	runUniformChromeSettingsContractTest();
  console.log("Builder browser contract tests: ok");
}

module.exports = { homeMarkup, categoryRow };
