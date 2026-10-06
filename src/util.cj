package docguard

import std.fs.*
import std.collection.*
import std.time.*
import std.env.*

let ENGINE_VERSION = "0.1.0"
let ENGINE_RULES = "docguard-v1-native-fixed-snapshot-latest-attempt"

func v(o: J, key: String): J { if (o.kind == "object") { o.get(key) } else { J.nil() } }
func text(o: J, key: String, fallback: String): String {
    let x = v(o, key)
    return if (x.kind == "null") { fallback } else { x.s() }
}
func number(o: J, key: String, fallback: Int64): Int64 {
    let x = v(o, key)
    return if (x.kind == "null") { fallback } else { x.i() }
}
func flag(o: J, key: String, fallback: Bool): Bool {
    let x = v(o, key)
    return if (x.kind == "null") { fallback } else { x.b() }
}
func array(o: J, key: String): J {
    let x = v(o, key)
    if (x.kind == "null") { return J.arr() }
    if (x.kind != "array") { throw Exception("array required: " + key) }
    return x
}
func readText(path: String): String { String.fromUtf8(File.readFrom(path)) }
func mkdir(path: String): Unit { if (path.isEmpty()) { return }; if (!exists(path)) { Directory.create(path, recursive: true) } }
func writeText(path: String, content: String): Unit {
    mkdir(Path(path).parent.toString())
    File.writeTo(path, content.toArray())
}
func digestText(s: String): String { sha256(s.toArray()) }
func join(a: String, b: String): String { Path(if (a.isEmpty()) { "." } else { a }).join(b).normalize().toString() }
func inside(path: String, root: String): Bool { path == root || path.startsWith(root + "/") }
func resolved(root: String, relative: String): String {
    if (relative.isEmpty() || Path(relative).isAbsolute()) { throw Exception("relative path required: " + relative) }
    let path = join(root, relative)
    if (!inside(path, root)) { throw Exception("path escapes project: " + relative) }
    if (exists(path)) {
        if (FileInfo(path).isSymbolicLink()) { throw Exception("symbolic links unsupported: " + relative) }
        let real = canonicalize(path).toString()
        if (!inside(real, root)) { throw Exception("path escapes project: " + relative) }
        return real
    }
    var parent = Path(path).parent.toString()
    while (!exists(parent)) { parent = Path(parent).parent.toString() }
    if (!inside(canonicalize(parent).toString(), root)) { throw Exception("parent path escapes project: " + relative) }
    return path
}
func envValue(key: String): String { getVariable(key) ?? "" }
func nowText(): String { DateTime.now().toString() }
func sorted(values: ArrayList<String>): ArrayList<String> {
    // Small stable insertion sort keeps manifest ordering independent of FS iteration.
    let out = ArrayList<String>()
    for (s in values) {
        var i: Int64 = 0
        while (i < out.size && out[i] < s) { i++ }
        out.add(s)
        var j = out.size - 1
        while (j > i) { out[j] = out[j - 1]; j-- }
        out[i] = s
    }
    return out
}
func diagnostic(rule: String, severity: String, message: String, source: String): J {
    J.obj().put("rule", J.str(rule)).put("severity", J.str(severity))
        .put("message", J.str(message)).put("source", J.str(source)).put("line", J.num(0)).put("column", J.num(0))
}
func arrayContains(xs: J, item: String): Bool {
    for (x in xs.items) { if (x.s() == item) { return true } }
    return false
}
func allowedKeys(o: J, keys: Array<String>, label: String): Unit {
    if (o.kind != "object") { throw Exception("table required: " + label) }
    for ((key, _) in o.fields) {
        var known = false
        for (k in keys) { if (key == k) { known = true } }
        if (!known) { throw Exception("unknown configuration field: " + label + "." + key) }
    }
}

