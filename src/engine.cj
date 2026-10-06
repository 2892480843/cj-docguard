package docguard

import std.fs.*
import std.collection.*
import std.env.*

func allProjectFiles(project: Project, directory: String, files: ArrayList<String>, issues: J): Unit {
    let names = ArrayList<String>()
    for (info in Directory.readFrom(directory)) { names.add(info.name) }
    for (name in sorted(names)) {
        let path = join(directory, name)
        if (project.excluded(path)) { continue }
        let info = FileInfo(path)
        if (info.isSymbolicLink()) { issues.add(diagnostic("INPUT_SYMLINK", "error", "Symbolic input is not supported", path[project.root.size + 1..])); continue }
        if (info.isDirectory()) { allProjectFiles(project, path, files, issues) }
        else if (info.isRegular()) { files.add(path[project.root.size + 1..]) }
        else { issues.add(diagnostic("INPUT_SPECIAL", "error", "Non-regular input is unsupported", name)) }
    }
}

func projectManifest(project: Project): J {
    let paths = ArrayList<String>()
    let issues = J.arr()
    allProjectFiles(project, project.root, paths, issues)
    let files = J.arr()
    for (path in paths) {
        let absolute = join(project.root, path)
        files.add(J.obj().put("path", J.str(path)).put("sha256", J.str(sha256File(absolute))).put("size", J.num(FileInfo(absolute).size)))
    }
    var closure = flag(project.config.get("project"), "closed_inputs", false) && issues.items.size == 0
    // Missing source roots and deliberately excluded code cannot be treated as a closed input set.
    for (source in array(project.config.get("project"), "sources").items) {
        let path = resolved(project.root, source.s())
        if (!exists(path) || project.excluded(path)) { issues.add(diagnostic("SOURCE_MISSING", "error", "Source root missing/excluded", source.s())); closure = false }
    }
    let fingerprint = digestText(files.dump() + "\n" + project.config.dump() + "\n" + ENGINE_RULES + "\n" + sha256File(canonicalize(getCommand()).toString()))
    return J.obj().put("schema_version", J.num(1)).put("fingerprint", J.str(fingerprint))
        .put("files", files).put("closure_complete", J.boolean(closure)).put("diagnostics", issues)
        .put("excluded", J.arr().add(J.str("output directory, .git, target, .DS_Store, .env*")))
}

func reviewedImport(declaration: String): Bool {
    for (module in ["std.collection", "std.math", "std.sort", "std.convert", "std.core"]) {
        if (declaration.startsWith("import" + module + ".") || declaration == "import" + module) { return true }
    }
    return false
}

