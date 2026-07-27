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
const productVisibility = readPlugin(
  "includes",
  "class-kidia-mobile-product-channel-visibility.php",
);
const aiOffers = readPlugin(
  "includes",
  "class-kidia-mobile-ai-offer-engine.php",
);
const recovery = readPlugin(
  "includes",
  "class-kidia-mobile-recovery-campaigns.php",
);
const admin = readPlugin("admin", "class-kidia-mobile-cms-admin.php");
const storeData = readPlugin("admin", "pages", "store-data.php");
const push = readPlugin("admin", "pages", "push-notifications.php");
const splash = readPlugin("admin", "pages", "splash-screen.php");
const shellCss = readPlugin("admin", "assets", "cms-shell.css");
const mobileAnalytics = readRepository(
  "lib",
  "core",
  "analytics",
  "mobile_analytics.dart",
);
const storeApiClient = readRepository(
  "lib",
  "core",
  "network",
  "store_api_client.dart",
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
  "site_visit",
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
  "WP_User_Query",
]) {
  assert.match(
    admin,
    new RegExp(marker),
    `Customer source filtering must use ${marker}.`,
  );
}
assert.match(
  analytics,
  /_kidia_website_customer/,
  "Website customer activity must be marked for dual-channel badges.",
);
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
assert.match(
  storeData,
  /source_tabs[\s\S]*analytics[\s\S]*Website[\s\S]*Mobile App/,
  "Analytics must support All, Website and Mobile App source filters.",
);
assert.doesNotMatch(storeData, /Mobile App only/);
assert.match(storeData, /Main categories[\s\S]*Subcategories/);
assert.match(storeData, /Sales funnel[\s\S]*Sales opportunities/);
assert.match(storeData, /Website[\s\S]*Mobile App/);
assert.match(storeData, /kidia-source-badges[\s\S]*is-website[\s\S]*is-mobile/);
assert.match(storeData, /product_search[\s\S]*product_page/);
assert.match(storeData, /product_visibility[\s\S]*Shown everywhere[\s\S]*Hidden from both/);
assert.match(storeData, /Hide from mobile[\s\S]*Hide from website/);
assert.doesNotMatch(storeData, /General store settings/);
assert.match(admin, /abandoned_carts[\s\S]*Abandoned Carts/);
assert.match(admin, /posts_per_page'[\s\S]*product_per_page[\s\S]*fields'[\s\S]*ids/);
assert.doesNotMatch(
  storeData,
  /wc_get_customer_order_count|wc_get_customer_total_spent/,
  "Customer cards must use primed WooCommerce user meta without N+1 totals.",
);
assert.match(analytics, /source varchar\(12\)[\s\S]*source_event_time/);
assert.match(analytics, /summary\( int \$from, int \$to, string \$source/);
assert.match(productVisibility, /MOBILE_META[\s\S]*WEBSITE_META/);
assert.match(productVisibility, /woocommerce_store_api_product_query/);
assert.match(productVisibility, /woocommerce_product_query_meta_query/);
assert.match(admin, /coupon_page[\s\S]*coupon_status[\s\S]*coupon_type[\s\S]*coupon_scope/);
assert.match(storeData, /Search coupon name or code[\s\S]*Individual use only[\s\S]*Specific categories/);
for (const couponDetail of ["Unlimited remaining", "allowed emails", "Excludes sale items"]) {
  assert.match(storeData, new RegExp(couponDetail), `Coupon rows must expose ${couponDetail}.`);
}
assert.match(storeData, /disabled\( 'custom' !== \$date_preset \)/);
assert.match(shellCss, /kidia-date-filter input:disabled[\s\S]*cursor:not-allowed/);
assert.match(shellCss, /kidia-product-actions\{[^}]*flex-wrap:nowrap/);
assert.match(shellCss, /screen-reader-shortcut\[href="#wpbody-content"\]\{display:none!important\}/);
assert.match(aiOffers, /signal_catalog[\s\S]*sales_velocity[\s\S]*frequent_pair/);
assert.match(push, /AI Offer Studio[\s\S]*Frequently bought together[\s\S]*Slow-stock rescue/);
assert.match(push, /Profit risk[\s\S]*Review this offer/);
for (const recoveryField of ["kidia_mobile_recovery_campaigns", "tracking_token", "converted_at"]) {
  assert.match(recovery, new RegExp(recoveryField), `Recovery storage must include ${recoveryField}.`);
}
assert.match(recovery, /set_usage_limit\( 1 \)[\s\S]*set_email_restrictions[\s\S]*set_date_expires/);
assert.match(recovery, /attribute_order[\s\S]*get_coupon_codes[\s\S]*customer_email/);
for (const recoveryControl of ["cart_ids\\[\\]", "Create coupons & send", "Recovery attribution"]) {
  assert.match(storeData, new RegExp(recoveryControl), `Recovery UI must expose ${recoveryControl}.`);
}
assert.match(bootstrap, /class-kidia-mobile-ai-offer-engine\.php[\s\S]*class-kidia-mobile-recovery-campaigns\.php/);
assert.match(storeApiClient, /X-Kidia-Channel'[\s\S]*mobile/);
assert.match(splash, /kidia-page-toolbar[\s\S]*kidia-builder-cards-scroll/);
assert.match(
  admin,
  /kidia-mobile-splash-screen[\s\S]*kidia-cms-builder-screen/,
  "Splash must participate in the fixed builder workspace.",
);
assert.match(
  shellCss,
  /\.kidia-data-tabs\{[\s\S]*repeat\(7,minmax\(138px,1fr\)\)/,
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
