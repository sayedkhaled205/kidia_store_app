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
    homeBlock("category_grid", 2, `${input("title", "Categories")}${input("columns", "4")}${input("limit", "4")}<input type="checkbox" name="blocks[0][settings][show_names]" value="1" checked>`),
    homeBlock("image_banner", 3, `${mediaField("image_url", "https://example.com/banner.jpg", "kidia-banner-image-url", "kidia-select-banner-image", "kidia-banner-image-preview")}${input("aspect_ratio", "2.4")}${input("border_radius", "18")}<div class="kidia-builder-field"><select name="blocks[0][settings][action_type]"><option value="product" selected>Product</option><option value="category">Category</option></select></div><div class="kidia-builder-field">${input("action_value", "12")}</div>`),
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

function categorySettings(id) {
  const field = (name, value, type = "text") => `<input type="${type}" name="categories[${id}][${name}]" value="${value}">`;
  return `<div class="kidia-category-settings" hidden>
    <button type="button" class="kidia-category-image-button">Choose image</button>
    <button type="button" class="kidia-category-image-clear" hidden>Clear</button>
    ${field("image_size", 68, "range")}${field("image_radius", 18, "range")}${field("image_scale", 100, "range")}
    ${field("border_width", 0, "number")}${field("border_color", "#DDE5E2", "color")}${field("background_color", "#FFFFFF", "color")}
    ${field("image_text_gap", 10, "range")}${field("font_size", 16, "range")}${field("font_color", "#1F2933", "color")}${field("line_height", 125, "range")}
    <select name="categories[${id}][image_shape]"><option value="rounded" selected>Rounded</option><option value="circle">Circle</option></select>
    <select name="categories[${id}][image_fit]"><option value="contain" selected>Contain</option></select>
    <select name="categories[${id}][image_effect]"><option value="none" selected>None</option></select>
    <select name="categories[${id}][image_position]"><option value="center" selected>Center</option></select>
    <select name="categories[${id}][font_weight]"><option value="800" selected>800</option></select>
    <select name="categories[${id}][text_align]"><option value="start" selected>Start</option></select>
    <select name="categories[${id}][text_max_lines]"><option value="2" selected>2</option></select>
  </div>`;
}

function categoryRow(id, name, hasChildren = false) {
  const child = hasChildren ? `<div class="kidia-category-children" hidden><ul class="kidia-category-list">${categoryRow(id + 10, `${name} Child`)}</ul></div>` : "";
  return `<li class="kidia-category-row" data-term-id="${id}" data-term-name="${name}" data-default-image="https://example.com/default-${id}.jpg">
    <div class="kidia-category-card">
      <span class="kidia-category-handle"></span>
      ${hasChildren ? '<button type="button" class="kidia-category-expand" aria-expanded="false">Expand</button>' : ""}
      <div class="kidia-category-image"><img src="https://example.com/category-${id}.jpg" alt=""></div>
      <div class="kidia-category-name"><strong>${name}</strong></div>
      <input class="kidia-category-order" name="categories[${id}][order]" value="0">
      <input class="kidia-category-image-id" name="categories[${id}][image_id]" value="0">
      <button type="button" class="kidia-category-settings-toggle" aria-expanded="false">Settings</button>
      <label class="kidia-category-visibility"><input type="checkbox" name="categories[${id}][hidden]" value="1"></label>
      ${categorySettings(id)}
    </div>${child}
  </li>`;
}

function runCategoryBuilderTest() {
  const markup = `<!doctype html><html><body><div class="kidia-category-builder">
    <div id="kidia-category-live-preview"></div>
    <div class="kidia-category-editor"><form><ul class="kidia-category-list">${categoryRow(1, "Clothes", true)}${categoryRow(2, "Toys")}</ul></form></div>
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

  const size = window.document.querySelector('[name="categories[1][image_size]"]');
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

  const settingsButton = window.document.querySelector(".kidia-category-settings-toggle");
  click(window, settingsButton);
  assert.equal(settingsButton.closest(".kidia-category-card").querySelector(".kidia-category-settings").hidden, false, "Image settings must open.");

  click(window, window.document.querySelector(".kidia-category-image-button"));
  assert.match(window.document.querySelector(".kidia-category-image img").src, /custom-thumb\.jpg$/, "Choosing media must update the editor image.");
  assert.match(window.document.querySelector(".kidia-category-preview-image img").src, /custom-thumb\.jpg$/, "Choosing media must update the phone preview.");
  click(window, window.document.querySelector(".kidia-category-image-clear"));
  assert.match(window.document.querySelector(".kidia-category-image img").src, /default-1\.jpg$/, "Clear must restore the WooCommerce image.");

  const hidden = window.document.querySelector('[name="categories[2][hidden]"]');
  hidden.checked = true;
  hidden.dispatchEvent(new window.Event("change", { bubbles: true }));
  assert.equal(window.document.querySelectorAll(".kidia-category-preview-branch").length, 1, "Hide in app must remove the branch from preview.");

  const rootList = window.document.querySelector(".kidia-category-editor form > .kidia-category-list");
  const rows = rootList.children;
  rootList.insertBefore(rows[1], rows[0]);
  rootList.kidiaSortableOptions.update.call(rootList);
  assert.equal(rootList.firstElementChild.querySelector(".kidia-category-order").value, "0", "Sorting must recalculate sibling order.");
  assert.equal(rootList.lastElementChild.querySelector(".kidia-category-order").value, "1", "Sorting must keep the next sibling order.");

  console.log("Category Builder: preview, expansion, media, visibility, settings and sorting passed.");
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
  assert.equal(window.document.querySelectorAll(".kidia-page-preview-grid i").length, 4, "Grid controls must update the mobile preview.");
  const list = window.document.getElementById("kidia-page-elements");
  list.insertBefore(list.lastElementChild, list.firstElementChild);
  list.kidiaSortableOptions.update();
  assert.equal(list.firstElementChild.querySelector('input[name$="[id]"]').name, "layout[elements][0][id]", "Reordering must keep submitted indexes valid.");
  assert.equal(window.document.querySelectorAll(".kidia-page-card--locked .kidia-page-drag").length, 0, "Fixed header/footer cards must never expose drag handles.");
  console.log("Page Builders: fixed chrome, page elements, preview and sorting passed.");
}

if (require.main === module) {
  runHomeBuilderTest();
  runCategoryBuilderTest();
  runPageBuilderTest();
  console.log("Builder browser contract tests: ok");
}

module.exports = { homeMarkup, categoryRow };