func projectApi(project: Project, manifest: J): J {
    let api = J.obj().put("symbols", J.arr()).put("diagnostics", J.arr()).put("files", J.arr()).put("imports", J.arr())
    var sourceCount = 0
    for (file in manifest.get("files").items) {
        let path = file.get("path").s()
        if (!path.endsWith(".cj")) { continue }
        var selected = false
        for (source in array(project.config.get("project"), "sources").items) {
            let root = source.s()
            if (root == "." || path == root || path.startsWith(root + "/")) { selected = true }
        }
        if (!selected) { continue }
        sourceCount++
        let code = readText(join(project.root, path))
        let result = extractSource(code, path)
        api.get("files").add(J.obj().put("source", J.str(path)).put("status", result.get("status")).put("package", result.get("package")).put("code", J.str(code)))
        for (symbol in result.get("symbols").items) {
            let id = "s-" + digestText(path + "\n" + text(symbol, "owner", "") + "\n" + symbol.get("declaration").s())[..20]
            symbol.put("id", J.str(id))
            let examples = J.arr()
            for (example in array(project.config, "examples").items) {
                let ref = text(example, "symbol", "")
                if (ref == symbol.get("name").s() || ref == text(symbol, "package", "") + "." + symbol.get("name").s() || ref == id) { examples.add(example) }
            }
            symbol.put("examples", examples)
            api.get("symbols").add(symbol)
        }
        for (d in result.get("diagnostics").items) { api.get("diagnostics").add(d) }
        for (im in result.get("imports").items) {
            api.get("imports").add(J.obj().put("source", J.str(path)).put("declaration", im))
            let normalized = im.s().replace(" ", "").replace("\n", "")
            if (!reviewedImport(normalized)) {
                manifest.put("closure_complete", J.boolean(false))
                api.get("diagnostics").add(diagnostic("INPUT_CLOSURE_UNKNOWN", "warning", "Import requires explicit dependency/external-input review: " + im.s(), path))
            }
        }
        if (result.get("status").s() != "OK") { manifest.put("closure_complete", J.boolean(false)) }
    }
    if (sourceCount == 0) { api.get("diagnostics").add(diagnostic("NO_SOURCES", "error", "No Cangjie sources in configured roots", "")); manifest.put("closure_complete", J.boolean(false)) }
    // Review imports and unsupported syntax in registered executable inputs too.
    for (example in array(project.config, "examples").items) {
        let path = resolved(project.root, example.get("file").s())
        if (!exists(path)) { continue }
        var source = readText(path)
        if (text(example, "kind", "program") == "snippet") {
            let wrapper = resolved(project.root, example.get("wrapper").s())
            if (!exists(wrapper)) { manifest.put("closure_complete", J.boolean(false)); continue }
            source = readText(wrapper).replace("{{code}}", source)
        }
        let result = extractSource(source, example.get("file").s())
        if (result.get("status").s() != "OK") { manifest.put("closure_complete", J.boolean(false)) }
        for (im in result.get("imports").items) {
            let normalized = im.s().replace(" ", "").replace("\n", "")
            if (!reviewedImport(normalized)) {
                manifest.put("closure_complete", J.boolean(false))
                api.get("diagnostics").add(diagnostic("INPUT_CLOSURE_UNKNOWN", "warning", "Example import uses external inputs: " + im.s(), example.get("file").s()))
            }
        }
    }
    api.put("source_count", J.num(sourceCount))
    return api
}

func freezeProject(project: Project, manifest: J): String {
    let base = join(project.output, "snapshots/" + manifest.get("fingerprint").s())
    let destination = join(base, "project")
    if (!exists(join(base, "manifest.json"))) {
        mkdir(destination)
        for (file in manifest.get("files").items) {
            let relative = file.get("path").s()
            let source = resolved(project.root, relative)
            if (sha256File(source) != file.get("sha256").s()) { throw Exception("Input changed while freezing snapshot: " + relative) }
            let target = join(destination, relative)
            mkdir(Path(target).parent.toString())
            copy(source, to: target, overwrite: true)
        }
        writeText(join(base, "manifest.json"), manifest.dump())
    }
    if (parseJson(readText(join(base, "manifest.json"))).dump() != manifest.dump()) { throw Exception("Snapshot manifest integrity mismatch") }
    // Verify archived content on reuse. An edited snapshot is never trusted from its directory name.
    for (file in manifest.get("files").items) {
        let path = join(destination, file.get("path").s())
        if (!exists(path) || sha256File(path) != file.get("sha256").s()) { throw Exception("Snapshot integrity mismatch") }
    }
    return destination
}

func readAttempts(project: Project): J {
    let records = J.arr()
    let directory = join(project.output, "attempts")
    if (!exists(directory)) { return records }
    let names = ArrayList<String>()
    for (file in Directory.readFrom(directory)) { if (file.name.endsWith(".json")) { names.add(file.name) } }
    let sequences = HashSet<Int64>()
    for (name in sorted(names)) {
        let record = parseJson(readText(join(directory, name)))
        let seq = record.get("sequence").i()
        if (sequences.contains(seq)) { throw Exception("Duplicate attempt sequence; evidence history invalid") }
        sequences.add(seq)
        records.add(record)
    }
    return records
}

func inspectEnvironments(project: Project): J {
    let envs = J.arr()
    let directory = join(project.output, "inspection")
    mkdir(directory)
    for (sdk in array(project.config, "sdks").items) {
        envs.add(inspectSdk(sdk, project.runner, directory))
    }
    return envs
}

func executionEnvironment(environment: J): HashMap<String, String> {
    let result = HashMap<String, String>()
    for ((key, value) in environment.get("environment").fields) { result[key] = value.s() }
    return result
}

