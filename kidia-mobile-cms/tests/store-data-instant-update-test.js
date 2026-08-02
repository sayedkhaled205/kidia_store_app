"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const pluginRoot = path.resolve(__dirname, "..");
const shellScript = fs.readFileSync(
  path.join(pluginRoot, "admin", "assets", "cms-shell.js"),
  "utf8",
);
const shellCss = fs.readFileSync(
  path.join(pluginRoot, "admin", "assets", "cms-shell.css"),
  "utf8",
);
const storeDataPage = fs.readFileSync(
  path.join(pluginRoot, "admin", "pages", "store-data.php"),
  "utf8",
);

assert.match(storeDataPage, /data-kidia-instant-filter="date"/);
assert.match(storeDataPage, /data-kidia-reporting-filter="1"[\s\S]*data-kidia-generate-store-reporting/);
assert.match(storeDataPage, /data-kidia-instant-filter="products"/);
assert.match(storeDataPage, /data-kidia-instant-filter="coupons"/);
assert.match(storeDataPage, /data-kidia-instant-action="coupon-channel"/);
assert.match(shellCss, /kidia-cms-js \[data-kidia-instant-submit-fallback\]\{display:none!important\}/);
assert.match(
  shellScript,
  /isStoreDataView[\s\S]*canUseCache = !isStoreDataView[\s\S]*window\.kidiaCmsNavigate/,
  "Store Data navigation must always bypass stale view-cache entries.",
);
assert.match(
  shellScript,
  /kidia:cms-page-ready[\s\S]*initLiveStoreData\(document\)/,
  "Live Reports and Analytics refresh must restart after persistent navigation.",
);

