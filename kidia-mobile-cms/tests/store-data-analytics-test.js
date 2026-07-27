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
const pushService = readPlugin(
  "includes",
  "class-kidia-mobile-push-service.php",
);
const couponChannel = readPlugin(
  "includes",
  "class-kidia-mobile-coupon-channel.php",
);
const bundleRecipes = readPlugin(
  "includes",
  "class-kidia-mobile-bundle-recipes.php",
);
const admin = readPlugin("admin", "class-kidia-mobile-cms-admin.php");
const storeData = readPlugin("admin", "pages", "store-data.php");
const push = readPlugin("admin", "pages", "push-notifications.php");
const aiInsights = readPlugin("admin", "pages", "ai-insights.php");
const splash = readPlugin("admin", "pages", "splash-screen.php");
const shellCss = readPlugin("admin", "assets", "cms-shell.css");
const shellScript = readPlugin("admin", "assets", "cms-shell.js");
const splashScript = readPlugin("admin", "assets", "splash-screen.js");
const websiteAnalytics = readPlugin(
  "public",
  "assets",
  "website-analytics.js",
);
const homeBlockModel = readRepository(
  "lib",
  "features",
  "home",
  "data",
  "models",
  "home_block_model.dart",
);
const bundleScreen = readRepository(
  "lib",
  "features",
  "bundles",
  "presentation",
  "bundle_builder_screen.dart",
);
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
for (const route of [
  "/analytics/event",
  "/analytics/cart",
  "/analytics/website-event",
]) {
  assert.match(analytics, new RegExp(route), `${route} must be registered.`);
}
assert.match(
  analytics,
  /wp_enqueue_scripts[\s\S]*website-analytics\.js[\s\S]*record_website_event_request/,
  "Website analytics must bypass full-page caches through the browser tracker.",
);
assert.match(
  websiteAnalytics,
  /site_visit[\s\S]*add_to_cart[\s\S]*remove_from_cart/,
  "The website tracker must record visits and commerce intent.",
);
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
  "last_year",
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
assert.match(storeData, /Last month[\s\S]*Last year[\s\S]*Custom/);
assert.doesNotMatch(storeData, /Open full manager/);
assert.doesNotMatch(storeData, /\$starts->format_i18n/, "Coupon dates must not call Woo-only methods on WordPress DateTime objects.");
assert.match(storeData, /wp_date\([^;]*\$starts->getTimestamp\(\)/, "Coupon dates must render through a safe WordPress timestamp.");
assert.match(shellCss, /kidia-date-filter input:disabled[\s\S]*cursor:not-allowed/);
assert.match(shellCss, /kidia-product-actions\{[^}]*flex-wrap:nowrap/);
assert.match(shellCss, /kidia-row-actions :is\(a,button\)[\s\S]*align-items:center!important[\s\S]*justify-content:center!important/);
assert.match(shellCss, /input\[type="checkbox"\]:checked[\s\S]*background:#2f806e!important/);
assert.match(shellCss, /screen-reader-shortcut\[href="#wpbody-content"\]\{display:none!important\}/);
assert.match(aiOffers, /signal_catalog[\s\S]*sales_velocity[\s\S]*frequent_pair/);
assert.match(aiOffers, /remove_friction[\s\S]*signup_friction[\s\S]*search_demand[\s\S]*peak_timing/);
assert.match(aiOffers, /minimum_confidence[\s\S]*maximum_recommendations[\s\S]*protect_margin/);
assert.match(aiOffers, /automatic_profile[\s\S]*high_interest_min_views[\s\S]*minimum_confidence/);
assert.match(
  analytics,
  /commerce_snapshot[\s\S]*wc_get_orders[\s\S]*orders_scanned[\s\S]*pairs/,
  "AI Studio must analyze historical WooCommerce orders and product pairs.",
);
assert.match(
  analytics,
  /sync_website_sessions[\s\S]*woocommerce_sessions[\s\S]*session_value/,
  "Abandoned carts must import existing WooCommerce session carts.",
);
assert.match(aiInsights, /AI Offer Studio[\s\S]*Sales funnel[\s\S]*Demand signals[\s\S]*Decision-ready recommendations/);
assert.match(aiOffers, /Frequently bought together[\s\S]*Slow-stock rescue[\s\S]*Peak-time scheduling[\s\S]*Registration friction/);
assert.match(aiInsights, /Why this recommendation[\s\S]*Decision target:[\s\S]*Profit risk/);
assert.match(aiInsights, /ai_source[\s\S]*ai_kind[\s\S]*date_preset/);
assert.doesNotMatch(
  aiInsights,
  /Save analysis settings|name="ai_settings\[/,
  "Owners must review generated actions rather than configure analysis rules.",
);
assert.doesNotMatch(
  admin,
  /kidia_mobile_save_ai_insights|save_ai_insights_settings/,
  "The removed manual analysis settings must not remain as a hidden admin endpoint.",
);
assert.match(
  aiInsights,
  /WooCommerce orders analysed[\s\S]*Best-selling product/,
  "AI Studio must expose the real data used to generate recommendations.",
);
assert.match(
  aiInsights,
  /Automatic store analysis is active[\s\S]*historical WooCommerce orders[\s\S]*product relationships/,
  "AI Studio must explain that its analysis is automatic and data-driven.",
);
assert.match(aiInsights, /disabled\( 'custom' !== \$date_preset \)/);
assert.doesNotMatch(push, /kidia-ai-offer-studio|data-ai-scheme-filter|data-ai-scheme-card/);
assert.match(push, /Delivery connection[\s\S]*Setup required[\s\S]*Firebase Cloud Messaging[\s\S]*OneSignal/);
for (const recoveryField of ["kidia_mobile_recovery_campaigns", "tracking_token", "converted_at"]) {
  assert.match(recovery, new RegExp(recoveryField), `Recovery storage must include ${recoveryField}.`);
}
assert.match(recovery, /set_usage_limit\( 1 \)[\s\S]*set_email_restrictions[\s\S]*set_date_expires/);
assert.match(recovery, /attribute_order[\s\S]*get_coupon_codes[\s\S]*customer_email/);
assert.match(pushService, /\/push\/devices[\s\S]*\/push\/events[\s\S]*dispatch_onesignal[\s\S]*dispatch_fcm[\s\S]*dispatch_webhook/);
assert.match(pushService, /trigger_automation[\s\S]*cooldown_hours[\s\S]*stop_on_purchase/);
assert.match(couponChannel, /_kidia_coupon_channel[\s\S]*Website only[\s\S]*Mobile App only/);
assert.match(bundleRecipes, /mix_match[\s\S]*build_box[\s\S]*buy_x_get_y[\s\S]*frequently_bought[\s\S]*subscription/);
assert.match(bundleRecipes, /\/claim[\s\S]*validate_bundle_coupon[\s\S]*minimum_items[\s\S]*maximum_items/);
assert.match(homeBlockModel, /HomeBlockType\.bundleCollection[\s\S]*_parseBundleCollection/);
assert.match(bundleScreen, /bundleDetailProvider[\s\S]*addProductPurchaseSelectionProvider[\s\S]*applyCoupon/);
for (const recoveryControl of ["cart_ids\\[\\]", "Create coupons & send", "Recovery attribution"]) {
  assert.match(storeData, new RegExp(recoveryControl), `Recovery UI must expose ${recoveryControl}.`);
}
for (const recoveryGroup of ["Personal coupon", "Notification message", "Delivery"]) {
  assert.match(storeData, new RegExp(recoveryGroup), `Recovery controls must group ${recoveryGroup}.`);
}
assert.match(storeData, /Action display[\s\S]*Open link[\s\S]*Button[\s\S]*Button text[\s\S]*Destination URL/);
assert.match(recovery, /action_style[\s\S]*cta_label/);
assert.match(shellScript, /data-recovery-action-style[\s\S]*data-recovery-button-label/);
assert.match(bootstrap, /class-kidia-mobile-ai-offer-engine\.php[\s\S]*class-kidia-mobile-recovery-campaigns\.php/);
assert.match(storeApiClient, /X-Kidia-Channel'[\s\S]*mobile/);
assert.match(splash, /kidia-page-toolbar[\s\S]*kidia-builder-cards-scroll/);
assert.match(splash, /data-splash-overlay[\s\S]*data-splash-replay/);
assert.match(splashScript, /function play\(\)[\s\S]*is-playing[\s\S]*is-finished/);
assert.match(shellCss, /kidia-date-filter button\{[^}]*align-items:center!important[^}]*justify-content:center!important/);
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
