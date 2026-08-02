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
  styles,
  /#wpbody-content\{\s*min-height:calc\(100vh - 68px\)!important;/,
  "Every desktop CMS workspace must reach at least the bottom of the shared sidebar."
);
assert.match(
  styles,
  /html\{[^}]*height:100%;[^}]*overflow:hidden!important;[^}]*scrollbar-gutter:auto!important;/,
  "The WordPress document must stay locked while the plugin workspace owns scrolling."
);
assert.match(
  styles,
  /body\.kidia-cms-plugin-page\{[^}]*height:100%;[^}]*overflow:hidden!important;/,
  "The WordPress body must not become a second scroll owner on plugin pages."
);
assert.match(
  iconInteractionGuard,
  /body\.kidia-cms-plugin-page :is\([\s\S]*?\.dashicons,[\s\S]*?\.kidia-app-icon,[\s\S]*?\.kidia-category-preview-material-icon,[\s\S]*?\[aria-hidden="true"\][\s\S]*?\)[\s\S]*?user-select:none!important;[\s\S]*?caret-color:transparent!important;/,
  "CMS icon glyphs must not expose text selection or a Word-style caret on any plugin page."
);
assert.match(
  iconInteractionGuard,
  /body\.kidia-cms-plugin-page :is\([\s\S]*?\.dashicons,[\s\S]*?svg\[aria-hidden="true"\],[\s\S]*?img\[aria-hidden="true"\][\s\S]*?\)\{[^}]*-webkit-user-drag:none;/,
  "CMS icon artwork must not start the browser's native image or glyph drag behavior."
);
assert.doesNotMatch(
  iconInteractionGuard,
  /pointer-events\s*:\s*none/,
  "The global icon guard must not disable clicks on icon buttons or intentional drag handles."
);
assert.match(
  styles,
  /body\.kidia-cms-plugin-page #wpbody\{[^}]*height:calc\(100vh - 46px\)!important;[^}]*overflow-y:scroll!important;[^}]*overscroll-behavior:contain;[^}]*scrollbar-gutter:stable;/,
  "Every CMS view must use the plugin workspace as its only vertical scroll box."
);
assert.match(
  styles,
  /@media\(min-width:783px\)\{[\s\S]*body\.kidia-cms-plugin-page #wpbody\{[^}]*height:calc\(100vh - 32px\)!important;[^}]*direction:ltr;/,
  "Desktop CMS views must size their inner scrollbar below the WordPress toolbar."
);
assert.match(
  styles,
  /body\.kidia-cms-builder-screen #wpbody\{[^}]*height:100%!important;[^}]*overflow-y:scroll!important;[^}]*overscroll-behavior:contain;[^}]*scrollbar-gutter:stable;[^}]*direction:ltr;/,
  "Customize must keep the same plugin-owned scrollbar rail beside the WordPress menu."
);
assert.match(
  styles,
  /@media\(min-width:783px\)\{[\s\S]*body\.kidia-cms-plugin-page #adminmenuwrap\{[^}]*position:fixed!important;[^}]*inset-block-start:32px!important;[^}]*inset-block-end:0!important;[^}]*overflow-y:scroll!important;[^}]*overscroll-behavior:contain;[^}]*scrollbar-gutter:stable;/,
  "The WordPress admin menu must own an isolated desktop scrollbar without restoring document scrolling."
);
assert.match(
  styles,
  /body\.kidia-cms-plugin-page #adminmenuwrap\{[^}]*overflow-y:scroll!important;[^}]*direction:ltr;/,
  "The WordPress menu scroll container must place its scrollbar on the physical right."
);
assert.match(
  styles,
  /html\[dir="rtl"\] body\.kidia-cms-plugin-page #adminmenu,[^}]*\.rtl body\.kidia-cms-plugin-page #adminmenu\{[^}]*direction:rtl;/,
  "Moving the WordPress menu scrollbar must preserve the RTL menu content layout."
);
assert.match(
  styles,
  /html\.kidia-cms-builder-screen,\s*html:has\(body\.kidia-cms-builder-screen\)\{[^}]*overflow:hidden!important;[^}]*scrollbar-gutter:auto!important;/,
  "Entering Customize must keep the WordPress document locked without an outer scrollbar gutter."
);
assert.match(
  styles,
  /body\.kidia-cms-builder-screen\{[^}]*overflow:hidden!important;/,
  "Customize must not release the WordPress body as a second scroll owner."
);
assert.match(
  styles,
  /body\.kidia-cms-builder-screen #wpwrap\{[^}]*height:calc\(100vh - 32px\);[^}]*overflow:hidden!important;/,
  "Customize must clip the outer WordPress wrapper to the available viewport."
);
assert.doesNotMatch(
  styles,
  /html(?:\.kidia-cms-builder-screen)?[^\{]*\{[^}]*overflow-y:scroll!important;/,
  "No CMS state may restore the outer WordPress scrollbar."
);
assert.match(
  styles,
  /\.kidia-cms-sidebar\{[\s\S]*inset-inline-start:-16px;[\s\S]*width:236px;/,
  "The shared sidebar must retain its full width and outer-gutter extension."
);
assert.match(
  styles,
  /body\.kidia-cms-builder-screen #wpbody-content\{[^}]*overflow:visible!important;/,
  "Customize must not clip the sidebar's 16px outer-gutter extension."
);
assert.doesNotMatch(
  styles,
  /body\.kidia-cms-builder-screen #wpbody-content\{[^}]*overflow:hidden!important;/,
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
assert.match(admin, /'builderScreen'\s*=>\s*\$this->is_builder_screen/, "Every fragment must report whether its view owns the fixed Builder workspace.");
assert.match(admin, /'version'\s*=>\s*KIDIA_MOBILE_CMS_VERSION/, "The shell and every fragment must expose the active plugin version.");
assert.match(script, /version:\s*currentVersion/, "Every fragment request must identify the version of the running shell.");
assert.match(script, /assetsCompatible[\s\S]*findLoadedAsset\(asset, 'css'\)\.conflict[\s\S]*findLoadedAsset\(asset, 'js'\)\.conflict[\s\S]*if \(!assetsCompatible\(payload\)\)[\s\S]*hardNavigate\(cacheKey\)/, "Only conflicting plugin assets may force a clean document load.");
assert.doesNotMatch(script, /classList\.add\('is-kidia-page-loading'\)/, "Fragment navigation must not dim the existing shell while the next view loads.");
assert.match(
  script,
  /const stylesReady = loadStyles\(payload\)[\s\S]*payload\.nodes\.forEach[\s\S]*resetWorkspaceScroll\(\)[\s\S]*Promise\.all\(\[loadScripts\(payload\), stylesReady\]\)/,
  "Customize markup must be displayed before its Media, style, and Builder assets finish loading."
);
assert.match(
  script,
  /function resetDocumentScroll\(\)[\s\S]*scrollRestoration = 'manual';[\s\S]*documentScroll\.scrollTop = 0;[\s\S]*document\.body\.scrollTop = 0;[\s\S]*window\.scrollTo/,
  "The locked WordPress document must always be reset to its true viewport origin."
);
assert.match(
  script,
  /function resetWorkspaceScroll\(\)[\s\S]*resetDocumentScroll\(\);[\s\S]*#wpbody[\s\S]*scrollTop = 0;[\s\S]*scrollLeft = 0;[\s\S]*payload\.nodes\.forEach[\s\S]*resetWorkspaceScroll\(\)/,
  "Changing CMS views must reset both the locked WordPress document and the independent plugin scrollbar."
);
assert.doesNotMatch(script, /syncBuilderScreen\(enabled\)[\s\S]{0,260}if \(!active\) return;/, "Non-Builder CMS views must keep the same document scroll lock as Builders.");
assert.match(script, /window\.addEventListener\('pageshow', resetDocumentScroll\)/, "Restored CMS pages must not revive a stale WordPress scroll offset.");
assert.doesNotMatch(script.slice(0, script.indexOf("installPersistentCmsNavigation();")), /window\.location\.assign\(/, "Navigation must not destroy the shell.");
assert.doesNotMatch(script.slice(0, script.indexOf("installPersistentCmsNavigation();")), /DOMParser|response\.text\(/, "Navigation must not fetch and parse another WordPress document.");
assert.match(splashScript, /kidia:cms-page-ready[\s\S]*bootSplashBuilder/, "Splash must initialize after fragment navigation, not only on the first document load.");
assert.match(settingsSectionsScript, /kidia:cms-page-ready[\s\S]*bootSettingsSections/, "Customize settings must regroup after fragment navigation.");

const splashDom = new JSDOM(`<!doctype html><html><body>
  <div class="kidia-splash-builder"><form>
    <input type="checkbox" name="splash[enabled]">
    <input name="splash[duration_ms]" value="1800">
    <input name="splash[background_color]" value="#ffffff">
    <input name="splash[background_color_end]" value="#eeeeee">
    <input name="splash[image_url]" value="">
    <input name="splash[image_width]" value="120">
    <input name="splash[image_height]" value="120">
    <input name="splash[image_fit]" value="contain">
    <input name="splash[image_shape]" value="rounded">
    <input name="splash[store_name]" value="Kidia">
    <input type="checkbox" name="splash[show_store_name]" checked>
    <input name="splash[text_color]" value="#111111">
    <input type="checkbox" name="splash[show_loader]" checked>
    <input name="splash[loader_color]" value="#2f806e">
    <div class="kidia-page-card"><button type="button" class="kidia-page-expand"></button><div class="kidia-page-card__body" hidden></div></div>
  </form></div>
  <div id="kidia-splash-preview"><div data-splash-overlay><img><strong></strong><span class="spinner"></span><span class="kidia-splash-progress"></span></div></div>
</body></html>`, { runScripts: "outside-only" });
splashDom.window.eval(splashScript);
splashDom.window.document.dispatchEvent(new splashDom.window.CustomEvent("kidia:cms-page-ready"));
splashDom.window.document.dispatchEvent(new splashDom.window.CustomEvent("kidia:cms-page-ready"));
const splashForm = splashDom.window.document.querySelector(".kidia-splash-builder form");
assert.equal(splashForm.dataset.kidiaSplashBooted, "1", "Splash fragment initialization must complete exactly once.");
splashForm.querySelector(".kidia-page-expand").dispatchEvent(new splashDom.window.MouseEvent("click", { bubbles: true }));
assert.equal(splashForm.querySelector(".kidia-page-card__body").hidden, false, "Repeated page-ready events must not duplicate Customize handlers.");

const initial = `<!doctype html><html><head><title>Overview</title></head>
<body class="wp-admin kidia-mobile-cms">
  <div id="wpbody">
    <main id="wpbody-content">
    <aside data-kidia-cms-sidebar>
      <nav class="kidia-cms-sidebar__nav">
        <a class="is-active" data-kidia-sidebar-view="overview" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms">Overview</a>
        <a data-kidia-sidebar-view="pages" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home">Design Your Pages</a>
        <a data-kidia-sidebar-view="setup" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=setup">Setup Wizard</a>
      </nav>
    </aside>
    <div class="kidia-cms-shell" data-kidia-cms-shell>
      <nav class="kidia-cms-tabs">
        <a class="is-active" data-kidia-page-view="overview" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms">Overview</a>
        <a data-kidia-page-view="home" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home">Home</a>
        <a data-kidia-page-view="setup" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=setup">Setup Wizard</a>
      </nav>
    </div>
    <div data-kidia-background-job-stack>
      <div data-kidia-app-build data-build-persistent data-kidia-background-job="app-build">Persistent build</div>
      <div data-kidia-background-job="abandoned-carts">Persistent cart import</div>
      <div class="kidia-ai-progress-overlay" data-kidia-background-job="generate-offers">Persistent offers</div>
    </div>
    <section data-page-content>Overview content</section>
    </main>
  </div>
</body></html>`;
const dom = new JSDOM(initial, {
  runScripts: "outside-only",
  url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms"
});
dom.window.scrollTo = () => {};
dom.window.kidiaCMSNavigation = {
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

const originalSidebar = dom.window.document.querySelector("[data-kidia-cms-sidebar]");
const originalShell = dom.window.document.querySelector("[data-kidia-cms-shell]");
const originalBuildCard = dom.window.document.querySelector("[data-build-persistent]");
const originalJobStack = dom.window.document.querySelector("[data-kidia-background-job-stack]");
const originalJobCards = Array.from(dom.window.document.querySelectorAll("[data-kidia-background-job]"));
const originalWorkspace = dom.window.document.querySelector("#wpbody-content");
const originalScrollWorkspace = dom.window.document.querySelector("#wpbody");
originalScrollWorkspace.scrollTop = 320;
dom.window.eval(script);
originalSidebar.querySelector('[data-kidia-sidebar-view="pages"]').dispatchEvent(
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
  assert.deepEqual(
    Array.from(dom.window.document.querySelectorAll("[data-kidia-background-job]")),
    originalJobCards,
    "A new background card must remain beside every older card instead of replacing it."
  );
  assert.strictEqual(
    dom.window.document.querySelector("[data-build-persistent]"),
    originalBuildCard,
    "Navigation must retain the exact background build card DOM node."
  );
  assert.strictEqual(
    dom.window.document.querySelector("[data-kidia-background-job-stack]"),
    originalJobStack,
    "Navigation must retain the one shared background-job stack."
  );
  assert.strictEqual(
    dom.window.document.querySelector("#wpbody-content"),
    originalWorkspace,
    "Navigation must retain the exact shared CMS workspace frame."
  );
  assert.equal(dom.window.document.querySelector("[data-page-content]").textContent, "Home content");
  assert.equal(originalScrollWorkspace.scrollTop, 0, "A new CMS view must reset the plugin-owned inner scrollbar.");
  assert.equal(currentSidebar.querySelector("a.is-active").textContent, "Design Your Pages");
  assert.equal(originalShell.hidden, false);
  assert.equal(dom.window.location.search, "?page=kidia-mobile-cms&view=home");
  assert.equal(dom.window.document.body.classList.contains("kidia-cms-builder-screen"), true, "Entering a Builder fragment must restore the fixed body workspace.");
  assert.equal(dom.window.document.documentElement.classList.contains("kidia-cms-builder-screen"), true, "The document root must lock with the Builder body.");

  originalSidebar.querySelector('[data-kidia-sidebar-view="setup"]').dispatchEvent(
    new dom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
  );
  setTimeout(() => {
    assert.equal(dom.window.document.querySelector("[data-page-content]").textContent, "Setup content");
    assert.equal(currentSidebar.querySelector("a.is-active").textContent, "Setup Wizard");
    assert.equal(originalShell.hidden, true);
    assert.equal(dom.window.location.search, "?page=kidia-mobile-cms&view=setup");
    assert.equal(dom.window.document.body.classList.contains("kidia-cms-builder-screen"), false, "Leaving a Builder fragment must release the fixed body workspace.");
    assert.equal(dom.window.document.documentElement.classList.contains("kidia-cms-builder-screen"), false, "The document root must be released with the Builder body.");
    assert.equal(dom.window.document.querySelectorAll("[data-kidia-cms-sidebar]").length, 1);
    assert.equal(dom.window.document.querySelectorAll("[data-kidia-cms-shell]").length, 1);
    assert.strictEqual(dom.window.document.querySelector("[data-build-persistent]"), originalBuildCard, "A second page change must still retain the running or completed build card.");
    assert.deepEqual(Array.from(dom.window.document.querySelectorAll("[data-kidia-background-job]")), originalJobCards, "All three independent job cards must survive repeated navigation together.");
    assert.deepEqual(requestedVersions, ["1.45.60", "1.45.60"], "Every navigation request must carry the running asset version.");

    const staleDom = new JSDOM(`<!doctype html><html><head>
      <link id="legacy-kidia-shell-css" rel="stylesheet" href="https://store.test/wp-content/plugins/kidia-mobile-cms/admin/assets/cms-shell.css?ver=1.45.52-old">
    </head><body class="wp-admin kidia-mobile-cms">
      <main id="wpbody-content">
        <aside data-kidia-cms-sidebar>
          <a data-kidia-sidebar-view="pages" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home">Design Your Pages</a>
        </aside>
        <div class="kidia-cms-shell" data-kidia-cms-shell>
          <a data-kidia-page-view="home" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home">Home</a>
        </div>
        <section data-page-content>Overview content</section>
      </main>
    </body></html>`, {
      runScripts: "outside-only",
      url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms"
    });
    staleDom.window.scrollTo = () => {};
    staleDom.window.kidiaCMSNavigation = {
      ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
      nonce: "test-nonce",
      version: "1.45.60"
    };
    let forcedUrl = "";
    staleDom.window.kidiaCmsHardNavigate = (url) => {
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
            handle: "kidia-mobile-cms-shell",
            src: "https://store.test/wp-content/plugins/kidia-mobile-cms/admin/assets/cms-shell.css?ver=1.45.60-new"
          }],
          scripts: []
        }
      })
    });
    staleDom.window.eval(script);
    staleDom.window.document.querySelector('[data-kidia-sidebar-view="pages"]').dispatchEvent(
      new staleDom.window.MouseEvent("click", { bubbles: true, cancelable: true, button: 0 })
    );
    setTimeout(() => {
      assert.equal(
        forcedUrl,
        "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home",
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
        <link id="kidia-mobile-cms-shell-css" rel="stylesheet" href="https://store.test/wp-content/plugins/kidia-mobile-cms/admin/assets/cms-shell.css?ver=1.45.60-current">
        <script id="jquery-core-js" src="https://store.test/wp-includes/js/jquery/jquery.min.js?ver=3.7.1"></script>
      </head><body class="wp-admin kidia-mobile-cms">
        <main id="wpbody-content">
          <aside data-kidia-cms-sidebar>
            <a data-kidia-sidebar-view="pages" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home">Design Your Pages</a>
          </aside>
          <div class="kidia-cms-shell" data-kidia-cms-shell>
            <a data-kidia-page-view="home" href="https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=home">Home</a>
          </div>
          <section data-page-content>Overview content</section>
        </main>
      </body></html>`, {
        runScripts: "outside-only",
        url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms"
      });
      builderDom.window.scrollTo = () => {};
      builderDom.window.kidiaCMSNavigation = {
        ajaxUrl: "https://store.test/wp-admin/admin-ajax.php",
        nonce: "test-nonce",
        version: "1.45.60"
      };
      let builderForcedUrl = "";
      builderDom.window.kidiaCmsHardNavigate = (url) => {
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
                handle: "kidia-mobile-cms-shell",
                src: "https://store.test/wp-content/plugins/kidia-mobile-cms/admin/assets/cms-shell.css?ver=1.45.60-current"
              },
              {
                handle: "kidia-mobile-fixed-chrome",
                src: "https://store.test/wp-content/plugins/kidia-mobile-cms/admin/assets/page-builder.css?ver=1.45.60"
              }
            ],
            scripts: [
              {
                handle: "jquery-core",
                src: "https://store.test/wp-includes/js/jquery/jquery.min.js?ver=3.7.2"
              },
              {
                handle: "kidia-mobile-splash-screen",
                src: "https://store.test/wp-content/plugins/kidia-mobile-cms/admin/assets/splash-screen.js?ver=1.45.60"
              }
            ]
          }
        })
      });
      const builderSidebar = builderDom.window.document.querySelector("[data-kidia-cms-sidebar]");
      const builderShell = builderDom.window.document.querySelector("[data-kidia-cms-shell]");
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
      builderSidebar.querySelector('[data-kidia-sidebar-view="pages"]').dispatchEvent(
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
        assert.strictEqual(builderDom.window.document.querySelector("[data-kidia-cms-sidebar]"), builderSidebar, "Builder navigation must retain the sidebar DOM node.");
        assert.strictEqual(builderDom.window.document.querySelector("[data-kidia-cms-shell]"), builderShell, "Builder navigation must retain the shared frame DOM node.");
        assert.equal(builderDom.window.document.querySelector("[data-page-content]").textContent, "Home Builder content");
        assert.equal(builderAssetSawPage, "Home Builder content", "Customize scripts must execute only after their new page markup exists.");
        assert.equal(builderDom.window.document.querySelector("#wpbody-content").classList.contains("is-kidia-page-loading"), false);
        console.log("Persistent CMS sidebar and asset version runtime tests passed.");
      }, 70);
    }, 25);
  }, 25);
}, 25);