(async () => {
  const dom = new JSDOM(
    `<!doctype html><html><body>
      <form method="get" data-kidia-instant-filter="products">
        <input type="hidden" name="page" value="kidia-mobile-store-data">
        <input type="hidden" name="store_tab" value="products">
        <input type="search" name="product_search" value="">
        <select name="product_visibility">
          <option value="all" selected>All</option>
          <option value="hidden_mobile">Hidden from mobile</option>
        </select>
        <button type="submit" data-kidia-instant-submit-fallback>Search</button>
      </form>
      <form method="get" data-kidia-instant-filter="date" data-kidia-reporting-filter="1" data-kidia-reporting-ready="0">
        <input type="hidden" name="page" value="kidia-mobile-store-data">
        <input type="hidden" name="store_tab" value="analytics">
        <select name="date_preset">
          <option value="today" selected>Today</option>
          <option value="last_7_days">Last 7 days</option>
          <option value="custom">Custom</option>
        </select>
        <input type="date" name="date_from" value="2026-07-01" disabled>
        <input type="date" name="date_to" value="2026-07-31" disabled>
        <button type="button" data-kidia-generate-store-reporting>Generate</button>
      </form>
      <form method="post" action="https://store.test/wp-admin/admin-post.php" data-kidia-instant-action="coupon-channel">
        <input type="hidden" name="action" value="kidia_mobile_set_coupon_channel">
        <input type="hidden" name="coupon_id" value="31">
        <select name="coupon_channel" data-kidia-saved-value="all">
          <option value="all" selected>All</option>
          <option value="mobile">Mobile</option>
        </select>
        <button type="submit" data-kidia-instant-submit-fallback>Save channel</button>
      </form>
    </body></html>`,
    {
      runScripts: "outside-only",
      url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-cms&view=store-data&store_tab=products",
    },
  );

  const { window } = dom;
  window.kidiaCMSBackground = { ajaxUrl: "https://store.test/wp-admin/admin-ajax.php", storeNonce: "store-nonce" };
  window.scrollTo = () => {};
  const posts = [];
  window.fetch = async (url, options = {}) => {
    posts.push({ url: String(url), options });
    if (options.body && options.body.get("action") === "kidia_mobile_generate_store_reporting") {
      return {
        ok: true,
        json: async () => ({
          success: true,
          data: { url: "https://store.test/wp-admin/admin.php?page=kidia-mobile-store-data&store_tab=analytics&date_preset=last_7_days&report_ready=1" },
        }),
      };
    }
    return { ok: true };
  };
  window.eval(shellScript);

  const navigations = [];
  window.kidiaCmsNavigate = async (url, options) => {
    navigations.push({ url: String(url), options });
  };

  assert.equal(
    window.document.documentElement.classList.contains("kidia-cms-js"),
    true,
    "JavaScript-enhanced Store Data must hide manual fallback buttons.",
  );

  const productForm = window.document.querySelector('[data-kidia-instant-filter="products"]');
  const search = productForm.querySelector('[name="product_search"]');
  search.focus();
  search.value = "dre";
  search.dispatchEvent(new window.Event("input", { bubbles: true }));
  search.value = "dress";
  search.dispatchEvent(new window.Event("input", { bubbles: true }));
  await new Promise((resolve) => window.setTimeout(resolve, 410));

  assert.equal(navigations.length, 1, "Typing must make one debounced request for the latest search value.");
  let requested = new URL(navigations[0].url);
  assert.equal(requested.searchParams.get("product_search"), "dress");
  assert.equal(navigations[0].options.fresh, true);
  assert.equal(navigations[0].options.preserveFocus, true);

  navigations.length = 0;
  const visibility = productForm.querySelector('[name="product_visibility"]');
  visibility.value = "hidden_mobile";
  visibility.dispatchEvent(new window.Event("change", { bubbles: true }));
  await new Promise((resolve) => window.setTimeout(resolve, 20));
  assert.equal(navigations.length, 1, "Selecting a product filter must load immediately.");
  requested = new URL(navigations[0].url);
  assert.equal(requested.searchParams.get("product_visibility"), "hidden_mobile");

  navigations.length = 0;
  const datePreset = window.document.querySelector('[name="date_preset"]');
  datePreset.value = "last_7_days";
  datePreset.dispatchEvent(new window.Event("change", { bubbles: true }));
  await new Promise((resolve) => window.setTimeout(resolve, 20));
  assert.equal(navigations.length, 0, "A reporting period must wait for Generate before the reporting source is ready.");

  const generate = window.document.querySelector("[data-kidia-generate-store-reporting]");
  generate.click();
  await new Promise((resolve) => window.setTimeout(resolve, 30));
  assert.equal(posts.length, 1, "Generate must explicitly prepare Store Data.");
  assert.equal(posts[0].options.body.get("action"), "kidia_mobile_generate_store_reporting");
  assert.equal(posts[0].options.body.get("nonce"), "store-nonce");
  assert.equal(posts[0].options.body.get("date_preset"), "last_7_days");
  assert.equal(navigations.length, 1, "Generate must open the prepared report selection.");
  requested = new URL(navigations[0].url);
  assert.equal(requested.searchParams.get("date_preset"), "last_7_days");
  assert.equal(requested.searchParams.has("date_from"), false);
  assert.equal(requested.searchParams.has("date_to"), false);

  navigations.length = 0;
  posts.length = 0;
  datePreset.value = "today";
  datePreset.dispatchEvent(new window.Event("change", { bubbles: true }));
  await new Promise((resolve) => window.setTimeout(resolve, 20));
  assert.equal(navigations.length, 1, "After Generate, reporting periods must load immediately from the indexed source.");
  requested = new URL(navigations[0].url);
  assert.equal(requested.searchParams.get("date_preset"), "today");

  navigations.length = 0;
  const couponChannel = window.document.querySelector('[name="coupon_channel"]');
  couponChannel.value = "mobile";
  couponChannel.dispatchEvent(new window.Event("change", { bubbles: true }));
  await new Promise((resolve) => window.setTimeout(resolve, 30));
  assert.equal(posts.length, 1, "Changing a coupon channel must save automatically.");
  assert.equal(posts[0].options.method, "POST");
  assert.equal(posts[0].options.body.get("coupon_channel"), "mobile");
  assert.equal(navigations.length, 1, "A successful inline update must refresh Store Data in place.");

  dom.window.close();
  console.log("Store Data waits for explicit Generate, then filters and channel updates run instantly.");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
