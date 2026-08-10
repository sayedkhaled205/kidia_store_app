"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const script = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.js"),
  "utf8"
);
const admin = fs.readFileSync(path.resolve(__dirname, "..", "admin", "class-mobishop-admin.php"), "utf8");
const styles = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "cms-shell.css"),
  "utf8"
);
const styleRules = styles.replace(/\/\*[\s\S]*?\*\//g, "");
const splashScript = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "splash-screen.js"),
  "utf8"
);
const settingsSectionsScript = fs.readFileSync(
  path.resolve(__dirname, "..", "admin", "assets", "settings-sections.js"),
  "utf8"
);
const iconInteractionGuard = styles.match(
  /\/\* Dashicons and the preview icon fonts[\s\S]*?(?=\/\* Keep WordPress navigation usable)/
)?.[0] || "";

assert.match(
  styleRules,
  /#wpbody-content\{\s*min-height:calc\(100vh - 68px\)!important;/,
  "Every desktop CMS workspace must reach at least the bottom of the shared sidebar."
);
assert.doesNotMatch(styleRules, /(?:^|\})\s*html(?:\.[^{]*)?\s*\{[^}]*overflow\s*:\s*hidden/i, "CMS styles must keep the native WordPress document scrollbar available.");
assert.doesNotMatch(styleRules, /body\.mobishop-cms-plugin-page\s*\{[^}]*overflow\s*:\s*hidden/i, "Opening MobiShop must not lock the WordPress body.");
assert.match(
  iconInteractionGuard,
  /body\.mobishop-cms-plugin-page :is\([\s\S]*?\.dashicons,[\s\S]*?\.mobishop-app-icon,[\s\S]*?\.mobishop-category-preview-material-icon,[\s\S]*?\[aria-hidden="true"\][\s\S]*?\)[\s\S]*?user-select:none!important;[\s\S]*?caret-color:transparent!important;/,
  "CMS icon glyphs must not expose text selection or a Word-style caret on any plugin page."
);
assert.match(
  iconInteractionGuard,
  /body\.mobishop-cms-plugin-page :is\([\s\S]*?\.dashicons,[\s\S]*?\.mobishop-material-icon-choice,[\s\S]*?\.mobishop-preview-header__icon,[\s\S]*?svg\[aria-hidden="true"\][\s\S]*?\)[\s\S]*?cursor:default!important;/,
  "Standalone Dashicon, Material and SVG icon artwork must use the normal arrow instead of a text cursor."
);
assert.match(
  iconInteractionGuard,
  /:is\(button,a,label,summary,\[role="button"\],\[role="link"\]\)[\s\S]*?:is\([\s\S]*?\.dashicons,[\s\S]*?\.mobishop-app-icon,[\s\S]*?\[aria-hidden="true"\][\s\S]*?\)[\s\S]*?cursor:inherit!important;/,
  "Icons inside interactive controls must retain their parent control cursor."
);
assert.match(
  iconInteractionGuard,
  /:is\([\s\S]*?\.mobishop-builder-drag,[\s\S]*?\.mobishop-page-drag,[\s\S]*?\.mobishop-category-handle,[\s\S]*?\.mobishop-checkout-field-drag,[\s\S]*?\.mobishop-chrome-item[\s\S]*?\)[\s\S]*?cursor:grab!important;/,
  "Intentional card and list drag handles must keep their grab cursor."
);
assert.doesNotMatch(
  iconInteractionGuard,
  /:is\([^)]*(?:input|textarea|select|\[contenteditable)/,
  "The global icon guard must never capture editable form controls."
);
assert.match(
  iconInteractionGuard,
  /body\.mobishop-cms-plugin-page :is\([\s\S]*?\.dashicons,[\s\S]*?svg\[aria-hidden="true"\],[\s\S]*?img\[aria-hidden="true"\][\s\S]*?\)\{[^}]*-webkit-user-drag:none;/,
  "CMS icon artwork must not start the browser's native image or glyph drag behavior."
);
assert.doesNotMatch(
  iconInteractionGuard,
  /pointer-events\s*:\s*none/,
  "The global icon guard must not disable clicks on icon buttons or intentional drag handles."
);
assert.match(
  styles,
  /body\.mobishop-cms-plugin-page #wpbody\{[^}]*height:calc\(100vh - 46px\)!important;[^}]*overflow-y:scroll!important;[^}]*overscroll-behavior:contain;[^}]*scrollbar-gutter:stable;/,
  "Every CMS view must keep its own inner scroll box without replacing the WordPress scrollbar."
);
assert.match(
  styles,
  /@media\(min-width:783px\)\{[\s\S]*body\.mobishop-cms-plugin-page #wpbody\{[^}]*height:calc\(100vh - 32px\)!important;[^}]*direction:ltr;/,
  "Desktop CMS views must size their inner scrollbar below the WordPress toolbar."
);
assert.match(
  styles,
  /body\.mobishop-cms-builder-screen #wpbody\{[^}]*height:100%!important;[^}]*overflow-y:scroll!important;[^}]*overscroll-behavior:contain;[^}]*scrollbar-gutter:stable;[^}]*direction:ltr;/,
  "Customize must keep the same plugin-owned scrollbar rail beside the WordPress menu."
);
assert.doesNotMatch(
  styleRules,
  /#(?:adminmenuback|adminmenuwrap|adminmenu)(?=[\s:{.#\[])/,
  "The CMS stylesheet must never position, size, scroll or restyle WordPress navigation."
);
assert.doesNotMatch(
  script,
  /['"]#(?:adminmenuback|adminmenuwrap|adminmenu)(?=[\s.#\[:'"])/,
  "CMS navigation JavaScript must never read, replace or reset WordPress navigation."
);
assert.doesNotMatch(styleRules, /html(?:\.mobishop-cms-builder-screen|:has\([^)]*mobishop-cms-builder-screen[^)]*\))?[^\{]*\{[^}]*overflow\s*:\s*hidden/i, "Customize must not disable the WordPress document scrollbar.");
assert.doesNotMatch(styleRules, /body\.mobishop-cms-builder-screen\s*\{[^}]*overflow\s*:\s*hidden/i, "Customize must not lock the WordPress body.");
assert.doesNotMatch(styleRules, /body\.mobishop-cms-builder-screen #wpwrap\s*\{[^}]*overflow\s*:\s*hidden/i, "Customize must not clip WordPress navigation through the outer wrapper.");
assert.match(
  styles,
  /\.mobishop-cms-sidebar\{[\s\S]*inset-inline-start:-16px;[\s\S]*width:236px;/,
  "The shared sidebar must retain its full width and outer-gutter extension."
);
assert.match(
  styles,
  /body\.mobishop-cms-builder-screen #wpbody-content\{[^}]*overflow:visible!important;/,
  "Customize must not clip the sidebar's 16px outer-gutter extension."
);
assert.doesNotMatch(
  styles,
  /body\.mobishop-cms-builder-screen #wpbody-content\{[^}]*overflow:hidden!important;/,
  "Customize must not pull the visible sidebar edge left by clipping its outer gutter."
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
  /:is\(\.mobishop-page-master-toggle,\.mobishop-page-toggle\) input\[type="checkbox"\]:checked::before\{[\s\S]*inset-inline-start:23px!important;[\s\S]*transform:none!important;/,
  "Standard page switches must position their thumb logically in both RTL and LTR."
);
assert.match(
  styles,
  /\.mobishop-builder-switch input:checked \+ \.mobishop-builder-switch__track::after\{[\s\S]*inset-inline-start:21px!important;[\s\S]*transform:none!important;/,
  "Card switches must use the same reliable logical thumb positioning."
);
assert.match(admin, /private const CMS_VIEWS = array[\s\S]*store-data/, "Navigation destinations must be views of one CMS screen.");
assert.match(admin, /wp_ajax_mobishop_view[\s\S]*cms_view_fragment/, "CMS views must use the fragment endpoint.");
assert.match(admin, /Returns one CMS view without another WordPress document/, "The endpoint must never return or replace another WordPress document.");
assert.match(admin, /include_shell[\s\S]*render_cms_shell/, "The first CMS entry may request the CMS shell inside the retained WordPress workspace.");
assert.match(admin, /'builderScreen'\s*=>\s*\$this->is_builder_screen/, "Every fragment must report whether its view owns the fixed Builder workspace.");
assert.match(admin, /'version'\s*=>\s*MOBISHOP_VERSION/, "The shell and every fragment must expose the active plugin version.");
assert.match(script, /version:\s*currentVersion/, "Every fragment request must identify the version of the running shell.");
assert.match(script, /assetsCompatible[\s\S]*findLoadedAsset\(asset, 'css'\)\.conflict[\s\S]*findLoadedAsset\(asset, 'js'\)\.conflict[\s\S]*if \(!assetsCompatible\(payload\)\)[\s\S]*hardNavigate\(cacheKey\)/, "Only conflicting plugin assets may force a clean document load.");
assert.doesNotMatch(script, /classList\.add\('is-mobishop-page-loading'\)/, "Fragment navigation must not dim the existing shell while the next view loads.");
assert.match(
  script,
  /const stylesReady = loadStyles\(payload\)[\s\S]*payload\.nodes\.forEach[\s\S]*resetWorkspaceScroll\(\)[\s\S]*Promise\.all\(\[loadScripts\(payload\), stylesReady\]\)/,
  "Customize markup must be displayed before its Media, style, and Builder assets finish loading."
);
assert.doesNotMatch(script, /function resetDocumentScroll|documentScroll\.scrollTop|document\.body\.scrollTop|window\.scrollTo/, "CMS navigation must never move the WordPress document or menu scrollbar.");
assert.match(
  script,
  /function resetWorkspaceScroll\(\)[\s\S]*#wpbody[\s\S]*scrollTop = 0;[\s\S]*scrollLeft = 0;[\s\S]*payload\.nodes\.forEach[\s\S]*resetWorkspaceScroll\(\)/,
  "Changing CMS views may reset only the independent plugin scrollbar."
);
assert.doesNotMatch(script, /pageshow[\s\S]*scroll/, "Restoring a CMS page must not reset the WordPress scrollbar.");
assert.doesNotMatch(script.slice(0, script.indexOf("installPersistentCmsNavigation();")), /window\.location\.assign\(/, "Navigation must not destroy the shell.");
assert.doesNotMatch(script.slice(0, script.indexOf("installPersistentCmsNavigation();")), /DOMParser|response\.text\(/, "Navigation must not fetch and parse another WordPress document.");
assert.match(splashScript, /mobishop:cms-page-ready[\s\S]*bootSplashBuilder/, "Splash must initialize after fragment navigation, not only on the first document load.");
assert.match(settingsSectionsScript, /mobishop:cms-page-ready[\s\S]*bootSettingsSections/, "Customize settings must regroup after fragment navigation.");

const splashDom = new JSDOM(`<!doctype html><html><body>
  <div class="mobishop-splash-builder"><form>
    <input type="checkbox" name="splash[enabled]">
    <input name="splash[duration_ms]" value="1800">
    <input name="splash[background_color]" value="#ffffff">
    <input name="splash[background_color_end]" value="#eeeeee">
    <input name="splash[image_url]" value="">
    <input name="splash[image_width]" value="120">
    <input name="splash[image_height]" value="120">
    <input name="splash[image_fit]" value="contain">
    <input name="splash[image_shape]" value="rounded">
    <input name="splash[store_name]" value="MobiShop">
    <input type="checkbox" name="splash[show_store_name]" checked>
    <input name="splash[text_color]" value="#111111">
    <input type="checkbox" name="splash[show_loader]" checked>
    <input name="splash[loader_color]" value="#2f806e">
    <div class="mobishop-page-card"><button type="button" class="mobishop-page-expand"></button><div class="mobishop-page-card__body" hidden></div></div>
  </form></div>
  <div id="mobishop-splash-preview"><div data-splash-overlay><img><strong></strong><span class="spinner"></span><span class="mobishop-splash-progress"></span></div></div>
</body></html>`, { runScripts: "outside-only" });
splashDom.window.eval(splashScript);
splashDom.window.document.dispatchEvent(new splashDom.window.CustomEvent("mobishop:cms-page-ready"));
splashDom.window.document.dispatchEvent(new splashDom.window.CustomEvent("mobishop:cms-page-ready"));
const splashForm = splashDom.window.document.querySelector(".mobishop-splash-builder form");
assert.equal(splashForm.dataset.mobishopSplashBooted, "1", "Splash fragment initialization must complete exactly once.");
splashForm.querySelector(".mobishop-page-expand").dispatchEvent(new splashDom.window.MouseEvent("click", { bubbles: true }));
assert.equal(splashForm.querySelector(".mobishop-page-card__body").hidden, false, "Repeated page-ready events must not duplicate Customize handlers.");

const initial = `<!doctype html><html><head><title>Overview</title></head>
<body class="wp-admin mobishop">
  <div id="wpadminbar">WordPress toolbar</div>
  <div id="adminmenuback"></div>
  <nav id="adminmenuwrap"><ul id="adminmenu"><li>WordPress menu</li></ul></nav>
  <div id="wpbody">
    <main id="wpbody-content">
    <aside data-mobishop-cms-sidebar>
      <nav class="mobishop-cms-sidebar__nav">
        <a class="is-active" data-mobishop-sidebar-view="overview" href="https://store.test/wp-admin/admin.php?page=mobishop">Overview</a>
        <a data-mobishop-sidebar-view="pages" href="https://store.test/wp-admin/admin.php?page=mobishop&view=home">Design Your Pages</a>
        <a data-mobishop-sidebar-view="setup" href="https://store.test/wp-admin/admin.php?page=mobishop&view=setup">Setup Wizard</a>
      </nav>
    </aside>
    <div class="mobishop-cms-shell" data-mobishop-cms-shell>
      <nav class="mobishop-cms-tabs">
        <a class="is-active" data-mobishop-page-view="overview" href="https://store.test/wp-admin/admin.php?page=mobishop">Overview</a>
        <a data-mobishop-page-view="home" href="https://store.test/wp-admin/admin.php?page=mobishop&view=home">Home</a>
        <a data-mobishop-page-view="setup" href="https://store.test/wp-admin/admin.php?page=mobishop&view=setup">Setup Wizard</a>
      </nav>
    </div>
    <div data-mobishop-background-job-stack>
      <div data-mobishop-app-build data-build-persistent data-mobishop-background-job="app-build">Persistent build</div>
      <div data-mobishop-background-job="abandoned-carts">Persistent cart import</div>
      <div class="mobishop-ai-progress-overlay" data-mobishop-background-job="generate-offers">Persistent offers</div>
    </div>
    <section data-page-content>Overview content</section>
    </main>
  </div>
</body></html>`;
const dom = new JSDOM(initial, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=mobishop"
});
dom.window.scrollTo = () => {};
dom.window.mobishopCMSNavigation = {
  ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
  nonce: "test-nonce",
  version: "1.45.60"
};
const requestedVersions = [];
dom.window.fetch = async (_url, options = {}) => {
  const request = new URLSearchParams(String(options.body || ""));
  const target = request.get("target") || "";
  requestedVersions.push(request.get("version"));
  const builderScreen = target.includes("view=home");
  return {
    ok: true,
    json: async () => ({
      success: true,
      data: {
        html: `<section data-page-content>${builderScreen ? "Home" : "Setup"} content</section>`,
        view: builderScreen ? "home" : "setup",
        activeSidebar: builderScreen ? "pages" : "setup",
        showPageTabs: builderScreen,
        builderScreen,
        version: "1.45.60",
        styles: [],
        scripts: []
      }
    })
  };
};

const originalSidebar = dom.window.document.querySelector("[data-mobishop-cms-sidebar]");
const originalShell = dom.window.document.querySelector("[data-mobishop-cms-shell]");
const originalBuildCard = dom.window.document.querySelector("[data-build-persistent]");
const originalJobStack = dom.window.document.querySelector("[data-mobishop-background-job-stack]");
const originalJobCards = Array.from(dom.window.document.querySelectorAll("[data-mobishop-background-job]"));
const originalWorkspace = dom.window.document.querySelector("#wpbody-content");
const originalScrollWorkspace = dom.window.document.querySelector("#wpbody");
const originalWordPressToolbar = dom.window.document.querySelector("#wpadminbar");
const originalWordPressMenuBack = dom.window.document.querySelector("#adminmenuback");
const originalWordPressMenuWrap = dom.window.document.querySelector("#adminmenuwrap");
const originalWordPressMenu = dom.window.document.querySelector("#adminmenu");
originalWordPressMenuWrap.scrollTop = 410;
originalScrollWorkspace.scrollTop = 320;
dom.window.eval(script);
originalSidebar.querySelector('[data-mobishop-sidebar-view="pages"]').dispatchEvent(
  new dom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
);

setTimeout(() => {
  const currentSidebar = dom.window.document.querySelector("[data-mobishop-cms-sidebar]");
  assert.strictEqual(currentSidebar, originalSidebar, "Navigation must retain the exact Overview sidebar DOM node.");
  assert.strictEqual(
    dom.window.document.querySelector("[data-mobishop-cms-shell]"),
    originalShell,
    "Navigation must retain the exact shared top frame DOM node."
  );
  assert.deepEqual(
    Array.from(dom.window.document.querySelectorAll("[data-mobishop-background-job]")),
    originalJobCards,
    "A new background card must remain beside every older card instead of replacing it."
  );
  assert.strictEqual(
    dom.window.document.querySelector("[data-build-persistent]"),
    originalBuildCard,
    "Navigation must retain the exact background build card DOM node."
  );
  assert.strictEqual(
    dom.window.document.querySelector("[data-mobishop-background-job-stack]"),
    originalJobStack,
    "Navigation must retain the one shared background-job stack."
  );
  assert.strictEqual(
    dom.window.document.querySelector("#wpbody-content"),
    originalWorkspace,
    "Navigation must retain the exact shared CMS workspace frame."
  );
  assert.strictEqual(dom.window.document.querySelector("#wpadminbar"), originalWordPressToolbar, "CMS navigation must retain the exact WordPress toolbar DOM node.");
  assert.strictEqual(dom.window.document.querySelector("#adminmenuback"), originalWordPressMenuBack, "CMS navigation must retain the exact WordPress menu backdrop DOM node.");
  assert.strictEqual(dom.window.document.querySelector("#adminmenuwrap"), originalWordPressMenuWrap, "CMS navigation must retain the exact WordPress menu scroll container DOM node.");
  assert.strictEqual(dom.window.document.querySelector("#adminmenu"), originalWordPressMenu, "CMS navigation must retain the exact WordPress menu DOM node.");
  assert.equal(originalWordPressMenuWrap.scrollTop, 410, "CMS navigation must not reset or move the WordPress menu scrollbar.");
  assert.equal(dom.window.document.querySelector("[data-page-content]").textContent, "Home content");
  assert.equal(originalScrollWorkspace.scrollTop, 0, "A new CMS view must reset the plugin-owned inner scrollbar.");
  assert.equal(currentSidebar.querySelector("a.is-active").textContent, "Design Your Pages");
  assert.equal(originalShell.hidden, false);
  assert.equal(dom.window.location.search, "?page=mobishop&view=home");
  assert.equal(dom.window.document.body.classList.contains("mobishop-cms-builder-screen"), true, "Entering a Builder fragment must restore the fixed body workspace.");
  assert.equal(dom.window.document.documentElement.classList.contains("mobishop-cms-builder-screen"), true, "The document root must lock with the Builder body.");

  originalSidebar.querySelector('[data-mobishop-sidebar-view="setup"]').dispatchEvent(
    new dom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
  );
  setTimeout(() => {
    assert.equal(dom.window.document.querySelector("[data-page-content]").textContent, "Setup content");
    assert.equal(currentSidebar.querySelector("a.is-active").textContent, "Setup Wizard");
    assert.equal(originalShell.hidden, true);
    assert.equal(dom.window.location.search, "?page=mobishop&view=setup");
    assert.equal(dom.window.document.body.classList.contains("mobishop-cms-builder-screen"), false, "Leaving a Builder fragment must release the fixed body workspace.");
    assert.equal(dom.window.document.documentElement.classList.contains("mobishop-cms-builder-screen"), false, "The document root must be released with the Builder body.");
    assert.equal(dom.window.document.querySelectorAll("[data-mobishop-cms-sidebar]").length, 1);
    assert.equal(dom.window.document.querySelectorAll("[data-mobishop-cms-shell]").length, 1);
    assert.strictEqual(dom.window.document.querySelector("#wpadminbar"), originalWordPressToolbar, "Repeated CMS navigation must not reload the WordPress toolbar.");
    assert.strictEqual(dom.window.document.querySelector("#adminmenuwrap"), originalWordPressMenuWrap, "Repeated CMS navigation must not reload the WordPress menu.");
    assert.strictEqual(dom.window.document.querySelector("#adminmenu"), originalWordPressMenu, "Repeated CMS navigation must preserve WordPress menu contents.");
    assert.equal(originalWordPressMenuWrap.scrollTop, 410, "Repeated CMS navigation must preserve the WordPress menu scroll position.");
    assert.strictEqual(dom.window.document.querySelector("[data-build-persistent]"), originalBuildCard, "A second page change must still retain the running or completed build card.");
    assert.deepEqual(Array.from(dom.window.document.querySelectorAll("[data-mobishop-background-job]")), originalJobCards, "All three independent job cards must survive repeated navigation together.");
    assert.deepEqual(requestedVersions, ["1.45.60", "1.45.60"], "Every navigation request must carry the running asset version.");

    const staleDom = new JSDOM(`<!doctype html><html><head>
      <link id="legacy-mobishop-shell-css" rel="stylesheet" href="https://store.test/wp-content/plugins/mobishop/admin/assets/cms-shell.css?ver=1.45.52-old">
    </head><body class="wp-admin mobishop">
      <main id="wpbody-content">
        <aside data-mobishop-cms-sidebar>
          <a data-mobishop-sidebar-view="pages" href="https://store.test/wp-admin/admin.php?page=mobishop&view=home">Design Your Pages</a>
        </aside>
        <div class="mobishop-cms-shell" data-mobishop-cms-shell>
          <a data-mobishop-page-view="home" href="https://store.test/wp-admin/admin.php?page=mobishop&view=home">Home</a>
        </div>
        <section data-page-content>Overview content</section>
      </main>
    </body></html>`, {
      runScripts: "outside-only",
      url: "https://store.test/wp-admin/admin.php?page=mobishop"
    });
    staleDom.window.scrollTo = () => {};
    staleDom.window.mobishopCMSNavigation = {
      ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
      nonce: "test-nonce",
      version: "1.45.60"
    };
    let forcedUrl = "";
    staleDom.window.mobishopCmsHardNavigate = (url) => {
      forcedUrl = url;
    };
    staleDom.window.fetch = async () => ({
      ok: true,
      json: async () => ({
        success: true,
        data: {
          html: "<section data-page-content>Home content</section>",
          view: "home",
          activeSidebar: "pages",
          showPageTabs: true,
          builderScreen: true,
          version: "1.45.60",
          styles: [{
            handle: "mobishop-shell",
            src: "https://store.test/wp-content/plugins/mobishop/admin/assets/cms-shell.css?ver=1.45.60-new"
          }],
          scripts: []
        }
      })
    });
    staleDom.window.eval(script);
    staleDom.window.document.querySelector('[data-mobishop-sidebar-view="pages"]').dispatchEvent(
      new staleDom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
    );
    setTimeout(() => {
      assert.equal(
        forcedUrl,
        "https://store.test/wp-admin/admin.php?page=mobishop&view=home",
        "A stale stylesheet must reload the requested view as a clean document."
      );
      assert.equal(
        staleDom.window.document.querySelector("[data-page-content]").textContent,
        "Overview content",
        "The stale shell must not be mutated before the clean document load."
      );
      assert.equal(
        staleDom.window.document.querySelectorAll('link[href*="cms-shell.css"]').length,
        1,
        "Navigation must never combine old and current copies of the shell stylesheet."
      );

      const builderDom = new JSDOM(`<!doctype html><html><head>
        <link id="wp-media-css" rel="stylesheet" href="https://store.test/wp-admin/load-styles.php?c=1&dir=rtl&load=media-views&ver=6.9">
        <link id="mobishop-shell-css" rel="stylesheet" href="https://store.test/wp-content/plugins/mobishop/admin/assets/cms-shell.css?ver=1.45.60-current">
        <script id="jquery-core-js" src="https://store.test/wp-includes/js/jquery/jquery.min.js?ver=3.7.1"></script>
      </head><body class="wp-admin mobishop">
        <main id="wpbody-content">
          <aside data-mobishop-cms-sidebar>
            <a data-mobishop-sidebar-view="pages" href="https://store.test/wp-admin/admin.php?page=mobishop&view=home">Design Your Pages</a>
          </aside>
          <div class="mobishop-cms-shell" data-mobishop-cms-shell>
            <a data-mobishop-page-view="home" href="https://store.test/wp-admin/admin.php?page=mobishop&view=home">Home</a>
          </div>
          <section data-page-content>Overview content</section>
        </main>
      </body></html>`, {
        runScripts: "outside-only",
        url: "https://store.test/wp-admin/admin.php?page=mobishop"
      });
      builderDom.window.scrollTo = () => {};
      builderDom.window.mobishopCMSNavigation = {
        ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
        nonce: "test-nonce",
        version: "1.45.60"
      };
      let builderForcedUrl = "";
      builderDom.window.mobishopCmsHardNavigate = (url) => {
        builderForcedUrl = url;
      };
      builderDom.window.fetch = async () => ({
        ok: true,
        json: async () => ({
          success: true,
          data: {
            html: "<section data-page-content>Home Builder content</section>",
            view: "home",
            activeSidebar: "pages",
            showPageTabs: true,
            builderScreen: true,
            version: "1.45.60",
            styles: [
              {
                handle: "wp-media",
                src: "https://store.test/wp-admin/load-styles.php?c=1&dir=rtl&load=media-views&ver=6.9.1"
              },
              {
                handle: "mobishop-shell",
                src: "https://store.test/wp-content/plugins/mobishop/admin/assets/cms-shell.css?ver=1.45.60-current"
              },
              {
                handle: "mobishop-fixed-chrome",
                src: "https://store.test/wp-content/plugins/mobishop/admin/assets/page-builder.css?ver=1.45.60"
              }
            ],
            scripts: [
              {
                handle: "jquery-core",
                src: "https://store.test/wp-includes/js/jquery/jquery.min.js?ver=3.7.2"
              },
              {
                handle: "mobishop-splash-screen",
                src: "https://store.test/wp-content/plugins/mobishop/admin/assets/splash-screen.js?ver=1.45.60"
              }
            ]
          }
        })
      });
      const builderSidebar = builderDom.window.document.querySelector("[data-mobishop-cms-sidebar]");
      const builderShell = builderDom.window.document.querySelector("[data-mobishop-cms-shell]");
      let builderAssetSawPage = "";
      const appendBuilderStyle = builderDom.window.document.head.appendChild.bind(builderDom.window.document.head);
      builderDom.window.document.head.appendChild = (node) => {
        const appended = appendBuilderStyle(node);
        if (node.matches && node.matches('link[href*="page-builder.css"]')) {
          setTimeout(() => node.dispatchEvent(new builderDom.window.Event("load")), 45);
        }
        return appended;
      };
      const appendBuilderAsset = builderDom.window.document.body.appendChild.bind(builderDom.window.document.body);
      builderDom.window.document.body.appendChild = (node) => {
        const appended = appendBuilderAsset(node);
        if (node.matches && node.matches('script[src*="splash-screen.js"]')) {
          builderAssetSawPage = builderDom.window.document.querySelector("[data-page-content]").textContent;
          setTimeout(() => node.dispatchEvent(new builderDom.window.Event("load")), 40);
        }
        return appended;
      };
      builderDom.window.eval(script);
      builderSidebar.querySelector('[data-mobishop-sidebar-view="pages"]').dispatchEvent(
        new builderDom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
      );
      setTimeout(() => {
        assert.equal(
          builderDom.window.document.querySelector("[data-page-content]").textContent,
          "Home Builder content",
          "The requested Customize view must appear while its optional scripts are still loading."
        );
      }, 5);
      setTimeout(() => {
        assert.equal(builderForcedUrl, "", "WordPress and Media query-version differences must not reload the document.");
        assert.strictEqual(builderDom.window.document.querySelector("[data-mobishop-cms-sidebar]"), builderSidebar, "Builder navigation must retain the sidebar DOM node.");
        assert.strictEqual(builderDom.window.document.querySelector("[data-mobishop-cms-shell]"), builderShell, "Builder navigation must retain the shared frame DOM node.");
        assert.equal(builderDom.window.document.querySelector("[data-page-content]").textContent, "Home Builder content");
        assert.equal(builderAssetSawPage, "Home Builder content", "Customize scripts must execute only after their new page markup exists.");
        assert.equal(builderDom.window.document.querySelector("#wpbody-content").classList.contains("is-mobishop-page-loading"), false);
        console.log("Persistent CMS sidebar and asset version runtime tests passed.");
      }, 70);
    }, 25);
  }, 25);
}, 25);
