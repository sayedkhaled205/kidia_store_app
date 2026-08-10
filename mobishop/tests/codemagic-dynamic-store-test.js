const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const workflow = fs.readFileSync(
  path.resolve(__dirname, "..", "..", "codemagic.yaml"),
  "utf8"
);
const exporter = fs.readFileSync(
  path.resolve(__dirname, "..", "includes", "class-mobishop-app-exporter.php"),
  "utf8"
);

assert.match(
  workflow,
  /if \[ -z "\$\{STORE_URL:-\}" \][\s\S]*STORE_URL is required/,
  "Codemagic must fail before compiling when the customer store URL is missing."
);
assert.match(
  workflow,
  /https:\/\/\*\)[\s\S]*STORE_URL must be a valid HTTPS store origin/,
  "Codemagic must reject non-HTTPS customer store origins."
);
assert.match(
  workflow,
  /ANDROID_APPLICATION_ID[\s\S]*ORG_GRADLE_PROJECT_APPLICATION_ID/,
  "Codemagic must compile the isolated Firebase Android application ID."
);

for (const command of ["build apk", "build appbundle"]) {
  const offset = workflow.indexOf(`flutter ${command}`);
  assert.notEqual(offset, -1, `Codemagic must include flutter ${command}.`);
  const block = workflow.slice(offset, offset + 520);
  assert.match(
    block,
    /--dart-define="STORE_URL=\$STORE_URL"/,
    `${command} must compile the customer-specific STORE_URL.`
  );
}
assert.doesNotMatch(
  workflow,
  /flutter build ios/,
  "Codemagic must not attempt an unsigned iOS customer build before Apple signing is configured."
);
assert.match(
  workflow,
  /Analyze Flutter project[\s\S]*flutter analyze lib test/,
  "Codemagic must analyze first-party Flutter sources without generated Apple SourcePackages."
);

assert.match(
  exporter,
  /'STORE_URL'\s*=>\s*home_url\(\s*'\/'\s*\)/,
  "The WordPress build manifest must source STORE_URL from the current customer site."
);
assert.match(
  exporter,
  /'dartDefines'\s*=>\s*array\([\s\S]*'STORE_NAME'[\s\S]*'STORE_LOCALE'[\s\S]*'PUSH_CONFIG_URL'/,
  "The WordPress build manifest must send the customer application values."
);
assert.match(
  exporter,
  /handle_build_start\(\)[\s\S]*'status'\s*=>\s*'building'[\s\S]*dispatch_build\(\s*\$request_token\s*\)[\s\S]*wp_send_json_success/,
  "Interactive builds must wait for provider dispatch and a real build ID before returning success."
);
assert.doesNotMatch(
  exporter,
  /refresh_build\([\s\S]*Action Scheduler and WP-Cron can be delayed[\s\S]*dispatch_build/,
  "Status polling must never start a provider build automatically."
);
for (const field of [
  "store_url",
  "app_name",
  "package_name",
  "version_name",
  "version_code",
  "settings_snapshot",
]) {
  assert.match(
    exporter,
    new RegExp(`'${field}'\\s*=>`),
    `The Laravel build request must include the required ${field} field.`
  );
}
assert.match(
  exporter,
  /'schema_version'\s*=>\s*\(string\)[\s\S]*'pages'\s*=>[\s\S]*'settings_snapshot'\s*=>\s*\$snapshot/,
  "The settings snapshot must expose the Laravel schema_version and pages contract."
);

console.log("Codemagic dynamic customer build contract verified.");
