#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/native_env.sh"
if [[ ! -x "$DOCGUARD_ROOT/build/cj-docguard-workbench" ]]; then echo 'Run bash scripts/build_workbench.sh first' >&2; exit 2; fi
DOCGUARD_ROOT_ARGS=(--root "$DOCGUARD_ROOT")
for DOCGUARD_ARG in "$@"; do if [[ "$DOCGUARD_ARG" == --root ]]; then DOCGUARD_ROOT_ARGS=(); fi; done
exec "$DOCGUARD_ROOT/build/cj-docguard-workbench" "${DOCGUARD_ROOT_ARGS[@]}" "$@"
