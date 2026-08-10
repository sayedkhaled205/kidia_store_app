"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.resolve(__dirname, "..");
const entryScript = fs.readFileSync(path.join(pluginRoot, "admin", "assets", "cms-entry.js"), "utf8");
const shellStyles = fs.readFileSync(path.join(pluginRoot, "admin", "assets", "cms-shell.css"), "utf8");
const admin = fs.readFileSync(path.join(pluginRoot, "admin", "class-mobishop-admin.php"), "utf8");
const styleRules = shellStyles.replace(/\/\*[\s\S]*?\*\//g, "");
const setupWizardScript = fs.readFileSync(path.join(pluginRoot, "admin", "assets", "setup-wizard.js"), "utf8");

assert.doesNotMatch(
  styleRules,
  /(?:^|\})\s*html(?:\.[^{]*)?\s*\{[^}]*overflow\s*:\s*hidden/i,
  "MobiShop must not disable the native WordPress document scrollbar."
);
assert.doesNotMatch(
  setupWizardScript,
  /window\.scrollTo/,
  "Dynamically loaded MobiShop views must never move the WordPress document scrollbar."
);
assert.doesNotMatch(
  styleRules,
  /body\.mobishop-cms-(?:plugin-page|builder-screen)\s*\{[^}]*overflow\s*:\s*hidden/i,
  "Plugin body classes must not replace WordPress document scrolling."
);
assert.doesNotMatch(
  styleRules,
  /#(?:adminmenuback|adminmenuwrap|adminmenu)(?=[\s:{.#\[])/,
  "The plugin stylesheet must not resize or overlay the WordPress menu or its scrollbar."
);
assert.match(
  admin,
  /mobishop-entry[\s\S]*cms-entry\.js[\s\S]*if \( ! \$is_mobishop_page \)/,
  "The tiny entry controller must load before returning from ordinary WordPress admin pages."
);
assert.match(
  admin,
  /\$include_shell\s*=\s*! empty\( \$_POST\['include_shell'\] \)[\s\S]*render_cms_shell\(\)[\s\S]*'bodyClasses'/,
  "The fragment endpoint must be able to bootstrap the complete CMS workspace without another WordPress document."
);

const dom = new JSDOM(`<!doctype html><html dir="rtl"><head><title>WordPress Products</title></head>
<body class="wp-admin rtl edit-php">
  <div id="wpadminbar">Toolbar</div>
  <div id="adminmenuback"></div>
  <nav id="adminmenuwrap">
    <ul id="adminmenu">
      <li><a id="products-link" href="#products">Products</a></li>
      <li><a id="cms-link" href="https://store.test/wp-admin/admin.php?page=mobishop">MobiShop</a></li>
    </ul>
  </nav>
  <div id="wpbody"><main id="wpbody-content"><section id="wordpress-page">Products page</section></main></div>
</body></html>`, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/edit.php?post_type=product"
});

dom.window.mobishopCMSEntry = {
  ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
  nonce: "entry-nonce",
  version: "1.46.50"
};

const requests = [];
dom.window.fetch = async (_url, options = {}) => {
  const request = new URLSearchParams(String(options.body || ""));
  requests.push(request);
  return {
    ok: true,
    json: async () => ({
      success: true,
      data: {
        html: `<aside data-mobishop-cms-sidebar>CMS sidebar</aside>
          <div data-mobishop-cms-shell hidden>CMS page tabs</div>
          <section data-cms-page>Overview</section>`,
        builderScreen: false,
        bodyClasses: ["mobishop", "mobishop-cms-plugin-page"],
        version: "1.46.50",
        styles: [],
        scripts: []
      }
    })
  };
};

const originalToolbar = dom.window.document.querySelector("#wpadminbar");
const originalMenuBack = dom.window.document.querySelector("#adminmenuback");
const originalMenuWrap = dom.window.document.querySelector("#adminmenuwrap");
const originalMenu = dom.window.document.querySelector("#adminmenu");
const originalContent = dom.window.document.querySelector("#wpbody-content");
originalMenuWrap.scrollTop = 390;
dom.window.document.documentElement.scrollTop = 245;

dom.window.eval(entryScript);

assert.equal(requests.length, 0, "Ordinary WordPress navigation must not call the CMS endpoint.");

const cmsClick = new dom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 });
assert.equal(dom.window.document.querySelector("#cms-link").dispatchEvent(cmsClick), false, "The MobiShop link must be handled without a document navigation.");

setTimeout(() => {
  assert.equal(requests.length, 1);
  assert.equal(requests[0].get("action"), "mobishop_view");
  assert.equal(requests[0].get("include_shell"), "1");
  assert.equal(requests[0].get("version"), "1.46.50");
  assert.strictEqual(dom.window.document.querySelector("#wpadminbar"), originalToolbar, "The exact WordPress toolbar node must survive CMS entry.");
  assert.strictEqual(dom.window.document.querySelector("#adminmenuback"), originalMenuBack, "The exact WordPress menu backdrop must survive CMS entry.");
  assert.strictEqual(dom.window.document.querySelector("#adminmenuwrap"), originalMenuWrap, "The exact WordPress scrollbar container must survive CMS entry.");
  assert.strictEqual(dom.window.document.querySelector("#adminmenu"), originalMenu, "The exact WordPress menu must survive CMS entry.");
  assert.strictEqual(dom.window.document.querySelector("#wpbody-content"), originalContent, "Only the contents of the existing WordPress workspace may change.");
  assert.equal(originalMenuWrap.scrollTop, 390, "Opening MobiShop must preserve the WordPress menu scrollbar position.");
  assert.equal(dom.window.document.documentElement.scrollTop, 245, "Opening MobiShop must preserve the native WordPress document scrollbar position.");
  assert.equal(dom.window.document.querySelector("[data-cms-page]").textContent, "Overview");
  assert.equal(dom.window.document.querySelector("#wordpress-page"), null);
  assert.equal(dom.window.document.body.classList.contains("mobishop-cms-plugin-page"), true);
  assert.equal(dom.window.location.search, "?page=mobishop");
}, 0);
