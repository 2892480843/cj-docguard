package docguard
import std.fs.*
import std.collection.*
private let EXPORT_BOUNDARY = "证据冻结于导出时刻；输入或环境变化后当前性必须重新查询。运行通过仅证明登记断言在记录环境下通过，不证明 API 全部行为正确。"
private func exportReject(example: String, status: String, fresh: String, reason: String): Int64 {
    println(J.obj().put("error", J.str("example is not eligible for export"))
        .put("example_id", J.str(example)).put("status", J.str(status))
        .put("freshness", J.str(fresh)).put("reason", J.str(reason))
        .put("exit_code", J.num(1)).dump())
    return 1
}
private func exportPath(project: Project, raw: String): String {
    let path = Path(raw)
    if (!path.isAbsolute()) {
        for (part in raw.split("/")) { if (part == "..") { throw Exception("--out parent traversal is unsupported") } }
    }
    var target = if (path.isAbsolute()) { path.normalize().toString() } else { join(canonicalize(".").toString(), raw) }
    var ancestor = target
    while (true) {
        if (exists(ancestor) && FileInfo(ancestor).isSymbolicLink() && ancestor != "/var" && ancestor != "/tmp") {
            throw Exception("--out symbolic links unsupported")
        }
        if (ancestor == "/") { break }
        let parent = Path(ancestor).parent.toString()
        if (parent == ancestor) { break }
        ancestor = parent
    }
    var existing = target
    while (!exists(existing)) { existing = Path(existing).parent.toString() }
    let canonical = canonicalize(existing).toString()
    target = canonical + target[existing.size..]
    if (target == "/" || target == project.root || inside(target, project.output) || inside(project.output, target)) {
        throw Exception("--out overlaps project output or root")
    }
    for (source in array(project.config.get("project"), "sources").items) {
        let root = resolved(project.root, source.s())
        if (inside(target, root) || inside(root, target)) { throw Exception("--out overlaps sources") }
    }
    if (exists(target)) {
        if (!FileInfo(target).isDirectory()) { throw Exception("--out is not a directory") }
        for (_ in Directory.readFrom(target)) { throw Exception("--out is not empty") }
    }
    return target
}
private func exportSourcePath(path: String): String {
    return "src/" + path
}
private func sourceInConfig(project: Project, relative: String): Bool {
    let absolute = join(project.root, relative)
    for (root in array(project.config.get("project"), "sources").items) {
        if (inside(absolute, resolved(project.root, root.s()))) { return true }
    }
    return false
}

private func shellQuote(value: String): String { "'" + value.replace("'", "'\"'\"'") + "'" }

private func exportMkdir(path: String, owned: ArrayList<String>): Unit {
    let missing = ArrayList<String>()
    var current = path
    while (!exists(current)) { missing.add(current); current = Path(current).parent.toString() }
    var i = missing.size
    while (i > 0) { i--; Directory.create(missing[i]); owned.add(missing[i]) }
}

private func exportBytes(path: String, body: Array<Byte>, files: ArrayList<String>, dirs: ArrayList<String>): Unit {
    exportMkdir(Path(path).parent.toString(), dirs)
    let file = File.create(path)
    files.add(path)
    try { file.write(body) } finally { file.close() }
}

