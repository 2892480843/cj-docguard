package docguard

import std.fs.*
import std.collection.*

func rField(j: J, key: String): J { if (j.kind == "object") { j.get(key) } else { J.nil() } }
func rText(j: J): String {
    if (j.kind == "null") { return "未提供" }
    if (j.kind == "string" || j.kind == "number" || j.kind == "boolean") { return j.text }
    return j.dump()
}
func rValue(j: J, key: String): String { rText(rField(j, key)) }
// The SDK 1.1.3 build raised ConcurrentModificationException in this renderer.
// Fixed array snapshots avoid retaining mutable-list iterators during rendering.
func rArray(j: J): Array<J> { if (j.kind == "array") { j.items.toArray() } else { [] } }
func rFileSource(file: J): String {
    let source = rField(file, "source")
    return if (source.kind == "null") { rValue(file, "path") } else { rText(source) }
}
func rEscape(s: String): String {
    let out = ArrayList<Byte>()
    for (b in s.toArray()) {
        let escaped = if (b == 38) { "&amp;" } else if (b == 60) { "&lt;" }
            else if (b == 62) { "&gt;" } else if (b == 34) { "&quot;" }
            else if (b == 39) { "&#39;" } else { "" }
        if (escaped.isEmpty()) { out.add(b) } else { for (e in escaped.toArray()) { out.add(e) } }
    }
    return String.fromUtf8(out.toArray())
}
func rMd(s: String): String {
    let out = ArrayList<Byte>()
    for (b in rEscape(s).toArray()) {
        if (b == 124) { for (e in "&#124;".toArray()) { out.add(e) } }
        else if (b == 10 || b == 13) { for (e in "<br>".toArray()) { out.add(e) } }
        else {
            if (b == 92 || b == 96 || b == 42 || b == 95 || b == 123 || b == 125 || b == 91 || b == 93 || b == 40 || b == 41 || b == 35 || b == 43 || b == 33) { out.add(92) }
            out.add(b)
        }
    }
    return String.fromUtf8(out.toArray())
}
func rPre(s: String): String { "<pre>" + rEscape(s) + "</pre>" }
func rBadge(status: String): String {
    let cls = if (status == "RUN_VERIFIED" || status == "COMPILE_VERIFIED") { " evidence" }
        else if (status.contains("FAILED") || status == "TIMEOUT" || status == "CANCELLED") { " failed" }
        else { "" }
    return "<span class=\"badge" + cls + "\">" + rEscape(status) + "</span>"
}
func rKnownStatuses(): Array<String> {
    ["RUN_VERIFIED", "COMPILE_VERIFIED", "COMPILE_FAILED", "RUN_FAILED", "ASSERTION_FAILED", "TIMEOUT", "CANCELLED", "SKIPPED", "UNSUPPORTED", "NOT_CHECKED", "UNKNOWN", "IN_PROGRESS"]
}
func rCounts(results: J): J {
    let counts = J.obj()
    for (s in rKnownStatuses()) { counts.put(s, J.num(0)) }
    for (r in rArray(results)) {
        let s = rValue(r, "status")
        let previous = rField(counts, s)
        counts.put(s, J.num(if (previous.kind == "number") { previous.i() + 1 } else { 1 }))
    }
    return counts
}
func rUnique(list: ArrayList<String>, s: String): Unit {
    for (item in list) { if (item == s) { return } }
    list.add(s)
}
func rSdk(e: J): String {
    let version = rField(e, "sdk_version")
    return if (version.kind == "null") { rValue(e, "version") } else { rText(version) }
}
func rSymbolMatch(symbol: J, result: J): Bool {
    let reference = rField(result, "symbol_id")
    let name = if (reference.kind == "null") { rField(result, "symbol") } else { reference }
    if (name.kind != "string") { return false }
    return name.text == rValue(symbol, "id") || name.text == rValue(symbol, "name") ||
        name.text == rValue(symbol, "package") + "." + rValue(symbol, "name")
}
func rParameters(symbol: J): String {
    let p = rField(symbol, "parameters")
    if (p.kind != "array") { return "未提供" }
    if (p.items.size == 0) { return "无参数" }
    var out = ""
    for (item in p.items) {
        if (!out.isEmpty()) { out += ", " }
        out += rValue(item, "name") + ": " + rValue(item, "type")
    }
    return out
}
func rSymbols(report: J): J { rField(rField(report, "api"), "symbols") }
func rHasSymbol(report: J, id: String): Bool {
    for (symbol in rArray(rSymbols(report))) { if (rValue(symbol, "id") == id) { return true } }
    return false
}
func rDefinitions(report: J): String {
    var out = "<section id=\"api\"><div class=\"section-heading\"><h2>接口文档</h2><span id=\"search-count\" aria-live=\"polite\"></span></div><label class=\"search-label\" for=\"api-search\">按名称或包名搜索</label><input id=\"api-search\" type=\"search\" placeholder=\"搜索接口名称、包名…\" autocomplete=\"off\"><div id=\"api-list\">"
    for (symbol in rArray(rSymbols(report))) {
        let id = rValue(symbol, "id")
        out += "<article class=\"api-card\" id=\"" + rEscape(id) + "\" data-name=\"" + rEscape(rValue(symbol, "name")) + "\" data-package=\"" + rEscape(rValue(symbol, "package")) + "\"><div class=\"api-heading\"><h3>" + rEscape(rValue(symbol, "name")) + "</h3>" + rBadge(rValue(symbol, "status")) + "</div><p class=\"muted\">" + rEscape(rValue(symbol, "package")) + " · " + rEscape(rValue(symbol, "kind")) + " · 所属对象：" + rEscape(rValue(symbol, "owner")) + "</p>"
        out += rPre(rValue(symbol, "declaration"))
        out += "<dl><dt>参数</dt><dd>" + rEscape(rParameters(symbol)) + "</dd><dt>返回值</dt><dd>" + rEscape(rValue(symbol, "returns")) + "</dd><dt>源码位置</dt><dd>" + rEscape(rValue(symbol, "source")) + ":" + rEscape(rValue(symbol, "line")) + ":" + rEscape(rValue(symbol, "column")) + "</dd><dt>符号 ID</dt><dd><code>" + rEscape(id) + "</code></dd></dl>"
        for (f in rArray(rField(rField(report, "api"), "files"))) {
            if (rFileSource(f) == rValue(symbol, "source") && rField(f, "code").kind == "string") {
                out += "<p><a href=\"#file-" + sha256(rFileSource(f).toArray())[..20] + "\">查看该文件源码</a></p>"
            }
        }
        out += "<h4>源码注释</h4><div class=\"comment\">" + rEscape(rValue(symbol, "comment")) + "</div><h4>关联示例</h4><ul class=\"example-links\">"
        var found = false
        var i: Int64 = 0
        for (result in rArray(rField(report, "results"))) {
            if (rSymbolMatch(symbol, result)) {
                found = true
                out += "<li><a href=\"#result-" + i.toString() + "\">" + rEscape(rValue(result, "example_id")) + "</a> · " + rEscape(rValue(result, "sdk_version")) + " · " + rBadge(rValue(result, "status")) + " · freshness: " + rEscape(rValue(result, "freshness")) + "</li>"
            }
            i++
        }
        if (!found) { out += "<li class=\"muted\">未提供与该接口关联的示例。</li>" }
        out += "</ul></article>"
    }
    if (rArray(rSymbols(report)).size == 0) { out += "<p class=\"empty\">未提供接口。请检查提取诊断。</p>" }
    return out + "</div><p id=\"search-empty\" class=\"empty\" hidden>没有匹配的接口。</p></section>"
}
func rMatrix(report: J): String {
    let sdks = ArrayList<String>()
    let examples = ArrayList<String>()
    for (e in rArray(rField(report, "environments"))) { rUnique(sdks, rSdk(e)) }
    for (r in rArray(rField(report, "results"))) { rUnique(sdks, rValue(r, "sdk_version")); rUnique(examples, rValue(r, "example_id")) }
    var out = "<section id=\"matrix\"><h2>SDK 验证矩阵</h2><p class=\"muted\">SDK 是仓颉开发工具包。矩阵展示报告内每条尝试；状态与 freshness（输入匹配情况）均保留原值。</p><div class=\"table-wrap\"><table><caption>示例 × SDK · 冻结快照内记录</caption><thead><tr><th scope=\"col\">示例</th>"
    for (sdk in sdks) { out += "<th scope=\"col\">" + rEscape(sdk) + "</th>" }
    out += "</tr></thead><tbody>"
    for (example in examples) {
        out += "<tr><th scope=\"row\">" + rEscape(example) + "</th>"
        for (sdk in sdks) {
            out += "<td>"
            var found = false
            var i: Int64 = 0
            for (r in rArray(rField(report, "results"))) {
                if (rValue(r, "sdk_version") == sdk && rValue(r, "example_id") == example) {
                    found = true
                    out += "<a class=\"matrix-entry\" href=\"#result-" + i.toString() + "\">" + rBadge(rValue(r, "status")) + "<small>" + rEscape(rValue(r, "freshness")) + " · #" + rEscape(rValue(r, "sequence")) + "</small></a>"
                }
                i++
            }
            if (!found) { out += "<span class=\"muted\">未检查</span>" }
            out += "</td>"
        }
        out += "</tr>"
    }
    if (examples.size == 0) { out += "<tr><td>未提供验证尝试。</td></tr>" }
    out += "</tbody></table></div><h3>状态计数</h3><p class=\"muted\">按报告内尝试记录计数；未知状态按原值单独保留。计数不代表当前仓库的可用证明。</p><div class=\"table-wrap\"><table><thead><tr><th>状态</th><th>数量</th></tr></thead><tbody>"
    for ((status, count) in rCounts(rField(report, "results")).fields) { out += "<tr><td>" + rBadge(status) + "</td><td>" + rEscape(rText(count)) + "</td></tr>" }
    out += "</tbody></table></div><details><summary>引擎提供的汇总</summary>" + rPre(rValue(report, "summary")) + "</details><h3>环境指纹与工具链信息</h3>"
    for (e in rArray(rField(report, "environments"))) { out += "<details><summary>SDK " + rEscape(rSdk(e)) + " · " + rEscape(rValue(e, "platform")) + "</summary>" + rPre(e.dump()) + "</details>" }
    return out + "</section>"
}
func rStage(name: String, stage: J): String {
    return "<h4>" + rEscape(name) + "</h4><dl><dt>退出码</dt><dd>" + rEscape(rValue(stage, "exit_code")) + "</dd><dt>执行参数</dt><dd>" + rPre(rValue(stage, "argv")) + "</dd><dt>超时 / 截断</dt><dd>" + rEscape(rValue(stage, "timed_out")) + " / " + rEscape(rValue(stage, "truncated")) + "</dd></dl><details><summary>stdout · 标准输出</summary>" + rPre(rValue(stage, "stdout")) + "</details><details><summary>stderr · 错误输出</summary>" + rPre(rValue(stage, "stderr")) + "</details>"
}
func rAttempts(report: J): String {
    var out = "<section id=\"evidence\"><h2>验证尝试与原始证据</h2><p class=\"muted\">以下为生成时固定的记录，包含失败、取消、跳过与未知结果。较新的失败不会被隐藏；页面不会重新核验输入。</p>"
    var i: Int64 = 0
    for (result in rArray(rField(report, "results"))) {
        out += "<article class=\"attempt\" id=\"result-" + i.toString() + "\"><div class=\"api-heading\"><h3>" + rEscape(rValue(result, "example_id")) + "</h3>" + rBadge(rValue(result, "status")) + "</div><dl><dt>SDK / 平台</dt><dd>" + rEscape(rValue(result, "sdk_version")) + " / " + rEscape(rValue(result, "platform")) + "</dd><dt>输入匹配情况</dt><dd>" + rEscape(rValue(result, "freshness")) + "</dd><dt>尝试 / 序号</dt><dd>" + rEscape(rValue(result, "attempt_id")) + " / " + rEscape(rValue(result, "sequence")) + "</dd><dt>状态原因</dt><dd>" + rEscape(rValue(result, "reason")) + "</dd></dl>"
        out += "<details><summary>登记的执行源码与包装</summary>" + rPre(rValue(result, "code")) + rPre(rValue(result, "wrapper")) + "</details>"
        out += rStage("编译", rField(result, "compile")) + rStage("运行", rField(result, "run"))
        out += "<h4>断言（对输出与退出码的预期检查）</h4>" + rPre(rValue(result, "assertions")) + "<details><summary>完整原始尝试记录</summary>" + rPre(result.dump()) + "</details></article>"
        i++
    }
    if (i == 0) { out += "<p class=\"empty\">未提供尝试。没有可据此确认的运行结果。</p>" }
    return out + "</section>"
}
func rLinks(report: J): String {
    var out = "<section id=\"links\"><h2>文档链接检查</h2><div class=\"table-wrap\"><table><thead><tr><th>来源</th><th>目标符号</th><th>状态 / 原因</th></tr></thead><tbody>"
    for (link in rArray(rField(report, "links"))) {
        let target = rValue(link, "target")
        let targetCell = if (rHasSymbol(report, target)) { "<a href=\"#" + rEscape(target) + "\">" + rEscape(target) + "</a>" } else { rEscape(target) }
        out += "<tr><td>" + rEscape(rValue(link, "from")) + "</td><td>" + targetCell + "</td><td>" + rEscape(rValue(link, "status")) + " / " + rEscape(rValue(link, "reason")) + "</td></tr>"
    }
    if (rArray(rField(report, "links")).size == 0) { out += "<tr><td colspan=\"3\">未提供链接检查记录。</td></tr>" }
    return out + "</tbody></table></div></section>"
}
func rDiagnostics(report: J): String {
    var out = "<section id=\"diagnostics\"><h2>诊断与检查范围</h2><p class=\"muted\">诊断包含提取错误、未支持语法、未检查项和引擎提示；未提供诊断不等于全部输入已检查。</p>"
    for (key in ["diagnostics", "files"]) {
        let apiValue = rField(rField(report, "api"), key)
        out += "<h3>" + (if (key == "diagnostics") { "接口诊断" } else { "接口文件" }) + "</h3>" + rPre(rText(apiValue))
    }
    out += "<h3>工程诊断</h3>" + rPre(rValue(report, "diagnostics"))
    out += "<h3>输入闭包（本次登记的完整输入集合）</h3><p>closure_complete: " + rEscape(rValue(rField(report, "manifest"), "closure_complete")) + "</p>" + rPre(rValue(rField(report, "manifest"), "files"))
    return out + "</section>"
}

