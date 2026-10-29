#!/usr/bin/env bash
# Sourced by native build/start wrappers; no Python needed at runtime.
set -euo pipefail
DOCGUARD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCGUARD_RUNTIME_VERSION="${CJ_DOCGUARD_RUNTIME_VERSION:-1.1.3}"
case "$DOCGUARD_RUNTIME_VERSION" in 1.1.3|1.2.0) ;; *) echo 'Unsupported runtime version' >&2; exit 2;; esac
for DOCGUARD_VERSION in 1.1.3 1.2.0; do
  DOCGUARD_ENV_KEY="CJ_DOCGUARD_SDK_${DOCGUARD_VERSION//./_}"
  DOCGUARD_HOME_VALUE="${!DOCGUARD_ENV_KEY:-}"
  for DOCGUARD_CANDIDATE in "$DOCGUARD_HOME_VALUE" "$DOCGUARD_ROOT/../.toolchains/$DOCGUARD_VERSION/cangjie" "$DOCGUARD_ROOT/.local/sdks/$DOCGUARD_VERSION/cangjie"; do
    if [[ -n "$DOCGUARD_CANDIDATE" && -f "$DOCGUARD_CANDIDATE/bin/cjc" ]]; then
      DOCGUARD_HOME_VALUE="$(cd "$DOCGUARD_CANDIDATE" && pwd -P)"
      export "$DOCGUARD_ENV_KEY=$DOCGUARD_HOME_VALUE"
      break
    fi
  done
  if [[ "$DOCGUARD_VERSION" == "$DOCGUARD_RUNTIME_VERSION" ]]; then DOCGUARD_RUNTIME_HOME="$DOCGUARD_HOME_VALUE"; fi
done
if [[ ! -f "${DOCGUARD_RUNTIME_HOME:-}/bin/cjc" ]]; then echo "Register Cangjie SDK $DOCGUARD_RUNTIME_VERSION first" >&2; exit 2; fi
export CANGJIE_HOME="$DOCGUARD_RUNTIME_HOME"
export CJ_DOCGUARD_RUNNER="$DOCGUARD_ROOT/build/cjdg-runner"
export PATH="$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:/usr/bin:/bin:/usr/sbin:/sbin"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    export DYLD_LIBRARY_PATH="$CANGJIE_HOME/runtime/lib/darwin_aarch64_cjnative"
    export SDKROOT="${CJ_DOCGUARD_SYSTEM_SDKROOT:-${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}}";;
  Linux-aarch64|Linux-x86_64)
    export LD_LIBRARY_PATH="$CANGJIE_HOME/runtime/lib/linux_$(uname -m)_cjnative";;
  *) echo 'Unsupported native host' >&2; exit 2;;
esac
