---
name: cj-docguard
description: Query current, SDK-specific executable evidence before using unfamiliar Cangjie APIs. Use with a registered CJ-DocGuard project; do not substitute historical or compilation-only examples for behavior verification.
---

# CJ-DocGuard evidence workflow

Read the target project's `docguard.toml` and confirm the SDK and actual platform. Query its registered read-only MCP tools, or the native CLI:

```bash
cj-docguard query --config /absolute/project/docguard.toml --tool list_symbols --symbol add
cj-docguard query --config /absolute/project/docguard.toml --tool get_verified_examples --symbol add --sdk 1.1.3 --platform Darwin-arm64
cj-docguard query --config /absolute/project/docguard.toml --tool get_evidence --example arithmetic --sdk 1.1.3 --platform Darwin-arm64
```

Only use `items` returned for the exact project, SDK and platform. A usable item must include `RUN_VERIFIED`, `CURRENT`, `eligible=true`, complete stage evidence, required assertions and an attempt ID. State which attempt supports a suggestion. Empty results mean evidence is missing: inspect `rejected` rather than falling back to older success, another SDK, `COMPILE_ONLY`, `STALE`, `UNKNOWN_CURRENT` or `FROZEN` records.

After changing code or example inputs, query again. Currentness is evaluated when queried; a static HTML/JSON report alone cannot confirm the current repository. Independently compile and test generated code in the user's normal development workflow; evidence for a library example does not prove newly generated code correct.

For an exact `eligible=true` example, `cj-docguard export --config FILE --example ID --sdk VERSION --platform OS-ARCH --out DIR` materializes the frozen single-package sources and a runnable `build.sh`; set `CJ_SDK_HOME` to the recorded SDK root and inspect `manifest.json` before using it. The export is evidence for the registered assertions in the recorded environment, not a guarantee about all API behavior.

Verification executes reviewed local code and is separate from read-only lookup. Use `verify` only within the user's authorized scope, after the project owner reviews its sources, registered examples and assertions. MCP offers no execution tool. Do not change `trusted` or `closed_inputs` merely to make a result pass. The Unix supervisor handles timeouts and descendants, not an operating-system security sandbox.
