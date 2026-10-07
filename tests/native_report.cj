package docguard
import std.fs.*

var reportAssertions: Int64 = 0
func reportExpect(ok: Bool, label: String): Unit {
    reportAssertions++
    if (!ok) { throw Exception("FAIL report: " + label) }
}
func readReportFile(path: String): String { String.fromUtf8(File.readFrom(path)) }
main(): Int64 {
    let output = "/tmp/cj-docguard-native-report"
    let attack = "</script><script>alert(1)</script> & \"quote\""
    let symbol = J.obj().put("id", J.str("symbol-001")).put("name", J.str("文档函数"))
        .put("package", J.str("demo.docs")).put("kind", J.str("function"))
        .put("declaration", J.str("public func safe(x: String): String"))
        .put("parameters", J.arr().add(J.obj().put("name", J.str("x")).put("type", J.str("String"))))
        .put("returns", J.str("String")).put("comment", J.str(attack))
        .put("source", J.str("src/api.cj")).put("line", J.num(7)).put("status", J.str("SUPPORTED"))
    let result = J.obj().put("example_id", J.str("sample-run")).put("symbol", J.str("symbol-001"))
        .put("sdk_version", J.str("1.1.3")).put("platform", J.str("darwin_arm64"))
        .put("status", J.str("RUN_VERIFIED")).put("freshness", J.str("CURRENT"))
        .put("attempt_id", J.str("attempt-001")).put("sequence", J.num(1))
        .put("compile", J.obj().put("exit_code", J.num(0)).put("stdout", J.str("compiler log")))
        .put("run", J.obj().put("exit_code", J.num(0)).put("stdout", J.str(attack)).put("stderr", J.str("error detail")))
        .put("assertions", J.arr().add(J.obj().put("name", J.str("stdout")).put("passed", J.boolean(true))))
    let report = J.obj().put("schema_version", J.str("1.0")).put("engine_version", J.str("0.1.0"))
        .put("generated_at", J.str("2026-10-06T08:00:00Z")).put("project", J.obj().put("name", J.str(attack)))
        .put("manifest", J.obj().put("fingerprint", J.str("abc123")).put("closure_complete", J.boolean(true)).put("files", J.arr()))
        .put("api", J.obj().put("symbols", J.arr().add(symbol)).put("diagnostics", J.arr()).put("files", J.arr()))
        .put("environments", J.arr().add(J.obj().put("sdk_version", J.str("1.1.3")).put("platform", J.str("darwin_arm64"))))
        .put("results", J.arr().add(result).add(J.obj().put("example_id", J.str("compile-fail")).put("sdk_version", J.str("1.2.0")).put("status", J.str("COMPILE_FAILED")).put("reason", J.str("actual compiler rejection"))))
        .put("links", J.arr().add(J.obj().put("from", J.str("README.md")).put("target", J.str("symbol-001")).put("status", J.str("RESOLVED"))))
        .put("diagnostics", J.arr().add(J.obj().put("message", J.str("diagnostic " + attack))))
        .put("extra_future_field", J.str("preserved"))
        .put("summary", J.obj().put("RUN_VERIFIED", J.num(1)).put("COMPILE_FAILED", J.num(1)))
    report.get("results").add(J.obj().put("example_id", J.str("sample-run")).put("sdk_version", J.str("1.1.3")).put("status", J.str("CANCELLED")).put("sequence", J.num(2)).put("freshness", J.str("STALE")))
    report.get("results").add(J.obj().put("example_id", J.str("future-status")).put("sdk_version", J.str("1.2.0")).put("status", J.str("FUTURE_STATUS")))
    writeReports(output, report)
    reportExpect(readReportFile(output + "/report.json") == report.dump(), "streamed report bytes match canonical dump")
    reportExpect(readReportFile(output + "/api.json") == report.get("api").dump() &&
        readReportFile(output + "/manifest.json") == report.get("manifest").dump(), "streamed component bytes match canonical dump")
    reportExpect(parseJson(readReportFile(output + "/report.json")).get("schema_version").text == "1.0", "full JSON artifact")
    reportExpect(parseJson(readReportFile(output + "/api.json")).get("symbols").items.size == 1, "API JSON artifact")
    reportExpect(parseJson(readReportFile(output + "/manifest.json")).get("fingerprint").s() == "abc123", "manifest JSON artifact")
    let html = readReportFile(output + "/site/index.html")
    let md = readReportFile(output + "/report.md")
    reportExpect(html.contains("冻结的静态快照") && html.contains("2026-10-06T08:00:00Z"), "explicit frozen generation time")
    reportExpect(html.contains("不能证明当前仓库状态"), "static boundary")
    reportExpect(md.contains("冻结的静态快照") && md.contains("2026-10-06T08:00:00Z"), "markdown static boundary")
    reportExpect(!html.contains(attack) && html.contains("&lt;/script&gt;&lt;script&gt;alert(1)&lt;/script&gt;"), "script breakout escaped")
    reportExpect(!html.contains("innerHTML") && !html.contains("fetch("), "no dynamic injection or network fetch")
    reportExpect(!html.contains("cdn.") && !html.contains("fonts.googleapis"), "offline assets")
    reportExpect(html.contains("id=\"symbol-001\"") && html.contains("href=\"#symbol-001\""), "symbol fragment links")
    reportExpect(html.contains("CANCELLED") && html.contains("STALE"), "newer cancelled and stale evidence retained")
    reportExpect(html.contains("FUTURE_STATUS"), "unknown future status retained")
    reportExpect(parseJson(readReportFile(output + "/report.json")).get("extra_future_field").s() == "preserved", "future report fields preserved")
    reportExpect(!md.contains(attack), "markdown HTML attack escaped")
    for (field in ["文档函数", "demo.docs", "public func safe", "String", "src/api.cj", "sample-run", "RUN_VERIFIED", "COMPILE_FAILED", "actual compiler rejection", "compiler log", "error detail", "attempt-001", "1.1.3", "1.2.0", "diagnostic"]) {
        reportExpect(html.contains(field), "HTML field " + field)
    }
    reportExpect(html.contains("data-name") && html.contains("data-package") && html.contains("addEventListener"), "offline search")
    let special = J.obj().put("api", J.obj().put("symbols", J.arr().add(J.obj().put("id", J.str("quoted-\"-id")).put("name", J.str("<img src=x onerror=alert(1)>")))))
    writeReports(output + "/special", special)
    let specialHtml = readReportFile(output + "/special/site/index.html")
    reportExpect(specialHtml.contains("id=\"quoted-&quot;-id\""), "attribute quotes escaped")
    reportExpect(!specialHtml.contains("<img src=x") && specialHtml.contains("&lt;img src=x onerror=alert(1)&gt;"), "HTML elements remain text")
    writeReports(output + "/empty", J.obj())
    reportExpect(readReportFile(output + "/empty/site/index.html").contains("未提供"), "missing fields graceful")
    reportExpect(parseJson(readReportFile(output + "/empty/report.json")).kind == "object", "empty JSON artifact")
    // A fresh matrix after a large retained history exercises the failing writer path.
    let matrix = J.arr()
    for (i in 0..28) {
        matrix.add(J.obj().put("example_id", J.str("matrix-" + (i / 2).toString()))
            .put("sdk_version", J.str(if (i % 2 == 0) { "1.1.3" } else { "1.2.0" }))
            .put("status", J.str(if (i < 2) { "COMPILE_ONLY" } else { "RUN_VERIFIED" }))
            .put("code", J.str("main(): Int64 { 0 }")))
    }
    let history = J.arr()
    let log = String.fromUtf8(Array<Byte>(4096, repeat: 97))
    for (i in 0..384) {
        history.add(J.obj().put("sequence", J.num(i)).put("status", J.str("RUN_VERIFIED"))
            .put("run", J.obj().put("stdout", J.str(log)).put("exit_code", J.num(0))))
    }
    let retained = J.obj().put("results", matrix).put("history", history)
    let freshMatrix = J.obj().put("results", parseJson(matrix.dump()))
    for (i in 0..8) {
        writeReports(output + "/large-history", retained)
        writeReports(output + "/fresh-matrix", freshMatrix)
    }
    let stored = parseJson(readReportFile(output + "/large-history/report.json"))
    reportExpect(stored.get("history").items.size == 384 && stored.get("results").items.size == 28, "large history and all matrix cells retained")
    reportExpect(rCounts(stored.get("results")).get("COMPILE_ONLY").i() == 2 && rCounts(stored.get("results")).get("RUN_VERIFIED").i() == 26, "actual native matrix statuses preserved")
    reportExpect(matrix.items.size == 28 && history.items.size == 384, "rendering preserves input collections")
    let sourceReport = parseJson(report.dump())
    sourceReport.get("api").put("files", J.arr()
        .add(J.obj().put("path", J.str("src/api.cj")).put("code", J.str("public func safe(): String { \"<escaped>\" }")).put("status", J.str("SUPPORTED")))
        .add(J.obj().put("source", J.str("src/second.cj")).put("code", J.str("package second")).put("status", J.str("SUPPORTED"))))
    writeReports(output + "/source", sourceReport)
    let sourceHtml = readReportFile(output + "/source/site/index.html")
    let sourceAnchor = "file-" + sha256("src/api.cj".toArray())[..20]
    reportExpect(sourceHtml.contains("id=\"" + sourceAnchor + "\"") && sourceHtml.contains("href=\"#" + sourceAnchor + "\""), "path/code source entry has reachable symbol anchor")
    reportExpect(sourceHtml.contains("id=\"file-" + sha256("src/second.cj".toArray())[..20] + "\""), "source/code entry remains supported")
    reportExpect(sourceHtml.contains("&lt;escaped&gt;") && !sourceHtml.contains("<escaped>"), "source code remains escaped text")
    let cyclic = J.arr(); cyclic.add(cyclic)
    let invalidOutput = output + "/invalid-tree"
    var rejected = false
    try { writeReports(invalidOutput, J.obj().put("history", cyclic)) }
    catch (_: Exception) { rejected = true }
    reportExpect(rejected && !exists(invalidOutput + "/report.json") &&
        !exists(invalidOutput + ".report-staging"), "malformed tree leaves no published output")
    println("PASS native report: " + reportAssertions.toString() + " assertions; files, snapshot, escaping, evidence, offline search")
    return 0
}
