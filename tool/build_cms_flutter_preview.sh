#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$ROOT/kidia-mobile-cms/admin/flutter-preview"

cd "$ROOT"
flutter pub get
flutter build web \
  --release \
  --pwa-strategy=none \
  --target lib/cms_preview_main.dart \
  --dart-define=CMS_PREVIEW=true \
  --dart-define=STORE_LOCALE=ar \
  --output "$OUTPUT"

# The bundle lives below a WordPress plugin directory whose site path varies.
# A relative base keeps every engine, asset and font request inside the plugin.
sed -i 's#<base href="/">#<base href="./">#' "$OUTPUT/index.html"
sed -i \
  -e 's#_flutter.loader.load({#_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"},#' \
  -e 's#_flutter.loader.load();#_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"}});#' \
  "$OUTPUT/flutter_bootstrap.js"
sed -i '/_flutter.loader.load(/i\
if (window.__kidiaPreviewVersion) { _flutter.buildConfig.builds.forEach(function (build) { if (build.mainJsPath) { build.mainJsPath += "?v=" + encodeURIComponent(window.__kidiaPreviewVersion); } }); }\
' "$OUTPUT/flutter_bootstrap.js"
node "$ROOT/tool/patch_cms_flutter_bootstrap.mjs" \
  "$OUTPUT/flutter_bootstrap.js"
cp "$ROOT/tool/cms-preview.htaccess" "$OUTPUT/.htaccess"

# Dart2JS uses CanvasKit. Keep both runtime-compatible CanvasKit variants and
# omit debug symbols plus WASM renderers that this build cannot select.
rm -f \
  "$OUTPUT/canvaskit/canvaskit.js.symbols" \
  "$OUTPUT/canvaskit/chromium/canvaskit.js.symbols"
rm -rf \
  "$OUTPUT/canvaskit/experimental_webparagraph" \
  "$OUTPUT/canvaskit/skwasm.js" \
  "$OUTPUT/canvaskit/skwasm.js.symbols" \
  "$OUTPUT/canvaskit/skwasm.wasm" \
  "$OUTPUT/canvaskit/skwasm_heavy.js" \
  "$OUTPUT/canvaskit/skwasm_heavy.js.symbols" \
  "$OUTPUT/canvaskit/skwasm_heavy.wasm" \
  "$OUTPUT/canvaskit/wimp.js" \
  "$OUTPUT/canvaskit/wimp.js.symbols" \
  "$OUTPUT/canvaskit/wimp.wasm"
