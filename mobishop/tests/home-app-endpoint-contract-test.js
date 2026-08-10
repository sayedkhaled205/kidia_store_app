const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..", "..");
const appConfig = fs.readFileSync(
  path.join(root, "lib", "core", "config", "app_config.dart"),
  "utf8"
);
const dataSource = fs.readFileSync(
  path.join(
    root,
    "lib",
    "features",
    "home",
    "data",
    "datasources",
    "home_remote_data_source.dart"
  ),
  "utf8"
);
const exporter = fs.readFileSync(
  path.join(root, "mobishop", "includes", "class-mobishop-app-exporter.php"),
  "utf8"
);

assert.match(
  appConfig,
  /HOME_LAYOUT_ENDPOINT[\s\S]*defaultValue:\s*'\/wp-json\/mobishop\/v1\/home-layout'/,
  "The Flutter app must request Home data from the canonical MobiShop endpoint."
);
assert.match(
  exporter,
  /'homeApi'\s*=>\s*rest_url\(\s*'mobishop\/v1\/home-layout'\s*\)/,
  "New app build manifests must publish the canonical Home Layout endpoint."
);
for (const endpoint of ["mobishop/v1", "mobishop/v1", "mobishop/v1"]) {
  assert.match(
    dataSource,
    new RegExp(endpoint.replace("/", "\\/")),
    `Home loading must retain the ${endpoint} compatibility route.`
  );
}

console.log("Home app endpoint contract passed.");
