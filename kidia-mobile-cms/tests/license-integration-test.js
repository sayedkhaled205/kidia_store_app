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

assert.match(plugin, /Version:\s+1\.33\.0/, "The plugin header must be version 1.33.0.");
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
assert.match(admin, /enforce_license_gate/, "All configuration screens must be locked until license activation.");
assert.match(admin, /Kidia_Mobile_License_Manager\(\) \)->is_active/, "Premium setup application must be license-gated.");
assert.match(dashboard, /Activate license/, "Overview must expose license activation.");
assert.match(dashboard, /Setup & Themes/, "Overview must link to Setup & Themes.");
assert.doesNotMatch(dashboard, /kidia_mobile_deactivate_license/, "The license UI must not expose deactivation.");
assert.match(dashboard, /Start Setup Wizard/, "Successful activation must offer the setup wizard.");
assert.match(dashboard, /Continue Manually/, "Successful activation must allow manual setup.");

console.log("License integration contract tests passed.");