func recordPath(project: Project, sequence: Int64): String { join(project.output, "attempts/" + sequence.toString() + ".json") }

func evidenceComplete(project: Project, record: J): Bool {
    try {
        let snapshot = join(project.output, "snapshots/" + record.get("project_fingerprint").s())
        let savedManifest = resolved(project.output, "snapshots/" + record.get("project_fingerprint").s() + "/manifest.json")
        if (!exists(savedManifest) || sha256File(savedManifest) != record.get("snapshot_manifest_sha256").s()) { return false }
        let frozenManifest = parseJson(readText(savedManifest))
        if (frozenManifest.get("fingerprint").s() != record.get("project_fingerprint").s()) { return false }
        for (file in frozenManifest.get("files").items) {
            let saved = resolved(join(snapshot, "project"), file.get("path").s())
            if (!exists(saved) || sha256File(saved) != file.get("sha256").s()) { return false }
        }
        let stages = if (text(record, "status", "") == "COMPILE_ONLY" && text(record, "reason", "").startsWith("Compilation only")) { ["compile"] } else { ["compile", "run"] }
        for (stage in stages) {
            let x = record.get(stage)
            if (x.kind != "object") { return false }
            for (stream in ["stdout", "stderr", "result"]) {
                let saved = resolved(project.output, x.get(stream + "_file").s())
                if (!exists(saved) || sha256File(saved) != x.get(stream + "_sha256").s()) { return false }
            }
            let control = parseJson(readText(resolved(project.output, x.get("result_file").s())))
            for (key in ["exit_code", "timed_out", "truncated", "interrupted", "io_error", "elapsed_ms", "pid"]) {
                if (v(x, key).kind == "null" || x.get(key).dump() != control.get(key).dump()) { return false }
            }
            if (control.get("timed_out").b() || control.get("truncated").b() || control.get("interrupted").b() || control.get("io_error").b()) { return false }
            if (stage == "compile" && control.get("exit_code").i() != 0) { return false }
            if (v(x, "argv").kind != "array" || x.get("argv").items.size == 0) { return false }
            for (a in x.get("argv").items) { if (a.s().isEmpty()) { return false } }
            let hashes = v(x, "environment_hashes")
            if (hashes.kind != "object") { return false }
            for (key in ["PATH", "CANGJIE_HOME", "LANG", "LC_ALL"]) { if (v(hashes, key).kind != "string" || hashes.get(key).s().size != 64) { return false } }
            if (text(record, "platform", "").startsWith("Darwin") && (v(hashes, "DYLD_LIBRARY_PATH").kind != "string" || v(hashes, "SDKROOT").kind != "string")) { return false }
            if (text(record, "platform", "").startsWith("Linux") && v(hashes, "LD_LIBRARY_PATH").kind != "string") { return false }
            if (text(x, "started_at", "").isEmpty() || text(x, "finished_at", "").isEmpty()) { return false }
        }
        for (assertion in array(record, "assertions").items) {
            if (!flag(assertion, "required", false)) { continue }
            let kind = assertion.get("kind").s()
            let actual = if (kind == "exit_code") { record.get("run").get("exit_code") }
                else if (kind == "stdout" || kind == "stderr") { J.str(readText(resolved(project.output, record.get("run").get(kind + "_file").s()))) }
                else { J.nil() }
            if (actual.kind == "null" || actual.dump() != assertion.get("actual").dump() || actual.dump() != assertion.get("expected").dump() || !assertion.get("passed").b()) { return false }
        }
        return true
    } catch (_: Exception) { return false }
}

func publicValue(project: Project, value: J): J {
    if (value.kind == "string") {
        var out = value.s().replace(project.root, "$PROJECT")
        for (sdk in array(project.config, "sdks").items) {
            let version = sdk.get("version").s()
            let home = text(sdk, "home", envValue("CJ_DOCGUARD_SDK_" + version.replace(".", "_")))
            if (!home.isEmpty()) { out = out.replace(home, "$SDK_" + version) }
        }
        return J.str(out)
    }
    if (value.kind == "array") { let out = J.arr(); for (item in value.items) { out.add(publicValue(project, item)) }; return out }
    if (value.kind == "object") { let out = J.obj(); for ((key, item) in value.fields) { out.put(key, publicValue(project, item)) }; return out }
    return value
}

