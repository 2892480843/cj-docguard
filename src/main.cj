package docguard

import std.collection.*
import std.fs.*

let HELP = "CJ-DocGuard 0.1.0 native Cangjie evidence tool\nCommands: init, doctor, build, verify, check, query, evidence, history, diff\n--config docguard.toml; verify --matrix or --sdk VERSION\nquery --tool list_symbols|get_verified_examples|get_evidence --sdk VERSION --platform Darwin-arm64 [--symbol NAME] [--example ID]\ndiff --old report.json --new report.json\nExit: 0 satisfied / 1 quality failure / 2 configuration or environment error\n"

func options(args: Array<String>): HashMap<String, String> {
    let out = HashMap<String, String>()
    var i: Int64 = 1
    while (i < args.size) {
        let key = args[i]
        if (out.contains(key)) { throw Exception("duplicate option " + key) }
        if (key == "--matrix" || key == "--strict") { out[key] = "true"; i++; continue }
        var known = false
        for (k in ["--config", "--sdk", "--tool", "--symbol", "--example", "--platform", "--old", "--new", "--project", "--report"]) { if (key == k) { known = true } }
        if (!known || i + 1 >= args.size) { throw Exception("unknown option or missing value: " + key) }
        out[key] = args[i + 1]; i += 2
    }
    return out
}
func opt(options: HashMap<String, String>, key: String, fallback: String): String { options.get(key) ?? fallback }

func validateOptions(command: String, parsed: HashMap<String, String>): Unit {
    let allowed: Array<String> = match (command) {
        case "init" => ["--config", "--project"]
        case "doctor" | "build" => ["--config"]
        case "verify" => ["--config", "--sdk", "--matrix"]
        case "check" => ["--config", "--strict"]
        case "query" => ["--config", "--tool", "--symbol", "--example", "--sdk", "--platform"]
        case "evidence" => ["--config", "--symbol", "--example", "--sdk", "--platform"]
        case "history" => ["--report", "--example", "--sdk"]
        case "diff" => ["--old", "--new"]
        case "--help" | "help" | "--version" => []
        case _ => throw Exception("unknown command: " + command)
    }
    // Reject ignored arguments before loading configuration or creating project files.
    for ((key, _) in parsed) {
        var accepted = false
        for (option in allowed) { if (option == key) { accepted = true } }
        if (!accepted) { throw Exception("option " + key + " is not valid for " + command) }
    }
    if (command == "init" && parsed.contains("--config") && parsed.contains("--project")) {
        throw Exception("--config and --project are mutually exclusive for init")
    }
}

func initialize(path: String): Unit {
    if (exists(path)) { throw Exception("configuration already exists; refusing overwrite") }
    let root = Path(path).parent.toString()
    let demo = join(root, "docguard-demo")
    if (exists(demo)) { throw Exception("docguard-demo already exists; refusing overwrite") }
    writeText(join(demo, "src/identity.cj"), "package docguard_demo\n/// Return the explicit input.\npublic func identity(x: Int64): Int64 { x }\n")
    writeText(join(demo, "examples/identity.cj"), "package docguard_demo\nmain(): Int64 { println(identity(3)); return 0 }\n")
    let template = "[project]\nname = \"my-cangjie-project\"\nsources = [\"docguard-demo/src\"]\ndocuments = []\noutput = \".docguard\"\ntrusted = false\nclosed_inputs = false\n\n[[sdks]]\nversion = \"1.1.3\"\n\n[[examples]]\nid = \"identity\"\nfile = \"docguard-demo/examples/identity.cj\"\nsymbol = \"identity\"\nmode = \"run\"\nkind = \"program\"\nstdout = \"3\\n\"\nexpected_exit = 0\nrequired = true\n"
    writeText(path, template)
}

