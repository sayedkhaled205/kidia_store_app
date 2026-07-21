#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$ROOT/kidia-mobile-cms/admin/flutter-preview"

cd "$ROOT"
flutter pub get
flutter build web \
  --release \
  --target lib/cms_preview_main.dart \
  --dart-define=CMS_PREVIEW=true \
  --dart-define=STORE_LOCALE=ar \
  --output "$OUTPUT"

# The bundle lives below a WordPress plugin directory whose site path varies.
# A relative base keeps every engine, asset and font request inside the plugin.
sed -i 's#<base href="/">#<base href="./">#' "$OUTPUT/index.html"
