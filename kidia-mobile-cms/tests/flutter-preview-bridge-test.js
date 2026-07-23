"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { JSDOM } = require("jsdom");

const assets = path.resolve(__dirname, "..", "admin", "assets");

function runBridge(asset, body, setup) {
  const dom = new JSDOM(`<!doctype html><body>${body}</body>`, {
    runScripts: "outside-only",
    url: "https://store.example/wp-admin/admin.php",
  });
  const { window } = dom;
  const frame = window.document.getElementById("kidia-flutter-preview");
  const messages = [];
  frame.contentWindow.postMessage = (message, origin) => messages.push({ message: JSON.parse(message), origin });
  window.setTimeout = () => 1;
  window.requestAnimationFrame = (callback) => { callback(); return 1; };
  window.kidiaFlutterPreview = { layoutPreviewEndpoint: "/layout-preview", categoryPreviewEndpoint: "/category-preview", restNonce: "nonce" };
  window.kidiaHomeBuilder = { layoutPreviewEndpoint: "/layout-preview", livePreviewEndpoint: "/home-preview", restNonce: "nonce" };
  window.fetch = async (url, options) => {
    const request = JSON.parse(options.body);
    const payload = String(url).includes("category-preview") ? request.general
      : String(url).includes("home-preview") ? { blocks: request.blocks }
      : request.layout;
    return { ok: true, json: async () => payload };
  };
  if (setup) setup(window);
  window.eval(fs.readFileSync(path.join(assets, asset), "utf8"));
  Object.defineProperties(messages, {
    window: { value: window },
    frame: { value: frame },
  });
  return messages;
}

function markFlutterReady(result) {
  result.window.dispatchEvent(new result.window.MessageEvent("message", {
    data: JSON.stringify({ type: "kidia-flutter-preview-ready" }),
    origin: "https://store.example",
    source: result.frame.contentWindow,
  }));
}

async function settle() {
	await Promise.resolve();
	await Promise.resolve();
	await Promise.resolve();
	await new Promise((resolve) => setImmediate(resolve));
}

test("generic Flutter preview sends canonical state as soon as Flutter is ready", async () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="kidia-page-builder" data-page="catalog">
      <form class="kidia-page-editor"><input name="layout[header][enabled]" value="1"></form>
      <div id="kidia-page-elements"><div class="kidia-page-card" data-element="product_grid"></div></div>
    </div>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  assert.equal(messages.length, 0);
  assert.equal(messages.frame.hidden, false, "The exact Flutter surface stays visible while loading.");
  assert.equal(messages.frame.getAttribute("aria-busy"), "true");
  assert.equal(messages.frame.nextElementSibling.hidden, true, "The approximate HTML replica must stay hidden.");
  markFlutterReady(messages);
  await settle();
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.page, "catalog");
  assert.equal(messages[0].message.layout.header.enabled, "1");
  assert.equal(messages[0].origin, "https://store.example");
  assert.equal(messages.frame.hidden, false);
  assert.equal(messages.frame.nextElementSibling.hidden, true);
});

test("generic Flutter preview preserves the submitted Off value for WordPress checkbox pairs", async () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="kidia-page-builder" data-page="wishlist">
      <form class="kidia-page-editor">
        <input type="hidden" name="layout[footer][enabled]" value="0">
        <input type="checkbox" name="layout[footer][enabled]" value="1">
        <input type="hidden" name="layout[footer][settings][show_labels]" value="0">
        <input type="checkbox" name="layout[footer][settings][show_labels]" value="1" checked>
      </form>
      <div id="kidia-page-elements"></div>
    </div>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  markFlutterReady(messages);
  await settle();
  assert.equal(messages[0].message.layout.footer.enabled, "0");
  assert.equal(messages[0].message.layout.footer.settings.show_labels, "1");
});

test("generic Flutter preview sends the currently selected Wishlist access mode", async () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="kidia-page-builder" data-page="wishlist">
      <form class="kidia-page-editor">
        <input type="radio" name="layout[settings][wishlist_access_mode]" value="guest">
        <input type="radio" name="layout[settings][wishlist_access_mode]" value="sign_in_required" checked>
      </form>
      <div id="kidia-page-elements"></div>
    </div>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  markFlutterReady(messages);
  await settle();
  assert.equal(messages.at(-1).message.layout.settings.wishlist_access_mode, "sign_in_required");
  const guest = messages.window.document.querySelector('[value="guest"]');
  guest.checked = true;
  guest.dispatchEvent(new messages.window.Event("change", { bubbles: true }));
  await settle();
  assert.equal(messages.at(-1).message.layout.settings.wishlist_access_mode, "guest");
});

