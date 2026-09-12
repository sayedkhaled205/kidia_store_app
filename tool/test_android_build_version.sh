#!/usr/bin/env bash
set -euo pipefail
cd "${BASH_SOURCE[0]%/*}/.."

( unset BUILD_VERSION_NAME BUILD_VERSION_CODE; source tool/android_build_version.sh; [[ ${#MOBISHOP_BUILD_VERSION_ARGS[@]} == 0 ]] )
( export BUILD_VERSION_NAME=1.46.67 BUILD_VERSION_CODE=1789246666; source tool/android_build_version.sh; [[ ${MOBISHOP_BUILD_VERSION_ARGS[0]} == '--build-name=1.46.67' && ${MOBISHOP_BUILD_VERSION_ARGS[1]} == '--build-number=1789246666' ]] )
( export BUILD_VERSION_NAME=1.0.0 BUILD_VERSION_CODE=2100000000; source tool/android_build_version.sh )
for invalid in 0 -1 1.5 001 2100000001 999999999999999999999 '1+1'; do
  if ( export BUILD_VERSION_NAME=1.0.0 BUILD_VERSION_CODE="$invalid"; source tool/android_build_version.sh ) 2>/dev/null; then
    echo "Invalid version code was accepted: $invalid" >&2
    exit 1
  fi
done
if ( unset BUILD_VERSION_CODE; export BUILD_VERSION_NAME=1.0.0; source tool/android_build_version.sh ) 2>/dev/null; then exit 1; fi
if ( unset BUILD_VERSION_NAME; export BUILD_VERSION_CODE=123; source tool/android_build_version.sh ) 2>/dev/null; then exit 1; fi
echo 'Android version request boundaries passed.'
