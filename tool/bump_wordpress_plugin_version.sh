#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Usage: tool/bump_wordpress_plugin_version.sh X.Y.Z' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$1"
PLUGIN_FILE="$ROOT/kidia-mobile-cms/kidia-mobile-cms.php"
README_FILE="$ROOT/kidia-mobile-cms/readme.txt"

perl -0pi -e "s/(Version:\s+)[0-9]+\.[0-9]+\.[0-9]+/\${1}${VERSION}/" "$PLUGIN_FILE"
perl -0pi -e "s/(KIDIA_MOBILE_CMS_VERSION',\s*\n\s*')[0-9]+\.[0-9]+\.[0-9]+/\${1}${VERSION}/" "$PLUGIN_FILE"
perl -0pi -e "s/(Stable tag:\s*)[0-9]+\.[0-9]+\.[0-9]+/\${1}${VERSION}/" "$README_FILE"

plugin_header_version="$(sed -n 's/^ \* Version:[[:space:]]*//p' "$PLUGIN_FILE")"
plugin_constant_version="$(sed -n "/KIDIA_MOBILE_CMS_VERSION/{n;s/^[[:space:]]*'\([^']*\)'.*/\1/p;}" "$PLUGIN_FILE")"
readme_version="$(sed -n 's/^Stable tag:[[:space:]]*//p' "$README_FILE")"

if [[ "$plugin_header_version" != "$VERSION" || "$plugin_constant_version" != "$VERSION" || "$readme_version" != "$VERSION" ]]; then
  echo 'Version update did not reach every required location.' >&2
  exit 1
fi

echo "Updated WordPress plugin version to $VERSION. Add a matching changelog entry before releasing."