test("Category Flutter preview sends canonical current fields immediately", async () => {
  const messages = runBridge("flutter-category-preview-bridge.js", `
    <div class="kidia-category-builder"><form>
      <input name="category_general[grid_columns]" type="number" value="3">
      <input name="category_general[show_arrow]" type="checkbox" checked>
    </form></div>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  assert.equal(messages.frame.hidden, false);
  assert.equal(messages.frame.nextElementSibling.hidden, true);
  markFlutterReady(messages);
  await settle();
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.category.grid_columns, "3");
  assert.equal(messages[0].message.category.show_arrow, "on");
});

test("Home Flutter preview sends canonical layout and blocks on its initial frame", async () => {
  const messages = runBridge("flutter-home-preview-bridge.js", `
    <div class="kidia-builder-wrap"></div>
    <form id="kidia-home-builder-form"><input name="layout[header][enabled]" value="1"></form>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`, (window) => {
      window.kidiaHomePreviewBlocks = [{ id: "hero", type: "hero_slider", enabled: true, settings: {} }];
    });
  assert.equal(messages.frame.hidden, false);
  assert.equal(messages.frame.nextElementSibling.hidden, true);
  markFlutterReady(messages);
  await settle();
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.page, "home");
  assert.equal(messages[0].message.layout.header.enabled, "1");
  assert.deepEqual(messages[0].message.home.blocks, [
    { id: "hero", type: "hero_slider", enabled: true, settings: {} },
  ]);
  markFlutterReady(messages);
  await settle();
  assert.equal(messages.length, 1, "Repeated ready messages must not start a refresh loop.");
});

test("Home Flutter preview focuses the selected Builder element", async () => {
  const messages = runBridge("flutter-home-preview-bridge.js", `
    <div class="kidia-builder-wrap"></div>
    <form id="kidia-home-builder-form"></form>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  markFlutterReady(messages);
  await settle();
  messages.window.document.dispatchEvent(new messages.window.CustomEvent("kidia:home-preview-focus", {
    detail: { target: "featured-products" },
  }));
  assert.deepEqual(messages.at(-1).message, {
    type: "kidia-preview-focus",
    page: "home",
    target: "featured-products",
  });
  assert.equal(messages.at(-1).origin, "https://store.example");
});

test("every Flutter iframe and bundle URL is tied to the plugin version", () => {
  for (const file of ["home-builder.php", "category-builder.php", "page-builder.php"]) {
    const source = fs.readFileSync(path.resolve(__dirname, "..", "admin", "pages", file), "utf8");
    assert.match(source, /'v'\s*=>\s*KIDIA_MOBILE_CMS_VERSION/);
  }
  const index = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "index.html"), "utf8");
  const sourceIndex = fs.readFileSync(path.resolve(__dirname, "..", "..", "web", "index.html"), "utf8");
  const bootstrap = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "flutter_bootstrap.js"), "utf8");
  assert.match(index, /flutter_bootstrap\.js.*encodeURIComponent\(cacheKey\)/s);
  assert.match(sourceIndex, /flutter_bootstrap\.js.*encodeURIComponent\(cacheKey\)/s);
  assert.match(bootstrap, /mainJsPath.*encodeURIComponent\(window\.__kidiaPreviewVersion\)/s);
  assert.match(bootstrap, /canvaskit\.js.*encodeURIComponent\(window\.__kidiaPreviewVersion\)/s);
  assert.match(bootstrap, /canvaskit\.wasm.*encodeURIComponent\(window\.__kidiaPreviewVersion\)/s);
  for (const bridge of ["flutter-preview-bridge.js", "flutter-category-preview-bridge.js", "flutter-home-preview-bridge.js"]) {
    const source = fs.readFileSync(path.join(assets, bridge), "utf8");
    assert.doesNotMatch(source, /frame\.hidden\s*=\s*true/, `${bridge} must not replace Flutter with an HTML replica while loading.`);
    assert.doesNotMatch(source, /fallback\.hidden\s*=\s*false/, `${bridge} must keep the approximate HTML replica hidden.`);
  }
});

test("Flutter web shell announces readiness once after its rendered view mounts", async () => {
  const index = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "index.html"), "utf8");
  const script = index.match(/<script>([\s\S]*startKidiaPreview[\s\S]*?)<\/script>/)?.[1];
  assert.ok(script);
  const dom = new JSDOM('<!doctype html><body><div id="kidia-flutter-loading">Loading exact Flutter preview…</div></body>', {
    runScripts: "outside-only",
    url: "https://store.example/preview/index.html?page=home&v=1.30.63",
  });
  const { window } = dom;
  const messages = [];
  window.requestAnimationFrame = (callback) => { callback(); return 1; };
  window.postMessage = (message) => messages.push(JSON.parse(message));
  window.eval(script);
  assert.equal(messages.length, 0, "Readiness cannot be announced before Flutter mounts");
  assert.ok(window.document.getElementById("kidia-flutter-loading"), "The exact preview displays an honest loading state.");
  window.document.body.appendChild(window.document.createElement("flutter-view"));
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(window.document.getElementById("kidia-flutter-loading"), null, "The loading state disappears only after Flutter mounts.");
  assert.equal(messages.at(-1)?.type, "kidia-flutter-preview-ready");
  window.dispatchEvent(new window.MessageEvent("message", {
    data: JSON.stringify({ type: "kidia-preview-layout", page: "home", layout: {} }),
  }));
  assert.equal(messages.length, 1, "Layout updates must not create a ready/layout feedback loop.");
});