func sanitizeStage(project: Project, stage: J): J {
    let result = parseJson(stage.dump())
    for (key in ["log_dir", "stdout_path", "stderr_path", "result_path"]) { result.fields.remove(key) }
    for (name in ["stdout", "stderr"]) { result.put(name, J.str(text(stage, name, "").replace(project.root, "$PROJECT"))) }
    let args = J.arr()
    for (a in array(stage, "argv").items) {
        var value = a.s().replace(project.root, "$PROJECT")
        for (sdk in array(project.config, "sdks").items) {
            let version = sdk.get("version").s()
            let home = text(sdk, "home", envValue("CJ_DOCGUARD_SDK_" + version.replace(".", "_")))
            if (!home.isEmpty()) { value = value.replace(home, "$SDK_" + version) }
        }
        args.add(J.str(value))
    }
    result.put("argv", args)
    return result
}

func bindStage(project: Project, stage: J): J {
    for (stream in ["stdout", "stderr", "result"]) {
        let path = stage.get(stream + "_path").s()
        stage.put(stream + "_file", J.str(path[project.output.size + 1..]))
        stage.put(stream + "_sha256", J.str(sha256File(path)))
    }
    return sanitizeStage(project, stage)
}

func verifyProject(project: Project, manifest: J, api: J, environments: J, selectedSdk: String): J {
    if (!flag(project.config.get("project"), "trusted", false)) { throw Exception("project.trusted must explicitly approve local code execution") }
    let snapshot = freezeProject(project, manifest)
    let attempts = readAttempts(project)
    var sequence: Int64 = 0
    for (r in attempts.items) { if (r.get("sequence").i() > sequence) { sequence = r.get("sequence").i() } }
    for (example in array(project.config, "examples").items) {
        for (environment in environments.items) {
            let version = environment.get("declared_version").s()
            if (!selectedSdk.isEmpty() && selectedSdk != version) { continue }
            let targets = array(example, "sdks")
            if (targets.items.size > 0 && !arrayContains(targets, version)) { continue }
            sequence++
            let id = example.get("id").s()
            let base = join(project.output, "evidence/" + sequence.toString())
            mkdir(base)
            let record = J.obj().put("schema_version", J.num(1)).put("engine_version", J.str(ENGINE_VERSION))
                .put("attempt_id", J.str("a-" + sequence.toString())).put("sequence", J.num(sequence)).put("example_id", J.str(id))
                .put("symbol", J.str(text(example, "symbol", ""))).put("sdk_version", J.str(version))
                .put("platform", environment.get("platform")).put("project_fingerprint", manifest.get("fingerprint"))
                .put("snapshot_manifest_sha256", J.str(sha256File(join(project.output, "snapshots/" + manifest.get("fingerprint").s() + "/manifest.json"))))
                .put("environment_fingerprint", environment.get("fingerprint")).put("execution_state", J.str("RUNNING"))
                .put("status", J.str("NOT_RUN")).put("reason", J.str("attempt registered before execution"))
                .put("started_at", J.str(nowText())).put("assertions", J.arr()).put("required", J.boolean(flag(example, "required", true)))
            // Register before starting any child. A crash/interruption blocks older success.
            writeText(recordPath(project, sequence), record.dump())
            try {
                if (!text(example, "skip_reason", "").isEmpty()) { record.put("status", J.str("SKIPPED")).put("reason", example.get("skip_reason")) }
                else if (!environment.get("available").b()) { record.put("status", J.str("ENV_UNAVAILABLE")).put("reason", environment.get("reason")) }
                else {
                    let file = text(example, "file", "")
                    let source = resolved(snapshot, file)
                    if (!exists(source)) { throw Exception("Example file is absent from frozen input") }
                    var actualSource = source
                    if (text(example, "kind", "program") == "snippet") {
                        let templatePath = resolved(snapshot, example.get("wrapper").s())
                        let template = readText(templatePath)
                        if (!template.contains("{{code}}")) { throw Exception("wrapper must contain {{code}}") }
                        actualSource = join(base, "snippet.cj")
                        writeText(actualSource, template.replace("{{code}}", readText(source)))
                        record.put("wrapper", J.obj().put("path", example.get("wrapper")).put("sha256", J.str(sha256File(templatePath)))
                            .put("template", J.str(template)).put("original_code", J.str(readText(source))))
                    }
                    record.put("code", J.str(readText(actualSource))).put("source", J.str(file)).put("cwd", J.str("$FROZEN_PROJECT"))
                    let parsed = extractSource(readText(actualSource), file)
                    let pack = text(parsed, "package", "")
                    let arguments = ArrayList<String>()
                    arguments.add(environment.get("compiler").s())
                    for (f in api.get("files").items) {
                        if (text(f, "package", "") == pack && f.get("source").s() != file) { arguments.add(join(snapshot, f.get("source").s())) }
                    }
                    arguments.add(actualSource)
                    arguments.add("-o"); arguments.add(join(base, "program"))
                    let compileDir = join(base, "compile")
                    mkdir(compileDir)
                    let compiled = runCommand(project.runner, arguments.toArray(), snapshot, compileDir, executionEnvironment(environment), 60000)
                    record.put("compile", bindStage(project, compiled))
                    if (compiled.get("exit_code").i() != 0 || flag(compiled, "timed_out", false) || flag(compiled, "truncated", false) || flag(compiled, "interrupted", false)) {
                        record.put("status", J.str("COMPILE_FAILED")).put("reason", J.str("compiler failed, timed out, interrupted or exceeded log limit"))
                    } else if (text(example, "mode", "run") == "compile") {
                        record.put("status", J.str("COMPILE_ONLY")).put("reason", J.str("Compilation only; no behavior verification"))
                    } else {
                        let runDir = join(base, "run")
                        mkdir(runDir)
                        let result = runCommand(project.runner, [join(base, "program")], snapshot, runDir, executionEnvironment(environment), number(example, "timeout_ms", 10000))
                        record.put("run", bindStage(project, result))
                        let assertions = record.get("assertions")
                        if (v(example, "expected_exit").kind != "null") {
                            assertions.add(J.obj().put("kind", J.str("exit_code")).put("required", J.boolean(true))
                                .put("expected", example.get("expected_exit")).put("actual", result.get("exit_code"))
                                .put("passed", J.boolean(result.get("exit_code").i() == example.get("expected_exit").i())))
                        }
                        for (stream in ["stdout", "stderr"]) {
                            if (v(example, stream).kind != "null") {
                                assertions.add(J.obj().put("kind", J.str(stream)).put("required", J.boolean(true))
                                    .put("expected", example.get(stream)).put("actual", result.get(stream))
                                    .put("passed", J.boolean(result.get(stream).s() == example.get(stream).s())))
                            }
                        }
                        var passed = assertions.items.size > 0
                        for (a in assertions.items) { if (!a.get("passed").b()) { passed = false } }
                        if (flag(result, "timed_out", false) || flag(result, "truncated", false) || flag(result, "interrupted", false) || (result.get("exit_code").i() != number(example, "expected_exit", 0))) {
                            record.put("status", J.str("RUN_FAILED")).put("reason", J.str("program failed, timed out, interrupted or exceeded log limit"))
                        } else if (assertions.items.size == 0) {
                            record.put("status", J.str("COMPILE_ONLY")).put("reason", J.str("Executed without registered assertions; behavior remains unverified"))
                        } else if (!passed) { record.put("status", J.str("ASSERTION_FAILED")).put("reason", J.str("Required behavior assertion failed")) }
                        else { record.put("status", J.str("RUN_VERIFIED")).put("reason", J.str("Registered assertions passed in this recorded environment")) }
                    }
                }
            } catch (error: Exception) { record.put("status", J.str("UNSUPPORTED")).put("reason", J.str(error.message.replace(project.root, "$PROJECT"))) }
            try { freezeProject(project, manifest) }
            catch (error: Exception) { record.put("status", J.str("UNSUPPORTED")).put("reason", J.str(error.message)) }
            record.put("execution_state", J.str("COMPLETED")).put("finished_at", J.str(nowText()))
            writeText(recordPath(project, sequence), record.dump())
            attempts.add(record)
        }
    }
    return attempts
}