private func exportScript(project: Project, record: J, sourcePaths: J, sdk: String, environment: J): String {
    let sequence = record.get("sequence").i().toString()
    let prefix = "$PROJECT/" + project.output[project.root.size + 1..] + "/"
    let frozen = prefix + "snapshots/" + record.get("project_fingerprint").s() + "/project/"
    let evidence = prefix + "evidence/" + sequence + "/"
    let compile = array(record.get("compile"), "argv").items
    let run = array(record.get("run"), "argv").items
    let recordedCompiler = publicValue(project, environment.get("compiler")).s()
    if (compile.size != sourcePaths.items.size + 4 || run.size != 1 ||
        compile[0].s() != recordedCompiler ||
        compile[compile.size - 2].s() != "-o" || compile[compile.size - 1].s() != evidence + "program" ||
        run[0].s() != evidence + "program") { throw Exception("recorded command does not match frozen inputs") }
    var command = "\"" + "$" + "{CJ_SDK_HOME}/bin/cjc\""
    var i: Int64 = 0
    for (source in sourcePaths.items) {
        if (compile[i + 1].s() != frozen + source.s()) { throw Exception("recorded source command differs from snapshot") }
        command += " " + shellQuote("./" + exportSourcePath(source.s()))
        i++
    }
    let mainArg = compile[i + 1].s()
    let expectedMain = if (v(record, "wrapper").kind == "object") { evidence + "snippet.cj" }
        else { frozen + join("", record.get("source").s()) }
    if (mainArg != expectedMain) {
        throw Exception("recorded example command differs from snapshot")
    }
    command += " './main_wrapped.cj' '-o' './program'"
    let dollar = "$"
    return "#!/usr/bin/env bash\n# Generated " + nowText() + " from attempt " + sequence + "\n" +
        "set -euo pipefail\ncd \"" + dollar + "(dirname \"" + dollar + "0\")\"\n" +
        ": \"" + dollar + "{CJ_SDK_HOME:?Set CJ_SDK_HOME to the recorded SDK root}\"\n" +
        "export CANGJIE_HOME=\"" + dollar + "CJ_SDK_HOME\"\n" +
        "export PATH=\"" + dollar + "CJ_SDK_HOME/bin:" + dollar + "CJ_SDK_HOME/tools/bin:" + dollar + "PATH\"\n" +
        "[[ \"" + dollar + "(uname -s)-" + dollar + "(uname -m)\" == " + shellQuote(record.get("platform").s()) + " ]] || { echo 'Platform differs from recorded evidence' >&2; exit 2; }\n" +
        "[[ \"" + dollar + "(\"" + dollar + "CJ_SDK_HOME/bin/cjc\" --version)\" == *" + shellQuote("Cangjie Compiler: " + sdk + " (") + "* ]] || { echo 'SDK differs from recorded evidence' >&2; exit 2; }\n" +
        "if [[ \"" + dollar + "(uname -s)\" == Darwin ]]; then\n" +
        "  export DYLD_LIBRARY_PATH=\"" + dollar + "CJ_SDK_HOME/runtime/lib/darwin_aarch64_cjnative\"\n" +
        "  export SDKROOT=\"" + dollar + "{CJ_DOCGUARD_SYSTEM_SDKROOT:-" + dollar + "{SDKROOT:-" + dollar + "(xcrun --sdk macosx --show-sdk-path)}}\"\n" +
        "  [[ \"" + dollar + "SDKROOT\" == /* && -f \"" + dollar + "SDKROOT/usr/lib/libSystem.tbd\" ]] || { echo 'Invalid system SDK root' >&2; exit 2; }\n" +
        "else\n  export LD_LIBRARY_PATH=\"" + dollar + "CJ_SDK_HOME/runtime/lib/linux_" + dollar + "(uname -m)_cjnative\"\nfi\n" +
        command + "\n./program\n"
}

