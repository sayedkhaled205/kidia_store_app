const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const workflow = fs.readFileSync(
  path.resolve(__dirname, "..", "..", "codemagic.yaml"),
  "utf8"
);
const exporter = fs.readFileSync(
  path.resolve(__dirname, "..", "includes", "class-kidia-mobile-app-exporter.php"),
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

for (const command of ["build apk", "build appbundle", "build ios"]) {
  const offset = workflow.indexOf(`flutter ${command}`);
  assert.notEqual(offset, -1, `Codemagic must include flutter ${command}.`);
  const block = workflow.slice(offset, offset + 520);
  assert.match(
    block,
    /--dart-define="STORE_URL=\$STORE_URL"/,
    `${command} must compile the customer-specific STORE_URL.`
  );
}

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

console.log("Codemagic dynamic customer build contract verified.");
