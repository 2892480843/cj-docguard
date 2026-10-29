# Native Cangjie Workbench Migration

Goal: replace production Python HTTP service with a Cangjie binary, preserve the browser contract, complete browser workflows, and audit finals #9 requirements against traceable evidence.

Architecture: compile existing src/*.cj except main.cj together with workbench_native/*.cj into build/cj-docguard-workbench. Core CLI remains build/cj-docguard. HTTP/state/task orchestration in Cangjie; existing C supervisor retains resource control. Bash build/start wrappers provide SDK runtime without Python. Python may remain testing/build assistance, not the serving process.

## Shared transport contract
- package docguard, all native files compiled together.
- class WbRequest { let method:String; let target:String; let headers:HashMap<String,String>; let body:String; init(method:String,target:String,headers:HashMap<String,String>,body:String) }. Headers lowercase. target raw path/query; service decodes path safely.
- class WbResponse { let status:Int64; let body:Array<Byte>; let contentType:String; var download:Bool=false; init(status:Int64,body:Array<Byte>,contentType:String) }.
- class NativeWorkbench { init(root:String,state:String,timeoutMs:Int64); func handle(request:WbRequest):WbResponse; func shutdown():Unit }.
- native main parses --port (default8765),--host loopback only,--root (repo root),--state-dir,--system-sdk. Sets registered runner/system SDK if explicit, delegates to app.handle.
- Existing /api/bootstrap /projects /jobs /artifacts routes and payloads unchanged. bootstrap adds implementation:'Cangjie', capabilities.native_server:true. Keep project IDs from old registry so existing demo/real library reopen.
- Add optional source endpoints only after coordination. No new unvalidated shell commands or arbitrary execution endpoint.

## Constraints
- Bind loopback; verify exact Host, same Origin, session token for mutation; UTF-8, bounded JSON/body/header, reject duplicate request framing/unsupported transfer encoding. Connection close responses; limited concurrent clients, socket deadlines.
- All native operations globally serial. Capture bounded UI logs separately from complete JSON result. Jobs cancellation/timeout controlled by existing C runner; shutdown reaps native processes. No automatic writer.lock removal. Exact platform/SDK matching.
- Configuration save atomically validates native supported TOML. Query current via CLI. History frozen. Export ZIP must contain original exported files; never manufacture successful compiler evidence.
- Registry and source/artifact paths reject escape/symlink abuse. Existing source files never modified by demo fault action; only owned copy.
- Preserve previous untracked user skill file. Work in current branch.

## Tasks
- [x] Transport: official SDK docs + actual socket prototype, bounded HTTP, headers, main, --version/help.
- [x] Native service/state/jobs: full existing API, registry/config/report/history/compare, CLI actions, cancel/logs, native ZIP packaging.
- [x] Native Bash build/start launcher and test harness migration. Verify running process executable is Cangjie, no Python server.
- [x] Frontend: show backend identity truthfully, robust web workflow checklist and query results, source/docs/link navigation where already supported.
- [x] Real native HTTP integration dualSDK, stale/fail/restore/export/rebuild, HTTP auth/invalid bodies/busy/cancel, config/init/compare. Browser checks.
- [x] Official finals intro/publish plus #9 complete task content if accessible. Maintain must/optional distinctions and unknowns. Requirement/evidence matrix, gaps and limits, no unsupported compliance claim.

## Completion evidence
See `docs/native-workbench-verification-2026-10-29.md`. Full #9 taskbook remains unavailable; completed the source audit and explicitly documented that limit rather than claiming unknown requirements passed. Latest user-provided notice supersedes old preparation dates: Oct 31 target, finals date unconfirmed, no submission now.
