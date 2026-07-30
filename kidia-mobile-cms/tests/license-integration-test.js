"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");

const bootstrap = read("includes", "class-kidia-mobile-cms.php");
const manager = read("includes", "class-kidia-mobile-license-manager.php");
const admin = read("admin", "class-kidia-mobile-cms-admin.php");
const dashboard = read("admin", "pages", "dashboard.php");
const shell = read("admin", "pages", "cms-shell.php");
const shellCss = read("admin", "assets", "cms-shell.css");
const plugin = read("kidia-mobile-cms.php");

assert.match(plugin, /Version:\s+1\.45\.73/, "The plugin header must be version 1.45.73.");
assert.match(
  plugin,
  /KIDIA_MOBILE_CMS_VERSION',\s*'1\.45\.73'/,
  "The runtime plugin version must match the 1.45.73 plugin header."
);
assert.match(
  plugin,
  /KIDIA_MOBILE_LICENSE_PUBLIC_KEY[\s\S]*pno\+qR490JO\/niHqlK82hXz0SwloDlwShxnmimmLQz0=/,
  "The production Ed25519 public key must be bundled with the plugin."
);
assert.match(bootstrap, /class-kidia-mobile-license-manager\.php/, "The license manager must load during bootstrap.");
assert.match(manager, /kidia_mobile_installation_id/, "Installation identity must persist independently of plugin updates.");
assert.match(manager, /https:\/\/api\.woomobile\.app\/api\/v1\/licenses/, "The live cPanel WooMobile licensing API must be used.");
for (const endpoint of ["/activate", "/verify"]) {
  assert.match(manager, new RegExp(`'${endpoint}'`), `The ${endpoint} endpoint must be integrated.`);
}
assert.match(manager, /X-WooMobile-Installation/, "Verification must bind to the stored installation.");
assert.match(manager, /Authorization.*Bearer/s, "Verification must use the activation token.");
assert.match(manager, /sodium_crypto_sign_verify_detached/, "Signed license proofs must support local Ed25519 verification.");
assert.match(manager, /valid_until/, "A server-defined offline grace window must be enforced.");
assert.match(manager, /wp_schedule_event/, "License verification must be scheduled.");
assert.match(manager, /'hourly'/, "Subscription recovery and suspension must be checked hourly.");
assert.match(manager, /license_inactive/, "A definitive server suspension must invalidate the cached local state.");
assert.match(shell, /payment is overdue/, "Past-due subscriptions must show a WordPress workspace warning.");
assert.match(shell, /grace_days_remaining/, "The warning must include the remaining grace period.");
assert.match(
  shellCss,
  /\.kidia-cms-sidebar\{[\s\S]*position:absolute;[\s\S]*inset-block-start:0;[\s\S]*inset-block-end:auto;[\s\S]*inset-inline-start:-16px;[\s\S]*width:236px;[\s\S]*height:calc\(100vh - 102px\);/,
  "Every desktop CMS page must keep the same Overview sidebar geometry inside the rounded workspace card."
);
assert.match(
  shellCss,
  /html\{[\s\S]*overflow-x:clip;[\s\S]*overflow-y:scroll;[\s\S]*scrollbar-gutter:stable;/,
  "CMS pages must reserve the document scrollbar gutter and prevent page-level horizontal scrolling."
);
assert.match(
  shellCss,
  /#wpbody-content\{[\s\S]*width:calc\(100% - 36px\);[\s\S]*max-width:calc\(100% - 36px\);/,
  "The CMS frame must use the available WordPress content width instead of the viewport width."
);
assert.doesNotMatch(
  shellCss,
  /#wpbody-content\{[^}]*width:calc\(100vw/,
  "The CMS frame must not include the browser scrollbar in its width."
);
assert.doesNotMatch(
  shellCss,
  /body\[class\*="kidia-mobile"\] \.kidia-cms-sidebar\{[\s\S]*position:fixed!important;/,
  "A global fixed viewport override must not pull the sidebar outside the workspace card."
);
assert.match(admin, /admin_post_kidia_mobile_activate_license/, "The activation handler must be registered.");
assert.doesNotMatch(admin, /admin_post_kidia_mobile_deactivate_license/, "Customers must not be able to deactivate a site-bound license.");
assert.match(admin, /enforce_license_gate/, "All configuration writes must be locked until license activation.");
assert.doesNotMatch(
  admin,
  /license_error['"]?\s*=>\s*__\(\s*'Activate your website license before using Woo Mobile CMS/,
  "Inactive customers must be able to browse CMS screens."
);
assert.match(admin, /kidia-cms-license-preview/, "Inactive CMS screens must expose preview mode.");
assert.match(admin, /plugin_installed[\s\S]*=> '1'/, "Plugin-originated connections must tell the website that WordPress is already installed.");
assert.match(admin, /https:\/\/woomobile\.app\/connect/, "The plugin connection journey must start on WooMobile.");
assert.match(admin, /Kidia_Mobile_License_Manager\(\) \)->is_active/, "Premium setup application must be license-gated.");
assert.match(dashboard, /Activate license/, "Overview must expose license activation.");
assert.doesNotMatch(
  dashboard,
  /Connect your store to WooMobile|Purchase and connect website/,
  "The license card must not repeat the external purchase and connection prompt."
);
assert.match(
  dashboard,
  /if \( \$license_active \)[\s\S]*else[\s\S]*class="kidia-license-form"/,
  "The activation form must only render while the license is inactive."
);
assert.doesNotMatch(
  dashboard,
  /class="kidia-setup-overview/,
  "The removed Setup workspace strip must not render inside the license card."
);
assert.doesNotMatch(dashboard, />Setup workspace ready</, "Overview must not repeat the Setup workspace status.");
assert.doesNotMatch(dashboard, /kidia_mobile_deactivate_license/, "The license UI must not expose deactivation.");
assert.match(dashboard, /Start Setup Wizard/, "Successful activation must offer the setup wizard.");
assert.match(dashboard, /Continue Manually/, "Successful activation must allow manual setup.");
for (const journeyStep of [
  "Purchase and connect",
  "Activate your license",
  "Set up your app",
  "Build your app",
]) {
  assert.match(dashboard, new RegExp(journeyStep), `The customer journey must include: ${journeyStep}.`);
}
assert.doesNotMatch(dashboard, /Install the plugin/, "Plugin installation must not appear as a pending in-plugin step.");
assert.match(
  dashboard,
  /\$license_step_complete\s*=\s*\$connection_step_complete\s*&&\s*\$license_active/,
  "License completion must remain locked until the website connection is complete."
);
assert.match(
  dashboard,
  /\$setup_step_complete\s*=\s*\$license_step_complete\s*&&\s*\$setup_complete/,
  "Setup completion must remain locked until website connection and license activation are complete."
);
assert.match(
  dashboard,
  /Woo Mobile CMS is already installed\. Connect this website, activate its serial, then choose the wizard or manual setup\./,
  "The plugin journey must start with the installed-plugin connection path."
);

console.log("License integration contract tests passed.");
