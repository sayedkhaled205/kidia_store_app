"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");

const manager = read("includes", "class-mobishop-license-manager.php");
const pushService = read("includes", "class-mobishop-push-service.php");
const exporter = read("includes", "class-mobishop-app-exporter.php");
const admin = read("admin", "class-mobishop-admin.php");
const page = read("admin", "pages", "push-notifications.php");

assert.match(manager, /https:\/\/api\.woomobile\.app\/api\/v1\/firebase/);
assert.match(manager, /firebase_service_request[\s\S]*Authorization[\s\S]*X-MobiShop-Installation/);
assert.match(manager, /firebase_config_file[\s\S]*'android', 'ios'[\s\S]*'\/project\/'[\s\S]*'-config'[\s\S]*Authorization/);
assert.match(pushService, /firebase_service_request\(\s*'project'/);
assert.match(pushService, /'android_package'\s*=>\s*'app\.mobishop\.'/);
assert.match(pushService, /'ios_bundle_id'\s*=>\s*'app\.mobishop\.'/);
assert.match(pushService, /'ios_bundle_id'\s*=>[\s\S]*str_replace\( '_', '', \$package_key \)/);
assert.match(pushService, /firebase_client_options[\s\S]*firebaseOptions[\s\S]*apiKey[\s\S]*messagingSenderId[\s\S]*projectId/);
assert.match(pushService, /firebase_service_request\([\s\S]*'messages'[\s\S]*'target_type'\s*=>\s*'token'/);
assert.doesNotMatch(pushService, /push_service_request\(\s*'notifications'/);
assert.match(exporter, /provision_project\(\)[\s\S]*build_request_payload\( \$manifest, \$provision_push \)/);
assert.match(admin, /admin_post_mobishop_provision_push[\s\S]*function provision_push/);
assert.match(admin, /admin_post_mobishop_test_push_connection[\s\S]*function test_push_connection/);
assert.match(page, /Prepare Firebase/);
assert.match(page, /Test connection/);
assert.match(page, /Android[\s\S]*iOS[\s\S]*Messaging/);
assert.doesNotMatch(page, /Firebase private key|Service-account private key|OneSignal App ID/);

console.log("Firebase provisioning plugin contract tests passed.");
