# Local Workbench Implementation Plan

Goal: deliver a local, browser-operated Cangjie documentation and executable evidence workbench.
Architecture: vanilla ES modules and CSS served by a Python standard-library loopback HTTP service; actual operations invoke the existing native CLI with dev.sdk_env. Core evidence rules remain native. Work in existing codex/cj-docguard branch; preserve untracked user files.

## Global constraints
- Chinese interface, UTF-8, offline assets, accessible keyboard navigation, responsive layout.
- No fabricated results; report is explicitly a snapshot until native refresh/query. All mutations require same-origin session token. Fixed action allowlist; no arbitrary command endpoint.
- One native operation at a time globally. Cancellation sends SIGINT and waits; never delete native writer.lock automatically.
- Default demo is an isolated copy of healthy under build/workbench/projects/demo; fault injection only in this owned copy.
- GET /api/bootstrap => {token, projects:[{id,name,config,root,sdk_versions,trusted,demo}], platform, active_job, capabilities}
- GET /api/projects/:id/report => {report: object|null, snapshot:true, config: parsed TOML, error?:string}
- GET /api/projects/:id/history => {items: report.history with freshness:FROZEN,eligible:false}
- POST /api/projects {config: absolute existing TOML path} => project record. Register only; native checks on operations.
- POST /api/projects/init {directory:absolute nonexistent target,name:string} => initialized untrusted project record, using native init.
- POST /api/projects/:id/config {content:string} => save valid TOML atomically; never flip trust automatically.
- GET /api/projects/:id/config => {content:string}
- POST /api/projects/:id/jobs {action:doctor|build|verify|check|query|export|demo_break|demo_restore, sdk?:string, tool?:string,symbol?:string,example?:string,platform?:string} => job
- GET /api/jobs => {items:jobs}; GET /api/jobs/:id => job; POST /api/jobs/:id/cancel => job
- Job = {id,project_id,action,status:queued|running|succeeded|failed|cancelled,started_at,finished_at,exit_code,stdout,stderr,result,artifact_url?,error?}. exit1 quality failure remains failure. Query result parsed native JSON. Export archive URL only after native success. demo actions modify demo copy only and invalidate cached view.
- GET /api/artifacts/:id => downloadable ZIP from dedicated artifact directory.
- POST /api/projects/:id/compare {old:report,new:report} => report differences, supplied snapshots only; no current eligibility assertions.
- Header X-DocGuard-Token from bootstrap on all POST. JSON errors {error:string}, HTTP 400 invalid,403 origin/token,404 missing,409 operation busy.

## Tasks
- [ ] 1. Backend behavior tests: report absence, auth/origin, job execution/conflict/cancel, invalid config/path, history frozen, native query/export delegation. Run unittest and observe missing-module red baseline.
- [ ] 2. Backend scripts/workbench.py + scripts/workbench_service.py: registry, global task runner, bounded logs, snapshots, safe artifact endpoints, server launcher.
- [ ] 3. web/index.html + styles.css + app.js + views.js: dashboard, symbols, examples, matrix, evidence drawer, tasks, issues, history/compare, AI queries, onboarding/config, demo guide; no dead controls.
- [ ] 4. Real compiler integration: doctor/build/verify/check/query/export/rebuild; isolated demo break/stale/failure/restore; cancellation and missing SDK; persist raw validation under build/workbench-validation.
- [ ] 5. Browser verification: localhost dashboard, search/filter, navigation, real task, error/empty states, responsive screenshot. README quickstart + docs/workbench.md + CHANGELOG + finals delta.
- [ ] 6. Review boundaries, targeted tests, entire existing Python regression if environment permits; report exact completed scope and gaps.

Run: python3 -m unittest discover -s tests -p 'test_workbench*.py' -v
Run: python3 scripts/workbench.py --port 8765
