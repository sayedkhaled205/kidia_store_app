"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const root = path.resolve(__dirname, "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");
const webpDimensions = (file) => {
  const buffer = fs.readFileSync(file);
  const marker = buffer.indexOf(Buffer.from([0x9d, 0x01, 0x2a]));
  assert.ok(marker > 0, `${file} must contain a decodable VP8 frame.`);
  return {
    width: buffer.readUInt16LE(marker + 3) & 0x3fff,
    height: buffer.readUInt16LE(marker + 5) & 0x3fff
  };
};

const service = read("includes", "class-kidia-mobile-setup-wizard.php");
const exporter = read("includes", "class-kidia-mobile-app-exporter.php");
const licenseManager = read("includes", "class-kidia-mobile-license-manager.php");
const pushService = read("includes", "class-kidia-mobile-push-service.php");
const bootstrap = read("includes", "class-kidia-mobile-cms.php");
const admin = read("admin", "class-kidia-mobile-cms-admin.php");
const wizardTemplate = read("admin", "pages", "setup-wizard.php");
const dashboardTemplate = read("admin", "pages", "dashboard.php");
const savedThemesTemplate = read("admin", "pages", "saved-themes.php");
const savedThemesScript = read("admin", "assets", "saved-themes.js");
const shellTemplate = read("admin", "pages", "cms-shell.php");
const wizardCss = read("admin", "assets", "setup-wizard.css");
const wizardJs = read("admin", "assets", "setup-wizard.js");
const shellCss = read("admin", "assets", "cms-shell.css");
const shellScript = read("admin", "assets", "cms-shell.js");
const codemagic = read("..", "codemagic.yaml");
const storeDataTemplate = read("admin", "pages", "store-data.php");
const pushTemplate = read("admin", "pages", "push-notifications.php");
const previewMain = read("..", "lib", "cms_preview_main.dart");
const previewCatalog = read("..", "lib", "features", "catalog", "data", "repositories", "cms_preview_catalog_repository.dart");
const previewBridge = read("..", "lib", "features", "page_builder", "presentation", "providers", "cms_preview_layout_bridge_web.dart");
const pageStore = read("includes", "class-kidia-mobile-page-layout-store.php");
const catalogCard = read("..", "lib", "features", "catalog", "presentation", "widgets", "catalog_product_card.dart");
const catalogScreen = read("..", "lib", "features", "catalog", "presentation", "pages", "catalog_product_list_screen.dart");
const pageChrome = read("..", "lib", "features", "page_builder", "presentation", "widgets", "cms_page_chrome.dart");
const productScreen = read("..", "lib", "features", "product", "presentation", "product_detail_screen.dart");
const pubspec = read("..", "pubspec.yaml");

