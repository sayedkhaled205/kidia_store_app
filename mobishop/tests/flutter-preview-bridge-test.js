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
  const frame = window.document.getElementById("mobishop-flutter-preview");
  const messages = [];
  frame.contentWindow.postMessage = (message, origin) => messages.push({ message: JSON.parse(message), origin });
  window.setTimeout = () => 1;
  window.requestAnimationFrame = (callback) => { callback(); return 1; };
  window.mobishopFlutterPreview = { layoutPreviewEndpoint: "/layout-preview", categoryPreviewEndpoint: "/category-preview", restNonce: "nonce" };
  window.mobishopHomeBuilder = { layoutPreviewEndpoint: "/layout-preview", livePreviewEndpoint: "/home-preview", restNonce: "nonce" };
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
    data: JSON.stringify({ type: "mobishop-flutter-preview-ready" }),
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

const readinessBridges = [
  {
    name: "generic",
    asset: "flutter-preview-bridge.js",
    editor: '<div class="mobishop-page-builder" data-page="catalog"><form class="mobishop-page-editor"><input name="layout[header][enabled]" value="1"></form></div>',
    requestsPerRefresh: 1,
    page: "catalog",
  },
  {
    name: "Category",
    asset: "flutter-category-preview-bridge.js",
    editor: '<div class="mobishop-category-builder"><form><input name="category_general[grid_columns]" value="3"></form></div>',
    requestsPerRefresh: 2,
    page: "category",
  },
];

function readinessFixture(bridge, setup) {
  return runBridge(bridge.asset, bridge.editor + '<div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>', setup);
}

function writePreviewDocument(frame, rendered = true, surface = "flutter-view") {
  frame.contentDocument.open();
  frame.contentDocument.write(rendered ? `<body><${surface}></${surface}></body>` : "<body></body>");
  frame.contentDocument.close();
}

function reloadPreview(result, rendered = true) {
  const oldDocument = result.frame.contentDocument;
  result.frame.src = "https://store.example/preview/reloaded.html";
  writePreviewDocument(result.frame, rendered);
  assert.notEqual(result.frame.contentDocument, oldDocument);
  result.frame.contentWindow.postMessage = (message, origin) => result.push({ message: JSON.parse(message), origin });
}

