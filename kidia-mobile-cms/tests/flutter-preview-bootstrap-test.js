"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const previewRoot = path.join(__dirname, "..", "admin", "flutter-preview");
const index = fs.readFileSync(path.join(previewRoot, "index.html"), "utf8");
const bootstrap = fs.readFileSync(
  path.join(previewRoot, "flutter_bootstrap.js"),
  "utf8",
);
const startup = fs.readFileSync(
  path.join(__dirname, "..", "..", "lib", "app", "app_startup_provider.dart"),
  "utf8",
);
const bootstrapPatcher = fs.readFileSync(
  path.join(
    __dirname,
    "..",
    "..",
    "tool",
    "patch_cms_flutter_bootstrap.mjs",
  ),
  "utf8",
);

assert.match(
  index,
  /getRegistrations\(\)[\s\S]*admin\/flutter-preview\/[\s\S]*unregister\(\)/,
  "The embedded preview must clear its stale scoped service worker.",
);
assert.match(
  index,
  /flutter-view, flt-glass-pane[\s\S]*requestAnimationFrame[\s\S]*kidia-flutter-preview-ready[\s\S]*MutationObserver/,
  "The web shell must repeat the ready handshake after Flutter has rendered.",
);
assert.match(
  index,
  /addEventListener\('message'[\s\S]*kidia-preview-layout[\s\S]*announceRendered\(\)/,
  "The rendered shell must acknowledge every parent layout retry.",
);
assert.match(
  index,
  /preview_attempt[\s\S]*preview_retry[\s\S]*Date\.now\(\)[\s\S]*location\.replace[\s\S]*setTimeout\(retryOrFail,\s*45000\)/,
  "A preview that never mounts must retry once with a fresh cache key instead of loading forever.",
);
assert.match(
  index,
  /WebAssembly\.compileStreaming[\s\S]*response\.clone\(\)[\s\S]*WebAssembly\.compile\(await response\.arrayBuffer\(\)\)/,
  "CanvasKit must fall back to byte compilation when a WordPress host serves WASM with a generic MIME type.",
);
assert.match(
  index,
  /kidia-flutter-preview-error[\s\S]*unhandledrejection[\s\S]*retryOrFail\(\)/,
  "Flutter engine failures must retry immediately instead of leaving the preview spinner running.",
);
assert.match(
  index,
  /name="viewport" content="width=device-width, initial-scale=1\.0"/,
  "The embedded preview must use the iframe's real mobile viewport width.",
);
assert.match(
  index,
  /html, body \{[\s\S]*width: 100%;[\s\S]*height: 100%;[\s\S]*margin: 0;[\s\S]*overflow: hidden;/,
  "The Flutter view must fill a stable, margin-free preview viewport.",
);
assert.doesNotMatch(
  bootstrap.slice(bootstrap.lastIndexOf("_flutter.loader.load")),
  /serviceWorkerSettings/,
  "The embedded preview must not register a reload-causing service worker.",
);
assert.match(
  bootstrap,
  /canvaskit\.js"[\s\S]*__kidiaPreviewVersion[\s\S]*canvaskit\.wasm"[\s\S]*__kidiaPreviewVersion/,
  "CanvasKit JavaScript and WASM must use the plugin version cache key.",
);
assert.match(
  bootstrap,
  /onEntrypointLoaded[\s\S]*initializeEngine[\s\S]*runApp[\s\S]*kidia-flutter-preview-error/,
  "The generated bootstrap must surface Flutter engine startup errors to the retry shell.",
);
assert.match(
  bootstrapPatcher,
  /canvaskit\.js[\s\S]*canvaskit\.wasm[\s\S]*onEntrypointLoaded[\s\S]*kidia-flutter-preview-error/,
  "The repeatable preview build must preserve cache busting and startup error handling.",
);
assert.match(
  startup,
  /if \(AppConfig\.isCmsPreview\) \{\s*return;/,
  "CMS preview startup must not wait for a store API request.",
);

console.log("Flutter preview bootstrap: ok");