const builtInThemes = ["fashion", "beauty", "electronics", "home_living", "kids_baby", "sports_fitness", "grocery", "luxury", "coffee", "multi_store", "jewelry", "pet_care", "family_pop", "marketplace_plus", "studio_fashion", "editorial_runway"];
const idealThemeAssetSizes = {
  hero: { width: 1200, height: 600 },
  banner: { width: 800, height: 600 },
  category: { width: 480, height: 480 }
};
const themeRoleAssetSizes = {
  family_pop: { hero: { width: 1200, height: 698 } },
  marketplace_plus: { hero: { width: 1410, height: 600 }, banner: { width: 690, height: 600 } },
  studio_fashion: { hero: { width: 1180, height: 1000 }, banner: { width: 810, height: 600 } },
  editorial_runway: { hero: { width: 780, height: 1000 }, banner: { width: 656, height: 800 } }
};
const themeProductAssetSizes = {
  fashion: { width: 810, height: 600 },
  beauty: { width: 600, height: 600 },
  electronics: { width: 600, height: 667 },
  home_living: { width: 720, height: 600 },
  kids_baby: { width: 600, height: 600 },
  sports_fitness: { width: 660, height: 600 },
  grocery: { width: 600, height: 698 },
  luxury: { width: 870, height: 600 },
  coffee: { width: 648, height: 600 },
  multi_store: { width: 600, height: 667 },
  jewelry: { width: 720, height: 600 },
  pet_care: { width: 600, height: 600 },
  family_pop: { width: 600, height: 600 },
  marketplace_plus: { width: 600, height: 682 },
  studio_fashion: { width: 810, height: 600 },
  editorial_runway: { width: 900, height: 600 }
};
const newThemeConfiguredRatios = {
  family_pop: { hero: 1.72, banner: 1.33, product: 1 },
  marketplace_plus: { hero: 2.35, banner: 1.15, product: 0.88 },
  studio_fashion: { hero: 1.18, banner: 1.35, product: 1.35 },
  editorial_runway: { hero: 0.78, banner: 0.82, product: 1.5 }
};
for (const theme of builtInThemes) {
  assert.match(service, new RegExp(`'${theme}'\\s*=>`), `Theme ${theme} must be registered.`);
}
assert.equal(builtInThemes.length, 16, "Quick Setup must provide exactly sixteen complete themes.");
for (const theme of builtInThemes) {
  for (const role of ["hero", "banner", "category", "product"]) {
    for (let index = 1; index <= 6; index += 1) {
      const asset = path.join(root, "admin", "assets", "theme-previews", theme, `${role}-${index}.webp`);
      assert.equal(fs.existsSync(asset), true, `Theme asset ${theme}/${role}-${index}.webp must be bundled.`);
      assert.ok(fs.statSync(asset).size > 1000, `Theme asset ${theme}/${role}-${index}.webp must contain real artwork.`);
      const idealSize = role === "product"
        ? themeProductAssetSizes[theme]
        : themeRoleAssetSizes[theme]?.[role] || idealThemeAssetSizes[role];
      assert.deepEqual(webpDimensions(asset), idealSize, `Theme asset ${theme}/${role}-${index}.webp must match its ideal setting ratio.`);
      if (newThemeConfiguredRatios[theme]?.[role]) {
        const actualRatio = idealSize.width / idealSize.height;
        assert.ok(Math.abs(actualRatio - newThemeConfiguredRatios[theme][role]) < 0.005, `Theme asset ${theme}/${role}-${index}.webp must physically match the configured ${role} ratio.`);
      }
    }
  }
}
assert.match(service, /create_backup\(\)/, "Applying a theme must snapshot the current application.");
assert.match(service, /Kidia_Mobile_Layout_Store/, "Themes must update the Home builder.");
assert.match(service, /Kidia_Mobile_Page_Layout_Store/, "Themes must update application page builders.");
assert.match(service, /Kidia_Mobile_Category_Page_Store/, "Themes must update the Category builder.");
assert.match(service, /kidia_mobile_splash_screen/, "Themes must configure the Splash screen.");
assert.match(service, /Kidia_Mobile_Checkout_Fields_Store::DESIGN_OPTION/, "Themes must preserve the selected checkout design.");
assert.doesNotMatch(service, /kidia_mobile_checkout_suggestions/, "Themes must not restore removed Checkout Suggested Products.");
for (const page of ["home", "category", "catalog", "product", "wishlist", "account"]) {
  assert.match(service, new RegExp(`'${page}'\\s*=>`), `Quick Setup must expose ${page} in page selection.`);
}
assert.match(service, /array_fill_keys\(\s*array_keys\(\s*self::setup_pages\(\)\s*\),\s*\$theme_key\s*\)/, "One selected store theme must be shared by all enabled pages.");
assert.match(service, /catalog_slides\(\s*\$theme\s*\)[\s\S]*setup_theme_hero_[\s\S]*asset_url/, "Theme installation must place multiple bundled images in the live Home hero.");
assert.doesNotMatch(service.match(/private function catalog_slides[\s\S]*?return \$slides;\s*\}/)?.[0] || "", /wc_get_products|wp_get_attachment_image_url/, "Built-in theme slides must never read merchant products or media.");
assert.match(service, /build_demo_catalog[\s\S]*theme_demo_labels[\s\S]*product-\d|asset_url\(\s*\$theme,\s*'product'/, "Every built-in theme must include its own demo products and artwork.");
assert.match(service, /hydrate_theme_section_defaults[\s\S]*promo_strip[\s\S]*countdown[\s\S]*quick_links[\s\S]*brand_carousel[\s\S]*banner_grid[\s\S]*hero_slider[\s\S]*product_grid[\s\S]*category_grid/, "Every built-in theme section must receive visible starter content instead of rendering empty.");
assert.match(service, /! \$this->is_complete\(\)[\s\S]*array_intersect_key\( \$defaults[\s\S]*app_name[\s\S]*logo_url[\s\S]*primary_color/, "The first Setup Wizard step must prefer current connected-site identity defaults.");
assert.match(service, /get_option\( 'site_icon'[\s\S]*get_site_icon_url[\s\S]*woocommerce_email_header_image/, "Setup identity must discover a site icon or WooCommerce email logo when the theme has no custom logo.");
assert.match(service, /preview_snapshot[\s\S]*build_home[\s\S]*build_page_layout[\s\S]*build_category_settings/, "Built-in preview and installation must share the same real theme builders.");
assert.match(service, /theme_page_design[\s\S]*'fashion'[\s\S]*'beauty'[\s\S]*'electronics'[\s\S]*'home_living'[\s\S]*'kids_baby'[\s\S]*'sports_fitness'[\s\S]*'grocery'[\s\S]*'luxury'[\s\S]*'coffee'[\s\S]*'multi_store'[\s\S]*'jewelry'[\s\S]*'pet_care'[\s\S]*'family_pop'[\s\S]*'marketplace_plus'[\s\S]*'studio_fashion'[\s\S]*'editorial_runway'/, "Every built-in theme must define a distinct multi-page layout profile.");
for (const theme of Object.keys(newThemeConfiguredRatios)) {
  assert.match(service, new RegExp(`'${theme}'\\s*=>\\s*array\\([\\s\\S]{0,9000}'chrome'\\s*=>\\s*array[\\s\\S]*?'catalog'\\s*=>\\s*array[\\s\\S]*?'product'\\s*=>\\s*array[\\s\\S]*?'wishlist'\\s*=>\\s*array[\\s\\S]*?'account'\\s*=>\\s*array`), `Theme ${theme} must configure every application page instead of inheriting one generic card grid.`);
}
assert.match(service, /'studio_fashion'[\s\S]{0,1200}'category_layout'\s*=>\s*'default'[\s\S]{0,5000}'category_design'/, "Studio Fashion must carry its own lightweight category-list design.");
assert.match(service, /'editorial_runway'[\s\S]{0,5000}'hero_show_indicators'\s*=>\s*false[\s\S]{0,1000}'category_design'/, "Editorial Runway must keep its immersive hero and gallery category treatment.");
const familyThemeStart = service.indexOf("'family_pop' => self::theme(");
const familyThemeEnd = service.indexOf("'marketplace_plus' => self::theme(", familyThemeStart);
const familyTheme = service.slice(familyThemeStart, familyThemeEnd);
const profilesStart = service.indexOf("private function theme_page_design");
const familyProfileStart = service.indexOf("'family_pop' => array(", profilesStart);
const familyProfileEnd = service.indexOf("'marketplace_plus' => array(", familyProfileStart);
const familyProfile = service.slice(familyProfileStart, familyProfileEnd);
assert.match(familyTheme, /'hero_ratio'\s*=>\s*1\.0[\s\S]*'hero_radius'\s*=>\s*12[\s\S]*'hero_padding'\s*=>\s*16/, "Family Pop Home must use the official square campaign geometry and spacing.");
assert.match(familyTheme, /'category_columns'\s*=>\s*3[\s\S]*'category_size'\s*=>\s*64[\s\S]*'quick_columns'\s*=>\s*4[\s\S]*'quick_size'\s*=>\s*64/, "Family Pop Home discovery circles must match the official counts and 64px size.");
assert.match(familyTheme, /'product_ratio'\s*=>\s*1\.1[\s\S]*'product_radius'\s*=>\s*0/, "Family Pop Home product cards must use the shorter PatPat image height.");
assert.match(familyTheme, /'category_design'[\s\S]*'card_height'\s*=>\s*104[\s\S]*'image_size'\s*=>\s*64[\s\S]*'font_size'\s*=>\s*16/, "Family Pop primary categories must use the official list-row measurements.");
assert.match(familyProfile, /'font_family'\s*=>\s*'poppins'/, "Family Pop chrome must carry its own deterministic application font.");
assert.match(familyProfile, /'header_heights'\s*=>\s*array\(\s*'home'\s*=>\s*104[\s\S]*'catalog'\s*=>\s*56[\s\S]*'search_height'\s*=>\s*40[\s\S]*'search_icon_size'\s*=>\s*20/, "Family Pop must use the compact PatPat header, search and search-icon measurements.");
assert.match(service, /\$is_family_pop[\s\S]*'category'\s*=>\s*array[\s\S]*86,\s*array\(\s*'search_bar'[\s\S]*'catalog'\s*=>\s*array[\s\S]*'back'[\s\S]*'search',\s*'cart'/, "Family Pop must install page-specific official header compositions.");
assert.match(familyProfile, /'icon_size'\s*=>\s*22[\s\S]*'label_size'\s*=>\s*11[\s\S]*'icon_label_gap'\s*=>\s*3/, "Family Pop navigation must carry the compact PatPat icon and label measurements.");
assert.match(familyProfile, /'filter_button_style'\s*=>\s*'flat'[\s\S]*'filter_color'\s*=>\s*true[\s\S]*'gap'\s*=>\s*6[\s\S]*'image_ratio'\s*=>\s*1\.1/, "Family Pop catalog must use the four-part flat filter row and short product grid.");
assert.match(familyProfile, /'tabs_enabled'\s*=>\s*true[\s\S]*'gallery_ratio'\s*=>\s*\.88[\s\S]*'reviews_enabled'\s*=>\s*true[\s\S]*'related_ratio'\s*=>\s*1\.1[\s\S]*'button_width'\s*=>\s*62[\s\S]*'show_button_icon'\s*=>\s*false/, "Family Pop product detail must retain tabs and reviews with short related cards and the 62% text-only purchase button.");
assert.match(familyProfile, /'access'\s*=>\s*'sign_in_required'/, "Family Pop Wishlist must route signed-out customers to the sign-in state.");
assert.match(pageStore, /show_button_icon/, "Page Builder must expose the product purchase-button icon toggle.");
assert.match(pageStore, /font_family[\s\S]*content_horizontal_padding/, "Page Builder must preserve the Family Pop font and page spacing settings.");
assert.match(pageStore, /outer_horizontal_padding[\s\S]*image_inset[\s\S]*price_prefix[\s\S]*price_color/, "Product grids must expose exact image, spacing and price controls.");
assert.match(catalogCard, /imageInset[\s\S]*imageRadius[\s\S]*contentHorizontalPadding[\s\S]*pricePrefix[\s\S]*priceColor/, "Flutter product cards must consume every Family Pop grid token.");
assert.match(catalogScreen, /button_style[\s\S]*_FlatToolbarButton[\s\S]*catalog-color-button/, "Flutter catalog must render the official flat Sort, Size, Color and Filter toolbar.");
assert.match(pageChrome, /font_family[\s\S]*Poppins[\s\S]*textTheme\.apply/, "Flutter page chrome must apply the selected page font throughout the screen.");
assert.match(productScreen, /show_button_icon[\s\S]*FilledButton\.icon[\s\S]*FilledButton\(/, "Product purchase bar must support the official text-only button.");
assert.match(pubspec, /family:\s*Poppins[\s\S]*Poppins-Regular\.ttf[\s\S]*Poppins-Bold\.ttf/, "The licensed Poppins family must be bundled for deterministic visual parity.");
for (const fontFile of ["Poppins-Regular.ttf", "Poppins-Medium.ttf", "Poppins-SemiBold.ttf", "Poppins-Bold.ttf", "OFL.txt"]) {
  assert.ok(fs.statSync(path.join(root, "..", "assets", "fonts", fontFile)).size > 1000, `Font asset ${fontFile} must be bundled with its license.`);
}
for (const pageDesign of ["catalog", "product", "wishlist", "account"]) {
  assert.match(service, new RegExp(`'${pageDesign}'\\s*=>\\s*array`), `Complete themes must configure the ${pageDesign} page.`);
}
assert.match(service, /secondary_color/, "Setup identity must persist the secondary application color.");
assert.match(service, /site_identity_defaults[\s\S]*custom_logo[\s\S]*site_logo[\s\S]*woocommerce_email_header_image/, "Setup identity must discover the connected site's logo without requiring a second upload.");
assert.match(service, /get_theme_mods[\s\S]*astra-settings[\s\S]*xts-woodmart-options[\s\S]*collect_site_colors/, "Setup identity must inspect semantic palette settings used by popular WordPress themes.");
assert.match(service, /#0878e5[\s\S]*#e8f3ff[\s\S]*defaults\['primary_color'\][\s\S]*defaults\['secondary_color'\]/, "Legacy demo blues must migrate to the detected site palette without replacing user-selected colors.");
assert.match(service, /wp_get_global_settings[\s\S]*'theme'[\s\S]*'custom'[\s\S]*'default'[\s\S]*tint_color/, "Setup identity must derive editable brand colors from every global palette and calculate a safe tint fallback.");
assert.match(service, /compact_product_card_settings[\s\S]*'card_style'\s*=>\s*'outlined'[\s\S]*'image_ratio'\s*=>\s*\.88[\s\S]*'show_rating'\s*=>\s*true[\s\S]*'quick_add_icon_variant'\s*=>\s*'bag'[\s\S]*'quick_add_position'\s*=>\s*'bottom_end'/, "Setup themes must use the compact outlined product card with rating, price, and over-image bag action.");
assert.match(service, /compact_product_card_settings[\s\S]*'quick_add_icon_color'\s*=>\s*\$primary[\s\S]*'quick_add_background_color'\s*=>\s*'#FFFFFF'/, "The quick-add bag must use the brand color on a white circle.");
assert.match(service, /preview_snapshot[\s\S]*identity\(\)[\s\S]*primary_color[\s\S]*build_page_layout\( \$page, \$theme, \$primary, \$secondary/, "Built-in previews must use the brand colors captured on the identity step.");
assert.match(service, /Navigation accents always follow the store brand[\s\S]*active_color'\] = \$primary[\s\S]*button_color'\] = \$primary/, "Active navigation and footer actions must always use the brand primary color.");
assert.match(service, /product_tabs'[\s\S]*'active_color'\s*=>\s*\$primary[\s\S]*footer'\]\['settings'\]\['button_color'\]\s*=\s*\$primary/, "Product tabs and product actions must use the brand primary color.");
assert.match(wizardJs, /snapshotWithLiveBrand[\s\S]*setup\[primary_color\][\s\S]*setup\[secondary_color\][\s\S]*JSON\.parse\(JSON\.stringify[\s\S]*selectPreviewPage\(previewPage\)/, "Changing either identity color must rebuild the open Flutter preview from the live brand fields.");
assert.match(wizardCss, /\.kidia-theme-modal__device iframe\{[^}]*transform:scale\(var\(--kidia-theme-preview-scale\)\);[^}]*transform-origin:top left/, "Theme preview must scale deterministically inside the shared phone frame.");
assert.doesNotMatch(wizardCss, /\.kidia-theme-modal__device iframe\{[^}]*zoom:/, "Theme preview must not use browser-dependent iframe zoom that distorts the phone frame.");
assert.match(service, /sanitize_enabled_pages/, "Setup must sanitize required and optional page selections.");
assert.match(service, /layout\['enabled'\]\s*=\s*false/, "Unselected setup pages must be disabled without overwriting their layout.");
assert.match(service, /SAVED_THEMES_OPTION/, "Saved themes must use a dedicated persistent store.");
assert.match(service, /strip_product_images/, "Saved themes must exclude WooCommerce product images.");
assert.doesNotMatch(service, /\$snapshot\['category'\]\['categories'\][\s\S]{0,500}\['image_url'\]\s*=\s*''/, "Saved themes must retain category artwork for settings-and-images exports.");
assert.match(service, /saved_theme_preview[\s\S]*collect_preview_image_urls/, "Saved theme cards must derive their artwork from the stored theme snapshot.");
assert.match(service, /build_required/, "Applying or importing a theme must request a fresh application build.");
assert.match(bootstrap, /class-kidia-mobile-app-exporter\.php[\s\S]*Kidia_Mobile_App_Exporter\(\)\)->register/, "The app exporter must load and register with the plugin.");
assert.match(exporter, /woomobile-app-build-package[\s\S]*app-config\.json[\s\S]*push-config\.json[\s\S]*dart-defines\.json/, "Export App must download a portable build package.");
assert.match(exporter, /admin_post_kidia_mobile_build_app[\s\S]*admin_post_kidia_mobile_download_apk[\s\S]*wp_ajax_kidia_mobile_app_build_start[\s\S]*wp_ajax_kidia_mobile_app_build_status/, "APK builds must expose fallback, asynchronous start, status and download actions.");
assert.match(exporter, /start_build\(\)[\s\S]*'platform'\s*=>\s*'android'[\s\S]*'artifact'\s*=>\s*'apk'/, "Build APK must queue a real Android APK artifact.");
assert.match(exporter, /ASYNC_HOOK[\s\S]*queue_build\(\)[\s\S]*as_enqueue_async_action[\s\S]*wp_schedule_single_event[\s\S]*process_queued_build/, "APK creation must leave the Overview request immediately and dispatch the slow remote build in the background.");
assert.match(exporter, /START_TIMEOUT[\s\S]*did not start in time/, "A background build that never starts must return to a retryable failure state.");
assert.match(exporter, /refresh_build\(\)[\s\S]*handle_download_apk[\s\S]*download_url/, "APK builds must poll for completion before exposing the download.");
assert.match(exporter, /refresh_build\(\s*true\s*\)/, "Downloading must refresh the remote build so an expired signed APK URL is replaced.");
assert.match(exporter, /configuration_hash[\s\S]*plugin_version[\s\S]*provision_push/, "The APK request must use the production service's snake_case contract.");
assert.match(exporter, /download-link[\s\S]*redirect_to_artifact[\s\S]*wp_redirect/, "The finished build must request a fresh link and redirect straight to Codemagic without proxying the file through WordPress.");
assert.doesNotMatch(exporter, /wp_safe_remote_get[\s\S]*'stream'\s*=>\s*true/, "Large build files must not be downloaded into a WordPress temporary file.");
assert.match(licenseManager, /BUILD_API_BASE_URL[\s\S]*build_service_request[\s\S]*Authorization[\s\S]*X-WooMobile-Installation/, "The build service must reuse installation-bound license authorization without exposing it to the browser.");
assert.match(licenseManager, /PUSH_API_BASE_URL[\s\S]*push_service_request[\s\S]*Authorization[\s\S]*X-WooMobile-Installation/, "Managed Push delivery must reuse installation-bound license authorization.");
assert.match(exporter, /secondaryColor[\s\S]*enabledPages/, "Exported app identity must include colors and selected pages.");
assert.match(exporter, /Kidia_Mobile_Push_Service::client_configuration/, "Every exported application must inherit the plugin's public Push bootstrap.");
for (const secret of ["fcm_private_key", "fcm_client_email", "onesignal_api_key", "webhook_secret"]) {
  assert.doesNotMatch(exporter, new RegExp(`\\['${secret}'\\]`), `Export App must never expose ${secret}.`);
}
assert.match(pushService, /'\/push\/config'[\s\S]*public_configuration/, "Exported apps must be able to refresh public Push configuration from WordPress.");
assert.match(pushService, /'mode'\s*=>\s*'managed'[\s\S]*'provisionOnBuild'\s*=>\s*true[\s\S]*'requiresNativeSetup'\s*=>\s*false/, "Application builds must provision managed Push without customer Firebase setup.");
assert.doesNotMatch(pushService, /onesignal_api_key|fcm_private_key|fcm_client_email|webhook_secret/, "Provider credentials must not be stored by the WordPress plugin.");

assert.match(admin, /admin_post_kidia_mobile_apply_setup_wizard/, "Wizard apply action must be registered.");
assert.match(admin, /admin_post_kidia_mobile_manage_saved_theme/, "Saved theme actions must be registered.");
assert.match(admin, /render_cms_shell/, "Unified shell must render on CMS screens.");
assert.match(admin, /current_screen[^]*suppress_external_admin_notices/, "CMS pages must suppress notices emitted by WordPress and unrelated plugins.");
assert.match(admin, /remove_all_actions\( 'admin_notices' \)/, "Third-party admin notices must be removed inside the CMS workspace.");
assert.match(admin, /remove_submenu_page\(\s*'kidia-mobile-cms'/, "Legacy sidebar submenu pages must be hidden.");
assert.match(admin, /add_submenu_page\(\s*null,\s*__\( 'Home Page'/, "Top-tab pages must remain registered as hidden WordPress pages.");
assert.doesNotMatch(admin, /remove_submenu_page\(\s*'kidia-mobile-cms',\s*'kidia-mobile-home-builder'/, "Public builders must not be unregistered while hiding sidebar links.");
assert.match(admin, /Kidia_Mobile_Setup_Wizard\(\) \)->is_complete/, "First visit must resolve setup state.");
assert.match(wizardTemplate, /kidia-theme-gallery/, "Wizard must render a theme gallery.");
assert.match(wizardTemplate, /Choose a complete store theme/, "Setup must select one complete store theme instead of one design per page.");
assert.doesNotMatch(wizardTemplate, /setup\[page_themes\]/, "Setup must not mix unrelated designs across different pages.");
assert.match(wizardTemplate, /Preview full theme[\s\S]*data-theme-modal-page[\s\S]*data-theme-modal-frame/, "Every complete theme must have a real all-page Flutter preview.");
assert.match(wizardTemplate, /Choose application pages[\s\S]*data-page-toggle/, "The second setup step must select required and optional application pages.");
assert.match(wizardTemplate, /setup\[secondary_color\]/, "Application identity must expose a secondary color.");
assert.match(wizardTemplate, /detected from the connected site and remain editable/, "Application identity must explain that its defaults came from the connected site.");
assert.match(wizardTemplate, /data-color-picker="primary"[\s\S]*data-color-code="primary"[\s\S]*data-color-picker="secondary"[\s\S]*data-color-code="secondary"/, "Both application colors must expose a picker and editable HEX code.");
assert.match(wizardCss, /\.kidia-setup-color-control\{display:flex!important;[^}]*align-items:stretch;[^}]*width:100%}/, "Each color picker and HEX code must stay in one compact row.");
assert.match(wizardCss, /\.kidia-setup-color-control input\[type=text\]\{[^}]*width:auto!important;[^}]*flex:1 1 auto;[^}]*direction:ltr;/, "HEX fields must share the color row without wrapping and keep the hash on the left.");
assert.match(wizardTemplate, /if \( \$is_required \)[\s\S]*type="hidden"[\s\S]*data-required-page="1"[\s\S]*else[\s\S]*type="checkbox"[\s\S]*if \( ! \$is_required \)[\s\S]*kidia-page-choice__switch/, "Required pages must stay enabled without rendering a checkbox or On/Off switch.");
assert.match(wizardTemplate, /catalog_stats/, "Wizard must report real catalog content.");
assert.doesNotMatch(wizardTemplate, /catalog_images/, "Theme cards must never use merchant catalog images.");
assert.match(wizardTemplate, /asset_url\(\s*\$theme,\s*'category'[\s\S]*asset_url\(\s*\$theme,\s*'product'/, "Theme cards must use their bundled category and product artwork.");
assert.match(wizardTemplate, /Finish setup[\s\S]*name="finish_setup"[\s\S]*Finish/, "Setup Wizard must finish by applying the theme before customization.");
assert.doesNotMatch(wizardTemplate, /name="build_after_apply"[\s\S]*Build APK/, "Setup Wizard must not start an APK build from its final action.");
assert.match(admin, /'page'\s*=>\s*'kidia-mobile-splash-screen'[\s\S]*'setup_done'\s*=>\s*'1'/, "Finish must open Customize Your Pages after applying the setup.");
assert.match(service, /function theme_header_layout[\s\S]*'fashion'[\s\S]*'beauty'[\s\S]*'electronics'[\s\S]*'editorial_runway'/, "All built-in themes must define intentional, distinct home header compositions.");
assert.match(service, /function signature_feature[\s\S]*'Shop by skin concern'[\s\S]*'Tech deal drop'[\s\S]*'Shop the room'[\s\S]*'Fresh today'[\s\S]*'The private collection'[\s\S]*'The campaign story'/, "Every business theme must install a business-specific signature section.");
assert.match(service, /signature_feature[\s\S]*theme_header_layout[\s\S]*signature_feature/, "Theme signatures and header layouts must be consumed by the generated application layout.");
assert.match(dashboardTemplate, /kidia-customer-journey__build-step[\s\S]*data-kidia-app-build[\s\S]*kidia-app-build__card-form[\s\S]*data-build-form-action[\s\S]*kidia-app-build__card kidia-app-build__card-button[\s\S]*data-build-action/, "The complete fourth launch card must be the single stateful build/download button.");
assert.match(shellTemplate, /data-build-persistent[\s\S]*data-kidia-background-job="app-build"[\s\S]*data-build-modal[\s\S]*role="dialog"[\s\S]*data-build-message[\s\S]*data-build-progress[\s\S]*data-build-cancel/, "The build progress card must live in the permanent CMS shell and keep its action across page changes.");
assert.match(shellTemplate, /\$shell_build_active[\s\S]*Cancel Build[\s\S]*OK/, "The server-rendered build card must show Cancel only while active and OK after a terminal state.");
assert.match(admin, /if \( \$this->is_public_cms_page\( \$page \) \)[\s\S]*kidia-mobile-app-builder/, "Every CMS page must load the persistent build tracker.");
assert.doesNotMatch(dashboardTemplate, /Developer build files|Download configuration ZIP/, "The compact build card must not render developer copy or a second action.");
assert.match(dashboardTemplate, /\.kidia-app-build__card-button\s*\{[^}]*width:\s*100%;[^}]*height:\s*100%;[^}]*min-height:\s*120px;[^}]*background:\s*#2f806e;/, "The complete build card button must use the WooMobile color and fill the journey card without a blank strip.");
assert.doesNotMatch(dashboardTemplate, /kidia-app-build__card-button[\s\S]{0,500}kidia-customer-journey__number[^}]*>4</, "The complete build card button must not show a fourth-step number.");
assert.match(dashboardTemplate, /\.kidia-app-build__card-label\s*\{[^}]*font-size:\s*clamp\([^}]*font-weight:\s*700;[^}]*text-wrap:\s*balance;/, "The build action label must use balanced, polished typography.");
assert.match(dashboardTemplate, /Build Your App[\s\S]*Android &amp; iOS/, "The build card must show only the Android and iOS platform subtitle beneath Build Your App.");
assert.match(dashboardTemplate, /last 5 days[\s\S]*data-build-download-again[\s\S]*data-build-new-version/, "A build from the last 5 days must offer download again or a new build.");
assert.match(codemagic, /flutter build apk --release[\s\S]*flutter build appbundle --release[\s\S]*app-release\.apk[\s\S]*app-release\.aab[\s\S]*woomobile-build-files\.zip/, "Codemagic must package both the direct-install APK and Google Play AAB.");
assert.doesNotMatch(codemagic, /flutter build ios|ios-app\.zip|\.ipa/, "The customer bundle must exclude unsigned iOS output until Apple Developer signing is configured.");
assert.doesNotMatch(wizardTemplate, /kidia-saved-themes/, "Saved Themes must no longer occupy the Setup Wizard.");
assert.match(savedThemesTemplate, /kidia-saved-themes__empty/, "Saved Themes must provide a dedicated empty state.");
assert.match(savedThemesTemplate, /Import Theme/, "The empty Saved Themes page must center an Import Theme action.");
assert.match(shellTemplate, /kidia-cms-sidebar/, "Shell must expose the primary left navigation.");
assert.match(shellTemplate, /data-kidia-cms-shell[\s\S]*\$show_page_tabs \? '' : ' hidden'/, "The one permanent page frame must hide outside Customize without being removed.");
assert.match(shellTemplate, /kidia-cms-tabs/, "Customize Your Pages must preserve the existing top page tabs.");
assert.doesNotMatch(shellTemplate, /kidia-cms-more/, "The obsolete More menu must not appear in the page header.");
assert.doesNotMatch(shellTemplate, /window\.prompt/, "Save Theme must not use the browser prompt.");
assert.match(shellTemplate, /data-kidia-save-theme[\s\S]*data-kidia-theme-modal[\s\S]*data-kidia-theme-name[\s\S]*Save Theme/, "Every page header must open the centered themed Save Theme dialog.");
assert.doesNotMatch(shellTemplate.match(/<form class="kidia-cms-save-theme"[\s\S]*?<\/form>/)?.[0] || "", /dashicons/, "The compact Save Theme button must not render a trailing icon.");
assert.match(shellCss, /\.kidia-cms-save-theme \.button\s*\{[^}]*width:max-content;[^}]*min-width:0;/, "The Save Theme button must fit its label instead of keeping an oversized width.");
assert.match(shellCss, /\.kidia-cms-save-theme \.button\s*\{[^}]*border-color:#236b59!important;[^}]*background:#2f806e!important;[^}]*color:#fff!important;/, "Save Theme must keep the Kidia color instead of inheriting WordPress blue.");
assert.match(shellScript, /data-kidia-theme-modal[\s\S]*kidia_save_theme_name[\s\S]*requestSubmit/, "The themed Save Theme dialog must preserve unsaved builder fields before creating the named theme.");
assert.match(shellScript, /installPersistentCmsNavigation[\s\S]*kidia_mobile_cms_view[\s\S]*response\.json\(\)[\s\S]*persistentShellNode\(node, sidebar, shell\)[\s\S]*history\.pushState/, "CMS navigation must request only a view fragment and retain the shell plus every background-job card.");
assert.doesNotMatch(shellScript.slice(0, shellScript.indexOf("installPersistentCmsNavigation();")), /DOMParser|response\.text\(/, "CMS navigation must never fetch another WordPress document.");
assert.match(shellScript, /window\.kidiaCmsNavigatorInstalled/, "Persistent CMS navigation must be installed once even when page assets are refreshed.");
assert.match(shellCss, /#wpbody-content\.is-kidia-page-loading \.kidia-cms-sidebar\{[^}]*opacity:1;[^}]*pointer-events:auto;/, "The persistent sidebar must never show the adjacent page loading state.");
assert.equal(fs.existsSync(path.join(root, "tests", "persistent-cms-sidebar-test.js")), true, "The persistent sidebar must have a runtime identity test.");
assert.match(savedThemesTemplate, /kidia-theme-file[\s\S]*button-primary/, "Theme import must use the WooMobile file control and theme-colored action.");
assert.match(savedThemesTemplate, /data-saved-theme-phone[\s\S]*theme_images[\s\S]*data-saved-theme-preview/, "Every saved theme card must show its own artwork and expose Preview.");
assert.match(savedThemesTemplate, /data-saved-theme-dialog/, "Saved themes must provide a focused large preview dialog.");
assert.match(savedThemesTemplate, /data-saved-theme-snapshot[\s\S]*Kidia_Mobile_Setup_Wizard::setup_pages\(\)[\s\S]*data-saved-theme-page[\s\S]*data-saved-theme-dialog-frame/, "Saved Theme Preview must expose every application page in the real Flutter surface.");
assert.match(savedThemesScript, /homePreviewEndpoint[\s\S]*categoryPreviewEndpoint[\s\S]*kidia-preview-layout[\s\S]*kidia-flutter-preview-ready/, "Saved Theme Preview must send the stored page layouts to the real Flutter preview.");
assert.match(savedThemesTemplate, /kidia-saved-theme-dialog__device[\s\S]*kidia-saved-theme-dialog__screen[\s\S]*data-saved-theme-dialog-frame/, "Saved Theme Preview must reuse the clean Page Builder phone and screen structure.");
assert.match(wizardCss, /\.kidia-saved-theme-dialog__device:before\{display:none;content:none\}[\s\S]*\.kidia-saved-theme-dialog__screen\{[^}]*height:680px[\s\S]*zoom:\.85/, "Saved Theme Preview must remove the earpiece and show the full 800px Flutter surface at the Page Builder scale.");
assert.match(savedThemesTemplate, /data-saved-theme-export[\s\S]*data-saved-theme-export-dialog[\s\S]*value="settings"[\s\S]*value="settings_and_images"/, "Export must ask whether to include settings only or settings and non-product images.");
assert.match(service, /export_saved_theme\(\s*string \$id,\s*bool \$include_images[\s\S]*export_theme_images[\s\S]*collect_theme_image_urls[\s\S]*import_theme_images[\s\S]*replace_theme_image_urls/, "Saved theme files must embed and restore selected non-product images.");
assert.match(admin, /export_mode[\s\S]*settings_and_images[\s\S]*export_saved_theme\(\s*\$theme_id,\s*\$include_images\s*\)/, "The export handler must honor the selected image mode.");
assert.match(admin, /kidiaSavedThemePreview[\s\S]*flutterUrl[\s\S]*layoutPreviewBase[\s\S]*homePreviewEndpoint[\s\S]*categoryPreviewEndpoint/, "Saved Theme Preview must receive authenticated live-preview endpoints.");
assert.match(admin, /preview_snapshot[\s\S]*kidiaSetupThemePreview[\s\S]*flutterUrl[\s\S]*layoutPreviewBase[\s\S]*homePreviewEndpoint[\s\S]*categoryPreviewEndpoint/, "Setup themes must receive their exact generated layouts and authenticated Flutter preview endpoints.");
assert.match(admin, /kidia-mobile-saved-themes[\s\S]*admin\/assets\/saved-themes\.js/, "The Saved Themes page must load its preview interactions.");
assert.match(admin, /'overview'\s*=>\s*\$tab\(\s*__\(\s*'Overview'/, "The sidebar must start with Overview.");
assert.match(admin, /'setup'\s*=>\s*\$tab\(\s*__\(\s*'Setup Wizard'/, "Setup Wizard must follow Overview.");
assert.match(admin, /\$tabs\s*=\s*array\([\s\S]*'splash'\s*=>\s*\$tab\(\s*__\(\s*'Splash'/, "Splash must be the first page tab.");
assert.match(admin, /'pages'\s*=>\s*\$tab\(\s*__\(\s*'Customize Your Pages'/, "Customize Your Pages must own the page-builder sidebar destination.");
assert.doesNotMatch(admin, /'splash'\s*=>\s*\$tab\(\s*__\(\s*'Splash Page'/, "Splash must not remain a standalone sidebar destination.");
assert.match(admin, /'saved_themes'\s*=>\s*\$tab\(\s*__\(\s*'Saved Themes'/, "Saved Themes must have its own sidebar destination.");
assert.match(admin, /saved_theme_redirect[\s\S]*save_current_theme[\s\S]*kidia-mobile-saved-themes/, "Named page-header saves must persist the latest builder state and open Saved Themes.");
assert.match(admin, /'account'[\s\S]*'checkout'\s*=>\s*\$tab\(\s*__\(\s*'Checkout'/, "Checkout must appear immediately after Account in the page tabs.");
assert.doesNotMatch(admin, /'size_chart'\s*=>\s*\$tab[\s\S]*'similar'\s*=>\s*\$tab/, "Size Chart and Similar Products must not remain in the main page header.");
assert.match(admin, /'store_data'\s*=>\s*\$tab\([\s\S]*'ai_insights'\s*=>\s*\$tab\([\s\S]*'push'\s*=>\s*\$tab\(/, "Store Data, AI Offer Studio and Push Notifications must be available in the CMS sidebar.");
assert.match(admin, /function store_data_page[\s\S]*WP_Query[\s\S]*wc_get_product[\s\S]*wc_get_orders/, "Store Data must read the paginated live WooCommerce catalog and orders.");
assert.match(admin, /function send_push_notification[\s\S]*kidia_mobile_send_push_notification[\s\S]*kidia_mobile_push_history/, "Push Notifications must validate, dispatch and record notifications.");
for (const tab of ["Products", "Categories", "Discounts", "Customers", "Orders", "Reports", "Analytics"]) {
  assert.match(storeDataTemplate, new RegExp(`'${tab}'`), `Store Data must expose the ${tab} workspace.`);
}
for (const editor of ["get_edit_post_link", "get_edit_term_link", "get_edit_user_link"]) {
  assert.match(storeDataTemplate, new RegExp(editor), "Store Data rows must open the real WooCommerce and WordPress editors.");
}
for (const layout of ["kidia-data-table", "kidia-order-list", "kidia-customer-list", "kidia-category-list"]) {
  assert.match(storeDataTemplate, new RegExp(layout), `Store Data must render ${layout}.`);
}
assert.match(storeDataTemplate, /data-copy-link[\s\S]*data-copy-text/, "Products, categories and coupons must expose useful copy actions.");
assert.match(storeDataTemplate, /store_source[\s\S]*Website[\s\S]*Mobile App/, "Orders, customers, reports and abandoned carts must filter All, Website and Mobile App data.");
assert.match(storeDataTemplate, /source_tabs[\s\S]*analytics/, "Analytics must expose the shared source filter.");
assert.match(pushTemplate, /Broadcast[\s\S]*Offer[\s\S]*Order update[\s\S]*Back in stock[\s\S]*Abandoned cart[\s\S]*Welcome[\s\S]*Custom/, "Push Notifications must expose all supported notification journeys without forcing AI Studio into Push.");
assert.match(pushTemplate, /Push connection managed automatically[\s\S]*no provider selection or Firebase keys are required/, "Push Notifications must explain its automatic managed connection.");
assert.doesNotMatch(pushTemplate, /data-push-provider|OneSignal App ID|Service-account private key/, "Push Notifications must not ask customers to choose or configure a vendor.");
assert.match(pushTemplate, /push_title[\s\S]*push_message[\s\S]*push_audience[\s\S]*push_delivery[\s\S]*Live preview[\s\S]*History/, "Push Notifications must provide compose, targeting, delivery, live preview and history.");
assert.match(pushTemplate, /Message[\s\S]*Open destination[\s\S]*Audience & delivery/, "Push composer controls must be divided into clear task groups.");
assert.match(shellScript, /data-push-title[\s\S]*data-push-preview-title/, "Push notification copy must update its live preview.");
assert.match(shellScript, /data-push-submit-label[\s\S]*Schedule notification[\s\S]*Save automation[\s\S]*Send notification/, "The primary Push action must describe the selected delivery mode.");
assert.match(shellScript, /date_preset[\s\S]*customDates[\s\S]*input\.disabled/, "Custom dates must remain disabled until Custom is selected.");
assert.match(admin, /function ai_insights_page[\s\S]*Kidia_Mobile_AI_Offer_Engine::recommendations/, "AI Offer Studio must have its own evidence-backed page.");
assert.match(admin, /ai_offer_id[\s\S]*selected_push_type\s*=\s*'offer'/, "An optional reviewed AI offer push must prefill the editable offer composer.");
assert.match(wizardCss, /kidia-theme-phone/, "Theme previews must have a detailed mobile mockup.");
assert.match(wizardCss, /kidia-theme-modal__workspace[\s\S]*kidia-theme-modal__device[\s\S]*iframe/, "Full theme preview must host the real Flutter application surface.");
assert.match(wizardTemplate, /kidia-theme-modal__controls[\s\S]*kidia-theme-modal__pages[\s\S]*kidia-theme-modal__select/, "Theme selection must sit directly below the page buttons.");
assert.match(wizardCss, /\.kidia-theme-modal__select\{[^}]*margin-top:0!important;[^}]*border-color:#111!important;[^}]*background:#111!important/, "Theme selection must stay directly below the page buttons and retain its black action color.");
assert.match(wizardCss, /kidia-theme-modal__dialog\{[^}]*height:min\(850px,calc\(100vh - 40px\)\)[^}]*overflow:hidden/, "Theme preview must fit the popup viewport without an outer scrollbar.");
assert.match(wizardCss, /kidia-theme-modal__device\{[^}]*--kidia-theme-preview-scale:\.72[^}]*width:calc\(360px \* var\(--kidia-theme-preview-scale\) \+ 16px\)[^}]*height:calc\(800px \* var\(--kidia-theme-preview-scale\) \+ 16px\)[^}]*overflow:hidden/, "The complete phone must include its padding and border without clipping either side of the preview.");
assert.match(wizardCss, /kidia-setup-apply\{[^}]*flex-direction:row!important[^}]*white-space:nowrap\}[\s\S]*kidia-setup-apply \.dashicons\{[^}]*line-height:20px/, "Finish label and check icon must remain centered on one row.");
assert.match(wizardCss, /kidia-setup-color-control\{display:flex!important;[^}]*align-items:stretch;[^}]*width:100%}/, "Color picker and HEX code must stay compact and side by side.");
assert.match(wizardCss, /\.kidia-setup-actions \.button\[hidden\]\{display:none!important\}/, "Apply Theme must remain hidden until the final setup step.");
assert.match(wizardCss, /--kidia-setup-theme-color:#2f806e/, "Setup actions must expose a theme-driven color.");
const wizardScript = read("admin", "assets", "setup-wizard.js");
assert.match(wizardScript, /setProperty\('--kidia-setup-theme-color', '#2f806e'\)/, "Setup actions must keep the WooMobile brand color.");
assert.match(wizardScript, /normalizeHex[\s\S]*data-color-code[\s\S]*syncColorPair/, "Editable HEX color values must stay synchronized with their color pickers.");
assert.match(wizardScript, /homePreviewEndpoint[\s\S]*categoryPreviewEndpoint[\s\S]*kidia-preview-layout[\s\S]*kidia-flutter-preview-ready/, "Built-in theme preview must render real Home, Category and page layouts in Flutter.");
assert.match(wizardScript, /demo_catalog[\s\S]*searchParams\.set\('demo', '1'\)[\s\S]*searchParams\.set\('product', '9001'\)/, "Built-in previews must route every page through the theme-only demo catalog.");
assert.match(previewMain, /catalogRepositoryProvider\.overrideWithValue[\s\S]*CmsPreviewCatalogRepository/, "Flutter theme previews must replace the live catalog repository.");
assert.match(previewCatalog, /CmsPreviewLayoutBridge\.demoCatalog/, "The preview catalog must read only the selected theme payload.");
assert.doesNotMatch(previewCatalog, /Dio|StoreApi|apiBaseUrl|wc_/, "The preview catalog must never call the merchant store.");
assert.match(previewBridge, /demo_catalog[\s\S]*_demoCatalogReady/, "The preview bridge must deliver the bundled demo catalog before product pages render.");
assert.match(wizardScript, /kidia-theme-modal__select/, "Full preview must allow selecting the previewed complete theme.");
assert.match(wizardScript, /document\.querySelector\('\.kidia-setup-hero'\)/, "Wizard navigation must keep the Setup & Themes hero visible.");
assert.match(wizardScript, /history\.scrollRestoration = 'manual'/, "Wizard must ignore stale browser scroll restoration.");
assert.match(wizardScript, /show\(0, false\)/, "Initial wizard rendering must not scroll past the top hero.");
assert.match(shellCss, /position:sticky/, "Unified navigation must remain available while editing.");
assert.match(shellCss, /box-shadow:inset 0 0 0 2px #2f806e/, "Header focus must use an inset Kidia-colored ring.");
assert.match(shellCss, /\.kidia-cms-setup-link\{[^}]*background:#236b59;[^}]*color:#fff\}/, "Quick Setup & Themes must use the dark Kidia button color.");
assert.match(shellCss, /\.kidia-cms-tabs>a:focus[^}]*color:#216e5e/, "Focused CMS tabs must keep readable dark-green text instead of turning white.");
assert.match(shellCss, /\.kidia-cms-setup-link:focus[^}]*box-shadow:none!important/, "Quick Setup must not draw a square focus box after it is clicked.");
assert.match(shellCss, /#wpbody-content\{[^}]*border:/, "The unified workspace must be enclosed by a full-page frame.");
assert.match(shellCss, /#wpbody-content\{height:auto!important\}[\s\S]*#wpbody-content\{\s*min-height:calc\(100vh - 68px\)!important;/, "Short CMS pages must reach the shared sidebar bottom while longer pages remain content-sized.");
assert.match(shellCss, /#wpbody-content\{padding-bottom:0!important\}/, "WordPress must not append footer padding below the CMS frame.");
assert.match(shellCss, /#wpfooter\{display:none\}/, "The unused WordPress footer must not extend CMS pages.");
assert.match(shellCss, /html\{[^}]*height:100%;[^}]*overflow:hidden!important;[^}]*scrollbar-gutter:auto!important;/, "WordPress document scrolling must stay disabled throughout the CMS workspace.");
assert.match(shellCss, /body\.kidia-cms-plugin-page #wpbody\{[^}]*height:calc\(100vh - 46px\)!important;[^}]*overflow-y:scroll!important;[^}]*scrollbar-gutter:stable;/, "The plugin workspace must own the only vertical scrollbar on every CMS screen.");
assert.match(shellCss, /@media\(min-width:783px\)\{[\s\S]*body\.kidia-cms-plugin-page #wpbody\{[^}]*height:calc\(100vh - 32px\)!important;[^}]*direction:ltr;/, "The desktop plugin scrollbar must fit below the WordPress toolbar.");
assert.match(shellCss, /html\[dir="ltr"\][^}]*#wpbody\{[^}]*direction:rtl;/, "LTR WordPress must place the plugin scrollbar beside its left admin menu.");
assert.match(shellCss, /html\[dir="rtl"\][^}]*#wpbody-content,[^}]*\.rtl body[^}]*#wpbody-content\{[^}]*direction:rtl;/, "Moving the plugin scrollbar to the physical right must not change RTL content direction.");
assert.match(shellCss, /@media\(min-width:783px\)\{[\s\S]*body\.kidia-cms-plugin-page #adminmenuwrap\{[^}]*position:fixed!important;[^}]*inset-block-start:32px!important;[^}]*inset-block-end:0!important;[^}]*inset-inline-start:0!important;[^}]*overflow-y:scroll!important;[^}]*overscroll-behavior:contain;[^}]*scrollbar-gutter:stable;/, "The black WordPress menu must keep its own contained desktop scrollbar.");
assert.match(shellCss, /#adminmenuwrap::-webkit-scrollbar\{[^}]*width:8px;/, "The isolated WordPress menu scrollbar must stay compact and must not consume plugin workspace width.");
assert.match(admin, /admin_body_class[\s\S]*kidia-cms-builder-screen/, "Builder pages must be marked for the fixed workspace before rendering.");
assert.match(shellCss, /body\.kidia-cms-builder-screen\{[^}]*overflow:hidden!important;/, "Builder pages must keep the outer WordPress document locked.");
assert.match(shellCss, /body\.kidia-cms-builder-screen #wpwrap\{[^}]*overflow:hidden!important;/, "The Builder wrapper must stay inside the locked WordPress viewport.");
assert.match(shellCss, /body\.kidia-cms-builder-screen #wpcontent\{[^}]*overflow:hidden!important;/, "Builder content viewports must remain fixed while the internal card rail owns scrolling.");
assert.match(shellCss, /body\.kidia-cms-builder-screen #wpbody\{[^}]*overflow-y:scroll!important;[^}]*scrollbar-gutter:stable;/, "Builder documents must retain the shared plugin scrollbar rail without moving the workspace.");
assert.match(shellCss, /body\.kidia-cms-builder-screen #wpbody-content\{[^}]*height:calc\(100% - 24px\)!important;[^}]*margin-bottom:6px;[^}]*overflow:visible!important;/, "The fixed Builder frame must contain the complete phone without clipping the shared sidebar gutter.");
assert.match(shellScript, /function resetDocumentScroll\(\)[\s\S]*scrollRestoration[\s\S]*window\.scrollTo[\s\S]*syncBuilderScreen[\s\S]*resetDocumentScroll\(\)/, "Every CMS view must ignore stale WordPress document scroll restoration.");
assert.match(shellScript, /syncBuilderScreen\(payload\.builderScreen\)/, "Fragment navigation must restore or release the fixed Builder workspace for the destination.");

const wizardDom = new JSDOM(`<!doctype html><body>
  <div class="kidia-setup-progress">${Array.from({ length: 5 }, () => "<span></span>").join("")}</div>
  <form class="kidia-setup-form">
    <section class="kidia-setup-step" data-step="1"><span data-step-number></span><input required value="Store"></section>
    <section class="kidia-setup-step" data-step="2"><span data-step-number></span><input type="hidden" data-page-toggle="home" data-required-page="1"><input type="checkbox" data-page-toggle="category"><input type="checkbox" data-page-toggle="catalog" checked><input type="hidden" data-page-toggle="product" data-required-page="1"><input type="checkbox" data-page-toggle="wishlist" checked><input type="checkbox" data-page-toggle="account" checked></section>
    <section class="kidia-setup-step" data-step="3"><span data-step-number></span><label class="kidia-theme-card" data-theme-key="fashion" data-theme-name="Fashion" style="--theme-primary:#222222;--theme-soft:#eeeeee;--theme-ink:#111111;--theme-surface:#ffffff"><input type="radio" name="setup[theme]" required checked><button type="button" class="kidia-theme-preview-button">Preview</button></label></section>
    <section class="kidia-setup-step" data-step="4"><span data-step-number></span><h3 data-review-name></h3><strong data-review-theme></strong><span data-review-page="category"></span></section>
    <section class="kidia-setup-step" data-step="5"><span data-step-number></span></section>
    <input name="setup[app_name]" value="Store">
    <input type="color" name="setup[primary_color]" value="#2c2926" data-color-picker="primary"><input type="text" value="#2C2926" data-color-code="primary">
    <input type="color" name="setup[secondary_color]" value="#f2e9df" data-color-picker="secondary"><input type="text" value="#F2E9DF" data-color-code="secondary">
    <button type="button" class="kidia-setup-back"></button>
    <button type="button" class="kidia-setup-next"></button>
    <button type="submit" class="kidia-setup-apply"></button>
  </form>
  <div class="kidia-theme-modal" hidden>
    <button type="button" class="kidia-theme-modal__close" data-theme-modal-close></button>
    <h2 data-theme-modal-name></h2>
    <button type="button" data-theme-modal-page="home"></button>
    <button type="button" data-theme-modal-page="account"></button>
    <iframe data-theme-modal-frame></iframe>
    <div data-theme-modal-loading><b>Loading</b></div>
    <button type="button" class="kidia-theme-modal__select"></button>
  </div>
</body>`, { runScripts: "outside-only", url: "https://example.test/wp-admin/admin.php" });
wizardDom.window.scrollTo = () => {};
wizardDom.window.kidiaSetupThemePreview = {
  flutterUrl: "https://example.test/wp-content/plugins/kidia/admin/flutter-preview/index.html",
  layoutPreviewBase: "https://example.test/wp-json/woo-mobile/v1/page-layout/",
  homePreviewEndpoint: "https://example.test/wp-json/woomobileapp/v1/home-layout/preview",
  categoryPreviewEndpoint: "https://example.test/wp-json/woo-mobile/v1/category-page/preview",
  themes: { fashion: { home: [], pages: { home: {}, account: {} }, category: { general: {} } } },
  restNonce: "nonce",
  version: "test"
};
wizardDom.window.fetch = () => Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
wizardDom.window.eval(read("admin", "assets", "setup-wizard.js"));
const next = wizardDom.window.document.querySelector(".kidia-setup-next");
next.click();
assert.equal(wizardDom.window.document.querySelector('[data-step="2"]').classList.contains("is-active"), true, "Continue must advance the wizard.");
next.click();
assert.equal(wizardDom.window.document.querySelector('[data-step="3"]').classList.contains("is-active"), true, "One complete theme step must follow page selection.");
assert.equal(wizardDom.window.document.querySelectorAll('input[name="setup[theme]"]').length, 1, "One complete theme selection must drive every page.");
next.click();
assert.equal(wizardDom.window.document.querySelector('[data-review-theme]').textContent, "Fashion", "Review must name the selected complete theme.");
next.click();
assert.equal(next.hidden, true, "Continue must disappear on the final setup step.");
assert.equal(wizardDom.window.document.querySelector(".kidia-setup-apply").hidden, false, "Build APK must appear only on the final setup step.");
assert.equal(wizardDom.window.document.querySelector('[data-review-page="category"]').hidden, true, "Unselected optional pages must stay out of the final theme review.");
const primaryCode = wizardDom.window.document.querySelector('[data-color-code="primary"]');
primaryCode.value = "#123ABC";
primaryCode.dispatchEvent(new wizardDom.window.Event("input", { bubbles: true }));
assert.equal(wizardDom.window.document.querySelector('[data-color-picker="primary"]').value, "#123abc", "Typing a HEX value must update the submitted color picker.");
wizardDom.window.document.querySelector('input[name="setup[theme]"]').dispatchEvent(new wizardDom.window.Event("change", { bubbles: true }));
assert.equal(wizardDom.window.document.querySelector('[data-color-picker="primary"]').value, "#123abc", "Choosing a layout theme must preserve the connected site's brand color.");
wizardDom.window.document.querySelector(".kidia-theme-preview-button").click();
assert.equal(wizardDom.window.document.querySelector(".kidia-theme-modal").hidden, false, "Theme preview must open without applying the theme.");
assert.match(wizardDom.window.document.querySelector("[data-theme-modal-frame]").src, /page=home/, "Built-in theme preview must open the real Flutter Home page.");
assert.match(wizardDom.window.document.querySelector("[data-theme-modal-frame]").src, /demo=1/, "Built-in theme preview must not load merchant data.");
wizardDom.window.document.querySelector('[data-theme-modal-page="account"]').click();
assert.match(wizardDom.window.document.querySelector("[data-theme-modal-frame]").src, /page=account/, "Theme preview navigation must render every selected application page.");

const shellDom = new JSDOM(`<!doctype html><body><div class="kidia-cms-shell"></div></body>`, { runScripts: "outside-only" });
shellDom.window.scrollTo = () => {};
shellDom.window.eval(read("admin", "assets", "cms-shell.js"));
assert.equal(shellDom.window.document.querySelector(".kidia-cms-more"), null, "More menu must remain removed.");

const savedThemeDom = new JSDOM(`<!doctype html><body>
  <article data-saved-theme-card>
    <script type="application/json" data-saved-theme-snapshot>{"home":[],"pages":{"home":{"elements":[]}}}</script>
    <div class="kidia-saved-theme-phone" data-saved-theme-phone><img src="theme-banner.jpg" alt=""></div>
    <button type="button" data-saved-theme-preview data-theme-name="Fashion Theme">Preview</button>
    <button type="button" data-saved-theme-export data-theme-id="theme-123" data-theme-name="Fashion Theme">Export</button>
  </article>
  <dialog data-saved-theme-dialog>
    <button type="button" data-saved-theme-dialog-close></button>
    <h2 data-saved-theme-dialog-title></h2>
    <button type="button" data-saved-theme-page="home"></button>
    <button type="button" data-saved-theme-page="account"></button>
    <iframe data-saved-theme-dialog-frame></iframe>
    <div data-saved-theme-loading><b>Loading</b></div>
  </dialog>
  <dialog data-saved-theme-export-dialog>
    <button type="button" data-saved-theme-export-close></button>
    <form data-saved-theme-export-form>
      <input data-saved-theme-export-id>
      <p data-saved-theme-export-name></p>
      <button type="submit" name="export_mode" value="settings">Settings</button>
      <button type="submit" name="export_mode" value="settings_and_images">Images</button>
    </form>
  </dialog>
</body>`, { runScripts: "outside-only", url: "https://example.test/wp-admin/admin.php" });
savedThemeDom.window.kidiaSavedThemePreview = {
  flutterUrl: "https://example.test/wp-content/plugins/kidia/admin/flutter-preview/index.html",
  layoutPreviewBase: "https://example.test/wp-json/woo-mobile/v1/page-layout/",
  homePreviewEndpoint: "https://example.test/wp-json/woomobileapp/v1/home-layout/preview",
  categoryPreviewEndpoint: "https://example.test/wp-json/woo-mobile/v1/category-page/preview",
  restNonce: "nonce",
  version: "test"
};
savedThemeDom.window.fetch = () => Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
savedThemeDom.window.eval(savedThemesScript);
savedThemeDom.window.document.querySelector("[data-saved-theme-preview]").click();
assert.equal(savedThemeDom.window.document.querySelector("[data-saved-theme-dialog]").hasAttribute("open"), true, "Preview must open without applying the theme.");
assert.equal(savedThemeDom.window.document.querySelector("[data-saved-theme-dialog-title]").textContent, "Fashion Theme", "Preview must show the selected theme name.");
assert.match(savedThemeDom.window.document.querySelector("[data-saved-theme-dialog-frame]").src, /page=home/, "Preview must open the real Flutter Home page first.");
savedThemeDom.window.document.querySelector("[data-saved-theme-export]").click();
assert.equal(savedThemeDom.window.document.querySelector("[data-saved-theme-export-dialog]").hasAttribute("open"), true, "Export must open the two-choice dialog.");
assert.equal(savedThemeDom.window.document.querySelector("[data-saved-theme-export-id]").value, "theme-123", "Export must target the selected saved theme.");

console.log("Setup wizard and unified CMS shell tests passed.");
