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
const plugin = read("kidia-mobile-cms.php");

assert.match(plugin, /Version:\s+1\.36\.2/, "The plugin header must be version 1.36.2.");
assert.match(
  plugin,
  /KIDIA_MOBILE_LICENSE_PUBLIC_KEY[\s\S]*pno\+qR490JO\/niHqlK82hXz0SwloDlwShxnmimmLQz0=/,
  "The production Ed25519 public key must be bundled with the plugin."
);
assert.match(bootstrap, /class-kidia-mobile-license-manager\.php/, "The license manager must load during bootstrap.");
assert.match(manager, /kidia_mobile_installation_id/, "Installation identity must persist independently of plugin updates.");
assert.match(manager, /https:\/\/api\.woomobile\.app\/api\/v1\/licenses/, "The stable v1 licensing API must be used.");
for (const endpoint of ["/activate", "/verify"]) {
  assert.match(manager, new RegExp(`'${endpoint}'`), `The ${endpoint} endpoint must be integrated.`);
}
assert.match(manager, /X-WooMobile-Installation/, "Verification must bind to the stored installation.");
assert.match(manager, /Authorization.*Bearer/s, "Verification must use the activation token.");
assert.match(manager, /sodium_crypto_sign_verify_detached/, "Signed license proofs must support local Ed25519 verification.");
assert.match(manager, /valid_until/, "A server-defined offline grace window must be enforced.");
assert.match(manager, /wp_schedule_event/, "License verification must be scheduled.");
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
assert.match(dashboard, /Setup & Themes/, "Overview must link to Setup & Themes.");
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
