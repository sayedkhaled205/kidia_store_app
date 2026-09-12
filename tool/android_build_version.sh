# Source this file before a Flutter Android build. Do not execute it separately.
# With no version request, Flutter uses pubspec.yaml for local/staging builds.
MOBISHOP_BUILD_VERSION_ARGS=()
if [[ -n "${BUILD_VERSION_NAME:-}" || -n "${BUILD_VERSION_CODE:-}" ]]; then
  if [[ ! "${BUILD_VERSION_NAME:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'BUILD_VERSION_NAME must contain three numeric components.' >&2
    return 1
  fi
  if [[ ! "${BUILD_VERSION_CODE:-}" =~ ^[1-9][0-9]{0,9}$ ]] || (( BUILD_VERSION_CODE > 2100000000 )); then
    echo 'BUILD_VERSION_CODE must be an integer from 1 to 2100000000.' >&2
    return 1
  fi
  MOBISHOP_BUILD_VERSION_ARGS=("--build-name=$BUILD_VERSION_NAME" "--build-number=$BUILD_VERSION_CODE")
fi
