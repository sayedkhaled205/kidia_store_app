"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { JSDOM } = require("jsdom");

const assets = path.resolve(__dirname, "..", "admin", "assets");

function runBridge(asset, body) {
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

test("generic Flutter preview sends state immediately when cached iframe load was missed", () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="kidia-page-builder" data-page="catalog">
      <form class="kidia-page-editor"><input name="layout[header][enabled]" value="1"></form>
      <div id="kidia-page-elements"><div class="kidia-page-card" data-element="product_grid"></div></div>
    </div>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.page, "catalog");
  assert.equal(messages[0].message.layout.header.enabled, "1");
  assert.equal(messages[0].message.layout.elements[0].id, "product_grid");
  assert.equal(messages[0].origin, "https://store.example");
  assert.equal(messages.frame.hidden, true, "Flutter stays hidden until it reports that the UI is ready");
  assert.equal(messages.frame.nextElementSibling.hidden, false, "The local preview is visible during Flutter startup");
  markFlutterReady(messages);
  assert.equal(messages.frame.hidden, false);
  assert.equal(messages.frame.nextElementSibling.hidden, true);
});

test("Category Flutter preview sends current fields immediately", () => {
  const messages = runBridge("flutter-category-preview-bridge.js", `
    <div class="kidia-category-builder"><form>
      <input name="category_general[grid_columns]" type="number" value="3">
      <input name="category_general[show_arrow]" type="checkbox" checked>
    </form></div>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.category.grid_columns, 3);
  assert.equal(messages[0].message.category.show_arrow, true);
});

test("Home Flutter preview sends an initial frame without waiting for iframe load", () => {
  const messages = runBridge("flutter-home-preview-bridge.js", `
    <div class="kidia-builder-wrap"></div>
    <form id="kidia-home-builder-form"><input name="layout[header][enabled]" value="1"></form>
    <div><iframe id="kidia-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="kidia-legacy-preview-fallback" hidden></div></div>`);
  assert.equal(messages.length, 1);
  assert.equal(messages[0].message.page, "home");
  assert.equal(messages[0].message.layout.header.enabled, "1");
  assert.deepEqual(messages[0].message.home.blocks, []);
});

test("every Flutter iframe and bundle URL is tied to the plugin version", () => {
  for (const file of ["home-builder.php", "category-builder.php", "page-builder.php"]) {
    const source = fs.readFileSync(path.resolve(__dirname, "..", "admin", "pages", file), "utf8");
    assert.match(source, /'v'\s*=>\s*KIDIA_MOBILE_CMS_VERSION/);
  }
  const index = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "index.html"), "utf8");
  const sourceIndex = fs.readFileSync(path.resolve(__dirname, "..", "..", "web", "index.html"), "utf8");
  const bootstrap = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "flutter_bootstrap.js"), "utf8");
  assert.match(index, /flutter_bootstrap\.js.*encodeURIComponent\(version\)/s);
  assert.match(sourceIndex, /flutter_bootstrap\.js.*encodeURIComponent\(version\)/s);
  assert.match(bootstrap, /mainJsPath.*encodeURIComponent\(window\.__kidiaPreviewVersion\)/s);
});

test("Flutter web shell repeats readiness only after its rendered view mounts", async () => {
  const index = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "index.html"), "utf8");
  const script = index.match(/<script>([\s\S]*startKidiaPreview[\s\S]*?)<\/script>/)?.[1];
  assert.ok(script);
  const dom = new JSDOM("<!doctype html><body></body>", {
    runScripts: "outside-only",
    url: "https://store.example/preview/index.html?page=home&v=1.30.63",
  });
  const { window } = dom;
  const messages = [];
  window.requestAnimationFrame = (callback) => { callback(); return 1; };
  window.postMessage = (message) => messages.push(JSON.parse(message));
  window.eval(script);
  assert.equal(messages.length, 0, "Readiness cannot be announced before Flutter mounts");
  window.document.body.appendChild(window.document.createElement("flutter-view"));
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(messages.at(-1)?.type, "kidia-flutter-preview-ready");
  const firstReadyCount = messages.length;
  window.dispatchEvent(new window.MessageEvent("message", {
    data: JSON.stringify({ type: "kidia-preview-layout", page: "home", layout: {} }),
  }));
  assert.equal(messages.length, firstReadyCount + 1, "A parent retry receives a fresh rendered acknowledgement");
  assert.equal(messages.at(-1)?.type, "kidia-flutter-preview-ready");
});
