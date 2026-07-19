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
  assert.match(builderCss, /grid-template-columns:\s*286px minmax\(0, 1fr\)/, "The editor must keep using the available workspace beside the phone preview.");
  assert.match(builderCss, /\.kidia-builder-block\s*\{[\s\S]*?width:\s*77%;/, "Element cards must be 10% wider than their previous 70% width.");
  assert.match(builderCss, /\.kidia-builder-block__header\s*\{[\s\S]*?min-height:\s*70px;/, "Collapsed element cards must use the requested 70px height.");
  assert.match(builderCss, /\.kidia-builder-grid\s*\{[\s\S]*?repeat\(3, minmax\(0, 1fr\)\)/, "Element settings must keep the original three-column layout.");
  assert.match(builderCss, /--kidia-field-width:\s*64\.9351%;/, "The wider 77% card must preserve controls at 50% of their original width.");
  assert.match(builderCss, /input\[type="text"\],[\s\S]*?width:\s*var\(--kidia-field-width\);/, "Settings controls must use the calculated half-original width.");
  assert.match(builderCss, /input\[type="color"\]\s*\{[\s\S]*?width:\s*var\(--kidia-field-width\);/, "Color controls must use the calculated half-original width.");
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
    ["margin_top", "13", "marginTop", "13px"],
    ["margin_bottom", "17", "marginBottom", "17px"],
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
  const backgroundField = categoryBlock.querySelector('[name$="[settings][block_background]"]');
  backgroundField.value = "#eaf6f2";
  backgroundField.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.equal(categoryFrame().style.backgroundColor, "rgb(234, 246, 242)", "Block background must update the Home preview instantly.");
  presentationCases.forEach(([fieldName]) => {
    const field = categoryBlock.querySelector(`[name$="[settings][${fieldName}]"]`);
    field.value = "0";
    field.dispatchEvent(new window.Event("input", { bubbles: true }));
  });
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

function categoryGeneralSettings() {
	  const field = (name, value, type = "text") => `<input type="${type}" name="category_general[${name}]" value="${value}">`;
	  return `<section class="kidia-category-general">
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
	      <div class="kidia-category-image-actions"><button type="button" class="kidia-category-image-button">Choose image</button><button type="button" class="kidia-category-image-clear" hidden>Clear</button></div>
	      <label class="kidia-category-visibility"><input type="hidden" name="categories[${id}][hidden]" value="1"><input type="checkbox" name="categories[${id}][hidden]" value="0" checked></label>
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
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-branch").length, 2, "Root categories must render as app-style rows.");
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 0, "Subcategories start collapsed.");

  click(window, window.document.querySelector(".kidia-category-expand"));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 1, "Expand must show subcategories instantly.");
  assert.ok(window.document.querySelector(".kidia-category-preview-branch.is-expanded"), "Expanded branch styling must be applied.");

	  const size = window.document.querySelector('[name="category_general[image_size]"]');
  size.value = "96";
  size.dispatchEvent(new window.Event("input", { bubbles: true }));
  assert.equal(window.document.querySelector(".kidia-category-preview-root .kidia-category-preview-image").style.width, "78px", "Preview must clamp category art to the app row width.");
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 1, "Expanded subcategories must stay open when live settings rerender the preview.");

  click(window, window.document.querySelector(".kidia-category-preview-expand"));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 0, "Preview Expand control must collapse the matching category.");
  assert.equal(window.document.querySelector(".kidia-category-expand").getAttribute("aria-expanded"), "false", "Preview collapse must synchronize the editor state.");
  click(window, window.document.querySelector(".kidia-category-preview-expand"));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-child").length, 1, "Preview Expand control must reopen the matching category.");
  assert.equal(window.document.querySelector(".kidia-category-expand").getAttribute("aria-expanded"), "true", "Preview expansion must synchronize the editor state.");

	  const appName = window.document.querySelector('[name="categories[1][name]"]');
	  appName.value = "Kids Clothes";
	  appName.dispatchEvent(new window.Event("input", { bubbles: true }));
	  assert.match(window.document.querySelector(".kidia-category-preview-name").textContent, /Kids Clothes/, "App-only names must update the preview instantly.");

  click(window, window.document.querySelector(".kidia-category-image-button"));
  assert.match(window.document.querySelector(".kidia-category-image img").src, /custom-thumb\.jpg$/, "Choosing media must update the editor image.");
  assert.match(window.document.querySelector(".kidia-category-preview-image img").src, /custom-thumb\.jpg$/, "Choosing media must update the phone preview.");
  click(window, window.document.querySelector(".kidia-category-image-clear"));
  assert.match(window.document.querySelector(".kidia-category-image img").src, /default-1\.jpg$/, "Clear must restore the WooCommerce image.");

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
  const markup = `<!doctype html><html><body>
    <div class="kidia-page-builder" data-page="catalog">
      <div id="kidia-page-live-preview"></div>
      <form><section class="kidia-page-card kidia-page-card--locked" data-element="header">
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
  console.log("Page Builders: fixed chrome, page elements, preview and sorting passed.");
}

function runChromeComposerTest() {
  const layout = JSON.stringify({ rows: [{ columns: [{width:25,align:"left",items:["logo"]},{width:50,align:"center",items:[]},{width:25,align:"right",items:["cart"]}] }, { columns: [{width:100,align:"center",items:["search_bar"]}] }] });
  const markup = `<!doctype html><html><body><section class="kidia-fixed-chrome-card" data-element="header"><input type="checkbox" name="layout[header][enabled]" checked><div class="kidia-chrome-composer" data-part="header" data-page="home"><input class="kidia-chrome-layout-json" name="layout[header][settings][layout_json]" value='${layout}'><div class="kidia-chrome-layout"></div><div class="kidia-chrome-palette"><div class="kidia-chrome-palette__items"><button class="kidia-chrome-item" data-item="logo">Logo</button><button class="kidia-chrome-item" data-item="cart">Cart</button><button class="kidia-chrome-item" data-item="search_bar">Search bar</button><button class="kidia-chrome-item" data-item="support">Support</button></div></div><button class="kidia-chrome-reset"></button></div><section data-item-section="logo"></section><section data-item-section="cart"><div class="kidia-chrome-icon-choice"><button class="kidia-chrome-icon-option" data-icon-value="bag">Bag</button><button class="kidia-chrome-icon-option is-selected" data-icon-value="basket">Basket</button><select class="kidia-chrome-icon-select" name="layout[header][settings][cart_icon_variant]"><option value="bag">Bag</option><option value="basket" selected>Basket</option></select></div></section><section data-item-section="search_bar"></section><section class="kidia-chrome-footer-icon-row" data-item-section="support"><button class="kidia-chrome-icon-option" data-icon-value="chat">Chat</button><button class="kidia-chrome-icon-option is-selected" data-icon-value="headset">Headset</button><select class="kidia-chrome-icon-select" name="layout[header][settings][support_icon_variant]"><option value="chat">Chat</option><option value="headset" selected>Headset</option></select></section><input name="layout[header][settings][subtitle]" value="Kids"><input name="layout[header][settings][height]" value="112"><input name="layout[header][settings][background_color]" value="#FFFFFF"><input name="layout[header][settings][icon_color]" value="#1F2933"><input name="layout[header][settings][icon_size]" value="24"><select name="layout[header][settings][cart_style]"><option value="circle" selected>Circle</option></select><input name="layout[header][settings][cart_color]" value="#123456"><input name="layout[header][settings][cart_background]" value="#FFFFFF"><input name="layout[header][settings][cart_radius]" value="12"><input name="layout[header][settings][icon_gap]" value="6"><input name="layout[header][settings][row_gap]" value="4"><input name="layout[header][settings][vertical_padding]" value="0"><input name="layout[header][settings][horizontal_padding]" value="16"><input name="layout[header][settings][search_width_percent]" value="100"><input name="layout[header][settings][search_height]" value="40"><input name="layout[header][settings][search_radius]" value="14"><input name="layout[header][settings][search_background]" value="#F1F3F4"><input name="layout[header][settings][search_placeholder]" value="Search products"></section></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only", url: "https://example.com/wp-admin/admin.php" });
  const { window } = dom;
  window.eval(readAsset("chrome-layout.js"));
  window.document.dispatchEvent(new window.Event("DOMContentLoaded"));
  const card = window.document.querySelector(".kidia-fixed-chrome-card");
  card.insertAdjacentHTML("beforeend", '<input name="layout[header][settings][margin_top]" value="7"><input name="layout[header][settings][margin_bottom]" value="9">');
  const preview = window.KidiaChromePreview.renderHeader(card, "Home");
  assert.match(preview, /kidia-app-icon--cart-basket/, "The selected cart design must render immediately in preview.");
	assert.match(preview, /is-circle[^>]+border:1px solid #123456/, "Header icon style must visibly affect the live preview.");
	assert.match(preview, /kidia-app-header-brand[\s\S]*Kids/, "The subtitle must render with the logo instead of occupying a separate row item.");
	window.document.querySelector('[data-icon-value="bag"]').dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
	assert.match(window.KidiaChromePreview.renderHeader(card, "Home"), /kidia-app-icon--cart-bag/, "Icon image buttons outside the composer must update the preview immediately.");
	window.document.querySelector('[data-item-section="support"] [data-icon-value="chat"]').dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
	assert.equal(window.document.querySelector('[name$="[support_icon_variant]"]').value, "chat", "Icon choices inside the combined footer-style section must remain clickable.");
  assert.match(preview, /grid-template-columns:minmax\(0,100fr\)/, "A one-column row must span the header without overflowing when row gaps are present.");
  assert.match(preview, /width:100%/, "Search width must be applied instantly as a percentage.");
	assert.match(preview, /--row-gap:4px/, "The real gap between header rows must be reflected without browser-only scaling.");
	assert.match(preview, /padding:0px 16px!important/, "Zero vertical padding must be reflected immediately instead of falling back to the default.");
	assert.match(preview, /margin:7px 0 9px/, "Header space above and below must update the preview.");
	const searchWidth = card.querySelector('[name$="[search_width_percent]"]');
	searchWidth.value = "150";
	assert.match(window.KidiaChromePreview.renderHeader(card, "Home"), /width:100%/, "Search width must clamp to the full available row instead of silently overflowing.");
  assert.equal(window.document.querySelectorAll(".kidia-chrome-row").length, 2, "Home header must support two draggable rows.");
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
  const markup = `<!doctype html><html><body><form><section class="kidia-fixed-chrome-card">
    <input type="checkbox" name="layout[header][enabled]" value="1" checked>
    <input type="hidden" name="layout[header][settings][collapse_on_scroll]" value="0">
    <input type="checkbox" class="kidia-collapsed-header-enabled" name="layout[header][settings][collapse_on_scroll]" value="1">
    <input name="layout[header][settings][layout_json]" value='${regular}'>
    <input name="layout[header][settings][compact_layout_json]" value='${collapsed}'>
    <input name="layout[header][settings][title]" value="Products">
    <input name="layout[header][settings][height]" value="64">
    <input name="layout[header][settings][compact_height]" value="56">
    <input name="layout[header][settings][background_color]" value="#FFFFFF">
    <input name="layout[header][settings][compact_background_color]" value="#F4F5F5">
    <select name="layout[header][settings][collapse_transition]"><option value="fade_slide" selected>Fade + slide</option></select>
    <select name="layout[header][settings][collapse_speed]"><option value="slow" selected>Slow</option></select>
  </section></form></body></html>`;
  const dom = new JSDOM(markup, { runScripts: "outside-only" });
  const { window } = dom;
  window.eval(readAsset("chrome-layout.js"));
  const card = window.document.querySelector(".kidia-fixed-chrome-card");
  const toggle = card.querySelector(".kidia-collapsed-header-enabled");

  assert.doesNotMatch(window.KidiaChromePreview.renderHeader(card, "Products"), /is-collapsed/, "Off must preview the regular header.");
  toggle.checked = true;
	  assert.doesNotMatch(window.KidiaChromePreview.renderHeader(card, "Products"), /is-collapsed/, "On must still show the real regular header while the preview is at the top.");
	  const collapsedPreview = window.KidiaChromePreview.renderHeader(card, "Products", { collapsed: true });
	  assert.match(collapsedPreview, /is-collapsed/, "Scrolling the preview must show the collapsed header.");
  assert.match(collapsedPreview, /height:56px/, "The sticky preset must expand enough to keep its search field inside the compact header.");
  assert.match(collapsedPreview, /kidia-app-header-item--cart/, "The saved compact layout must drive the collapsed preview.");
  assert.match(collapsedPreview, /is-transition-fade_slide/, "The selected collapsed transition must drive the preview.");
  assert.match(collapsedPreview, /--collapse-duration:420ms/, "The selected transition speed must drive the preview.");
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
  const preview = window.KidiaChromePreview.renderFooter(footerCard);
  assert.match(preview, /padding:0 5%/, "Footer outside spacing must use the saved percentage on both sides.");
  assert.match(preview, /kidia-app-icon--home-filled/, "Footer icon design must match the selected visual option.");
	  assert.match(preview, />الرئيسية</, "Footer labels must match the Arabic Flutter footer.");
	assert.match(preview, /border-top:3px solid #ABCDEF/, "Footer border controls must update preview instantly.");
	assert.match(preview, /border-radius:12px/, "Footer corner radius must update preview without browser-only scaling.");
	assert.match(preview, /0 4px 12px/, "Footer shadow must update preview instantly.");
	assert.match(preview, /kidia-app-footer-item--wishlist is-filled/, "Footer icon style must be applied to the preview.");
	assert.doesNotMatch(preview, /kidia-app-footer-item--share/, "The preview must omit footer items that Flutter does not support on navigation pages.");
	assert.doesNotMatch(preview, /--item-icon-size:30px/, "Per-icon sizes must no longer move one footer icon out of alignment.");
	assert.match(preview, /--item-icon-size:26px/, "Every footer icon must use the same shared size.");
	assert.match(preview, /margin:6px 0 8px/, "Footer space above and below must update the preview.");
	  console.log("Footer preview: equal items, side spacing, labels and icon designs passed.");
}

function runUnsavedChangesDialogTest() {
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

if (require.main === module) {
  runHomeBuilderTest();
  runCategoryBuilderTest();
  runPageBuilderTest();
  runChromeComposerTest();
  runCollapsedHeaderToggleTest();
	  runFooterPreviewControlsTest();
	  runUnsavedChangesDialogTest();
	  runCommercePreviewTest();
  console.log("Builder browser contract tests: ok");
}

module.exports = { homeMarkup, categoryRow };
