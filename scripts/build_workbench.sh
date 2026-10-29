#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/native_env.sh"
cd "$DOCGUARD_ROOT"
mkdir -p build
DOCGUARD_CC_ARGS=(-std=c11 -O2 -Wall -Wextra)
if [[ "$(uname -s)" == Darwin ]]; then DOCGUARD_CC_ARGS+=(-mmacosx-version-min=12.0); fi
cc "${DOCGUARD_CC_ARGS[@]}" scripts/runner.c -o build/cjdg-runner
cc "${DOCGUARD_CC_ARGS[@]}" -c scripts/workbench_signal.c -o build/workbench_signal.o
ar rcs build/libworkbench_signal.a build/workbench_signal.o
DOCGUARD_CORE_SOURCES=(src/*.cj)
"$CANGJIE_HOME/bin/cjc" "${DOCGUARD_CORE_SOURCES[@]}" -O2 -Woff unused -o build/cj-docguard
DOCGUARD_SERVICE_SOURCES=()
for DOCGUARD_SOURCE in "${DOCGUARD_CORE_SOURCES[@]}"; do
  if [[ "$DOCGUARD_SOURCE" != src/main.cj ]]; then DOCGUARD_SERVICE_SOURCES+=("$DOCGUARD_SOURCE"); fi
done
"$CANGJIE_HOME/bin/cjc" "${DOCGUARD_SERVICE_SOURCES[@]}" workbench_native/*.cj -Lbuild -lworkbench_signal -O2 -Woff unused -o build/cj-docguard-workbench
printf 'Built native CLI and Cangjie workbench with SDK %s\n' "$DOCGUARD_RUNTIME_VERSION"
