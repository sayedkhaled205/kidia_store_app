"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const root = path.resolve(__dirname, "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");

const bootstrap = read("includes", "class-kidia-mobile-cms.php");
const service = read(
  "includes",
  "class-kidia-mobile-website-app-promotion.php",
);
const admin = read("admin", "class-kidia-mobile-cms-admin.php");
const template = read("admin", "pages", "website-app-promotion.php");
const adminScript = read("admin", "assets", "website-app-promotion.js");
const adminCss = read("admin", "assets", "website-app-promotion.css");
const shellCss = read("admin", "assets", "cms-shell.css");
const publicScript = read("public", "assets", "website-app-promotion.js");
const publicCss = read("public", "assets", "website-app-promotion.css");

assert.match(
  bootstrap,
  /class-kidia-mobile-website-app-promotion\.php[\s\S]*Kidia_Mobile_Website_App_Promotion\(\)\)->register/,
  "The website promotion engine must load and register with the plugin.",
);
for (const hook of [
  "wp_enqueue_scripts",
  "wp_head",
  "wp_body_open",
  "wp_footer",
  "add_shortcode",
  "admin_post_kidia_mobile_save_website_app_promotion",
  "wp_ajax_kidia_mobile_app_promotion_event",
  "wp_ajax_nopriv_kidia_mobile_app_promotion_event",
]) {
  assert.match(service, new RegExp(hook), `${hook} must be registered.`);
}
for (const campaign of [
  "smart_banner",
  "bottom_sheet",
  "popup",
  "desktop_qr",
  "floating_button",
  "inline_banner",
]) {
  assert.match(
    service,
    new RegExp(`'${campaign}'\\s*=>\\s*array`),
    `${campaign} must have persisted defaults.`,
  );
  assert.match(
    template,
    new RegExp(`data-promotion-type="${campaign}"|${campaign}`),
    `${campaign} must be editable in the admin page.`,
  );
  assert.match(
    publicScript,
    new RegExp(campaign),
    `${campaign} must render on the website.`,
  );
}
for (const setting of [
  "android_url",
  "ios_url",
  "huawei_url",
  "smart_url",
  "deep_link",
  "audience_devices",
  "audience_users",
  "page_target",
  "frequency",
  "coupon_code",
]) {
  assert.match(service, new RegExp(setting), `${setting} must be sanitized.`);
  assert.match(template, new RegExp(setting), `${setting} must be configurable.`);
}
assert.match(
  service,
  /app-id=[\s\S]*apple-itunes-app/,
  "Safari's native Apple Smart App Banner must be supported.",
);
assert.match(
  service,
  /check_admin_referer\([\s\S]*sanitize\(\s*\$submitted\s*\)/,
  "Saving campaigns must verify a nonce and sanitize every setting.",
);
assert.match(
  service,
  /check_ajax_referer[\s\S]*rate_limited[\s\S]*METRICS_OPTION/,
  "Public campaign metrics must be nonce-protected and rate-limited.",
);
assert.match(
  admin,
  /kidia-mobile-website-app-promotion[\s\S]*website_promotion[\s\S]*Promote App on Website/,
  "The campaign builder must be a first-class CMS sidebar page.",
);
assert.match(
  admin,
  /'website_promotion'\s*=>[\s\S]*'dashicons-smartphone'/,
  "The website promotion sidebar item must use a clear app icon.",
);
assert.match(
  shellCss,
  /\.kidia-cms-sidebar\{[\s\S]*inset-inline-start:-16px;[\s\S]*width:236px;/,
  "The sidebar must widen into the outer gutter without moving the content edge.",
);
assert.match(
  shellCss,
  /\.kidia-cms-sidebar__nav a:focus,[\s\S]*box-shadow:inset 0 0 0 2px #2f806e;/,
  "Sidebar keyboard focus must use the Kidia brand color instead of WordPress blue.",
);
assert.match(
  admin,
  /website-app-promotion\.css[\s\S]*website-app-promotion\.js/,
  "The admin page must load isolated campaign assets.",
);
assert.match(
  template,
  /Campaign views[\s\S]*Download clicks[\s\S]*Click rate[\s\S]*Dismissed/,
  "The page must show useful conversion metrics.",
);
assert.match(
  template,
  /data-preview-device="mobile"[\s\S]*class="is-active" data-preview-device="desktop"[\s\S]*kidia-promotion-device is-desktop/,
  "The campaign builder must open on the laptop preview while keeping mobile available.",
);
assert.match(
  template,
  /Kidia_Mobile_Website_App_Promotion::preview_url\(\)[\s\S]*data-promotion-site-frame/,
  "The campaign preview must load the current customer's real website.",
);
assert.doesNotMatch(
  template,
  /kidia-promotion-store__(?:hero|cards|lines)/,
  "The real website preview must replace the old decorative skeleton.",
);
assert.match(
  service,
  /preview_url\(\)[\s\S]*wp_create_nonce\([\s\S]*home_url\(\s*'\/'\s*\)/,
  "The live preview URL must be dynamic per WordPress installation and nonce protected.",
);
assert.match(
  service,
  /test_url\([\s\S]*TEST_NONCE_QUERY[\s\S]*wp_create_nonce\(\s*self::TEST_ACTION/,
  "Every campaign must expose a nonce-protected private live test URL.",
);
assert.match(
  template,
  /data-test-campaign=[\s\S]*Test on live site/,
  "Each campaign card must provide a real website test action.",
);
assert.match(
  service,
  /site_logo_url\([\s\S]*custom_logo[\s\S]*get_site_icon_url/,
  "Campaigns must fall back to the website brand mark instead of a text initial.",
);
assert.match(
  service,
  /is_preview_request\(\)[\s\S]*current_user_can\(\s*'manage_options'\s*\)[\s\S]*wp_verify_nonce/,
  "Only an authenticated administrator may suppress saved campaigns in preview mode.",
);
assert.match(
  service,
  /enqueue_assets\(\)[\s\S]*is_preview_request\(\)[\s\S]*render_footer\(\)[\s\S]*is_preview_request\(\)/,
  "Preview mode must prevent the saved campaign from rendering behind the draft overlay.",
);
assert.match(
  service,
  /add_action\(\s*'wp_footer',\s*array\(\s*\$this,\s*'render_footer'\s*\),\s*5\s*\)/,
  "The promotion root must be printed before WordPress footer scripts run at priority 20.",
);
assert.match(
  publicScript,
  /document\.readyState === "loading"[\s\S]*DOMContentLoaded[\s\S]*boot/,
  "Website promotion rendering must wait until late footer markup is available.",
);
assert.match(
  publicScript,
  /if \(!root\)[\s\S]*document\.createElement\("div"\)[\s\S]*kidiaAppPromoRoot[\s\S]*append\(root\)/,
  "The frontend must create its own promotion root when a theme omits the footer slot.",
);
assert.match(
  service,
  /data-kidia-app-promo-config[\s\S]*wp_json_encode\([\s\S]*frontend_config/,
  "The footer must embed a cache-safe copy of the live promotion config.",
);
assert.match(
  service,
  /purge_frontend_cache\(\)[\s\S]*breeze_clear_all_cache[\s\S]*litespeed_purge_all/,
  "Publishing campaigns must invalidate common WordPress and hosting page caches.",
);
assert.match(
  publicScript,
  /readConfig[\s\S]*data-kidia-app-promo-config[\s\S]*bootAttempts[\s\S]*setTimeout\(boot, 250\)/,
  "The frontend must recover when optimization changes config and script order.",
);
assert.match(
  template,
  /\[woo_mobile_app_promo\]/,
  "Inline promotions must expose a placement shortcode.",
);
assert.match(
  adminScript,
  /selectCampaign[\s\S]*renderPreview[\s\S]*wp\.media[\s\S]*clipboard/,
  "Campaign selection, live preview, media selection and shortcode copy must work.",
);
assert.match(
  adminCss,
  /\.kidia-app-promotion-workspace[\s\S]*grid-template-columns:minmax\(0,1fr\) 370px/,
  "The editor must keep a dedicated sticky preview rail.",
);
assert.match(
  adminCss,
  /is-desktop-preview \.kidia-app-promotion-workspace\{grid-template-columns:minmax\(0,1fr\)\}[\s\S]*is-desktop-preview \.kidia-app-promotion-preview\{grid-row:1;position:relative;top:auto;width:100%;max-width:none\}/,
  "Desktop preview mode must place the laptop preview at full page width above the editor.",
);
assert.match(
  adminCss,
  /\.kidia-promotion-device-switch\{[\s\S]*gap:8px[\s\S]*\.kidia-promotion-device-switch button\{[\s\S]*width:36px[\s\S]*min-width:36px/,
  "Mobile and laptop controls must have separate non-overlapping click targets.",
);
assert.match(
  adminCss,
  /\.kidia-promotion-device\.is-desktop \.kidia-promotion-browser\{width:1366px;height:768px/,
  "The desktop website preview must use a real 1366 by 768 laptop viewport.",
);
assert.match(
  adminCss,
  /\.kidia-promotion-live-site iframe\{[\s\S]*width:100%;height:100%;border:0/,
  "The customer's website iframe must fill the laptop viewport.",
);
assert.match(
  adminScript,
  /previewSizes[\s\S]*desktop:\s*\{\s*width:\s*1366,\s*height:\s*768\s*\}[\s\S]*is-desktop-preview/,
  "Desktop selection must switch to the real laptop viewport.",
);
assert.match(
  adminScript,
  /resizePreview[\s\S]*--preview-scale[\s\S]*ResizeObserver/,
  "The laptop preview must rescale automatically when its available width changes.",
);
assert.match(
  publicScript,
  /pageAllowed[\s\S]*deviceAllowed[\s\S]*visitorAllowed/,
  "Website rendering must enforce page, device and visitor targeting.",
);
assert.match(
  publicScript,
  /frequency[\s\S]*sessionStorage[\s\S]*localStorage/,
  "Dismissal frequency must persist per campaign.",
);
assert.match(
  publicScript,
  /settings\.deep_link[\s\S]*visibilityState[\s\S]*window\.location\.href = fallback/,
  "App deep links must safely fall back to the matching app store.",
);
assert.match(
  publicScript,
  /new window\.QRCode/,
  "Desktop cards must generate a real scannable QR code.",
);
assert.match(
  publicScript,
  /requiresDestination[\s\S]*desktop_qr[\s\S]*floating_button[\s\S]*!campaignDestination[\s\S]*!isTestMode/,
  "Message campaigns must not disappear just because no app-store destination has been published yet.",
);
assert.match(
  publicCss,
  /@media\(max-width:767px\)[\s\S]*desktop_qr:not\(\.is-test\)\{display:none!important\}/,
  "Desktop QR cards must never crowd mobile screens.",
);
assert.match(
  publicScript,
  /settings\.popup\?\.enabled[\s\S]*!\(isMobile && settings\.bottom_sheet\?\.enabled\)/,
  "Mobile visitors must never receive a duplicate popup over the enabled bottom sheet.",
);
assert.match(
  admin,
  /website-app-promotion-preview[\s\S]*public\/assets\/website-app-promotion\.css[\s\S]*website-app-promotion-admin/,
  "Admin preview and live campaigns must share the same visual stylesheet.",
);
assert.match(
  publicCss,
  /prefers-reduced-motion:reduce/,
  "Campaign motion must respect accessibility preferences.",
);
assert.match(
  publicCss,
  /\.kidia-app-promo\{[\s\S]*--kidia-app-promo-soft:color-mix/,
  "Campaigns moved outside the root must keep an opaque themed surface.",
);
assert.match(
  service,
  /data-kidia-app-promo-placement="after_header"[\s\S]*data-kidia-app-promo-placement="before_footer"/,
  "Automatic inline slots must declare their intended theme placement.",
);
assert.match(
  publicScript,
  /placeInlineSlot[\s\S]*after_header[\s\S]*header\.after\(slot\)[\s\S]*before_footer[\s\S]*footer\.before\(slot\)/,
  "Automatic inline campaigns must be moved beside the real theme header or footer.",
);
assert.equal(
  fs.existsSync(path.join(root, "public", "assets", "vendor", "qrcode.min.js")),
  true,
  "The QR generator must be bundled without a third-party runtime dependency.",
);
assert.equal(
  fs.existsSync(path.join(root, "public", "assets", "vendor", "qrcode.LICENSE")),
  true,
  "The bundled QR generator must preserve its license.",
);

const adminMarkup = `
    <div data-promotion-admin>
      <form data-promotion-form></form>
      <div class="kidia-app-promotion-state">Campaigns paused</div>
      <input type="checkbox" data-promotion-master>
      <span data-promotion-master-label>Off</span>
      <article data-promotion-type="smart_banner"><strong>Smart Banner</strong><input type="checkbox"></article>
      <div data-promotion-campaign-panel="smart_banner"></div>
      <small data-preview-campaign-label></small>
      <button data-preview-device="mobile" aria-pressed="false"></button>
      <button data-preview-device="desktop" aria-pressed="true"></button>
      <div data-promotion-preview>
        <div data-promotion-screen><div data-promotion-browser><div data-preview-output></div></div></div>
      </div>
    </div>
`;
const adminDom = new JSDOM(
  "<!doctype html><body></body>",
  { runScripts: "outside-only", url: "https://store.example/wp-admin/admin.php" },
);
adminDom.window.ResizeObserver = class ResizeObserver {
  constructor(callback) {
    this.callback = callback;
  }
  observe() {
    this.callback();
  }
};
adminDom.window.requestAnimationFrame = (callback) => callback();
adminDom.window.eval(adminScript);
adminDom.window.document.body.innerHTML = adminMarkup;
const adminPreview = adminDom.window.document.querySelector(
  "[data-promotion-preview]",
);
Object.defineProperty(adminPreview, "clientWidth", { value: 700 });
adminDom.window.document.dispatchEvent(
  new adminDom.window.CustomEvent("kidia:cms-page-ready"),
);
assert.equal(
  adminDom.window.document
    .querySelector("[data-promotion-admin]")
    .classList.contains("is-desktop-preview"),
  true,
  "The campaign builder must expand the laptop preview rail by default.",
);
assert.equal(
  adminDom.window.document
    .querySelector('[data-preview-device="desktop"]')
    .classList.contains("is-active"),
  true,
  "The laptop control must be selected by default.",
);
adminDom.window.document
  .querySelector('[data-preview-device="mobile"]')
  .click();
assert.equal(
  adminDom.window.document
    .querySelector("[data-promotion-preview]")
    .classList.contains("is-mobile"),
  true,
  "The mobile control must still switch the live preview after fragment navigation.",
);
assert.equal(
  adminDom.window.document
    .querySelector('[data-preview-device="mobile"]')
    .getAttribute("aria-pressed"),
  "true",
  "The selected device control must expose its active state.",
);
adminDom.window.document
  .querySelector('[data-preview-device="desktop"]')
  .click();
assert.equal(
  adminDom.window.document.querySelector("[data-promotion-screen]").style.width,
  "700px",
  "The 1366px laptop viewport must scale to the available preview width.",
);
assert.equal(
  adminDom.window.document.querySelector("[data-promotion-screen]").style.height,
  "394px",
  "Responsive scaling must preserve the laptop aspect ratio.",
);
assert.ok(
  adminDom.window.document.querySelector(
    "[data-preview-output] .kidia-app-promo--smart_banner",
  ),
  "The editor preview must render the same campaign component used by the live website.",
);
assert.equal(
  adminDom.window.document.querySelector(".kidia-preview-promo"),
  null,
  "The retired approximate preview component must not be used.",
);
const campaignToggle = adminDom.window.document.querySelector(
  '[data-promotion-type="smart_banner"] input[type="checkbox"]',
);
campaignToggle.checked = true;
campaignToggle.dispatchEvent(
  new adminDom.window.Event("change", { bubbles: true }),
);
assert.equal(
  adminDom.window.document.querySelector("[data-promotion-master]").checked,
  true,
  "Enabling a campaign must also enable the master publishing switch.",
);
assert.equal(
  adminDom.window.document.querySelector("[data-promotion-master-label]")
    .textContent,
  "On",
  "Automatically enabling publishing must update the visible master state.",
);

const dom = new JSDOM(
  `<!doctype html><body>
    <header id="header">Store header</header>
    <main>Store content</main>
    <div data-kidia-app-promo-slot="inline" data-kidia-app-promo-placement="after_header"></div>
    <div data-kidia-app-promo-slot="inline" data-kidia-app-promo-placement="before_footer"></div>
    <footer id="footer">Store footer</footer>
    <div data-kidia-app-promo-root></div>
  </body>`,
  {
    runScripts: "outside-only",
    url: "https://store.example/shop/",
  },
);
dom.window.matchMedia = () => ({ matches: true });
dom.window.navigator.sendBeacon = () => true;
dom.window.QRCode = function QRCode(holder) {
  holder.append(dom.window.document.createElement("canvas"));
};
dom.window.QRCode.CorrectLevel = { M: 0 };
dom.window.KidiaAppPromotion = {
  ajaxUrl: "https://store.example/wp-admin/admin-ajax.php",
  nonce: "nonce",
  loggedIn: false,
  page: { type: "shop", path: "/shop/" },
  settings: {
    enabled: true,
    app_name: "Kidia",
    tagline: "Shop faster",
    description: "Download the app",
    logo_url: "",
    primary_color: "#2f806e",
    text_color: "#15352d",
    surface_color: "#ffffff",
    button_label: "Download app",
    dismiss_label: "Not now",
    offer_text: "10% app discount",
    coupon_code: "APP10",
    android_url: "https://play.google.com/store/apps/details?id=test",
    ios_url: "https://apps.apple.com/app/id1",
    huawei_url: "",
    smart_url: "https://store.example/app",
    deep_link: "",
    qr_url: "",
    audience_devices: "all",
    audience_users: "all",
    page_target: "all",
    custom_paths: "",
    excluded_paths: "/checkout/order-received/",
    frequency: "daily",
    smart_banner: { enabled: true, position: "top", delay: 0 },
    bottom_sheet: { enabled: false },
    popup: { enabled: false },
    desktop_qr: { enabled: false },
    floating_button: { enabled: false },
    inline_banner: { enabled: true, style: "coupon" },
  },
};
dom.window.eval(publicScript);

const qrDom = new JSDOM(
  `<!doctype html><body><div data-kidia-app-promo-root></div></body>`,
  {
    runScripts: "outside-only",
    url: "https://store.example/",
  },
);
let generatedQrDestination = "";
qrDom.window.matchMedia = () => ({ matches: false });
qrDom.window.navigator.sendBeacon = () => true;
qrDom.window.QRCode = function QRCode(holder, options) {
  generatedQrDestination = options.text;
  holder.append(qrDom.window.document.createElement("canvas"));
};
qrDom.window.QRCode.CorrectLevel = { M: 0 };
qrDom.window.KidiaAppPromotion = {
  ajaxUrl: "https://store.example/wp-admin/admin-ajax.php",
  nonce: "nonce",
  loggedIn: false,
  page: { type: "home", path: "/" },
  settings: {
    enabled: true,
    app_name: "Kidia",
    tagline: "Scan to download",
    primary_color: "#2f806e",
    text_color: "#15352d",
    surface_color: "#ffffff",
    button_label: "Download app",
    dismiss_label: "Not now",
    android_url: "",
    ios_url: "",
    huawei_url: "",
    smart_url: "",
    deep_link: "",
    qr_url: "https://download.example/kidia",
    audience_devices: "all",
    audience_users: "all",
    page_target: "all",
    custom_paths: "",
    excluded_paths: "",
    frequency: "always",
    smart_banner: { enabled: false },
    bottom_sheet: { enabled: false },
    popup: { enabled: false },
    desktop_qr: {
      enabled: true,
      position: "bottom-right",
      delay: 0,
    },
    floating_button: { enabled: false },
    inline_banner: { enabled: false },
  },
};
qrDom.window.eval(publicScript);

const lateRootDom = new JSDOM(
  "<!doctype html><body><main>Home page</main></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/",
  },
);
lateRootDom.window.matchMedia = () => ({ matches: false });
lateRootDom.window.navigator.sendBeacon = () => true;
lateRootDom.window.QRCode = function QRCode(holder) {
  holder.append(lateRootDom.window.document.createElement("canvas"));
};
lateRootDom.window.QRCode.CorrectLevel = { M: 0 };
lateRootDom.window.KidiaAppPromotion = JSON.parse(
  JSON.stringify(qrDom.window.KidiaAppPromotion),
);
lateRootDom.window.KidiaAppPromotion.settings.page_target = "home";

lateRootDom.window.eval(publicScript);
const lateRoot = lateRootDom.window.document.createElement("div");
lateRoot.dataset.kidiaAppPromoRoot = "";
lateRootDom.window.document.body.append(lateRoot);
lateRootDom.window.document.dispatchEvent(
  new lateRootDom.window.Event("DOMContentLoaded"),
);

const missingRootDom = new JSDOM(
  "<!doctype html><body><main>Theme without a promotion footer root</main></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/",
  },
);
missingRootDom.window.matchMedia = () => ({ matches: false });
missingRootDom.window.navigator.sendBeacon = () => true;
missingRootDom.window.QRCode = function QRCode(holder) {
  holder.append(missingRootDom.window.document.createElement("canvas"));
};
missingRootDom.window.QRCode.CorrectLevel = { M: 0 };
missingRootDom.window.KidiaAppPromotion = JSON.parse(
  JSON.stringify(qrDom.window.KidiaAppPromotion),
);
missingRootDom.window.KidiaAppPromotion.settings.page_target = "home";
missingRootDom.window.eval(publicScript);
missingRootDom.window.document.dispatchEvent(
  new missingRootDom.window.Event("DOMContentLoaded"),
);

const delayedConfigDom = new JSDOM(
  "<!doctype html><body><main>Cached home markup</main></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/",
  },
);
delayedConfigDom.window.matchMedia = () => ({ matches: false });
delayedConfigDom.window.navigator.sendBeacon = () => true;
delayedConfigDom.window.QRCode = function QRCode(holder) {
  holder.append(delayedConfigDom.window.document.createElement("canvas"));
};
delayedConfigDom.window.QRCode.CorrectLevel = { M: 0 };
const qrOnlyConfig = JSON.parse(JSON.stringify(qrDom.window.KidiaAppPromotion));
qrOnlyConfig.settings.page_target = "home";
qrOnlyConfig.settings.smart_banner = { enabled: true, position: "top", delay: 0 };
delayedConfigDom.window.eval(publicScript);
delayedConfigDom.window.document.dispatchEvent(
  new delayedConfigDom.window.Event("DOMContentLoaded"),
);
const embeddedConfig = delayedConfigDom.window.document.createElement("script");
embeddedConfig.type = "application/json";
embeddedConfig.dataset.kidiaAppPromoConfig = "";
embeddedConfig.textContent = JSON.stringify(qrOnlyConfig);
delayedConfigDom.window.document.body.append(embeddedConfig);
delayedConfigDom.window.document.dispatchEvent(
  new delayedConfigDom.window.Event("kidia:app-promotion-config-ready"),
);

const messageOnlyDom = new JSDOM(
  "<!doctype html><body><main>Campaign without a published store URL</main><div data-kidia-app-promo-root></div></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/",
  },
);
messageOnlyDom.window.matchMedia = () => ({ matches: false });
messageOnlyDom.window.navigator.sendBeacon = () => true;
messageOnlyDom.window.QRCode = function QRCode(holder) {
  holder.append(messageOnlyDom.window.document.createElement("canvas"));
};
messageOnlyDom.window.QRCode.CorrectLevel = { M: 0 };
messageOnlyDom.window.KidiaAppPromotion = {
  ajaxUrl: "https://store.example/wp-admin/admin-ajax.php",
  nonce: "nonce",
  loggedIn: false,
  page: { type: "home", path: "/" },
  settings: {
    enabled: true,
    app_name: "Kidia",
    tagline: "The app is coming soon",
    primary_color: "#2f806e",
    text_color: "#15352d",
    surface_color: "#ffffff",
    button_label: "Download app",
    dismiss_label: "Not now",
    android_url: "",
    ios_url: "",
    huawei_url: "",
    smart_url: "",
    deep_link: "",
    qr_url: "",
    audience_devices: "all",
    audience_users: "all",
    page_target: "all",
    custom_paths: "",
    excluded_paths: "",
    frequency: "always",
    smart_banner: { enabled: true, position: "top", delay: 0 },
    bottom_sheet: { enabled: false },
    popup: { enabled: false },
    desktop_qr: { enabled: true, position: "bottom-right", delay: 0 },
    floating_button: { enabled: true, position: "bottom-left" },
    inline_banner: { enabled: false },
  },
};
messageOnlyDom.window.eval(publicScript);

const privateQrTestDom = new JSDOM(
  "<!doctype html><body><main>Private campaign test</main><div data-kidia-app-promo-root></div></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/?kidia_app_promotion_test=desktop_qr",
  },
);
privateQrTestDom.window.matchMedia = () => ({ matches: false });
privateQrTestDom.window.navigator.sendBeacon = () => true;
privateQrTestDom.window.QRCode = function QRCode(holder) {
  holder.append(privateQrTestDom.window.document.createElement("canvas"));
};
privateQrTestDom.window.QRCode.CorrectLevel = { M: 0 };
privateQrTestDom.window.KidiaAppPromotion = JSON.parse(
  JSON.stringify(messageOnlyDom.window.KidiaAppPromotion),
);
privateQrTestDom.window.KidiaAppPromotion.testCampaign = "desktop_qr";
privateQrTestDom.window.KidiaAppPromotion.labels = {
  comingSoon: "Coming soon",
  needsLink: "Add an app link",
  testPreview: "Private live test",
};
privateQrTestDom.window.eval(publicScript);

const privateFloatingTestDom = new JSDOM(
  "<!doctype html><body><main>Private floating test</main><div data-kidia-app-promo-root></div></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/?kidia_app_promotion_test=floating_button",
  },
);
privateFloatingTestDom.window.matchMedia = () => ({ matches: false });
privateFloatingTestDom.window.navigator.sendBeacon = () => true;
privateFloatingTestDom.window.KidiaAppPromotion = JSON.parse(
  JSON.stringify(privateQrTestDom.window.KidiaAppPromotion),
);
privateFloatingTestDom.window.KidiaAppPromotion.testCampaign =
  "floating_button";
privateFloatingTestDom.window.eval(publicScript);

const mobileConflictDom = new JSDOM(
  "<!doctype html><body><main>Mobile campaign orchestration</main><div data-kidia-app-promo-root></div></body>",
  {
    runScripts: "outside-only",
    url: "https://store.example/",
  },
);
mobileConflictDom.window.matchMedia = () => ({ matches: true });
mobileConflictDom.window.navigator.sendBeacon = () => true;
mobileConflictDom.window.KidiaAppPromotion = JSON.parse(
  JSON.stringify(messageOnlyDom.window.KidiaAppPromotion),
);
mobileConflictDom.window.KidiaAppPromotion.settings.smart_banner.enabled = false;
mobileConflictDom.window.KidiaAppPromotion.settings.bottom_sheet = {
  enabled: true,
  trigger: "immediate",
  delay: 0,
  style: "compact",
};
mobileConflictDom.window.KidiaAppPromotion.settings.popup = {
  enabled: true,
  trigger: "delay",
  delay: 0,
  style: "split",
};
mobileConflictDom.window.eval(publicScript);

setTimeout(() => {
  const smartBanner = dom.window.document.querySelector(
    ".kidia-app-promo--smart_banner",
  );
  assert.ok(smartBanner, "The enabled Smart Banner must render.");
  assert.equal(
    smartBanner.querySelector(".kidia-app-promo__copy strong").textContent,
    "Kidia",
    "The live campaign must use saved app identity.",
  );
  assert.equal(
    smartBanner.querySelector(".kidia-app-promo__coupon").textContent,
    "APP10",
    "The app-only coupon must appear in the website campaign.",
  );
  assert.ok(
    dom.window.document.querySelector(
      '[data-kidia-app-promo-slot="inline"] .kidia-app-promo--inline_banner',
    ),
    "Shortcode and automatic inline slots must receive a real banner.",
  );
  assert.equal(
    dom.window.document.querySelector("#header").nextElementSibling,
    dom.window.document.querySelector(
      '[data-kidia-app-promo-placement="after_header"]',
    ),
    "After-header campaigns must sit after the real theme header instead of above it.",
  );
  assert.equal(
    dom.window.document.querySelector("#footer").previousElementSibling,
    dom.window.document.querySelector(
      '[data-kidia-app-promo-placement="before_footer"]',
    ),
    "Before-footer campaigns must sit before the real theme footer instead of below it.",
  );
  smartBanner.querySelector(".kidia-app-promo__dismiss").click();
  assert.ok(
    Number(
      dom.window.localStorage.getItem(
        "kidia_app_promo_dismissed_v1_smart_banner",
      ),
    ) > 0,
    "Dismissing one campaign must remember that campaign's frequency.",
  );
  const desktopQr = qrDom.window.document.querySelector(
    ".kidia-app-promo--desktop_qr",
  );
  assert.ok(
    desktopQr,
    "The Desktop QR Card must render when only its custom QR destination is configured.",
  );
  assert.equal(
    generatedQrDestination,
    "https://download.example/kidia",
    "The generated desktop QR code must use the custom QR destination.",
  );
  assert.equal(
    desktopQr.querySelector(".kidia-app-promo__action").href,
    "https://download.example/kidia",
    "The Desktop QR Card action must use the same custom destination.",
  );
  assert.ok(
    lateRootDom.window.document.querySelector(
      ".kidia-app-promo--desktop_qr",
    ),
    "Home-only Desktop QR must render when its script loads before the footer root.",
  );
  assert.ok(
    missingRootDom.window.document.querySelector(
      "[data-kidia-app-promo-root] .kidia-app-promo--desktop_qr",
    ),
    "Home-only Desktop QR must render even when the active theme never prints a promotion root.",
  );
  assert.ok(
    delayedConfigDom.window.document.querySelector(
      ".kidia-app-promo--smart_banner",
    ),
    "A QR-only destination must still power the enabled Smart Banner on Home.",
  );
  assert.ok(
    delayedConfigDom.window.document.querySelector(
      ".kidia-app-promo--desktop_qr",
    ),
    "The Desktop QR card must recover when its embedded config arrives after the script.",
  );
  assert.equal(
    delayedConfigDom.window.document.querySelector(
      "[data-kidia-app-promo-root]",
    ).dataset.kidiaAppPromoStatus,
    "ready",
    "The real frontend root must expose a successful runtime state.",
  );
  const messageOnlyBanner = messageOnlyDom.window.document.querySelector(
    ".kidia-app-promo--smart_banner",
  );
  assert.ok(
    messageOnlyBanner,
    "An enabled message campaign must render even before an app-store URL is available.",
  );
  assert.equal(
    messageOnlyBanner.querySelector(".kidia-app-promo__action"),
    null,
    "A message-only campaign must not expose a fake # download action.",
  );
  assert.equal(
    messageOnlyDom.window.document.querySelector(
      ".kidia-app-promo--desktop_qr",
    ),
    null,
    "A QR campaign must stay hidden until it has a destination to encode.",
  );
  assert.equal(
    messageOnlyDom.window.document.querySelector(
      ".kidia-app-promo--floating_button",
    ),
    null,
    "A destinationless floating button must not create a dead control.",
  );
  const privateQrCard = privateQrTestDom.window.document.querySelector(
    ".kidia-app-promo--desktop_qr.is-test",
  );
  assert.ok(
    privateQrCard,
    "Private live test mode must show the Desktop QR design before a store URL exists.",
  );
  assert.ok(
    privateQrCard.querySelector(".kidia-app-promo__qr-placeholder"),
    "A destinationless QR test must use an honest placeholder instead of a fake code.",
  );
  assert.equal(
    privateQrCard.querySelector(".kidia-app-promo__action"),
    null,
    "Private QR tests must not expose a fake download action.",
  );
  const privateFloatingButton =
    privateFloatingTestDom.window.document.querySelector(
      ".kidia-app-promo--floating_button.is-test",
    );
  assert.ok(
    privateFloatingButton,
    "Private live test mode must show the floating button before a store URL exists.",
  );
  assert.equal(
    privateFloatingButton.getAttribute("aria-disabled"),
    "true",
    "A test-only destinationless floating button must clearly expose its disabled state.",
  );
  assert.ok(
    mobileConflictDom.window.document.querySelector(
      '[data-kidia-app-promotion="bottom_sheet"]',
    ),
    "The enabled mobile bottom sheet must render.",
  );
  assert.equal(
    mobileConflictDom.window.document.querySelector(
      '[data-kidia-app-promotion="popup"]',
    ),
    null,
    "The mobile popup must defer when the bottom sheet is enabled.",
  );
  console.log("Website app promotion tests passed.");
}, 20);
