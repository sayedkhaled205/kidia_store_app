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
const shellTemplate = read("admin", "pages", "cms-shell.php");
const wizardCss = read("admin", "assets", "setup-wizard.css");
const shellCss = read("admin", "assets", "cms-shell.css");

for (const theme of ["aurora", "bloom", "canvas", "pulse", "avenue", "metro"]) {
  assert.match(service, new RegExp(`'${theme}'\\s*=>`), `Theme ${theme} must be registered.`);
}
assert.match(service, /create_backup\(\)/, "Applying a theme must snapshot the current application.");
assert.match(service, /Kidia_Mobile_Layout_Store/, "Themes must update the Home builder.");
assert.match(service, /Kidia_Mobile_Page_Layout_Store/, "Themes must update application page builders.");
assert.match(service, /Kidia_Mobile_Category_Page_Store/, "Themes must update the Category builder.");
assert.match(service, /kidia_mobile_splash_screen/, "Themes must configure the Splash screen.");
assert.match(service, /kidia_mobile_checkout_suggestions/, "Themes must configure checkout recommendations.");

assert.match(admin, /admin_post_kidia_mobile_apply_setup_wizard/, "Wizard apply action must be registered.");
assert.match(admin, /render_cms_shell/, "Unified shell must render on CMS screens.");
assert.match(admin, /remove_submenu_page\(\s*'kidia-mobile-cms'/, "Legacy sidebar submenu pages must be hidden.");
assert.match(admin, /Kidia_Mobile_Setup_Wizard\(\) \)->is_complete/, "First visit must resolve setup state.");
assert.match(wizardTemplate, /kidia-theme-gallery/, "Wizard must render a theme gallery.");
assert.match(wizardTemplate, /catalog_stats/, "Wizard must report real catalog content.");
assert.match(wizardTemplate, /catalog_images/, "Wizard previews must use real catalog images when available.");
assert.match(shellTemplate, /kidia-cms-tabs/, "Shell must expose top navigation tabs.");
assert.match(shellTemplate, /<\/nav>\s*<div class="kidia-cms-more">/, "More menu must sit outside the scrollable tab strip so its dropdown remains visible.");
assert.match(wizardCss, /kidia-theme-phone/, "Theme previews must have a detailed mobile mockup.");
assert.match(shellCss, /position:sticky/, "Unified navigation must remain available while editing.");
assert.match(shellCss, /#wpbody-content\{[^}]*border:/, "The unified workspace must be enclosed by a full-page frame.");

const wizardDom = new JSDOM(`<!doctype html><body>
  <div class="kidia-setup-progress"><span></span><span></span><span></span><span></span></div>
  <form class="kidia-setup-form">
    <section class="kidia-setup-step" data-step="1"><input required value="Store"></section>
    <section class="kidia-setup-step" data-step="2"></section>
    <section class="kidia-setup-step" data-step="3"></section>
    <section class="kidia-setup-step" data-step="4"><h3 data-review-name></h3></section>
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

const shellDom = new JSDOM(`<!doctype html><body><div class="kidia-cms-more"><button aria-expanded="false"></button><div></div></div></body>`, { runScripts: "outside-only" });
shellDom.window.eval(read("admin", "assets", "cms-shell.js"));
shellDom.window.document.querySelector(".kidia-cms-more button").click();
assert.equal(shellDom.window.document.querySelector(".kidia-cms-more").classList.contains("is-open"), true, "More menu must open inside the CMS shell.");

console.log("Setup wizard and unified CMS shell tests passed.");
