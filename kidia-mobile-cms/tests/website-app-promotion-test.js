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
  /data-preview-device="mobile"[\s\S]*data-preview-device="desktop"[\s\S]*data-promotion-preview/,
  "The campaign builder must include mobile and desktop live previews.",
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
  publicCss,
  /@media\(max-width:767px\)[\s\S]*desktop_qr\{display:none!important\}/,
  "Desktop QR cards must never crowd mobile screens.",
);
assert.match(
  publicCss,
  /prefers-reduced-motion:reduce/,
  "Campaign motion must respect accessibility preferences.",
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

const dom = new JSDOM(
  `<!doctype html><body>
    <div data-kidia-app-promo-slot="inline"></div>
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
  smartBanner.querySelector(".kidia-app-promo__dismiss").click();
  assert.ok(
    Number(
      dom.window.localStorage.getItem(
        "kidia_app_promo_dismissed_v1_smart_banner",
      ),
    ) > 0,
    "Dismissing one campaign must remember that campaign's frequency.",
  );
  console.log("Website app promotion tests passed.");
}, 20);
