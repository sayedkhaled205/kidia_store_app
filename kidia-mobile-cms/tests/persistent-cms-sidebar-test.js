"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.js"),
  "utf8"
);
const initial = `<!doctype html><html><head><title>Overview</title></head>
<body class="wp-admin kidia-mobile-cms">
  <main id="wpbody-content">
    <aside data-kidia-cms-sidebar>
      <nav class="kidia-cms-sidebar__nav">
        <a class="is-active" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms">Overview</a>
        <a href="https://store.test/wp-admin/admin.php?page=kidia-mobile-setup">Setup Wizard</a>
      </nav>
    </aside>
    <section data-page-content>Overview content</section>
  </main>
</body></html>`;
const next = `<!doctype html><html><head><title>Setup</title></head>
<body class="wp-admin kidia-mobile-setup">
  <main id="wpbody-content">
    <aside data-kidia-cms-sidebar>
      <nav class="kidia-cms-sidebar__nav">
        <a href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms">Overview</a>
        <a class="is-active" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-setup">Setup Wizard</a>
      </nav>
    </aside>
    <section data-page-content>Setup content</section>
  </main>
</body></html>`;

const dom = new JSDOM(initial, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms"
});
dom.window.scrollTo = () => {};
dom.window.fetch = async () => ({
  ok: true,
  url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-setup",
  text: async () => next
});

const originalSidebar = dom.window.document.querySelector("[data-kidia-cms-sidebar]");
dom.window.eval(script);
originalSidebar.querySelector("a:last-child").dispatchEvent(
  new dom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
);

setTimeout(() => {
  const currentSidebar = dom.window.document.querySelector("[data-kidia-cms-sidebar]");
  assert.strictEqual(currentSidebar, originalSidebar, "Navigation must retain the exact Overview sidebar DOM node.");
  assert.equal(dom.window.document.querySelector("[data-page-content]").textContent, "Setup content");
  assert.equal(currentSidebar.querySelector("a.is-active").textContent, "Setup Wizard");
  assert.equal(dom.window.location.search, "?page=kidia-mobile-setup");
  assert.equal(dom.window.document.title, "Setup");
  console.log("Persistent CMS sidebar runtime test passed.");
}, 25);
