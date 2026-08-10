#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/kidia-mobile-cms"
BUILD_ROOT="${1:-$ROOT/build/wordpress-org}"
PACKAGE_SLUG="mobishop"
PACKAGE_DIR="$BUILD_ROOT/$PACKAGE_SLUG"
PACKAGE_ZIP="$BUILD_ROOT/$PACKAGE_SLUG.zip"

mkdir -p "$PACKAGE_DIR"
find "$PACKAGE_DIR" -mindepth 1 -depth -delete

# WordPress.org submission archives must stay below 10 MB and must not contain
# development files. The Flutter iframe has a maintained JavaScript fallback in
# the plugin, so the directory build omits its large compiled runtime while
# preserving the icon font used by that fallback.
rsync -a --delete \
  --exclude '/tests/' \
  --exclude '/admin/flutter-preview/' \
  --exclude '*.map' \
  --exclude '.DS_Store' \
  "$SOURCE/" "$PACKAGE_DIR/"

mkdir -p "$PACKAGE_DIR/admin/flutter-preview/assets/fonts"
cp \
  "$SOURCE/admin/flutter-preview/assets/fonts/MaterialIcons-Regular.otf" \
  "$PACKAGE_DIR/admin/flutter-preview/assets/fonts/MaterialIcons-Regular.otf"

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v identify >/dev/null 2>&1; then
  echo 'FFmpeg and ImageMagick are required to optimize the WordPress.org package.' >&2
  exit 1
fi

shopt -s globstar nullglob
image_work_dir="$(mktemp -d "$BUILD_ROOT/.image-optimization.XXXXXXXX")"
for packaged_image in "$PACKAGE_DIR"/admin/assets/theme-previews/**/*.webp; do
  if (( $(wc -c < "$packaged_image") <= 30000 )); then
    continue
  fi
  relative_image="${packaged_image#"$PACKAGE_DIR"/}"
  source_image="$SOURCE/$relative_image"
  source_geometry="$(identify -format '%wx%h' "$source_image")"
  optimized_image="$image_work_dir/optimized.webp"
  ffmpeg \
    -hide_banner \
    -loglevel error \
    -y \
    -i "$packaged_image" \
    -frames:v 1 \
    -c:v libwebp \
    -quality 50 \
    -compression_level 6 \
    "$optimized_image"
  mv -f "$optimized_image" "$packaged_image"
  packaged_geometry="$(identify -format '%wx%h' "$packaged_image")"
  if [[ "$source_geometry" != "$packaged_geometry" ]]; then
    echo "Image optimization changed dimensions for $relative_image." >&2
    exit 1
  fi
done
rmdir "$image_work_dir"
shopt -u globstar nullglob

if find "$PACKAGE_DIR" -type f \( -name '*.zip' -o -name '*.tar' -o -name '*.tar.gz' \) -print -quit | grep -q .; then
  echo 'Distribution contains a compressed archive, which WordPress.org does not allow.' >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_DIR/readme.txt" || ! -f "$PACKAGE_DIR/kidia-mobile-cms.php" ]]; then
  echo 'Distribution is missing its readme or main plugin file.' >&2
  exit 1
fi

if command -v php >/dev/null 2>&1; then
  find "$PACKAGE_DIR" -type f -name '*.php' -exec php -l {} \; >/dev/null
else
  echo 'PHP is unavailable locally; CI will run the required PHP syntax check.' >&2
fi

temporary_dir="$(mktemp -d "$BUILD_ROOT/.mobishop.XXXXXXXX")"
temporary_zip="$temporary_dir/$PACKAGE_SLUG.zip"
(
  cd "$BUILD_ROOT"
  zip -9qr "$temporary_zip" "$PACKAGE_SLUG"
)
mv -f "$temporary_zip" "$PACKAGE_ZIP"
rmdir "$temporary_dir"

maximum_size=$((10 * 1024 * 1024))
archive_size="$(wc -c < "$PACKAGE_ZIP")"
if (( archive_size >= maximum_size )); then
  echo "Distribution ZIP is ${archive_size} bytes; WordPress.org requires less than 10 MB." >&2
  exit 1
fi

echo "Built $PACKAGE_ZIP (${archive_size} bytes)."