for (const bridge of readinessBridges) {
  test(`${bridge.name} recovers a cached rendered iframe whose ready message was missed`, async (t) => {
    let requests = 0;
    const messages = readinessFixture(bridge, (window) => {
      const frame = window.document.getElementById("mobishop-flutter-preview");
      writePreviewDocument(frame, true, bridge.page === "category" ? "flt-glass-pane" : "flutter-view");
      markFlutterReady({ window, frame });
      const fetch = window.fetch;
      window.fetch = (...args) => { requests++; return fetch(...args); };
    });
    t.after(() => messages.window.close());
    await settle();
    assert.equal(requests, bridge.requestsPerRefresh);
    assert.equal(messages.length, 1);
    assert.equal(messages[0].message.page, bridge.page);
    assert.equal(messages[0].origin, "https://store.example");
    assert.equal(messages.frame.getAttribute("aria-busy"), null);
    const input = messages.window.document.querySelector("input");
    input.value = "4";
    input.dispatchEvent(new messages.window.Event("input", { bubbles: true }));
    await settle();
    assert.equal(messages.length, 2);
    assert.equal(bridge.page === "category" ? messages[1].message.category.grid_columns : messages[1].message.layout.header.enabled, "4");
  });

  test(`${bridge.name} starts once for repeated readiness and a late same-document load`, async (t) => {
    let requests = 0;
    const messages = readinessFixture(bridge, (window) => {
      const fetch = window.fetch;
      window.fetch = (...args) => { requests++; return fetch(...args); };
    });
    t.after(() => messages.window.close());
    await settle();
    assert.equal(requests, 0, "A cold iframe still waits for Flutter.");
    markFlutterReady(messages);
    markFlutterReady(messages);
    messages.frame.dispatchEvent(new messages.window.Event("load"));
    await settle();
    assert.equal(requests, bridge.requestsPerRefresh);
    assert.equal(messages.length, 1);
    markFlutterReady(messages);
    await settle();
    assert.equal(requests, bridge.requestsPerRefresh);
  });

  test(`${bridge.name} refreshes a new document once when ready precedes load`, async (t) => {
    let requests = 0;
    const messages = readinessFixture(bridge, (window) => {
      const fetch = window.fetch;
      window.fetch = (...args) => { requests++; return fetch(...args); };
    });
    t.after(() => messages.window.close());
    markFlutterReady(messages);
    await settle();
    reloadPreview(messages);
    markFlutterReady(messages);
    messages.frame.dispatchEvent(new messages.window.Event("load"));
    await settle();
    assert.equal(requests, bridge.requestsPerRefresh * 2);
    assert.equal(messages.length, 2);
    markFlutterReady(messages);
    await settle();
    assert.equal(requests, bridge.requestsPerRefresh * 2);
  });

  test(`${bridge.name} discards an old document response even if fetch ignores abort`, async (t) => {
    const pending = [];
    const messages = readinessFixture(bridge, (window) => {
      window.fetch = (url, options) => new Promise((resolve) => {
        const request = JSON.parse(options.body);
        pending.push({
          signal: options.signal,
          resolve: () => resolve({ ok: true, json: async () => String(url).includes("category-preview") ? request.general : request.layout }),
        });
      });
    });
    t.after(() => messages.window.close());
    markFlutterReady(messages);
    assert.equal(pending.length, bridge.requestsPerRefresh);
    const oldRequests = pending.slice();
    reloadPreview(messages, false);
    messages.frame.dispatchEvent(new messages.window.Event("load"));
    await settle();
    assert.ok(oldRequests.every((request) => request.signal.aborted));
    for (const request of oldRequests) request.resolve();
    await settle();
    assert.equal(messages.length, 0);
    messages.window.document.querySelector("input").value = "4";
    markFlutterReady(messages);
    assert.equal(pending.length, bridge.requestsPerRefresh * 2);
    for (const request of pending.slice(bridge.requestsPerRefresh)) request.resolve();
    await settle();
    assert.equal(messages.length, 1);
    assert.equal(bridge.page === "category" ? messages[0].message.category.grid_columns : messages[0].message.layout.header.enabled, "4");
  });

  test(`${bridge.name} retains validated ready messages when iframe DOM is unavailable`, async (t) => {
    const messages = readinessFixture(bridge, (window) => {
      Object.defineProperty(window.document.getElementById("mobishop-flutter-preview"), "contentDocument", {
        get() { throw new window.DOMException("Blocked cross-origin access", "SecurityError"); },
      });
    });
    t.after(() => messages.window.close());
    for (const invalid of [{ origin: "https://other.example", source: messages.frame.contentWindow }, { origin: "https://store.example", source: messages.window }]) {
      messages.window.dispatchEvent(new messages.window.MessageEvent("message", {
        data: JSON.stringify({ type: "mobishop-flutter-preview-ready" }), ...invalid,
      }));
    }
    await settle();
    assert.equal(messages.length, 0);
    markFlutterReady(messages);
    await settle();
    assert.equal(messages.length, 1);
    messages.frame.dispatchEvent(new messages.window.Event("load"));
    markFlutterReady(messages);
    await settle();
    assert.equal(messages.length, 2, "Without DOM access, preserve the existing validated message flow.");
  });
}

test("generic Flutter preview sends canonical state as soon as Flutter is ready", async () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="mobishop-page-builder" data-page="catalog">
      <form class="mobishop-page-editor"><input name="layout[header][enabled]" value="1"></form>
      <div id="mobishop-page-elements"><div class="mobishop-page-card" data-element="product_grid"></div></div>
    </div>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`);
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
    <div class="mobishop-page-builder" data-page="wishlist">
      <form class="mobishop-page-editor">
        <input type="hidden" name="layout[footer][enabled]" value="0">
        <input type="checkbox" name="layout[footer][enabled]" value="1">
        <input type="hidden" name="layout[footer][settings][show_labels]" value="0">
        <input type="checkbox" name="layout[footer][settings][show_labels]" value="1" checked>
      </form>
      <div id="mobishop-page-elements"></div>
    </div>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`);
  markFlutterReady(messages);
  await settle();
  assert.equal(messages[0].message.layout.footer.enabled, "0");
  assert.equal(messages[0].message.layout.footer.settings.show_labels, "1");
});

