"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.js"),
  "utf8"
);
const admin = fs.readFileSync(path.resolve(__dirname, "..", "admin", "class-kidia-mobile-cms-admin.php"), "utf8");
const styles = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.css"),
  "utf8"
);

assert.match(
  styles,
  /#wpbody-content\{\s*min-height:calc\(100vh - 68px\)!important;/,
  "Every desktop CMS workspace must reach at least the bottom of the shared sidebar."
);
assert.match(
  styles,
  /html\{[\s\S]*overflow-x:clip;[\s\S]*overflow-y:scroll;[\s\S]*scrollbar-gutter:stable;/,
  "The WordPress document must keep a stable vertical gutter without horizontal page scrolling."
);
assert.match(
  styles,
  /#wpbody-content\{[\s\S]*width:calc\(100% - 36px\);[\s\S]*max-width:calc\(100% - 36px\);/,
  "The shared frame must fit the WordPress content box on every desktop CMS view."
);
assert.doesNotMatch(
  styles,
  /#wpbody-content\{[^}]*width:calc\(100vw/,
  "Viewport-based CMS frame widths must not reintroduce horizontal overflow."
);
assert.match(
  styles,
  /:is\(\.kidia-page-master-toggle,\.kidia-page-toggle\) input\[type="checkbox"\]:checked::before\{[\s\S]*inset-inline-start:23px!important;[\s\S]*transform:none!important;/,
  "Standard page switches must position their thumb logically in both RTL and LTR."
);
assert.match(
  styles,
  /\.kidia-builder-switch input:checked \+ \.kidia-builder-switch__track::after\{[\s\S]*inset-inline-start:21px!important;[\s\S]*transform:none!important;/,
  "Card switches must use the same reliable logical thumb positioning."
);
assert.match(admin, /private const CMS_VIEWS = array[\s\S]*store-data/, "Navigation destinations must be views of one CMS screen.");
assert.match(admin, /wp_ajax_kidia_mobile_cms_view[\s\S]*cms_view_fragment/, "CMS views must use the fragment endpoint.");
assert.match(admin, /Returns one CMS view without another WordPress document, sidebar or frame/, "The endpoint must return view content only.");
assert.doesNotMatch(script.slice(0, script.indexOf("installPersistentCmsNavigation();")), /window\.location\.assign\(/, "Navigation must not destroy the shell.");
assert.doesNotMatch(script.slice(0, script.indexOf("installPersistentCmsNavigation();")), /DOMParser|response\.text\(/, "Navigation must not fetch and parse another WordPress document.");
const initial = `<!doctype html><html><head><title>Overview</title></head>
<body class="wp-admin kidia-mobile-cms">
  <main id="wpbody-content">
    <aside data-kidia-cms-sidebar>
      <nav class="kidia-cms-sidebar__nav">
        <a class="is-active" data-kidia-sidebar-view="overview" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms">Overview</a>
        <a data-kidia-sidebar-view="setup" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=setup">Setup Wizard</a>
      </nav>
    </aside>
    <div class="kidia-cms-shell" data-kidia-cms-shell>
      <nav class="kidia-cms-tabs">
        <a class="is-active" data-kidia-page-view="overview" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms">Overview</a>
        <a data-kidia-page-view="setup" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=setup">Setup Wizard</a>
      </nav>
    </div>
    <section data-page-content>Overview content</section>
  </main>
</body></html>`;
const dom = new JSDOM(initial, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms"
});
dom.window.scrollTo = () => {};
dom.window.kidiaCMSNavigation = {
  ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
  nonce: "test-nonce"
};
dom.window.fetch = async () => ({
  ok: true,
  json: async () => ({
    success: true,
    data: {
      html: "<section data-page-content>Setup content</section>",
      view: "setup",
      activeSidebar: "setup",
      showPageTabs: false,
      styles: [],
      scripts: []
    }
  })
});

const originalSidebar = dom.window.document.querySelector("[data-kidia-cms-sidebar]");
const originalShell = dom.window.document.querySelector("[data-kidia-cms-shell]");
const originalWorkspace = dom.window.document.querySelector("#wpbody-content");
dom.window.eval(script);
originalSidebar.querySelector("a:last-child").dispatchEvent(
  new dom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
);

setTimeout(() => {
  const currentSidebar = dom.window.document.querySelector("[data-kidia-cms-sidebar]");
  assert.strictEqual(currentSidebar, originalSidebar, "Navigation must retain the exact Overview sidebar DOM node.");
  assert.strictEqual(
    dom.window.document.querySelector("[data-kidia-cms-shell]"),
    originalShell,
    "Navigation must retain the exact shared top frame DOM node."
  );
  assert.strictEqual(
    dom.window.document.querySelector("#wpbody-content"),
    originalWorkspace,
    "Navigation must retain the exact shared CMS workspace frame."
  );
  assert.equal(dom.window.document.querySelector("[data-page-content]").textContent, "Setup content");
  assert.equal(currentSidebar.querySelector("a.is-active").textContent, "Setup Wizard");
  assert.equal(originalShell.hidden, true);
  assert.equal(dom.window.location.search, "?page=kidia-mobile-cms&view=setup");
  assert.equal(dom.window.document.querySelectorAll("[data-kidia-cms-sidebar]").length, 1);
  assert.equal(dom.window.document.querySelectorAll("[data-kidia-cms-shell]").length, 1);
  console.log("Persistent CMS sidebar runtime test passed.");
}, 25);
