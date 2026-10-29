# Finals Fixes and Public Release Implementation Plan

> **For agentic workers:** Use subagent-driven-development for bounded independent implementation and review; root integrates, verifies, freezes and publishes. User explicitly authorized fixes, regression, full validation, source freeze and public sync.

**Goal:** Close audit F01/F02/F03 and deliver a public-clone reproducible finals version with source identity and current evidence.
**Architecture:** Pure Cangjie link and binding logic; native HTTP/web consume resolved native results. Keep tested source identity separate from later evidence-only publication metadata to avoid self-referential commit hashes. Preserve old public archives as dated history.
**Tech Stack:** Cangjie1.1.3/1.2.0, Bash, C supervisor, existing Python testing/packaging clients and JS UI.

## Global constraints
- Preserve existing work and the user's preexisting skills/cj-docguard/README.md; do not publish that unreviewed draft (it contains a placeholder) as part of the release.
- Never change assertions to force passing, never hide original upstream failures, never overwrite old frozen archives, never publish private contact files, .env, SDKs, binaries or raw user paths.
- No force push or destructive history rewrite. Integrate public changes; push authorized public main refs and source freeze tag after verification.
- Explicitly mark offline external links UNVERIFIED. Index URLs resolve relative to actual HTML location, keep all expected API-anchor checks, and do not confuse regeneration with detection.
- Bind examples only to exactly one API identity; ambiguous short name/overload/unknown mapping is diagnosed, not auto-attached or used as eligible evidence. Old records cannot gain a new binding by display fallback.
- Root owns checkLinks/native source lists/integration tests and publication; binding worker owns projectApi/binding record/report/query portions only; parser worker owns links.cj/native_links test; documentation worker owns specified new docs only.

## Tasks
- [x] F03: add failing owned-member/overload/cross-file/unknown and precise-ID tests; central binding resolution and report/query association; run actual SDK focused regressions.
- [x] F01/F02: add failing HTML href/src/asset tests and multiline Setext/containers; parser extraction with source lines; root integrate actual-index and expected-anchor checks preserving URL safety; run bothSDK/native/HTTP tests.
- [x] Update reproduction entry and install diagnostics, reviewed fixed-library workflow, public license/provenance and initial/finals material distinctions. Validate via shell/static checks and actual independent clone, not format-only tests.
- [x] Independent review each implementation and integration; full scripts/test.py with Unicode probes, Node suite, real native HTTP end-to-end, original/fixed library and export/rebuild. All defects addressed before freeze.
- [ ] Freeze tested source commit/tag, generate public redacted evidence with file checksums and exact commands, update finals matrix/iteration notes/material index and source archive without changing historical packages.
- [ ] Publish main refs to AtomGit primary and GitHub mirror without force; anonymous clone from primary, follow README with explicitly registered SDKs, build/start/search/verify/check/query/export/rebuild, record receipts and publish metadata-only verification supplement.

## Verification/release ledger
Source freeze and all actual hashes/results are filled after observed verification. The final evidence must distinguish original/expected negative outcomes from product regressions, and installed-SDK local proof from untested fresh OS installation. No formal contest submission, email or signatures in this task.

Pre-freeze observed: both SDKs each pass 10 native programs, including 97 link and 13 actual-index assertions; independent implementation review found no blockers. Explicit Unicode extension: 6 tests pass, 48 original/fixed calls. Staged-source independent build/start: 47 APIs, 28 CURRENT (26 run/2 compile), 178 link PASS; both SDK queries/export/rebuild pass. Full integration and public-clone gates remain pending until recorded.

Full regression observed: scripts/test.py exit0; 20 native programs pass; integration121 tests/613.190s,120pass+1 explicitly gated Unicode skip. The skipped method was independently enabled within six real-project tests, all6pass/3.093s (48 native calls). No product source changed during verification. UI regression and all10 browser navigation pages pass. Fresh staged-source dualSDK query/export/rebuild passes. Live demo/library refresh and remote receipts are publication followups tied to unchanged source.
