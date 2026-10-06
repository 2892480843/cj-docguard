package docguard

import std.collection.*
import std.fs.*
import std.process.*

// The C supervisor owns process groups and resource limits. No shell interpolation.
func runCommand(runner: String, argv: Array<String>, cwd: String, logDir: String,
    environment: HashMap<String, String>, timeoutMs: Int64): J {
    if (argv.isEmpty()) { throw Exception("command argv cannot be empty") }
    if (timeoutMs <= 0 || timeoutMs > 600000) { throw Exception("timeout must be 1..600000 ms") }
    if (!exists(runner)) { throw Exception("resource supervisor unavailable: " + runner) }
    if (!exists(cwd) || !FileInfo(cwd).isDirectory()) { throw Exception("command working directory unavailable") }
    mkdir(logDir)
    let logs = Directory.createTemp(logDir).toString()
    let stdoutPath = join(logs, "stdout.log")
    let stderrPath = join(logs, "stderr.log")
    let resultPath = join(logs, "result.json")
    let args = ArrayList<String>([timeoutMs.toString(), "1048576", canonicalize(cwd).toString(),
        stdoutPath, stderrPath, resultPath, "--"])
    for (argument in argv) { args.add(argument) }
    let started = nowText()
    let process = launch(canonicalize(runner).toString(), args.toArray(),
        workingDirectory: Path(cwd), environment: environment,
        stdIn: ProcessRedirect.Discard, stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let (supervisorExit, supervisorOut, supervisorErr) = process.waitOutput()
    let finished = nowText()
    if (supervisorExit != 0) {
        throw Exception("resource supervisor failed (${supervisorExit}): " + String.fromUtf8(supervisorErr) + String.fromUtf8(supervisorOut))
    }
    if (!exists(resultPath) || !exists(stdoutPath) || !exists(stderrPath)) {
        throw Exception("resource supervisor did not produce complete evidence")
    }
    let result = parseJson(readText(resultPath))
    // Strict field reads reject malformed supervisor output instead of inventing success.
    result.get("exit_code").i(); result.get("timed_out").b(); result.get("truncated").b()
    result.get("interrupted").b(); result.get("elapsed_ms").i(); result.get("pid").i()
    if (result.get("io_error").b()) { throw Exception("resource supervisor evidence I/O failure") }
    let arguments = J.arr()
    for (argument in argv) { arguments.add(J.str(argument)) }
    let envHashes = J.obj()
    for ((key, value) in environment) { envHashes.put(key, J.str(digestText(value))) }
    return result.put("stdout", J.str(readText(stdoutPath))).put("stderr", J.str(readText(stderrPath)))
        .put("argv", arguments).put("started_at", J.str(started)).put("finished_at", J.str(finished))
        .put("log_dir", J.str(logs)).put("stdout_path", J.str(stdoutPath))
        .put("stderr_path", J.str(stderrPath)).put("result_path", J.str(resultPath))
        .put("environment_hashes", envHashes)
}

private func basicEnvironment(): HashMap<String, String> {
    let environment = HashMap<String, String>()
    environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    environment["LANG"] = "C"
    environment["LC_ALL"] = "C"
    return environment
}

private func commandText(runner: String, argv: Array<String>, workDir: String,
    environment: HashMap<String, String>): String {
    let result = runCommand(runner, argv, workDir, workDir, environment, 10000)
    if (result.get("exit_code").i() != 0 || result.get("timed_out").b() ||
        result.get("truncated").b() || result.get("interrupted").b()) {
        throw Exception("identity probe failed: " + argv[0] + " " + result.get("stderr").s())
    }
    return result.get("stdout").s().trimAscii()
}

// Each inspection rereads every relevant file. Cache only repeated canonical targets
// within this single traversal, never based on timestamps or previous inspections.
private class SdkManifest {
    let home: String
    let entries = J.obj()
    let fileHashes = HashMap<String, String>()
    let seenDirectories = HashSet<String>()
    init(home: String) { this.home = home }

    func addFile(path: String, key: String): Unit {
        let real = canonicalize(path).toString()
        var hash = ""
        if (let Some(found) <- fileHashes.get(real)) { hash = found } else {
            hash = sha256File(real)
            fileHashes[real] = hash
        }
        entries.put(key, J.obj().put("target", J.str(real)).put("sha256", J.str(hash)))
    }

    func walk(path: String, key: String): Unit {
        let real = canonicalize(path).toString()
        let info = FileInfo(real)
        if (info.isDirectory()) {
            entries.put(key + "/", J.obj().put("target", J.str(real)).put("kind", J.str("directory")))
            if (seenDirectories.contains(real)) { return }
            seenDirectories.add(real)
            let children = ArrayList<String>()
            Directory.walk(path, { item => children.add(item.path.toString()); true })
            for (child in sorted(children)) {
                let name = Path(child).fileName
                walk(child, key + "/" + name)
            }
        } else if (info.isRegular()) {
            addFile(path, key)
        } else {
            throw Exception("SDK special file unsupported: " + path)
        }
    }

    func collect(): J {
        for (part in ["bin", "tools", "third_party", "modules", "lib", "runtime"]) {
            let path = join(home, part)
            if (exists(path)) { walk(path, part) } else { entries.put(part, J.nil()) }
        }
        return entries
    }
}

func inspectSdk(sdk: J, runner: String, workDir: String): J {
    let declared = text(sdk, "version", "")
    var home = text(sdk, "home", "")
    if (home.isEmpty()) { home = envValue("CJ_DOCGUARD_SDK_" + declared.replace(".", "_")) }
    let result = J.obj().put("declared_version", J.str(declared)).put("version", J.str(""))
        .put("available", J.boolean(false)).put("reason", J.str(""))
        .put("home", J.str(home)).put("compiler", J.str(""))
        .put("platform", J.str("")).put("environment", J.obj()).put("fingerprint", J.str(""))
    try {
        if (declared.isEmpty()) { throw Exception("SDK declared version missing") }
        if (home.isEmpty()) { throw Exception("SDK home not registered") }
        if (!Path(home).isAbsolute()) { throw Exception("SDK home must be absolute") }
        if (!exists(home)) { throw Exception("SDK home unavailable: " + home) }
        home = canonicalize(home).toString()
        let compiler = join(home, "bin/cjc")
        result.put("home", J.str(home)).put("compiler", J.str(compiler))
        if (!exists(compiler)) { throw Exception("SDK compiler unavailable") }
        mkdir(workDir)
        let environment = basicEnvironment()
        let os = commandText(runner, ["/usr/bin/uname", "-s"], workDir, environment)
        let arch = commandText(runner, ["/usr/bin/uname", "-m"], workDir, environment)
        let platform = os + "-" + arch
        result.put("platform", J.str(platform))
        environment["PATH"] = join(home, "bin") + ":" + join(home, "tools/bin") + ":/usr/bin:/bin:/usr/sbin:/sbin"
        environment["CANGJIE_HOME"] = home
        var runtime = ""
        if (os == "Darwin" && (arch == "arm64" || arch == "aarch64")) {
            runtime = "darwin_aarch64_cjnative"
            environment["DYLD_LIBRARY_PATH"] = join(home, "runtime/lib/" + runtime)
            environment["SDKROOT"] = commandText(runner, ["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"], workDir, basicEnvironment())
        } else if (os == "Linux" && (arch == "x86_64" || arch == "aarch64")) {
            runtime = "linux_" + arch + "_cjnative"
            environment["LD_LIBRARY_PATH"] = join(home, "runtime/lib/" + runtime)
        } else { throw Exception("unsupported actual platform: " + platform) }
        let envJson = J.obj()
        for ((key, value) in environment) { envJson.put(key, J.str(value)) }
        result.put("environment", envJson)
        let output = commandText(runner, [compiler, "--version"], workDir, environment)
        var actual = ""
        for (line in output.split("\n")) {
            if (line.startsWith("Cangjie Compiler: ")) {
                let tail = line[18..].trimAscii()
                actual = tail.split(" ")[0]
            }
        }
        result.put("version", J.str(actual))
        if (actual.isEmpty()) { throw Exception("compiler actual version unrecognized") }
        if (actual != declared) { throw Exception("SDK version mismatch: declared " + declared + ", actual " + actual) }
        let manifest = SdkManifest(home).collect()
        let identity = J.obj().put("declared_version", J.str(declared)).put("version", J.str(actual))
            .put("platform", J.str(platform)).put("environment", envJson).put("files", manifest)
            .put("supervisor", J.str(sha256File(runner))).put("rules", J.str("sdk-content-v1"))
        return result.put("available", J.boolean(true)).put("fingerprint", J.str(digestText(identity.dump())))
            .put("hashed_entries", J.num(manifest.fields.size))
    } catch (e: Exception) {
        return result.put("available", J.boolean(false)).put("reason", J.str(e.message))
            .put("fingerprint", J.str(digestText(result.dump())))
    }
}