func findByteString(source: String, pattern: String, start: Int64): Int64 {
    let bytes = source.toArray(); let needle = pattern.toArray()
    var p = start
    while (p + needle.size <= bytes.size) {
        var equal = true
        for (i in 0..needle.size) { if (bytes[p + i] != needle[i]) { equal = false; break } }
        if (equal) { return p }; p++
    }
    return -1
}

func headingSlug(s: String): String {
    var out = ""
    for (r in s.trimAscii().toRuneArray()) {
        if (r == r' ' || r == r'\t') { out += "-" }
        else if ((r >= r'a' && r <= r'z') || (r >= r'0' && r <= r'9') || r == r'-' || r == r'_' || UInt32(r) > 127) { out += r.toString() }
        else if (r >= r'A' && r <= r'Z') { out += Rune(UInt32(r) + 32).toString() }
    }
    return out
}

func linkCheck(project: Project, from: String, target: String, required: Bool): J {
    let result = J.obj().put("from", J.str(from)).put("target", J.str(target)).put("required", J.boolean(required))
    if (target.startsWith("https://") || target.startsWith("http://") || target.startsWith("mailto:")) {
        return result.put("status", J.str("UNVERIFIED")).put("reason", J.str("External link not checked in offline mode"))
    }
    try {
        let parts = target.split("#")
        let file = if (parts[0].isEmpty()) { from } else { join(Path(from).parent.toString(), parts[0]) }
        let path = resolved(project.root, file)
        if (!exists(path)) { return result.put("status", J.str("FAIL")).put("reason", J.str("Target file does not exist")) }
        if (parts.size > 1 && !parts[1].isEmpty()) {
            let content = readText(path)
            var anchor = content.contains("id=\"" + parts[1] + "\"") || content.contains("id='" + parts[1] + "'")
            if (file.endsWith(".md")) {
                for (line in content.split("\n")) {
                    if (line.startsWith("#")) {
                        var first: Int64 = 0
                        while (first < line.size && line.toArray()[first] == 35) { first++ }
                        if (headingSlug(line[first..]) == parts[1]) { anchor = true }
                    }
                }
            }
            if (!anchor) { return result.put("status", J.str("FAIL")).put("reason", J.str("Target anchor does not exist")) }
        }
        return result.put("status", J.str("PASS")).put("reason", J.str("Local target exists"))
    } catch (error: Exception) { return result.put("status", J.str("FAIL")).put("reason", J.str(error.message.replace(project.root, "$PROJECT"))) }
}

