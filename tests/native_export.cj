package docguard

import std.fs.*
import std.collection.*

private func checkExport(ok: Bool, label: String): Unit { if (!ok) { throw Exception("FAIL native export: " + label) } }

main(): Int64 {
    let sdk = envValue("CJ_DOCGUARD_TEST_SDK")
    checkExport(!sdk.isEmpty(), "test SDK is selected")
    let temp = Directory.createTemp("/tmp").toString()
    try {
        let sentinel = join(temp, "exclusive-sentinel")
        writeText(sentinel, "original")
        var exclusive = false
        try { File.create(sentinel) } catch (_: Exception) { exclusive = true }
        checkExport(exclusive && readText(sentinel) == "original", "File.create refuses existing bytes")
        let root = join(temp, "project")
        mkdir(root)
        let config = join(root, "docguard.toml")
        let source = join(root, "src/lib.cj")
        writeText(source, "package demo\n/// Add inputs.\npublic func add(a: Int64,b: Int64): Int64 { a+b }\n")
        writeText(join(root, "example.cj"), "package demo\nmain(): Int64 { println(add(1,2)); return 0 }\n")
        let settings = "[project]\nname=\"Native export\"\nsources=[\"src\"]\ndocuments=[]\noutput=\".docguard\"\ntrusted=true\nclosed_inputs=true\n[[sdks]]\nversion=\"" + sdk + "\"\n[[examples]]\nid=\"add\"\nfile=\"example.cj\"\nsymbol=\"add\"\nstdout=\"3\\n\"\nexpected_exit=0\n"
        writeText(config, settings)
        let project = Project(config)
        let untouched = J.obj().put("status", J.str("RUN_VERIFIED"))
        let privateRecord = J.obj().put("cwd", J.str(project.root + "/src"))
            .put("nested", untouched)
        let sanitized = publicValue(project, privateRecord)
        checkExport(privateRecord.get("cwd").s() == project.root + "/src" &&
            sanitized.get("cwd").s() == "$PROJECT/src", "redaction leaves source record untouched")
        sanitized.put("extra", J.num(1))
        checkExport(privateRecord.get("extra").kind == "null" &&
            privateRecord.get("nested").dump() == sanitized.get("nested").dump(),
            "changed parent is independent and unchanged subtree retains equal content")
        let options = HashMap<String, String>()
        options["--example"] = "missing"; options["--sdk"] = sdk; options["--platform"] = "Darwin-arm64"
        options["--out"] = join(temp, "unknown")
        checkExport(exportExample(project, options) == 1 && !exists(options["--out"]), "unknown refused without target")
        let manifest = projectManifest(project)
        let api = projectApi(project, manifest)
        let environments = inspectEnvironments(project)
        checkExport(environments.items[0].get("available").b(), "actual SDK available")
        let actualPlatform = environments.items[0].get("platform").s()
        options["--platform"] = actualPlatform
        let attempts = verifyProject(project, manifest, api, environments, sdk)
        checkExport(latestAttempt(attempts, "add", sdk).get("status").s() == "RUN_VERIFIED", "real verification")
        options["--example"] = "add"; options["--out"] = join(temp, "bundle")
        checkExport(exportExample(project, options) == 0, "verified export")
        let bundle = options["--out"]
        checkExport(exists(join(bundle, "src/src/lib.cj")) && exists(join(bundle, "examples/example.cj")) &&
            exists(join(bundle, "main_wrapped.cj")) && exists(join(bundle, "build.sh")) && exists(join(bundle, "manifest.json")), "bundle files")
        let exported = parseJson(readText(join(bundle, "manifest.json")))
        checkExport(exported.get("project_fingerprint").s() == manifest.get("fingerprint").s() &&
            exported.get("attempt_sequence").i() == 1 && exported.get("assertions").items.size > 0, "manifest evidence")
        let runtime = executionEnvironment(environments.items[0]); runtime["CJ_SDK_HOME"] = environments.items[0].get("home").s()
        let reproduced = runCommand(project.runner, ["/bin/bash", "build.sh"], bundle, join(temp, "repro"), runtime, 120000)
        checkExport(reproduced.get("exit_code").i() == 0 && reproduced.get("stdout").s() == "3\n", "real exported compile/run")
        let cli = envValue("CJ_DOCGUARD_TEST_CLI")
        checkExport(exists(cli), "matching SDK CLI built")
        let arguments = [cli, "export", "--config", config, "--example", "add", "--sdk", sdk,
            "--platform", actualPlatform, "--out", join(temp, "missing")]
        let withoutOut = [cli, "export", "--config", config, "--example", "add", "--sdk", sdk, "--platform", actualPlatform]
        let withoutSdk = [cli, "export", "--config", config, "--example", "add", "--platform", actualPlatform, "--out", join(temp, "missing")]
        let withoutPlatform = [cli, "export", "--config", config, "--example", "add", "--sdk", sdk, "--out", join(temp, "missing")]
        let extraTool = [cli, "export", "--config", config, "--example", "add", "--sdk", sdk,
            "--platform", actualPlatform, "--out", join(temp, "missing"), "--tool", "list_symbols"]
        let queryOut = [cli, "query", "--config", config, "--out", join(temp, "missing")]
        for (cmd in [withoutOut, withoutSdk, withoutPlatform, extraTool, queryOut]) {
            let result = runCommand(project.runner, cmd, temp, join(temp, "cli-refusal"), runtime, 30000)
            checkExport(result.get("exit_code").i() == 2 && !exists(join(temp, "missing")), "CLI required/disallowed options")
        }
        let occupied = join(temp, "occupied"); mkdir(occupied); writeText(join(occupied, "keep"), "original")
        let nonempty = [cli, "export", "--config", config, "--example", "add", "--sdk", sdk,
            "--platform", actualPlatform, "--out", occupied]
        let refused = runCommand(project.runner, nonempty, temp, join(temp, "cli-nonempty"), runtime, 30000)
        checkExport(refused.get("exit_code").i() == 2 && readText(join(occupied, "keep")) == "original", "nonempty unchanged")
        writeText(source, readText(source).replace("a+b", "a-b"))
        options["--out"] = join(temp, "stale")
        checkExport(exportExample(project, options) == 1 && !exists(options["--out"]), "stale refused")
        options["--out"] = join(root, "src/nested")
        var blocked = false
        try { exportExample(project, options) } catch (_: Exception) { blocked = true }
        checkExport(blocked && !exists(options["--out"]), "source overlap refused")
        writeText(source, readText(source).replace("a-b", "a+b"))
        writeText(config, settings + "mode=\"compile\"\n")
        let compileProject = Project(config)
        let compileManifest = projectManifest(compileProject)
        let compileApi = projectApi(compileProject, compileManifest)
        let compileEnvs = inspectEnvironments(compileProject)
        verifyProject(compileProject, compileManifest, compileApi, compileEnvs, sdk)
        options["--out"] = join(temp, "compile-only")
        checkExport(exportExample(compileProject, options) == 1 && !exists(options["--out"]), "compile only refused")
        println("PASS native export: real SDK, frozen bundle, stale/unknown/compile/path refusals")
        return 0
    } finally { removeIfExists(temp, recursive: true) }
}
