"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..", "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), "utf8");

const pubspec = read("pubspec.yaml");
const main = read("lib", "main.dart");
const config = read("lib", "core", "config", "app_config.dart");
const service = read("lib", "core", "push", "push_notification_service.dart");
const bootstrap = read("lib", "core", "push", "push_bootstrap_config.dart");
const gradle = read("android", "app", "build.gradle.kts");
const manifest = read("android", "app", "src", "main", "AndroidManifest.xml");
const codemagic = read("codemagic.yaml");

assert.match(pubspec, /firebase_core:\s*\^4\.12\.1/);
assert.match(pubspec, /firebase_messaging:\s*\^16\.4\.3/);
assert.match(config, /PUSH_CONFIG_URL/);
assert.match(main, /PushNotificationService\.instance\.initialize\(\)/);
assert.match(bootstrap, /firebaseOptions[\s\S]*registrationUrl[\s\S]*eventsUrl/);
assert.match(service, /Firebase\.initializeApp[\s\S]*FirebaseOptions/);
assert.match(service, /requestPermission[\s\S]*getToken[\s\S]*onTokenRefresh/);
assert.match(service, /postUri[\s\S]*'token'[\s\S]*'client_id'/);
assert.match(manifest, /android\.permission\.POST_NOTIFICATIONS/);
assert.match(gradle, /gradleProperty\("APPLICATION_ID"\)[\s\S]*applicationId = storeApplicationId\.get\(\)/);
assert.match(codemagic, /ANDROID_APPLICATION_ID[\s\S]*ORG_GRADLE_PROJECT_APPLICATION_ID/);

console.log("Firebase native client contract tests passed.");