func exportExample(project: Project, manifest: J, environments: J, attempts: J,
                   options: HashMap<String, String>): Int64 {
    let id = options.get("--example") ?? ""
    let sdk = options.get("--sdk") ?? ""
    let platform = options.get("--platform") ?? ""
    let target = exportPath(project, options.get("--out") ?? "")
    var example = J.nil()
    for (item in array(project.config, "examples").items) { if (item.get("id").s() == id) { example = item } }
    let record = latestAttempt(attempts, id, sdk)
    if (example.kind == "null" || record.kind == "null") {
        return exportReject(id, "NOT_RUN", "UNKNOWN_CURRENT", "No attempt for this target")
    }
    var environment = J.nil()
    for (item in environments.items) { if (item.get("declared_version").s() == sdk) { environment = item } }
    if (environment.kind == "null") {
        return exportReject(id, record.get("status").s(), "UNKNOWN_CURRENT", "No current platform record")
    }
    if (!environment.get("available").b()) { throw Exception("SDK environment unavailable: " + environment.get("reason").s()) }
    if (environment.get("platform").s() != platform) {
        return exportReject(id, record.get("status").s(), "UNKNOWN_CURRENT", "No current platform record")
    }
    let api = projectApi(project, manifest)
    let binding = resolveBinding(api.get("symbols"), text(example, "symbol", ""))
    if (!bindingRecordCurrent(binding, record)) {
        return exportReject(id, record.get("status").s(), "UNKNOWN_CURRENT", "Example symbol binding is unknown, ambiguous, missing or changed")
    }
    let fp = manifest.get("fingerprint").s()
    let envFp = environment.get("fingerprint").s()
    var fresh = freshness(record, fp, envFp, manifest.get("closure_complete").b())
    var reason = record.get("reason").s()
    let complete = evidenceComplete(project, record)
    if ((record.get("status").s() == "RUN_VERIFIED" || record.get("status").s() == "COMPILE_ONLY") && !complete) {
        fresh = "UNKNOWN_CURRENT"; reason = "Evidence logs missing or altered"
    }
    if (fresh != "CURRENT" || !eligible(record, fp, envFp, sdk, platform, manifest.get("closure_complete").b()) || !complete) {
        return exportReject(id, record.get("status").s(), fresh, reason)
    }
    let snapshot = join(project.output, "snapshots/" + fp + "/project")
    let sourceFile = record.get("source").s()
    if (sourceFile != example.get("file").s()) { throw Exception("recorded example source differs from config") }
    let frozenCode = readText(resolved(snapshot, sourceFile))
    var mainCode = frozenCode
    var wrapper = ""
    if (text(example, "kind", "program") == "snippet") {
        wrapper = readText(resolved(snapshot, example.get("wrapper").s()))
        if (record.get("wrapper").get("template").s() != wrapper ||
            record.get("wrapper").get("original_code").s() != frozenCode ||
            record.get("wrapper").get("sha256").s() != digestText(wrapper)) {
            throw Exception("recorded wrapper differs from frozen source")
        }
        mainCode = wrapper.replace("{{code}}", frozenCode)
    }
    if (mainCode != record.get("code").s()) { throw Exception("recorded compilation unit differs from frozen source") }
    let sourcePaths = J.arr()
    let compileArgs = array(record.get("compile"), "argv").items
    let frozenPrefix = "$PROJECT/" + project.output[project.root.size + 1..] + "/snapshots/" + fp + "/project/"
    for (index in 1..(compileArgs.size - 3)) {
        let arg = compileArgs[index].s()
        if (!arg.startsWith(frozenPrefix)) { throw Exception("recorded library path is not frozen") }
        let relative = arg[frozenPrefix.size..]
        var listed = false
        for (file in manifest.get("files").items) { if (file.get("path").s() == relative) { listed = true } }
        if (!listed || !sourceInConfig(project, relative) || !relative.endsWith(".cj") || relative == sourceFile || arrayContains(sourcePaths, relative)) {
            throw Exception("recorded library path is not a unique configured source")
        }
        sourcePaths.add(J.str(relative))
    }
    let script = exportScript(project, record, sourcePaths, sdk, environment)
    let evidence = J.obj().put("schema_version", J.num(1)).put("tool", J.str("cj-docguard"))
        .put("tool_version", J.str(ENGINE_VERSION)).put("project", J.str(project.name()))
        .put("example_id", J.str(id)).put("symbol", J.str(text(example, "symbol", "")))
        .put("symbol_id", record.get("symbol_id")).put("binding_status", record.get("binding_status"))
        .put("sdk_version", J.str(sdk)).put("platform", J.str(platform))
        .put("project_fingerprint", J.str(fp)).put("environment_fingerprint", J.str(envFp))
        .put("attempt_sequence", record.get("sequence"))
        .put("snapshot_manifest_sha256", record.get("snapshot_manifest_sha256"))
        .put("status", J.str("RUN_VERIFIED")).put("freshness_at_export", J.str("CURRENT"))
        .put("assertions", publicValue(project, record.get("assertions"))).put("evidence_boundary", J.str(EXPORT_BOUNDARY))
    let readme = "# " + id + " · CJ-DocGuard export\n\n" +
        "This runnable bundle was built from frozen source and attempt " + record.get("sequence").i().toString() + ".\n\n" +
        "Run: `CJ_SDK_HOME=/absolute/path/to/cangjie bash build.sh`\n\n" +
        "See `manifest.json` for the recorded SDK, platform, fingerprints and assertions.\n\n" + EXPORT_BOUNDARY + "\n"
    let ownedFiles = ArrayList<String>()
    let ownedDirs = ArrayList<String>()
    try {
        if (exists(target)) {
            for (_ in Directory.readFrom(target)) { throw Exception("--out became nonempty") }
        } else { exportMkdir(target, ownedDirs) }
        for (file in manifest.get("files").items) {
            let relative = file.get("path").s()
            if (sourceInConfig(project, relative)) {
                exportBytes(resolved(target, exportSourcePath(relative)), File.readFrom(resolved(snapshot, relative)), ownedFiles, ownedDirs)
            }
        }
        let exampleDest = resolved(target, "examples/" + sourceFile)
        exportBytes(exampleDest, File.readFrom(resolved(snapshot, sourceFile)), ownedFiles, ownedDirs)
        if (!wrapper.isEmpty()) { exportBytes(join(target, "wrapper.cj"), wrapper.toArray(), ownedFiles, ownedDirs) }
        exportBytes(join(target, "main_wrapped.cj"), mainCode.toArray(), ownedFiles, ownedDirs)
        exportBytes(join(target, "build.sh"), script.toArray(), ownedFiles, ownedDirs)
        exportBytes(join(target, "manifest.json"), evidence.dump().toArray(), ownedFiles, ownedDirs)
        exportBytes(join(target, "README.md"), readme.toArray(), ownedFiles, ownedDirs)
    } catch (error: Exception) {
        for (path in ownedFiles) { removeIfExists(path) }
        var i = ownedDirs.size
        while (i > 0) { i--; try { removeIfExists(ownedDirs[i]) } catch (_: Exception) {} }
        throw error
    }
    println(J.obj().put("output", J.str(target)).put("example_id", J.str(id))
        .put("attempt_sequence", record.get("sequence")).put("exit_code", J.num(0)).dump())
    return 0
}

func exportExample(project: Project, options: HashMap<String, String>): Int64 {
    exportPath(project, options.get("--out") ?? "")
    let lock = join(project.output, "writer.lock")
    if (exists(lock)) { throw Exception("writer.lock exists: evidence is reserved") }
    let locked = exists(project.output)
    if (locked) { Directory.create(lock) }
    try {
        let sdk = options.get("--sdk") ?? ""
        var sdkConfig = J.nil()
        for (item in array(project.config, "sdks").items) { if (item.get("version").s() == sdk) { sdkConfig = item } }
        if (sdkConfig.kind == "null") { throw Exception("selected SDK is not declared") }
        let manifest = projectManifest(project)
        projectApi(project, manifest)
        let attempts = readAttempts(project)
        let environments = J.arr()
        if (latestAttempt(attempts, options.get("--example") ?? "", sdk).kind != "null") {
            // SDK probes write only into a disposable directory outside the project.
            let scratch = Directory.createTemp("/tmp").toString()
            try { environments.add(inspectSdk(sdkConfig, project.runner, scratch)) }
            finally { removeIfExists(scratch, recursive: true) }
        }
        return exportExample(project, manifest, environments, attempts, options)
    } finally { if (locked) { removeIfExists(lock, recursive: true) } }
}