func queryReport(report: J, options: HashMap<String, String>): J {
    let tool = opt(options, "--tool", "list_symbols")
    let symbol = opt(options, "--symbol", "")
    let example = opt(options, "--example", "")
    let sdk = opt(options, "--sdk", "")
    let platform = opt(options, "--platform", "")
    let items = J.arr()
    let rejected = J.arr()
    if (tool == "list_symbols") {
        for (s in report.get("api").get("symbols").items) {
            if (symbol.isEmpty() || s.get("name").s() == symbol || s.get("id").s() == symbol) { items.add(s) }
        }
    } else if (tool == "get_verified_examples" || tool == "get_evidence") {
        if (sdk.isEmpty() || platform.isEmpty()) { throw Exception("exact --sdk and --platform required for evidence queries") }
        for (r in report.get("results").items) {
            if (r.get("sdk_version").s() != sdk || r.get("platform").s() != platform) { continue }
            if (!example.isEmpty() && r.get("example_id").s() != example) { continue }
            if (!symbol.isEmpty() && text(r, "symbol", "") != symbol) { continue }
            if (flag(r, "eligible", false) && r.get("freshness").s() == "CURRENT") { items.add(r) }
            else { rejected.add(J.obj().put("example_id", r.get("example_id")).put("status", r.get("status")).put("freshness", r.get("freshness")).put("reason", r.get("reason"))) }
        }
    } else { throw Exception("unsupported read-only query tool") }
    return J.obj().put("tool", J.str(tool)).put("project_fingerprint", report.get("manifest").get("fingerprint"))
        .put("generated_at", report.get("generated_at")).put("sdk_version", J.str(sdk)).put("platform", J.str(platform))
        .put("items", items).put("rejected", rejected).put("summary", report.get("summary"))
}

func diffReports(old: J, fresh: J): J {
    let changes = J.arr()
    for (r in fresh.get("results").items) {
        var previous = J.nil()
        for (o in old.get("results").items) {
            if (o.get("example_id").s() == r.get("example_id").s() && o.get("sdk_version").s() == r.get("sdk_version").s()) { previous = o }
        }
        if (previous.kind == "null" || text(previous, "status", "") != r.get("status").s() || text(previous, "freshness", "") != r.get("freshness").s()) {
            changes.add(J.obj().put("example_id", r.get("example_id")).put("sdk_version", r.get("sdk_version"))
                .put("before", previous).put("after", r))
        }
    }
    let added = J.arr(); let removed = J.arr()
    for (s in fresh.get("api").get("symbols").items) {
        var found = false
        for (o in old.get("api").get("symbols").items) { if (o.get("id").s() == s.get("id").s()) { found = true } }
        if (!found) { added.add(s) }
    }
    for (s in old.get("api").get("symbols").items) {
        var found = false
        for (n in fresh.get("api").get("symbols").items) { if (n.get("id").s() == s.get("id").s()) { found = true } }
        if (!found) { removed.add(s) }
    }
    for (o in old.get("results").items) {
        var found = false
        for (n in fresh.get("results").items) { if (n.get("example_id").s() == o.get("example_id").s() && n.get("sdk_version").s() == o.get("sdk_version").s()) { found = true } }
        if (!found) { changes.add(J.obj().put("example_id", o.get("example_id")).put("sdk_version", o.get("sdk_version")).put("before", o).put("after", J.nil())) }
    }
    return J.obj().put("schema_version", J.num(1)).put("old_fingerprint", old.get("manifest").get("fingerprint"))
        .put("new_fingerprint", fresh.get("manifest").get("fingerprint")).put("old_summary", old.get("summary"))
        .put("new_summary", fresh.get("summary")).put("changes", changes).put("symbols_added", added).put("symbols_removed", removed)
}

