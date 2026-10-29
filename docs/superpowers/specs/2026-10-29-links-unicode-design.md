# Link checking and real-library Unicode repair

User authorization: directly implement link parsing completion, root-cause repair of four real-library assertions, full tests and browser-visible checking results.

## Design

Keep the core Cangjie and offline-first. Extract Markdown link/anchor logic into src/links.cj. Parse inline and full/collapsed/shortcut references, images and angle autolinks, escaped/nested delimiters, optional link titles, percent-encoded UTF-8 local paths, query/fragment separation, ATX/setext headings, duplicate heading anchors and HTML id/name. Ignore fenced/indented/inline code and comments. Resolve paths with the existing root/symlink protections. Unsafe, malformed or unsupported schemes never pass. External links remain explicitly UNVERIFIED offline; no network fetch or false accessibility claims. Link rows retain original target, source line and syntax and report totals for PASS/FAIL/UNVERIFIED.

The real library mixes byte counts in empty-string branches with rune counts in dynamic programming. Fix those branches to rune counts, preserve expected assertions and untouched pinned upstream/cache. Maintain a checked-in reviewed patch with exact before/after hashes, reproducible harness option and provenance. Keep original baseline separate from a local fixed project so the UI shows both truthful old failures and repaired results.

The issues page gains a dedicated link-check panel including passing rows, totals, filter/search, source/target/reason, and a native check button. No browser-side reclassification. Native HTTP report includes all link results; failure details expose expected versus actual assertion values.

## Acceptance

Native link tests fail before parser change then pass on two actual SDKs. Regression tests exercise dead links and malformed escapes and avoid code-block false positives. Both SDKs reproduce old Unicode failures; repaired source passes unchanged assertions and extra empty/nonempty Unicode cases. Full scripts/test.py, UI regressions, HTTP workflow, and actual-browser baseline/fixed/link panels verified. Document evidence and limits, no unqualified complete CommonMark or remote-link validation claim.