func checkLinks(project: Project, api: J, includeIndex: Bool): J {
    let links = J.arr()
    for (document in array(project.config.get("project"), "documents").items) {
        let from = document.s()
        let path = resolved(project.root, from)
        if (!exists(path)) { links.add(J.obj().put("from", J.str(from)).put("target", J.str(from)).put("required", J.boolean(true)).put("status", J.str("FAIL")).put("reason", J.str("Configured document is missing"))); continue }
        let content = readText(path)
        var p: Int64 = 0
        while (true) {
            let begin = findByteString(content, "](", p)
            if (begin < 0) { break }
            let end = findByteString(content, ")", begin + 2)
            if (end < 0) { break }
            let target = content[begin + 2..end].trimAscii()
            let required = !target.startsWith("https://") && !target.startsWith("http://") && !target.startsWith("mailto:")
            links.add(linkCheck(project, from, target, required)); p = end + 1
        }
    }
    for (link in array(project.config, "links").items) { links.add(linkCheck(project, link.get("from").s(), link.get("target").s(), true)) }
    if (includeIndex) {
        let file = join(project.output, "site/index.html")
        for (symbol in api.get("symbols").items) {
            let target = file[project.root.size + 1..] + "#" + symbol.get("id").s()
            links.add(linkCheck(project, ".index", target, true))
        }
    }
    return links
}