class Project {
    let configPath: String
    let root: String
    let config: J
    let output: String
    let runner: String
    init(path: String) {
        configPath = canonicalize(path).toString()
        root = Path(configPath).parent.toString()
        config = parseToml(readText(configPath))
        allowedKeys(config, ["project", "sdks", "examples", "links"], "config")
        let p = config.get("project")
        allowedKeys(p, ["name", "sources", "documents", "output", "trusted", "closed_inputs", "exclude"], "project")
        if (text(p, "name", "").isEmpty()) { throw Exception("project.name required") }
        output = resolved(root, text(p, "output", ".docguard"))
        if (output == root || output == configPath) { throw Exception("output must not overwrite project") }
        for (s in array(p, "sources").items) {
            let source = resolved(root, s.s())
            if (inside(source, output) || inside(output, source)) { throw Exception("output overlaps sources: " + s.s()) }
        }
        if (array(p, "sources").items.size == 0) { throw Exception("project.sources cannot be empty") }
        for (d in array(p, "documents").items) {
            if (inside(resolved(root, d.s()), output)) { throw Exception("output overlaps documents") }
        }
        for (e in array(p, "exclude").items) {
            resolved(root, e.s())
            if (e.s() == ".") { throw Exception("cannot exclude project") }
        }
        let sdkIds = HashSet<String>()
        for (sdk in array(config, "sdks").items) {
            allowedKeys(sdk, ["version", "home"], "sdks")
            let id = text(sdk, "version", "")
            if (id.isEmpty() || sdkIds.contains(id)) { throw Exception("missing/duplicate SDK version") }
            sdkIds.add(id)
        }
        if (sdkIds.size == 0) { throw Exception("at least one SDK declaration required") }
        let ids = HashSet<String>()
        for (e in array(config, "examples").items) {
            allowedKeys(e, ["id", "file", "symbol", "mode", "kind", "wrapper", "sdks", "stdout", "stderr", "expected_exit", "timeout_ms", "skip_reason", "required"], "examples")
            let id = text(e, "id", "")
            if (id.isEmpty() || ids.contains(id)) { throw Exception("missing/duplicate example id") }
            ids.add(id)
            for (c in id.toArray()) {
                if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 45 || c == 95)) { throw Exception("example id: use letters/digits/-/_") }
            }
            if (inside(resolved(root, text(e, "file", "")), output)) { throw Exception("output overlaps example file") }
            let mode = text(e, "mode", "run")
            if (mode != "run" && mode != "compile") { throw Exception("unsupported example mode") }
            let kind = text(e, "kind", "program")
            if (kind != "program" && kind != "snippet") { throw Exception("unsupported example kind") }
            if (kind == "snippet" && text(e, "wrapper", "").isEmpty()) { throw Exception("snippet wrapper required") }
            if (kind == "snippet" && inside(resolved(root, e.get("wrapper").s()), output)) { throw Exception("output overlaps snippet wrapper") }
            let t = number(e, "timeout_ms", 10000)
            if (t <= 0 || t > 600000) { throw Exception("timeout_ms must be 1..600000") }
            number(e, "expected_exit", 0)
            flag(e, "required", true)
            for (k in ["stdout", "stderr", "skip_reason", "symbol"]) { text(e, k, "") }
            for (s in array(e, "sdks").items) { if (!sdkIds.contains(s.s())) { throw Exception("example declares unknown SDK " + s.s()) } }
        }
        if (ids.size == 0) { throw Exception("at least one example required") }
        for (link in array(config, "links").items) { allowedKeys(link, ["from", "target"], "links"); resolved(root, link.get("from").s()); link.get("target").s() }
        runner = envValue("CJ_DOCGUARD_RUNNER")
        if (runner.isEmpty()) { throw Exception("CJ_DOCGUARD_RUNNER must point to the bundled Unix resource supervisor") }
        if (!exists(runner)) { throw Exception("resource supervisor unavailable") }
    }
    func name(): String { config.get("project").get("name").s() }
    func excluded(path: String): Bool {
        if (inside(path, output)) { return true }
        let relative = path[root.size + 1..]
        for (component in relative.split("/")) {
            if (component == ".git" || component == ".DS_Store" || component == "target" || component == ".env" || component.startsWith(".env.")) { return true }
        }
        for (e in array(config.get("project"), "exclude").items) { if (inside(path, resolved(root, e.s()))) { return true } }
        return false
    }
}
