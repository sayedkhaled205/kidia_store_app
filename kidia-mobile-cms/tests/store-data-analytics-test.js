"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const pluginRoot = path.resolve(__dirname, "..");
const repositoryRoot = path.resolve(pluginRoot, "..");
const readPlugin = (...parts) =>
  fs.readFileSync(path.join(pluginRoot, ...parts), "utf8");
const readRepository = (...parts) =>
  fs.readFileSync(path.join(repositoryRoot, ...parts), "utf8");

const bootstrap = readPlugin("includes", "class-kidia-mobile-cms.php");
const analytics = readPlugin("includes", "class-kidia-mobile-analytics.php");
const admin = readPlugin("admin", "class-kidia-mobile-cms-admin.php");
const storeData = readPlugin("admin", "pages", "store-data.php");
const splash = readPlugin("admin", "pages", "splash-screen.php");
const shellCss = readPlugin("admin", "assets", "cms-shell.css");
const mobileAnalytics = readRepository(
  "lib",
  "core",
  "analytics",
  "mobile_analytics.dart",
);
const auth = readRepository(
  "lib",
  "features",
  "auth",
  "application",
  "auth_controller.dart",
);
const cart = readRepository(
  "lib",
  "features",
  "cart",
  "presentation",
  "controllers",
  "cart_controller.dart",
);
const checkout = readRepository(
  "lib",
  "features",
  "checkout",
  "presentation",
  "checkout_screen.dart",
);

assert.match(
  bootstrap,
  /class-kidia-mobile-analytics\.php[\s\S]*Kidia_Mobile_Analytics\(\)\)->register/,
  "The first-party analytics service must load and register.",
);
for (const table of ["kidia_mobile_events", "kidia_mobile_carts"]) {
  assert.match(analytics, new RegExp(table), `${table} must be persisted.`);
}
for (const route of ["/analytics/event", "/analytics/cart"]) {
  assert.match(analytics, new RegExp(route), `${route} must be registered.`);
}
for (const event of [
  "app_open",
  "registration_started",
  "sign_up",
  "login",
  "view_item",
  "view_category",
  "search",
  "add_to_cart",
  "begin_checkout",
  "purchase",
  "purchase_item",
]) {
  assert.match(analytics, new RegExp(`'${event}'`), `${event} must be accepted.`);
}
for (const marker of [
  "_kidia_mobile_customer",
  "_kidia_mobile_customer_sessions_v1",
  "_kidia_website_customer",
  "WP_User_Query",
]) {
  assert.match(
    admin,
    new RegExp(marker),
    `Customer source filtering must use ${marker}.`,
  );
}
assert.doesNotMatch(
  admin,
  /customer_ids[\s\S]*get_customer_id\(\)[\s\S]*get_users/,
  "Customer filters must not be derived from the currently displayed orders.",
);
for (const preset of [
  "all_time",
  "today",
  "yesterday",
  "last_7_days",
  "last_30_days",
  "this_month",
  "previous_month",
  "custom",
]) {
  assert.match(admin, new RegExp(`'${preset}'`), `${preset} must be supported.`);
}
assert.match(storeData, /'abandoned-carts'[\s\S]*Abandoned Carts/);
assert.match(storeData, /'Analytics'[\s\S]*Mobile App only/);
assert.match(storeData, /Main categories[\s\S]*Subcategories/);
assert.match(storeData, /Mobile sales funnel[\s\S]*Sales opportunities/);
assert.match(storeData, /Website[\s\S]*Mobile App/);
assert.match(storeData, /kidia-source-badges[\s\S]*is-website[\s\S]*is-mobile/);
assert.match(splash, /kidia-page-toolbar[\s\S]*kidia-builder-cards-scroll/);
assert.match(
  admin,
  /kidia-mobile-splash-screen[\s\S]*kidia-cms-builder-screen/,
  "Splash must participate in the fixed builder workspace.",
);
assert.match(
  shellCss,
  /\.kidia-data-tabs\{[\s\S]*repeat\(9,minmax\(138px,1fr\)\)/,
  "Store tabs must keep a stable minimum width.",
);
assert.match(
  shellCss,
  /kidia-splash-builder \.kidia-page-editor[\s\S]*overflow:hidden/,
  "Splash chrome must stay fixed while settings scroll.",
);
assert.match(mobileAnalytics, /CMS_PREVIEW|isCmsPreview/);
assert.match(mobileAnalytics, /X-Kidia-Session/);
assert.match(auth, /registration_started[\s\S]*sign_up[\s\S]*login/);
assert.match(cart, /add_to_cart[\s\S]*remove_from_cart[\s\S]*captureCartInBackground/);
assert.match(checkout, /begin_checkout[\s\S]*purchase[\s\S]*purchase_item/);

console.log("Store Data analytics and abandoned-cart contract tests passed.");