func reportFor(project: Project, manifest: J, api: J, environments: J, attempts: J, includeIndex: Bool): J {
    let results = J.arr()
    let summary = J.obj().put("TOTAL", J.num(0)).put("VERIFIED_CURRENT", J.num(0))
    for (example in array(project.config, "examples").items) {
        for (environment in environments.items) {
            let sdk = environment.get("declared_version").s()
            let targets = array(example, "sdks")
            if (targets.items.size > 0 && !arrayContains(targets, sdk)) { continue }
            let latest = latestAttempt(attempts, example.get("id").s(), sdk)
            let r = if (latest.kind == "null") {
                J.obj().put("example_id", example.get("id")).put("symbol", J.str(text(example, "symbol", "")))
                    .put("sdk_version", J.str(sdk)).put("platform", environment.get("platform"))
                    .put("status", J.str("NOT_RUN")).put("reason", J.str("No attempt for this target"))
            } else { parseJson(latest.dump()) }
            let fresh = freshness(latest, manifest.get("fingerprint").s(), environment.get("fingerprint").s(), manifest.get("closure_complete").b())
            r.put("freshness", J.str(fresh)).put("required", J.boolean(flag(example, "required", true)))
            let good = latest.kind != "null" && eligible(latest, manifest.get("fingerprint").s(), environment.get("fingerprint").s(), sdk, environment.get("platform").s(), manifest.get("closure_complete").b()) && evidenceComplete(project, latest)
            r.put("eligible", J.boolean(good))
            r.put("compile_eligible", J.boolean(latest.kind != "null" && text(example, "mode", "run") == "compile" && text(r, "execution_state", "") == "COMPLETED" && text(r, "status", "") == "COMPILE_ONLY" && fresh == "CURRENT" && evidenceComplete(project, latest)))
            if (latest.kind != "null" && (text(r, "status", "") == "RUN_VERIFIED" || text(r, "status", "") == "COMPILE_ONLY") && !evidenceComplete(project, latest)) { r.put("freshness", J.str("UNKNOWN_CURRENT")).put("reason", J.str("Evidence logs missing or altered")) }
            results.add(publicValue(project, r))
            summary.put("TOTAL", J.num(number(summary, "TOTAL", 0) + 1))
            let status = r.get("status").s()
            summary.put(status, J.num(number(summary, status, 0) + 1))
            summary.put(r.get("freshness").s(), J.num(number(summary, r.get("freshness").s(), 0) + 1))
            if (good) { summary.put("VERIFIED_CURRENT", J.num(number(summary, "VERIFIED_CURRENT", 0) + 1)) }
        }
    }
    let publicEnvs = J.arr()
    for (e in environments.items) {
        publicEnvs.add(J.obj().put("declared_version", e.get("declared_version")).put("version", e.get("version"))
            .put("available", e.get("available")).put("platform", e.get("platform")).put("fingerprint", e.get("fingerprint"))
            .put("reason", e.get("reason")))
    }
    let diagnostics = J.arr()
    for (d in manifest.get("diagnostics").items) { diagnostics.add(d) }
    for (d in api.get("diagnostics").items) { diagnostics.add(d) }
    return J.obj().put("schema_version", J.num(1)).put("engine_version", J.str(ENGINE_VERSION)).put("generated_at", J.str(nowText()))
        .put("project", J.obj().put("name", J.str(project.name()))).put("manifest", manifest).put("api", api)
        .put("environments", publicEnvs).put("results", results).put("links", checkLinks(project, api, includeIndex))
        .put("diagnostics", diagnostics).put("summary", summary).put("history", publicValue(project, attempts))
}

func strictExit(report: J): Int64 {
    var bad = false
    var environmentError = false
    if (report.get("results").items.size == 0) { return 1 }
    for (e in report.get("environments").items) { if (!e.get("available").b()) { environmentError = true } }
    for (result in report.get("results").items) {
        if (!flag(result, "required", true)) { continue }
        let status = result.get("status").s()
        let compileOk = flag(result, "compile_eligible", false)
        if (!flag(result, "eligible", false) && !compileOk) { bad = true }
    }
    for (link in report.get("links").items) { if (flag(link, "required", true) && link.get("status").s() != "PASS") { bad = true } }
    for (d in report.get("diagnostics").items) { if (text(d, "severity", "") == "error") { bad = true } }
    return if (environmentError) { 2 } else if (bad) { 1 } else { 0 }
}