func rSources(report: J): String {
    var out = "<section id=\"sources\"><h2>源码入口</h2>"
    for (f in rArray(rField(rField(report, "api"), "files"))) {
        if (rField(f, "code").kind != "string") { continue }
        out += "<article class=\"api-card\" id=\"file-" + sha256(rFileSource(f).toArray())[..20] + "\"><h3>" + rEscape(rFileSource(f)) + "</h3>" + rPre(rValue(f, "code")) + "</article>"
    }
    return out + "</section>"
}

func rStyles(): String {
    return "*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:88px}body{margin:0;color:#263330;background:#f5f5f0;font:16px/1.65 -apple-system,BlinkMacSystemFont,\"Segoe UI\",\"PingFang SC\",\"Microsoft YaHei\",sans-serif}a{color:#176961;text-underline-offset:3px}a:hover{color:#0e4741}.topbar{display:flex;align-items:center;gap:32px;padding:16px max(24px,calc((100vw - 1180px)/2));background:#1c302d;color:#fff;position:sticky;top:0;z-index:2}.brand{color:#fff;font-weight:700;letter-spacing:.04em;text-decoration:none;white-space:nowrap}.topbar nav{display:flex;gap:22px;flex:1}.topbar nav a{color:#deebe7;text-decoration:none;font-size:14px}.offline{font-size:12px;color:#c4d8d1;white-space:nowrap}main{max-width:1180px;padding:44px 24px;margin:auto}section{margin-bottom:48px;scroll-margin-top:88px}h1,h2,h3,h4{line-height:1.3;color:#1b302b}h1{font-size:clamp(28px,4vw,42px);font-weight:650;margin:10px 0 16px;overflow-wrap:anywhere}h2{font-size:25px;margin:0 0 18px}h3{font-size:20px;margin:0 0 12px}h4{font-size:15px;margin:22px 0 8px}.eyebrow{font-size:11px;letter-spacing:.1em;font-weight:600;color:#497b70}.lead{font-size:18px;color:#586b64}.snapshot{padding:18px 20px;margin:26px 0 20px;border-left:4px solid #287c6e;background:#e8efea}.snapshot p{margin:8px 0 0;font-size:14px}.snapshot strong{font-size:15px}.muted{color:#62736c;font-size:14px}.metadata{font-size:13px}.stats{display:flex;gap:36px;margin:28px 0}.stats div{display:flex;flex-direction:column}.stats strong{font-size:30px;font-weight:600;line-height:1.4}.stats span{font-size:13px;color:#62736c}.artifact-links{display:flex;gap:20px;font-size:13px;flex-wrap:wrap}.section-heading,.api-heading{display:flex;align-items:center;justify-content:space-between;gap:16px}.api-heading h3{margin:0}.section-heading span{font-size:13px;color:#62736c}.search-label{display:block;font-size:14px;margin:0 0 8px}input[type=search]{width:100%;padding:13px 16px;font:inherit;background:#fff;border:1px solid #becdc4;border-radius:6px;margin-bottom:20px;color:#21382f}input:focus,a:focus-visible,summary:focus-visible{outline:3px solid #2a8e79;outline-offset:3px}.api-card,.attempt{padding:24px;background:#fff;border:1px solid #d9e2da;border-radius:8px;margin:0 0 18px;overflow-wrap:anywhere}.badge{display:inline-block;padding:3px 9px;border:1px solid #d2dcd5;border-radius:4px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;color:#52625a;background:#f2f4f1;white-space:nowrap}.badge.evidence{color:#19594a;background:#e5f2e9;border-color:#b7d6c4}.badge.failed{color:#85492f;background:#f8efe8;border-color:#e5cbbb}code,pre{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:13px}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f0f3ef;border:1px solid #e1e7df;padding:14px 16px;border-radius:5px;line-height:1.7;max-height:480px;overflow:auto}dl{display:grid;grid-template-columns:140px minmax(0,1fr);gap:8px 14px;margin:16px 0}dt{color:#607269;font-size:13px}dd{margin:0;font-size:14px;overflow-wrap:anywhere}dd pre{margin:0}.comment{white-space:pre-wrap;font-size:15px;border-left:2px solid #d8e4da;padding-left:14px}.example-links{padding-left:20px}.example-links li{margin:8px 0}.table-wrap{overflow-x:auto;background:#fff;border:1px solid #d9e2da;border-radius:6px;margin:16px 0 24px}table{width:100%;border-collapse:collapse;text-align:left;font-size:14px}caption{text-align:left;padding:12px 16px;background:#eaf0ea;font-size:12px;color:#54695d}th,td{padding:12px 16px;border-bottom:1px solid #e2e9e1;vertical-align:top}thead th{font-weight:600;background:#f4f7f2}tbody th{font-weight:500}.matrix-entry{display:block;margin-bottom:8px;text-decoration:none}.matrix-entry small{display:block;color:#62736c;font-size:11px;margin-top:3px}details{background:#fff;border:1px solid #d9e2da;border-radius:5px;padding:12px 16px;margin:10px 0}summary{cursor:pointer;color:#365a4e;font-size:14px}details pre{margin-bottom:2px}.empty{padding:24px;border:1px dashed #bccdc1;color:#607269;background:#edf2eb;border-radius:6px}footer{padding:28px 24px;border-top:1px solid #d9e2da;text-align:center;color:#61746a;font-size:12px}[hidden]{display:none!important}@media(max-width:700px){.topbar{padding:14px 18px;gap:14px;flex-wrap:wrap}.topbar nav{order:3;flex-basis:100%;gap:16px;overflow:auto}.offline{margin-left:auto}main{padding:28px 18px}.api-card,.attempt{padding:18px}.api-heading{align-items:flex-start;flex-wrap:wrap}dl{grid-template-columns:1fr;gap:4px}dd{margin-bottom:10px}.stats{gap:26px}.metadata code{word-break:break-all}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}"
}
func rScript(): String {
    return "(function(){'use strict';var input=document.getElementById('api-search');var cards=Array.prototype.slice.call(document.querySelectorAll('#api-list .api-card'));var count=document.getElementById('search-count');var empty=document.getElementById('search-empty');function update(){var q=input.value.trim().toLocaleLowerCase();var visible=0;cards.forEach(function(card){var haystack=(card.dataset.name+' '+card.dataset.package).toLocaleLowerCase();card.hidden=haystack.indexOf(q)===-1;if(!card.hidden){visible++;}});count.textContent=visible+' / '+cards.length+' 个接口';empty.hidden=visible!==0||cards.length===0;}input.addEventListener('input',update);update();})();"
}
func rHtml(report: J): String {
    let project = rValue(rField(report, "project"), "name")
    var out = "<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>" + rEscape(project) + " · CJ-DocGuard</title><style>" + rStyles() + "</style></head><body><header class=\"topbar\"><a class=\"brand\" href=\"#overview\">CJ–DocGuard</a><nav aria-label=\"报告导航\"><a href=\"#api\">接口</a><a href=\"#matrix\">SDK 矩阵</a><a href=\"#evidence\">验证证据</a><a href=\"#diagnostics\">诊断</a></nav><span class=\"offline\">离线报告</span></header><main><section class=\"overview\" id=\"overview\"><p class=\"eyebrow\">DOCUMENTATION EVIDENCE / 文档验证证据</p><h1>" + rEscape(project) + "</h1><p class=\"lead\">接口、示例与仓颉 SDK 的验证记录。</p><aside class=\"snapshot\"><strong>冻结的静态快照</strong><p>生成时间：<time>" + rEscape(rValue(report, "generated_at")) + "</time>。本报告不能证明当前仓库状态。CURRENT 仅表示生成时记录的输入匹配情况；请重新运行检查后判断当前状态。</p></aside><dl class=\"metadata\"><dt>输入指纹</dt><dd><code>" + rEscape(rValue(rField(report, "manifest"), "fingerprint")) + "</code></dd><dt>引擎 / 数据版本</dt><dd>" + rEscape(rValue(report, "engine_version")) + " / " + rEscape(rValue(report, "schema_version")) + "</dd></dl><div class=\"stats\"><div><strong>" + rArray(rSymbols(report)).size.toString() + "</strong><span>接口符号</span></div><div><strong>" + rArray(rField(report, "results")).size.toString() + "</strong><span>尝试记录</span></div><div><strong>" + rArray(rField(report, "environments")).size.toString() + "</strong><span>工具链环境</span></div></div><div class=\"artifact-links\"><a href=\"../report.json\">完整 JSON</a><a href=\"../api.json\">接口 JSON</a><a href=\"../manifest.json\">输入清单</a><a href=\"../report.md\">Markdown 报告</a></div></section>"
    out += rDefinitions(report) + rMatrix(report) + rAttempts(report) + rLinks(report) + rSources(report) + rDiagnostics(report)
    return out + "</main><footer>由 CJ-DocGuard 原生生成 · 冻结快照 · 所有数据与资源均可离线阅读</footer><script>" + rScript() + "</script></body></html>"
}
func rMarkdown(report: J): String {
    var out = "# CJ-DocGuard · " + rMd(rValue(rField(report, "project"), "name")) + "\n\n> **冻结的静态快照**。生成时间：" + rMd(rValue(report, "generated_at")) + "。本报告不能证明当前仓库状态。CURRENT 仅表示生成时记录的输入匹配情况；当前状态需重新运行核验。\n\n"
    out += "引擎 / 数据版本：" + rMd(rValue(report, "engine_version")) + " / " + rMd(rValue(report, "schema_version")) + "。输入指纹：" + rMd(rValue(rField(report, "manifest"), "fingerprint")) + "。输入闭包完整：" + rMd(rValue(rField(report, "manifest"), "closure_complete")) + "。\n\n"
    out += "## 接口文档\n\n"
    for (symbol in rArray(rSymbols(report))) {
        out += "### " + rMd(rValue(symbol, "name")) + "\n\n包：" + rMd(rValue(symbol, "package")) + "；类型：" + rMd(rValue(symbol, "kind")) + "；状态：" + rMd(rValue(symbol, "status")) + "。\n\n"
        out += rPre(rValue(symbol, "declaration")) + "\n\n参数：" + rMd(rParameters(symbol)) + "。返回值：" + rMd(rValue(symbol, "returns")) + "。\n\n源码：" + rMd(rValue(symbol, "source")) + ":" + rMd(rValue(symbol, "line")) + "。符号ID：" + rMd(rValue(symbol, "id")) + "。\n\n注释：\n\n" + rPre(rValue(symbol, "comment")) + "\n\n关联示例：\n\n"
        var found = false
        for (result in rArray(rField(report, "results"))) {
            if (rSymbolMatch(symbol, result)) {
                found = true
                out += "- " + rMd(rValue(result, "example_id")) + " / SDK " + rMd(rValue(result, "sdk_version")) + " / " + rMd(rValue(result, "status")) + " / " + rMd(rValue(result, "freshness")) + "\n"
            }
        }
        if (!found) { out += "未提供与该接口关联的示例。\n" }
        out += "\n"
    }
    out += "## SDK 验证矩阵与状态\n\nSDK 是仓颉开发工具包。以下逐条列出冻结快照中的记录，不隐藏失败或未知项。\n\n| 示例 | SDK | 平台 | 状态 | 输入匹配 | 尝试 / 序号 | 原因 |\n|---|---|---|---|---|---|---|\n"
    for (result in rArray(rField(report, "results"))) {
        out += "| " + rMd(rValue(result, "example_id")) + " | " + rMd(rValue(result, "sdk_version")) + " | " + rMd(rValue(result, "platform")) + " | " + rMd(rValue(result, "status")) + " | " + rMd(rValue(result, "freshness")) + " | " + rMd(rValue(result, "attempt_id")) + " / " + rMd(rValue(result, "sequence")) + " | " + rMd(rValue(result, "reason")) + " |\n"
    }
    out += "\n状态计数（尝试记录）：\n\n" + rPre(rCounts(rField(report, "results")).dump()) + "\n\n引擎汇总：\n\n" + rPre(rValue(report, "summary")) + "\n\n工具链环境：\n\n" + rPre(rValue(report, "environments")) + "\n\n## 原始验证证据\n\n"
    for (result in rArray(rField(report, "results"))) { out += "### " + rMd(rValue(result, "example_id")) + "\n\n" + rPre(result.dump()) + "\n\n" }
    out += "## 文档链接检查\n\n| 来源 | 目标 | 状态 | 原因 |\n|---|---|---|---|\n"
    for (link in rArray(rField(report, "links"))) { out += "| " + rMd(rValue(link, "from")) + " | " + rMd(rValue(link, "target")) + " | " + rMd(rValue(link, "status")) + " | " + rMd(rValue(link, "reason")) + " |\n" }
    out += "\n## 诊断与检查范围\n\n未提供诊断不等于全部输入已检查。\n\n工程诊断：\n\n" + rPre(rValue(report, "diagnostics")) + "\n\n接口诊断：\n\n" + rPre(rValue(rField(report, "api"), "diagnostics")) + "\n\n接口文件：\n\n" + rPre(rValue(rField(report, "api"), "files")) + "\n\n输入清单：\n\n" + rPre(rValue(rField(report, "manifest"), "files")) + "\n"
    return out
}
public func writeReports(output: String, report: J): Unit {
    // Build all five artifacts in a private staging directory. A malformed tree
    // cannot replace a previously published report, and large JSON stays bounded.
    let stage = output + ".report-staging"
    if (exists(stage)) { throw Exception("Report staging directory already exists") }
    let parent = Path(stage).parent.toString()
    if (!exists(parent)) { Directory.create(parent, recursive: true) }
    // This create is exclusive; cleanup below only touches a stage we own.
    Directory.create(stage)
    try {
        Directory.create(stage + "/site")
        writeJsonFile(stage + "/report.json", report)
        writeJsonFile(stage + "/api.json", rField(report, "api"))
        writeJsonFile(stage + "/manifest.json", rField(report, "manifest"))
        File.writeTo(stage + "/report.md", rMarkdown(report).toArray())
        File.writeTo(stage + "/site/index.html", rHtml(report).toArray())
        if (!exists(output)) { Directory.create(output, recursive: true) }
        let site = output + "/site"
        if (!exists(site)) { Directory.create(site, recursive: true) }
        copy(stage + "/api.json", to: output + "/api.json", overwrite: true)
        copy(stage + "/report.json", to: output + "/report.json", overwrite: true)
        copy(stage + "/manifest.json", to: output + "/manifest.json", overwrite: true)
        copy(stage + "/report.md", to: output + "/report.md", overwrite: true)
        copy(stage + "/site/index.html", to: site + "/index.html", overwrite: true)
    } finally { removeIfExists(stage, recursive: true) }
}
