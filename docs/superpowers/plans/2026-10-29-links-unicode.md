# Links and Unicode Repair Implementation Plan

> **For agentic workers:** Use subagent-driven-development for independent real-library and UI tasks, and root implementation for the Cangjie parser; review each task and final integration. No commits or remote writes in this already dirty workspace.

**Goal:** Complete documented Markdown link handling, repair the real Unicode defect without weakening assertions, and expose real results in the browser.
**Architecture:** Cangjie links.cj pure scanner + existing engine path guards; reviewed optional upstream patch + distinct fixed project; frontend renders native link results and assertion details.
**Tech Stack:** Cangjie 1.1.3/1.2.0, existing Python test/harness clients, HTML/CSS/JS, C process supervisor.

## Global constraints
Preserve uncommitted work and user skill README. No changes to pinned upstream bytes/cache or assertion expectations. Fixed source explicitly labeled local modification, hashes and license preserved. Offline external URLs UNVERIFIED. Malformed/unsafe targets never PASS. Existing link API statuses compatible; additive line/syntax/summary fields only. All core logic remains Cangjie. Report final-platform scope accurately. User authorized direct execution.

- [x] Task 1: Add tests/native_links.cj and scripts/test.py case; reproduce references, titles, encoded paths, escaped punctuation, duplicate/Unicode/setext headings, code exclusion, unsafe/malformed links. Add src/links.cj and replace engine checkLinks parsing using existing resolved(). Run focused compile/tests both SDKs.
- [x] Task 2: Reproduce unicode-empty and emoji-empty on pinned source; reviewed rune-length patch, hash-checked optional harness application, provenance and focused regression. Build fixed workbench project while preserving baseline. Review patch and tests.
- [x] Task 3: Update web/views.js, app.js, styles.css and tests/test_workbench_ui.mjs: all native link rows, totals, status/search filters and details; expected/actual assertions. Verify escaping, empty/partial reports, filters, PASS/FAIL/UNVERIFIED and no arbitrary external navigation. Review UI task.
- [x] Task 4: Build native CLI/server, run full scripts/test.py and UI suite, restart native listener, register fixed real project, verify both SDKs, strict check, native HTTP end-to-end. Validate actual browser both projects, link table and assertion details, narrow viewport. Capture screenshots and write final evidence docs.

Progress: Native parser 67 assertions pass on both SDKs. Independent reviews found false HTML anchors and UTF-8 generated-index errors; corrected and regression-tested. First full run had a test expectation mismatch (generated index is an additional PASS), preserved and corrected. Final complete suite running against frozen final production source.

Completed: final 118 Python tests pass, 16 dual-SDK native programs pass (67 link assertions each SDK), UI renderer/event tests pass; original36/40 versus fixed40/40 with strict/query/export/rebuild verified after tests, link demo9PASS2expectedFAIL1offlineUNVERIFIED verified, original16-step demo pipeline passed and restored. See docs/links-unicode-verification-2026-10-29.md.
