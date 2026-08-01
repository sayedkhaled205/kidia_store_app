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
const aiAnalysisJob = readPlugin(
  "includes",
  "class-kidia-mobile-ai-analysis-job.php",
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
assert.match(
  analytics,
  /event_id varchar\(64\) NULL[\s\S]*UNIQUE KEY event_id/,
  "Analytics writes must have a durable idempotency key.",
);
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
  /kidia_website_analytics_queue_v1[\s\S]*event_id[\s\S]*site_visit[\s\S]*add_to_cart[\s\S]*remove_from_cart/,
  "The website tracker must durably queue visits and commerce intent.",
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
  /commerce_snapshot[\s\S]*paginate'[\s\S]*orders_available[\s\S]*pairs/,
  "AI Studio must analyze historical WooCommerce orders and product pairs.",
);
assert.match(
  analytics,
  /kidia_analytics_summary_v3_[\s\S]*get_transient[\s\S]*set_transient/,
  "One generated AI summary must be reused instead of running the same heavy queries twice.",
);
assert.match(
  analytics,
  /summary\( int \$from, int \$to, string \$source = 'all', bool \$fresh = false \)[\s\S]*if \( ! \$fresh \)[\s\S]*get_transient[\s\S]*commerce_snapshot\( \$from, \$to, \$source, \$fresh \)/,
  "Store Data must be able to bypass stale summary and commerce caches.",
);
assert.match(
  admin,
  /Kidia_Mobile_Analytics::summary\( \$date_from, \$date_to, \$store_source, true \)/,
  "The Analytics page must always request a fresh source-of-truth summary.",
);
assert.match(
  admin,
  /'reports'\s*===\s*\$store_tab[\s\S]*Kidia_Mobile_Analytics::orders_in_period\(\s*\$date_from,\s*\$date_to,\s*\$store_source\s*\)/,
  "Store Data reports must use the verified shared WooCommerce order source.",
);
assert.match(
  analytics,
  /function orders_in_period[\s\S]*'date_created'\s*=>\s*\$from\s*\.\s*'\.\.\.'\s*\.\s*\$to[\s\S]*unset\(\s*\$args\['date_created'\]\s*\)[\s\S]*collect_orders_in_period/,
  "Analytics and reports must fall back to verified order dates when the native range returns no rows.",
);
assert.match(
  analytics,
  /get_date_created\(\)[\s\S]*getTimestamp\(\)[\s\S]*\$created_at\s*<\s*\$from[\s\S]*\$created_at\s*>\s*\$to/,
  "Fallback results must be checked against the exact requested timestamps.",
);
assert.match(
  admin,
  /array\(\s*'abandoned-carts',\s*'reports',\s*'analytics'\s*\)[\s\S]*\?\s*'today'/,
  "Abandoned Carts, Analytics and Reports must default to Today.",
);
assert.match(
  storeData,
  /in_array\(\s*\$tab,\s*array\(\s*'abandoned-carts',\s*'reports',\s*'analytics'\s*\),\s*true\s*\)[\s\S]*\?\s*'today'/,
  "Navigation into Abandoned Carts, Analytics or Reports must keep Today as the default.",
);
assert.match(
  analytics,
  /kidia_mobile_analytics_write_failed[\s\S]*'recorded'[\s\S]*'deduplicated'/,
  "The ingestion API must report failed writes and acknowledge duplicate retries.",
);
assert.match(
  mobileAnalytics,
  /kidia_mobile_analytics_queue_v1[\s\S]*event_id[\s\S]*_enqueue[\s\S]*_flush/,
  "The mobile app must persist and retry analytics events.",
);
assert.match(
  storeData,
  /data-kidia-live-store-data="reports"[\s\S]*data-kidia-live-store-data="analytics"/,
  "Reports and Analytics must expose a live-updating data region.",
);
assert.match(
  shellScript,
  /data-kidia-live-store-data[\s\S]*5000[\s\S]*cache:\s*'no-store'/,
  "Visible Reports and Analytics must refresh from the live source every five seconds.",
);
assert.match(
  storeData,
  /analytics\['commerce'\]\['orders'\][\s\S]*Paid orders[\s\S]*Paid revenue/,
  "Analytics order KPIs must use WooCommerce paid orders and revenue as the source of truth.",
);
assert.match(
  admin,
  /ai_generated[\s\S]*if \( \$ai_generated \)[\s\S]*Kidia_Mobile_Analytics::summary[\s\S]*Kidia_Mobile_AI_Offer_Engine::recommendations/,
  "AI Studio must not calculate analytics until Generate Analysis is requested.",
);
assert.match(
  aiInsights,
  /data-ai-generate-form[\s\S]*ai_generate[\s\S]*Generate Offers from Store Data[\s\S]*Ready to build data-backed offers/,
  "AI Studio must open in a lightweight ready state and expose an explicit generate action.",
);
assert.match(
  aiInsights,
  /data-ai-progress-overlay[\s\S]*data-ai-progress-value[\s\S]*Analyzing store data & generating offers[\s\S]*data-ai-progress-stage/,
  "Generating decisions must show centered staged percentage progress.",
);
assert.match(
  shellScript,
  /payload\.progress[\s\S]*records completed[\s\S]*kidia_mobile_start_ai_analysis[\s\S]*kidia_mobile_ai_analysis_status/,
  "The AI progress surface must advance from measured server batches.",
);
assert.match(
  shellScript,
  /progressLabel[\s\S]*toFixed\(1\)[\s\S]*setAttribute\('dir', 'ltr'\)/,
  "Large-store progress must show a real fractional percentage and an unambiguous processed/total order.",
);
assert.match(
  shellScript,
  /kidia_mobile_ai_analysis_status'[\s\S]*advance: '1'[\s\S]*Retrying without losing completed records/,
  "Foreground and parked analysis must self-advance and retry temporary batch failures.",
);
assert.doesNotMatch(
  shellScript,
  /setInterval[\s\S]*progress\s*\+=/,
  "AI Studio must never display timer-estimated progress.",
);
assert.match(
  aiAnalysisJob,
  /ORDER_BATCH[\s\S]*PRODUCT_BATCH[\s\S]*orders_processed[\s\S]*products_processed[\s\S]*100 \* \$processed \/ \$total/,
  "The incremental job must calculate progress from completed order and product records.",
);
assert.match(
  aiAnalysisJob,
  /status\( string \$job_id, int \$user_id, bool \$advance = false \)[\s\S]*return self::step\( \$job_id, \$user_id \)/,
  "Status polling must advance one protected batch when the server scheduler stalls.",
);
assert.match(
  aiAnalysisJob,
  /\$lock_token = self::acquire_step_lock[\s\S]*Always[\s\S]*\$latest = self::read_job\( \$job_id \)[\s\S]*release_step_lock[\s\S]*private static function acquire_step_lock[\s\S]*add_option\(/,
  "Every batch must own an atomic lock and reload the latest saved job before processing.",
);
assert.match(
  aiAnalysisJob,
  /continue_in_background[\s\S]*Parking often happens[\s\S]*acquire_step_lock[\s\S]*\$latest = self::read_job[\s\S]*release_step_lock/,
  "Parking the analysis must never overwrite a completed first batch with an older zero-progress copy.",
);
assert.match(
  aiAnalysisJob,
  /JOB_PREFIX = 'kidia_mobile_ai_job_v6_'[\s\S]*read_job[\s\S]*get_option[\s\S]*write_job[\s\S]*add_option[\s\S]*update_option/,
  "Large AI jobs must persist in non-autoloaded database options instead of size-limited transients.",
);
assert.match(
  aiAnalysisJob,
  /customer_bitmap'\s*=>\s*str_repeat\(\s*'00'[\s\S]*ASCII-hex probabilistic set[\s\S]*hexdec[\s\S]*dechex/,
  "The customer bitmap must remain valid utf8mb4 when WordPress serializes it into wp_options.",
);
assert.doesNotMatch(
  aiAnalysisJob,
  /set_transient\(\s*self::key\(/,
  "Analysis job state must never be written through an object-cache-backed transient.",
);
assert.doesNotMatch(
  aiAnalysisJob,
  /get_transient\( self::step_lock_key[\s\S]*set_transient\(\s*self::step_lock_key/,
  "The browser and scheduler must not share a non-atomic transient lock.",
);
assert.match(
  aiAnalysisJob,
  /'revision'\s*=>\s*0[\s\S]*\$job\['revision'\]\s*=\s*absint[\s\S]*'busy'\s*=>\s*\$busy/,
  "Every saved batch must expose a monotonic revision and mark lock contention as busy.",
);
assert.match(
  shellScript,
  /currentRevision[\s\S]*currentProcessed[\s\S]*payload\.busy[\s\S]*revision < currentRevision[\s\S]*processed < currentProcessed/,
  "An older or busy response must never move the visible analysis progress backwards.",
);
assert.match(
  aiInsights,
  /Continue in background[\s\S]*View results[\s\S]*Cancel analysis/,
  "Long analysis must be parkable or cancellable from the real progress surface.",
);
assert.match(
  shellCss,
  /kidia-ai-progress-card\{[\s\S]*grid-template-columns:minmax\(0,1fr\)[\s\S]*width:min\(680px[\s\S]*kidia-ai-progress-card>\*\{min-width:0;max-width:100%\}/,
  "The progress surface must keep every child inside the card.",
);
assert.match(
  shellCss,
  /kidia-ai-progress-actions\{[^}]*display:flex;[^}]*justify-content:flex-end;[^}]*width:100%[\s\S]*kidia-ai-progress-actions \[hidden\]\{display:none!important\}/,
  "Progress actions must stay aligned and keep View results hidden until completion.",
);
assert.match(
  shellCss,
  /kidia-ai-page \.button>\.dashicons\{[\s\S]*place-items:center[\s\S]*vertical-align:middle/,
  "AI Studio button icons must remain vertically centered with their labels.",
);
assert.match(
  shellScript,
  /positionAiDock[\s\S]*localStorage\.setItem[\s\S]*bindAiDockDrag[\s\S]*pointerdown[\s\S]*pointermove/,
  "The parked analysis card must be freely draggable and remember its safe screen position.",
);
assert.match(
  shellScript,
  /kidia:cms-before-page-change[\s\S]*persistAiProgressAcrossNavigation[\s\S]*document\.body\.appendChild\(overlay\)[\s\S]*pollBackgroundJob/,
  "An active analysis card must survive CMS view changes without a reload or a new job.",
);
assert.match(
  shellCss,
  /kidia-ai-progress-overlay\.is-docked \.kidia-ai-progress-card\{[\s\S]*cursor:grab[\s\S]*touch-action:none/,
  "The parked analysis card must expose mouse and touch dragging.",
);
for (const backgroundMarker of [
  "kidia_mobile_background_ai_analysis",
  "kidia_mobile_ai_analysis_status",
  "kidia_mobile_cancel_ai_analysis",
  "is-docked",
]) {
  assert.match(
    shellScript,
    new RegExp(backgroundMarker),
    `Parked analysis must include ${backgroundMarker}.`,
  );
}
assert.match(
  aiAnalysisJob,
  /BACKGROUND_HOOK[\s\S]*continue_in_background[\s\S]*run_background[\s\S]*as_enqueue_async_action[\s\S]*wp_schedule_single_event/,
  "A parked job must continue through Action Scheduler with a WP-Cron fallback.",
);
assert.match(
  aiAnalysisJob,
  /MAX_PAIR_KEYS[\s\S]*CUSTOMER_BITMAP_BYTES[\s\S]*paginate'\s*=>\s*true[\s\S]*isset\( \$result->orders \)/,
  "Large stores must use a compact bounded job state and explicitly paginated WooCommerce order batches.",
);
assert.doesNotMatch(
  aiAnalysisJob,
  /'customers'\s*=>\s*array\(\)[\s\S]*'product_customers'\s*=>\s*array\(\)/,
  "The analysis job must not retain every customer-to-product key in one oversized transient.",
);
assert.match(
  aiAnalysisJob,
  /product_sales'\]\s*=\s*array\(\)[\s\S]*foreach \( \$job\['products'\] as \$product_id => \$product_row \)[\s\S]*product_sales'\]\[\s*absint\( \$product_id \)\s*\]/,
  "Product sales must remain keyed by the real WooCommerce product ID for rotation classification.",
);
assert.match(
  aiInsights,
  /Fast-moving products[\s\S]*Medium-moving products[\s\S]*Slow-moving products[\s\S]*Poor-performing products[\s\S]*kidia-ai-rotation-summary/,
  "AI Studio must expose the four product-rotation groups before the recommendation cards.",
);
assert.match(
  aiInsights,
  /data-ai-segment-panel[\s\S]*empty\( \$rotation_recommendations \)[\s\S]*kidia-ai-segment-empty/,
  "Every selectable rotation group must retain a clear empty state when the current recommendation filter has no matching action.",
);
assert.match(
  shellCss,
  /kidia-ai-decision-products article\{[^}]*min-height:60px[\s\S]*width:52px;height:52px/,
  "Product recommendation cards must use a compact container with a larger product image.",
);
assert.match(
  aiAnalysisJob,
  /stock_status' => 'instock'[\s\S]*process_order_batch[\s\S]*process_product_batch[\s\S]*store_commerce_snapshot/,
  "The job must analyze all paid orders in bounded batches and only currently in-stock products.",
);
assert.match(
  aiAnalysisJob,
  /'status'\s*=>\s*Kidia_Mobile_Analytics::revenue_order_statuses\(\)/,
  "The incremental AI job must include paid orders moved into registered custom workflow statuses.",
);
assert.match(
  admin,
  /wp_ajax_kidia_mobile_start_ai_analysis[\s\S]*wp_ajax_kidia_mobile_step_ai_analysis[\s\S]*ai_ready[\s\S]*has_commerce_snapshot/,
  "AI results must render only after a completed server snapshot exists.",
);
assert.match(
  analytics,
  /funnel_snapshot[\s\S]*view_item[\s\S]*add_to_cart[\s\S]*begin_checkout[\s\S]*purchase/,
  "AI Studio must build a closed tracked funnel in the real journey order.",
);
assert.match(
  analytics,
  /Historical WooCommerce orders and live journey events are deliberately[\s\S]*kept separate[\s\S]*unmatched_purchases/,
  "Historical order totals must never fabricate Add to cart or Checkout funnel stages.",
);
assert.doesNotMatch(
  analytics,
  /\$events\['purchase'\]\s*=\s*array\([^;]*\$commerce/s,
  "Historical WooCommerce purchases must not overwrite tracked purchase events.",
);
assert.match(
  analytics,
  /tracked_top_purchases[\s\S]*top_purchases/,
  "Tracked product conversions must remain distinct from historical best sellers.",
);
assert.match(
  aiOffers,
  /tracked_top_purchases[\s\S]*high-interest/,
  "High-interest conversion decisions must compare tracked views with tracked purchases.",
);
assert.doesNotMatch(
  analytics,
  /kidia_mobile_ai_maximum_historical_orders|20000/,
  "AI Studio must not silently stop at a fixed historical-order sample.",
);
assert.match(
  analytics,
  /foreach \( \$batch as \$order \)[\s\S]*maximum_pages[\s\S]*orders_scanned[\s\S]*orders_available/,
  "Historical orders must be aggregated page by page without retaining every order object.",
);
assert.match(
  analytics,
  /stock_status' => 'instock'[\s\S]*catalog_in_stock[\s\S]*product_sales/,
  "AI product decisions must expose all currently in-stock catalog products and their measured sales.",
);
assert.match(
  analytics,
  /sync_website_sessions[\s\S]*woocommerce_sessions[\s\S]*session_value/,
  "Abandoned carts must import existing WooCommerce session carts.",
);
assert.match(
  analytics,
  /WEBSITE_IMPORT_OPTION[\s\S]*session_id > %d[\s\S]*ORDER BY session_id ASC[\s\S]*schedule_website_session_import/,
  "Historical cart import must advance through every retained WooCommerce session instead of rereading the first batch.",
);
assert.match(
  analytics,
  /WEBSITE_IMPORT_OPTION\s*=\s*'kidia_mobile_website_cart_import_v4'/,
  "Historical cart import must use a fresh state version so a previously completed zero-result scan is retried.",
);
assert.match(
  analytics,
  /SELECT COUNT\(\*\) FROM \{\$sessions_table\}[\s\S]*WHERE session_id > %d[\s\S]*import_website_session_row/,
  "Historical cart import must inspect every retained WooCommerce session and decide after deserializing it whether it contains a cart.",
);
assert.doesNotMatch(
  analytics,
  /session_value LIKE/,
  "Serialized WooCommerce carts must not be discarded by a fragile SQL text filter.",
);
assert.match(
  analytics,
  /ensure_website_session_import\( bool \$force_refresh = false \)[\s\S]*'complete' ===[\s\S]*! \$force_refresh[\s\S]*sync_website_sessions[\s\S]*ensure_website_session_import\(\)/,
  "Opening Abandoned Carts must preserve a completed import instead of restarting its counters.",
);
assert.doesNotMatch(
  analytics,
  /sync_website_sessions[\s\S]{0,500}ensure_website_session_import\( true \)/,
  "Normal report reads must never force a completed historical import back to zero.",
);
assert.match(
  analytics,
  /acquire_website_import_lock[\s\S]*add_option\(\s*self::WEBSITE_IMPORT_LOCK[\s\S]*release_website_import_lock/,
  "Foreground polling and the background runner must own each cursor batch atomically.",
);
assert.match(
  analytics,
  /_woocommerce_persistent_cart_[\s\S]*persistent_total[\s\S]*import_persistent_cart_row/,
  "Historical import must include WooCommerce persistent carts for registered customers, not only active session rows.",
);
assert.match(
  analytics,
  /\$last_activity\s*=\s*\$expiry > 0 \? min\(\s*time\(\)[\s\S]*website_session_expiration[\s\S]*WC_VERSION[\s\S]*'10\.1'[\s\S]*WEEK_IN_SECONDS/,
  "Imported session activity must use WooCommerce's guest and registered-customer lifetimes without producing future dates.",
);
assert.match(
  analytics,
  /decode_stored_array[\s\S]*maybe_unserialize[\s\S]*json_decode/,
  "Session import must decode the nested formats used by WooCommerce and compatible session handlers.",
);
assert.match(
  analytics,
  /abandoned_carts[\s\S]*status IN \('recovered','converted'\)[\s\S]*status = 'abandoned'[\s\S]*last_activity_at <= %s[\s\S]*LIMIT %d OFFSET %d/,
  "Abandoned and recovered carts must be queried independently with real server-side pagination.",
);
assert.match(
  analytics,
  /abandoned_summary[\s\S]*COUNT\(\*\) AS carts[\s\S]*potential_value/,
  "Abandoned-cart headline totals must cover the complete filtered dataset, not only the visible table rows.",
);
assert.match(
  admin,
  /array\(\s*'abandoned-carts',\s*'reports',\s*'analytics'\s*\)[\s\S]*\?\s*'today'/,
  "Abandoned Carts must open on Today by default.",
);
assert.match(
  admin,
  /cart_view[\s\S]*cart_per_page[\s\S]*array\( 20, 50, 100 \)[\s\S]*cart_page[\s\S]*cart_pages/,
  "Abandoned carts must default to paginated status views with selectable page sizes.",
);
assert.match(
  storeData,
  /kidia-cart-view-tabs[\s\S]*Abandoned[\s\S]*Recovered[\s\S]*data-cart-per-page[\s\S]*paginate_links/,
  "The cart workspace must expose Abandoned and Recovered tabs, a page-size control and numbered navigation.",
);
assert.match(
  storeData,
  /array\(\s*'abandoned-carts',\s*'reports',\s*'analytics'\s*\)[\s\S]*\?\s*'today'/,
  "Links into Abandoned Carts must preserve the Today default.",
);
assert.match(
  storeData,
  /Importing all retained WooCommerce carts in the background[\s\S]*Carts found[\s\S]*\$abandoned_summary/,
  "The page must show historical import progress and complete cart totals.",
);
assert.match(
  storeData,
  /data-kidia-live-store-data="abandoned-carts-overview"[\s\S]*data-kidia-live-store-data="abandoned-carts-table"/,
  "Abandoned-cart progress, totals and rows must expose live-update regions.",
);
assert.match(
  storeData,
  /Bought an alternative order[\s\S]*Returning customer[\s\S]*First-time customer[\s\S]*data-abandoned-cart-details/,
  "Every abandoned-cart row must expose the three customer segments and an order-details action.",
);
assert.match(
  storeData,
  /Cart order|View details/,
  "Each abandoned cart must provide a button that opens its three detail groups.",
);
assert.match(
  analytics,
  /abandoned_cart_order_insight[\s\S]*10 \* DAY_IN_SECONDS[\s\S]*customer_segment/,
  "Abandoned-cart insights must compare purchases within ten days and classify the customer.",
);
assert.match(
  shellScript,
  /kidia_mobile_abandoned_cart_details[\s\S]*Customer order history[\s\S]*Possible alternative order/,
  "The details action must load cart contents, customer order history and the possible alternative order.",
);
assert.match(
  shellScript,
  /edit_url[\s\S]*Open order[\s\S]*expandedCartDetails[\s\S]*aria-expanded', 'true'/,
  "Order details must link to WooCommerce orders and remain expanded across live table refreshes.",
);
assert.match(
  shellScript,
  /Name[\s\S]*Phone[\s\S]*Province[\s\S]*kidia-cart-details-stack[\s\S]*Customer details/,
  "The last details column must stack the alternative order above a compact customer summary.",
);
assert.match(
  analytics,
  /get_billing_phone[\s\S]*get_shipping_phone[\s\S]*billing_state[\s\S]*shipping_state[\s\S]*'customer'/,
  "Abandoned-cart insights must include the customer's available phone numbers and province.",
);
assert.match(
  analytics,
  /get_billing_country[\s\S]*get_shipping_country[\s\S]*province_label[\s\S]*get_states/,
  "Province must use the order country to convert WooCommerce state codes into readable governorate names.",
);
assert.match(
  storeData,
  /Completed — WooCommerce cart history is synced[\s\S]*Results are shown below automatically/,
  "The abandoned-cart import card must become Completed and expose refreshed results automatically.",
);
assert.match(
  shellScript,
  /Completed\. Loading your results…[\s\S]*view\.hidden = true[\s\S]*window\.location\.assign\(resultUrl\)/,
  "AI Offer Studio must become Completed and open its generated results automatically without a View results step.",
);
assert.match(
  aiAnalysisJob,
  /date_preset[\s\S]*sanitize_date_preset[\s\S]*'all_time'[\s\S]*result_args[\s\S]*'custom' === \$date_preset/,
  "AI result URLs must preserve the selected preset and only add explicit dates for Custom ranges.",
);
assert.match(
  shellScript,
  /querySelectorAll\('\[data-kidia-live-store-data\]'\)[\s\S]*freshRegions\.find[\s\S]*region\.innerHTML = fresh\.innerHTML/,
  "Every Store Data live region must refresh automatically without a browser reload.",
);
assert.match(aiInsights, /AI Offer Studio[\s\S]*Tracked sales funnel[\s\S]*Demand signals[\s\S]*Decision-ready recommendations/);
assert.match(
  aiInsights,
  /Fast-moving products[\s\S]*Medium-moving products[\s\S]*Slow-moving products[\s\S]*Poor-performing products/,
  "Generated decisions must be organized into the four requested stock-rotation groups.",
);
assert.match(
  aiOffers,
  /rotation_segments[\s\S]*fast_rotation[\s\S]*medium_rotation[\s\S]*slow_rotation[\s\S]*poor_rotation/,
  "AI Studio must calculate rotation groups and a group-specific executable decision.",
);
assert.match(
  aiOffers,
  /stock_status' => 'instock'[\s\S]*is_in_stock/,
  "Out-of-stock products must never enter generated decisions.",
);
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
  /Sales history and live journey tracking are analysed separately[\s\S]*historical orders are never inserted into Add to cart or Checkout counts/,
  "AI Studio must explain its sales-history and live-funnel coverage honestly.",
);
assert.match(
  aiInsights,
  /Recommended decision[\s\S]*Why this recommendation[\s\S]*Measure:[\s\S]*Guardrail:/,
  "Recommendation cards must contain a concrete decision and its analytical controls.",
);
assert.match(
  aiOffers,
  /discount_for_conversion_gap[\s\S]*discount_for_slow_stock[\s\S]*discount_for_bundle/,
  "Offer values must be calculated from each measured decision rather than copied from one manual default.",
);
for (const recommendationField of [
  "decision",
  "metrics",
  "success_metric",
  "guardrail",
  "products",
]) {
  assert.match(
    aiOffers,
    new RegExp(`'${recommendationField}'`),
    `AI recommendations must expose ${recommendationField}.`,
  );
}
assert.match(
  admin,
  /ai_insights_page[\s\S]*:\s*'all_time'[\s\S]*:\s*'all'/,
  "AI Studio must default to all store history and both channels.",
);
assert.match(
  admin,
  /kidia_mobile_ai_action_history_v1[\s\S]*review_ai_result[\s\S]*owner_decision/,
  "Approved AI actions and owner result decisions must be retained.",
);
assert.match(
  admin,
  /publish_ai_action_placement[\s\S]*bundle_collection[\s\S]*coupon_banner[\s\S]*product_carousel[\s\S]*save_layout/,
  "Approved Home decisions must publish a real matching Home Builder block.",
);
assert.match(
  admin,
  /recommended_product_ids[\s\S]*is_in_stock\(\)[\s\S]*stock_changed/,
  "Every reviewed action must recheck live stock before it can execute.",
);
assert.match(
  aiInsights,
  /Generated Decisions[\s\S]*Actions & Results[\s\S]*Products included in this action[\s\S]*Approve continue[\s\S]*Approve stop/,
  "AI Studio must separate generated decisions from executed actions and results.",
);
assert.match(aiInsights, /disabled\( 'custom' !== \$date_preset \)/);
assert.doesNotMatch(push, /kidia-ai-offer-studio|data-ai-scheme-filter|data-ai-scheme-card/);
assert.match(push, /Push connection managed automatically[\s\S]*no provider selection or Firebase keys are required/);
assert.doesNotMatch(push, /data-push-provider|OneSignal App ID|Service-account private key/);
for (const recoveryField of ["kidia_mobile_recovery_campaigns", "tracking_token", "converted_at"]) {
  assert.match(recovery, new RegExp(recoveryField), `Recovery storage must include ${recoveryField}.`);
}
assert.match(recovery, /set_usage_limit\( 1 \)[\s\S]*set_email_restrictions[\s\S]*set_date_expires/);
assert.match(recovery, /attribute_order[\s\S]*get_coupon_codes[\s\S]*customer_email/);
assert.match(pushService, /\/push\/devices[\s\S]*\/push\/events[\s\S]*dispatch_managed[\s\S]*push_service_request/);
assert.doesNotMatch(pushService, /dispatch_onesignal|dispatch_fcm|dispatch_webhook|fcm_private_key|onesignal_api_key/);
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