test("generic Flutter preview sends the currently selected Wishlist access mode", async () => {
  const messages = runBridge("flutter-preview-bridge.js", `
    <div class="mobishop-page-builder" data-page="wishlist">
      <form class="mobishop-page-editor">
        <input type="radio" name="layout[settings][wishlist_access_mode]" value="guest">
        <input type="radio" name="layout[settings][wishlist_access_mode]" value="sign_in_required" checked>
      </form>
      <div id="mobishop-page-elements"></div>
    </div>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`);
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
    <div class="mobishop-category-builder"><form>
      <input name="category_general[grid_columns]" type="number" value="3">
      <input name="category_general[show_arrow]" type="checkbox" checked>
    </form></div>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`);
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
    <div class="mobishop-builder-wrap"></div>
    <form id="mobishop-home-builder-form"><input name="layout[header][enabled]" value="1"></form>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`, (window) => {
      window.mobishopHomePreviewBlocks = [{ id: "hero", type: "hero_slider", enabled: true, settings: {} }];
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
    <div class="mobishop-builder-wrap"></div>
    <form id="mobishop-home-builder-form"></form>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`);
  markFlutterReady(messages);
  await settle();
  messages.window.document.dispatchEvent(new messages.window.CustomEvent("mobishop:home-preview-focus", {
    detail: { target: "featured-products" },
  }));
  assert.deepEqual(messages.at(-1).message, {
    type: "mobishop-preview-focus",
    page: "home",
    target: "featured-products",
  });
  assert.equal(messages.at(-1).origin, "https://store.example");
});

test("Persistent Flutter shell leaves wheel handling to the current page", () => {
  const sourceIndex = fs.readFileSync(
    path.resolve(__dirname, "..", "..", "web", "index.html"),
    "utf8",
  );
  assert.doesNotMatch(
    sourceIndex,
    /document\.addEventListener\('wheel'/,
  );
});

test("Home iframe wheel is relayed before CanvasKit can consume it", () => {
  const messages = runBridge("flutter-home-preview-bridge.js", `
    <div class="mobishop-builder-wrap"></div>
    <form id="mobishop-home-builder-form"></form>
    <div><iframe id="mobishop-flutter-preview" src="https://store.example/preview/index.html"></iframe><div class="mobishop-legacy-preview-fallback" hidden></div></div>`);
  messages.frame.contentWindow.dispatchEvent(new messages.window.WheelEvent("wheel", {
    deltaY: 96,
    cancelable: true,
  }));
  assert.deepEqual(messages.at(-1).message, {
    type: "mobishop-preview-scroll",
    page: "home",
    deltaY: 96,
  });
});

test("Non-Home iframe keeps native wheel scrolling", () => {
  const bridge = fs.readFileSync(path.join(assets, "flutter-preview-bridge.js"), "utf8");
  assert.doesNotMatch(bridge, /relayPreviewWheel|bindPreviewWheel/);
  assert.doesNotMatch(bridge, /mobishop-preview-scroll[\s\S]*preventDefault/);
});

test("Builder workspace fixes navigation, toolbar, and phone while only cards scroll", () => {
  const bridge = fs.readFileSync(path.join(assets, "flutter-home-preview-bridge.js"), "utf8");
  const sharedStyles = fs.readFileSync(path.join(assets, "admin-theme.css"), "utf8");
  const shellStyles = fs.readFileSync(path.join(assets, "cms-shell.css"), "utf8");
  const homeTemplate = fs.readFileSync(path.resolve(__dirname, "..", "admin", "pages", "home-builder.php"), "utf8");
  assert.match(homeTemplate, /data-mobishop-builder-cards-scroll/);
  assert.doesNotMatch(homeTemplate, /<p[^>]*>[\s\S]{0,160}Live preview —/);
  assert.match(bridge, /data-mobishop-builder-cards-scroll[\s\S]*\(cards \|\| window\)\.scrollBy[\s\S]*preventDefault/);
  assert.match(bridge, /mobishop-preview-scroll[\s\S]*contentWindow\.addEventListener\("wheel",\s*relayPreviewWheel/);
  assert.match(sharedStyles, /\.mobishop-builder-cards-scroll\s*\{[\s\S]*overflow-y:\s*auto[\s\S]*scrollbar-gutter:\s*stable/);
  assert.match(sharedStyles, /:is\(\.mobishop-preview,\.mobishop-page-preview,\.mobishop-category-mobile-preview\)[\s\S]*position:\s*relative !important/);
  assert.match(shellStyles, /body\.mobishop-cms-builder-screen #wpcontent\{[^}]*overflow:hidden!important/);
  assert.match(shellStyles, /body\.mobishop-cms-builder-screen #wpbody\{[^}]*overflow-y:scroll!important[^}]*scrollbar-gutter:stable/);
  assert.match(shellStyles, /body\.mobishop-cms-builder-screen #wpbody-content\{[^}]*overflow:visible!important/);
});

test("every Flutter iframe and bundle URL is tied to the plugin version", () => {
  for (const file of ["home-builder.php", "category-builder.php", "page-builder.php"]) {
    const source = fs.readFileSync(path.resolve(__dirname, "..", "admin", "pages", file), "utf8");
    assert.match(source, /'v'\s*=>\s*MOBISHOP_VERSION/);
  }
  const index = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "index.html"), "utf8");
  const sourceIndex = fs.readFileSync(path.resolve(__dirname, "..", "..", "web", "index.html"), "utf8");
  const bootstrap = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "flutter_bootstrap.js"), "utf8");
  assert.match(index, /flutter_bootstrap\.js.*encodeURIComponent\(cacheKey\)/s);
  assert.match(sourceIndex, /flutter_bootstrap\.js.*encodeURIComponent\(cacheKey\)/s);
  assert.match(bootstrap, /mainJsPath.*encodeURIComponent\(window\.__mobishopPreviewVersion\)/s);
  assert.match(bootstrap, /canvaskit\.js.*encodeURIComponent\(window\.__mobishopPreviewVersion\)/s);
  assert.match(bootstrap, /canvaskit\.wasm.*encodeURIComponent\(window\.__mobishopPreviewVersion\)/s);
  for (const bridge of ["flutter-preview-bridge.js", "flutter-category-preview-bridge.js", "flutter-home-preview-bridge.js"]) {
    const source = fs.readFileSync(path.join(assets, bridge), "utf8");
    assert.doesNotMatch(source, /frame\.hidden\s*=\s*true/, `${bridge} must not replace Flutter with an HTML replica while loading.`);
    assert.doesNotMatch(source, /fallback\.hidden\s*=\s*false/, `${bridge} must keep the approximate HTML replica hidden.`);
    assert.match(source, /frame\.setAttribute\("tabindex",\s*"0"\)/, `${bridge} must make the exact mobile preview focusable.`);
    assert.match(source, /frame\.addEventListener\("pointerenter",\s*focusPreview\)/, `${bridge} must hand mouse-wheel control to the mobile preview on hover.`);
  }
});

test("Flutter web shell announces readiness once after its rendered view mounts", async () => {
  const index = fs.readFileSync(path.resolve(__dirname, "..", "admin", "flutter-preview", "index.html"), "utf8");
  const script = index.match(/<script>([\s\S]*startMobiShopPreview[\s\S]*?)<\/script>/)?.[1];
  assert.ok(script);
  const dom = new JSDOM('<!doctype html><body><div id="mobishop-flutter-loading">Loading exact Flutter preview…</div></body>', {
    runScripts: "outside-only",
    url: "https://store.example/preview/index.html?page=home&v=1.30.63",
  });
  const { window } = dom;
  const messages = [];
  window.requestAnimationFrame = (callback) => { callback(); return 1; };
  window.postMessage = (message) => messages.push(JSON.parse(message));
  window.eval(script);
  assert.equal(messages.length, 0, "Readiness cannot be announced before Flutter mounts");
  assert.ok(window.document.getElementById("mobishop-flutter-loading"), "The exact preview displays an honest loading state.");
  window.document.body.appendChild(window.document.createElement("flutter-view"));
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(window.document.getElementById("mobishop-flutter-loading"), null, "The loading state disappears only after Flutter mounts.");
  assert.equal(messages.at(-1)?.type, "mobishop-flutter-preview-ready");
  window.dispatchEvent(new window.MessageEvent("message", {
    data: JSON.stringify({ type: "mobishop-preview-layout", page: "home", layout: {} }),
  }));
  assert.equal(messages.length, 1, "Layout updates must not create a ready/layout feedback loop.");
});