func operate(command: String, options: HashMap<String, String>): Int64 {
    if (command == "init") { initialize(opt(options, "--config", join(opt(options, "--project", "."), "docguard.toml"))); println("Created configuration and explicit demo; review trusted/closed_inputs before verify."); return 0 }
    if (command == "history") {
        let archived = parseJson(readText(opt(options, "--report", "")))
        let records = J.arr()
        for (r in archived.get("history").items) {
            if (!opt(options, "--example", "").isEmpty() && r.get("example_id").s() != opt(options, "--example", "")) { continue }
            if (!opt(options, "--sdk", "").isEmpty() && r.get("sdk_version").s() != opt(options, "--sdk", "")) { continue }
            let copy = parseJson(r.dump()).put("freshness", J.str("FROZEN")).put("eligible", J.boolean(false))
            records.add(copy)
        }
        println(J.obj().put("scope", J.str("FROZEN_ARCHIVE_NOT_CURRENT")).put("items", records).dump()); return 0
    }
    if (command == "diff") { println(diffReports(parseJson(readText(opt(options, "--old", ""))), parseJson(readText(opt(options, "--new", "")))).dump()); return 0 }
    var known = false
    for (c in ["doctor", "build", "verify", "check", "query", "evidence"]) { if (command == c) { known = true } }
    if (!known) { throw Exception("unknown command: " + command) }
    let project = Project(opt(options, "--config", "docguard.toml"))
    mkdir(project.output)
    let lock = join(project.output, "writer.lock")
    if (exists(lock)) { throw Exception("writer.lock exists: an active or interrupted verification must be resolved before using evidence") }
    if (command == "verify" && !flag(project.config.get("project"), "trusted", false)) { throw Exception("review project and set trusted=true before executing examples") }
    let selected = opt(options, "--sdk", "")
    if (options.contains("--matrix") && !selected.isEmpty()) { throw Exception("--matrix and --sdk are mutually exclusive") }
    if (!selected.isEmpty()) {
        var declared = false
        for (s in array(project.config, "sdks").items) { if (s.get("version").s() == selected) { declared = true } }
        if (!declared) { throw Exception("selected SDK is not declared") }
    }
    // Single-writer reservation; no stale-lock auto-removal or old-success fallback.
    Directory.create(lock)
    var phase = "input manifest"
    try {
        var manifest = projectManifest(project)
        phase = "API extraction"
        var api = projectApi(project, manifest)
        phase = "SDK inspection"
        var environments = inspectEnvironments(project)
        if (command == "doctor") {
            let doctor = J.obj().put("project", J.str(project.name())).put("environments", environments)
                .put("closure_complete", manifest.get("closure_complete")).put("diagnostics", api.get("diagnostics"))
            let managers = J.arr()
            var good = true
            for (e in environments.items) {
                let entry = J.obj().put("sdk", e.get("declared_version")).put("available", J.boolean(false))
                if (!e.get("available").b()) { good = false; entry.put("reason", e.get("reason")) }
                else {
                    let manager = join(e.get("home").s(), "tools/bin/cjpm")
                    entry.put("path", J.str(manager))
                    try {
                        let managerEnvironment = executionEnvironment(e)
                        let managerHome = join(project.output, "inspection/cjpm-home/" + e.get("declared_version").s())
                        mkdir(managerHome)
                        managerEnvironment["HOME"] = managerHome
                        let result = runCommand(project.runner, [manager, "--version"], project.root, join(project.output, "inspection"), managerEnvironment, 10000)
                        let ok = result.get("exit_code").i() == 0 && !result.get("timed_out").b() && !result.get("truncated").b()
                        entry.put("available", J.boolean(ok)).put("stdout", result.get("stdout")).put("stderr", result.get("stderr")).put("exit_code", result.get("exit_code"))
                        if (!ok) { good = false }
                    } catch (error: Exception) { good = false; entry.put("reason", J.str(error.message)) }
                }
                managers.add(entry)
            }
            doctor.put("package_managers", managers)
            println(doctor.dump())
            return if (good) { 0 } else { 2 }
        }
        var attempts = readAttempts(project)
        if (command == "verify") {
            phase = "example verification"
            attempts = verifyProject(project, manifest, api, environments, selected)
            // Re-read actual inputs and SDK after execution to detect changes during verification.
            phase = "post-verification manifest"
            manifest = projectManifest(project)
            phase = "post-verification API"
            api = projectApi(project, manifest)
            phase = "post-verification SDK"
            environments = inspectEnvironments(project)
        }
        if (command == "evidence") { options["--tool"] = "get_evidence" }
        phase = "report and query"
        if (command == "query" || command == "evidence") { println(queryReport(reportFor(project, manifest, api, environments, attempts, false), options).dump()); return 0 }
        if (command == "build" || command == "verify") {
            writeReports(project.output, reportFor(project, manifest, api, environments, attempts, false))
        }
        let report = reportFor(project, manifest, api, environments, attempts, true)
        writeReports(project.output, report)
        println(J.obj().put("summary", report.get("summary")).put("report", J.str(join(project.output, "report.json"))).dump())
        return if (command == "build") { 0 } else { strictExit(report) }
    } catch (error: Exception) { var trace = error.toString()
        for (frame in error.getStackTrace()) { trace += "\n" + frame.toString() }
        throw Exception(phase + ": " + trace) }
    finally { removeIfExists(lock, recursive: true) }
}

main(args: Array<String>): Int64 {
    if (args.isEmpty()) { print(HELP); return 0 }
    try {
        let parsed = options(args)
        validateOptions(args[0], parsed)
        if (args[0] == "--help" || args[0] == "help") { print(HELP); return 0 }
        if (args[0] == "--version") { println(ENGINE_VERSION); return 0 }
        return operate(args[0], parsed)
    }
    catch (error: Exception) { println(J.obj().put("error", J.str(error.message)).put("exit_code", J.num(2)).dump()); return 2 }
}
