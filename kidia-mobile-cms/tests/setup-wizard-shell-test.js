"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const root = path.resolve(__dirname, "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");

const service = read("includes", "class-kidia-mobile-setup-wizard.php");
const admin = read("admin", "class-kidia-mobile-cms-admin.php");
const wizardTemplate = read("admin", "pages", "setup-wizard.php");
const savedThemesTemplate = read("admin", "pages", "saved-themes.php");
const shellTemplate = read("admin", "pages", "cms-shell.php");
const wizardCss = read("admin", "assets", "setup-wizard.css");
const shellCss = read("admin", "assets", "cms-shell.css");
const shellScript = read("admin", "assets", "cms-shell.js");

for (const theme of ["aurora", "bloom", "canvas", "pulse", "avenue", "metro"]) {
  assert.match(service, new RegExp(`'${theme}'\\s*=>`), `Theme ${theme} must be registered.`);
}
assert.match(service, /create_backup\(\)/, "Applying a theme must snapshot the current application.");
assert.match(service, /Kidia_Mobile_Layout_Store/, "Themes must update the Home builder.");
assert.match(service, /Kidia_Mobile_Page_Layout_Store/, "Themes must update application page builders.");
assert.match(service, /Kidia_Mobile_Category_Page_Store/, "Themes must update the Category builder.");
assert.match(service, /kidia_mobile_splash_screen/, "Themes must configure the Splash screen.");
assert.match(service, /kidia_mobile_checkout_suggestions/, "Themes must configure checkout recommendations.");
for (const page of ["home", "category", "catalog", "product", "wishlist", "account"]) {
  assert.match(service, new RegExp(`'${page}'\\s*=>`), `Quick Setup must expose an independent ${page} design step.`);
}
assert.match(service, /submitted\['page_themes'\]/, "Theme application must accept independent page selections.");
assert.match(service, /SAVED_THEMES_OPTION/, "Saved themes must use a dedicated persistent store.");
assert.match(service, /strip_catalog_images/, "Saved themes must exclude product and category catalog images.");
assert.match(service, /build_required/, "Applying or importing a theme must request a fresh application build.");

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
assert.match(wizardTemplate, /Choose %s page design/, "Every design step heading must clearly identify that it configures a page.");
assert.match(wizardTemplate, /catalog_stats/, "Wizard must report real catalog content.");
assert.match(wizardTemplate, /catalog_images/, "Wizard previews must use real catalog images when available.");
assert.doesNotMatch(wizardTemplate, /kidia-saved-themes/, "Saved Themes must no longer occupy the Setup Wizard.");
assert.match(savedThemesTemplate, /kidia-saved-themes__empty/, "Saved Themes must provide a dedicated empty state.");
assert.match(savedThemesTemplate, /Import Theme/, "The empty Saved Themes page must center an Import Theme action.");
assert.match(shellTemplate, /kidia-cms-sidebar/, "Shell must expose the primary left navigation.");
assert.match(shellTemplate, /show_page_tabs/, "Page tabs must only appear inside Design Your Pages.");
assert.match(shellTemplate, /kidia-cms-tabs/, "Design Your Pages must preserve the existing top page tabs.");
assert.doesNotMatch(shellTemplate, /kidia-cms-more/, "The obsolete More menu must not appear in the page header.");
assert.match(shellTemplate, /kidia-cms-save-theme[\s\S]*window\.prompt[\s\S]*kidia_save_theme_name[\s\S]*requestSubmit[\s\S]*Save Theme/, "Every page header must save unsaved builder fields before creating a named theme.");
assert.match(admin, /'overview'\s*=>\s*\$tab\(\s*__\(\s*'Overview'/, "The sidebar must start with Overview.");
assert.match(admin, /'setup'\s*=>\s*\$tab\(\s*__\(\s*'Setup Wizard'/, "Setup Wizard must follow Overview.");
assert.match(admin, /'splash'\s*=>\s*\$tab\(\s*__\(\s*'Splash Page'/, "Splash Page must have its own sidebar destination.");
assert.match(admin, /'pages'\s*=>\s*\$tab\(\s*__\(\s*'Design Your Pages'/, "Design Your Pages must follow Splash Page.");
assert.match(admin, /'saved_themes'\s*=>\s*\$tab\(\s*__\(\s*'Saved Themes'/, "Saved Themes must have its own sidebar destination.");
assert.match(admin, /saved_theme_redirect[\s\S]*save_current_theme[\s\S]*kidia-mobile-saved-themes/, "Named page-header saves must persist the latest builder state and open Saved Themes.");
assert.match(admin, /'account'[\s\S]*'checkout'\s*=>\s*\$tab\(\s*__\(\s*'Checkout'/, "Checkout must appear immediately after Account in the page tabs.");
assert.match(wizardCss, /kidia-theme-phone/, "Theme previews must have a detailed mobile mockup.");
assert.match(wizardCss, /\.kidia-setup-actions \.button\[hidden\]\{display:none!important\}/, "Apply Theme must remain hidden until the final setup step.");
assert.match(wizardCss, /--kidia-setup-theme-color:#2f806e/, "Setup actions must expose a theme-driven color.");
const wizardScript = read("admin", "assets", "setup-wizard.js");
assert.match(wizardScript, /getPropertyValue\('--theme-primary'\)/, "Setup actions must follow the design selected on the current page.");
assert.match(wizardScript, /document\.querySelector\('\.kidia-setup-hero'\)/, "Wizard navigation must keep the Setup & Themes hero visible.");
assert.match(wizardScript, /history\.scrollRestoration = 'manual'/, "Wizard must ignore stale browser scroll restoration.");
assert.match(wizardScript, /show\(0, false\)/, "Initial wizard rendering must not scroll past the top hero.");
assert.match(shellCss, /position:sticky/, "Unified navigation must remain available while editing.");
assert.match(shellCss, /box-shadow:inset 0 0 0 2px #2f806e/, "Header focus must use an inset Kidia-colored ring.");
assert.match(shellCss, /\.kidia-cms-setup-link\{[^}]*background:#236b59;[^}]*color:#fff\}/, "Quick Setup & Themes must use the dark Kidia button color.");
assert.match(shellCss, /\.kidia-cms-tabs>a:focus[^}]*color:#216e5e/, "Focused CMS tabs must keep readable dark-green text instead of turning white.");
assert.match(shellCss, /\.kidia-cms-setup-link:focus[^}]*box-shadow:none!important/, "Quick Setup must not draw a square focus box after it is clicked.");
assert.match(shellCss, /#wpbody-content\{[^}]*border:/, "The unified workspace must be enclosed by a full-page frame.");
assert.match(shellCss, /#wpbody-content\{height:auto!important;min-height:0!important\}/, "CMS pages must end with their real content instead of a blank viewport-height tail.");
assert.match(shellCss, /#wpbody-content\{padding-bottom:0!important\}/, "WordPress must not append footer padding below the CMS frame.");
assert.match(shellCss, /#wpfooter\{display:none\}/, "The unused WordPress footer must not extend CMS pages.");
assert.match(shellCss, /#adminmenuwrap\{[^}]*overflow-y:auto!important;[^}]*overscroll-behavior:contain;/, "The WordPress sidebar must scroll independently without extending the plugin page.");
assert.match(shellCss, /#adminmenuback,[^}]*#adminmenuwrap\{[^}]*position:fixed!important;[^}]*bottom:0!important;/, "The WordPress sidebar must be constrained to the visible viewport.");
assert.match(admin, /admin_body_class[\s\S]*kidia-cms-builder-screen/, "Builder pages must be marked for the fixed workspace before rendering.");
assert.match(shellCss, /body\.kidia-cms-builder-screen #wpbody-content\{[\s\S]*height:calc\(100% - 24px\)!important;[\s\S]*margin-bottom:6px;[\s\S]*overflow:hidden!important;/, "Builder documents must remain fixed while the frame extends low enough to contain the complete phone.");
assert.match(shellScript, /kidia-cms-builder-screen[\s\S]*scrollRestoration[\s\S]*window\.scrollTo/, "Builders must ignore stale document scroll restoration.");

const wizardDom = new JSDOM(`<!doctype html><body>
  <div class="kidia-setup-progress">${Array.from({ length: 8 }, () => "<span></span>").join("")}</div>
  <form class="kidia-setup-form">
    <section class="kidia-setup-step" data-step="1"><input required value="Store"></section>
    <section class="kidia-setup-step" data-step="2"></section>
    <section class="kidia-setup-step" data-step="3"></section>
    <section class="kidia-setup-step" data-step="4"></section>
    <section class="kidia-setup-step" data-step="5"></section>
    <section class="kidia-setup-step" data-step="6"></section>
    <section class="kidia-setup-step" data-step="7"></section>
    <section class="kidia-setup-step" data-step="8"><h3 data-review-name></h3></section>
    <input name="setup[app_name]" value="Store">
    <button type="button" class="kidia-setup-back"></button>
    <button type="button" class="kidia-setup-next"></button>
    <button type="submit" class="kidia-setup-apply"></button>
  </form>
</body>`, { runScripts: "outside-only", url: "https://example.test/wp-admin/admin.php" });
wizardDom.window.scrollTo = () => {};
wizardDom.window.eval(read("admin", "assets", "setup-wizard.js"));
const next = wizardDom.window.document.querySelector(".kidia-setup-next");
next.click();
assert.equal(wizardDom.window.document.querySelector('[data-step="2"]').classList.contains("is-active"), true, "Continue must advance the wizard.");
for (let step = 3; step <= 8; step++) next.click();
assert.equal(next.hidden, true, "Continue must disappear on the final setup step.");
assert.equal(wizardDom.window.document.querySelector(".kidia-setup-apply").hidden, false, "Apply Theme must appear only on the final setup step.");

const shellDom = new JSDOM(`<!doctype html><body><div class="kidia-cms-shell"></div></body>`, { runScripts: "outside-only" });
shellDom.window.scrollTo = () => {};
shellDom.window.eval(read("admin", "assets", "cms-shell.js"));
assert.equal(shellDom.window.document.querySelector(".kidia-cms-more"), null, "More menu must remain removed.");

console.log("Setup wizard and unified CMS shell tests passed.");
