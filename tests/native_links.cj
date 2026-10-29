package docguard
import std.fs.*

var linkAssertions: Int64 = 0
func linkExpect(ok: Bool, label: String): Unit { linkAssertions++; if (!ok) { throw Exception("FAIL links: " + label) } }
func targetCount(rows: J, target: String): Int64 { var n: Int64 = 0; for (r in rows.items) { if (r.get("target").s() == target) { n++ } }; return n }
main(): Int64 {
    let temp = Directory.createTemp("/tmp").toString()
    try {
        writeText(join(temp,"lib.cj"), "package links\npublic func sample(): Unit {}\n")
        writeText(join(temp,"docguard.toml"), "[project]\nname=\"links\"\nsources=[\"lib.cj\"]\ndocuments=[\"README.md\"]\noutput=\".docguard\"\n[[sdks]]\nversion=\"1.1.3\"\n[[examples]]\nid=\"sample\"\nfile=\"lib.cj\"\n")
        writeText(join(temp,"a.md"), "# Same\n# Same\n# Same-1\n# Same\n# **中文** `API` &amp; More!\nSetext Heading\n---\n<a id='custom-anchor'></a>\n<a name=\"legacy\"></a>\n```md\n# hidden\n<a id='hidden-html'></a>\n```\n<!-- <a id='comment-id'></a> -->\n")
        writeText(join(temp,"space name(1).md"), "ok")
        writeText(join(temp,"a&b.md"), "ok")
        let project = Project(join(temp,"docguard.toml"))
        writeText(join(temp,"README.md"), "[full][REF]\n[collapsed][]\n[short]\n[REF]: a.md \"title\"\n[collapsed]: a.md\n[short]: a.md\n")
        var rows = checkLinks(project,J.obj().put("symbols",J.arr()),false)
        linkExpect(rows.items.size == 3 && targetCount(rows,"a.md") == 3,"full/collapsed/shortcut references and definitions not links")
        for (r in rows.items) { linkExpect(r.get("status").s()=="PASS" && number(r,"line",0)>0,"reference status/source line") }
        writeText(join(temp,"README.md"), "[nested [label]](space%20name(1).md \"optional title\")\n![img](<space name(1).md> 'image title')\n[escaped](space%20name\\(1\\).md)\n[entity](a&amp;b.md)\n<https://example.com>\n")
        rows = checkLinks(project,J.obj().put("symbols",J.arr()),false)
        linkExpect(rows.items.size==5,"titles, nested labels/destinations, images and autolinks")
        for (i in 0..4) { linkExpect(rows.items[i].get("status").s()=="PASS","local rich link " + i.toString() + ":" + rows.items[i].dump()) }
        linkExpect(rows.items[4].get("status").s()=="UNVERIFIED" && !rows.items[4].get("required").b(),"external autolink explicit offline")
        for (target in ["a.md#same","a.md#same-1","a.md#same-1-1","a.md#same-2","a.md#中文-api--more","a.md#setext-heading","a.md#custom-anchor","a.md#legacy","a.md?raw=1#same","a.md#%73ame","space%20name%281%29.md"]) {
            let r=linkCheck(project,"README.md",target,true)
            linkExpect(r.get("status").s()=="PASS","anchor/decoded target " + target + ":" + r.dump())
        }
        for (target in ["a.md#hidden","a.md#hidden-html","a.md#comment-id","missing.md","a.md#missing","%2e%2e/outside","a.md%00","a.md%ZZ","a.md%FF","javascript:alert(1)","data:text/plain,x","file:///tmp/a.md"]) {
            linkExpect(linkCheck(project,"README.md",target,true).get("status").s()=="FAIL","reject invalid or absent target " + target)
        }
        writeText(join(temp,"README.md"), "```md\n[x](missing-fence)\n```\n~~~\n[x](missing-tilde)\n~~~\n    [x](missing-indent)\n`[x](missing-code)`\n<!-- [x](missing-comment) -->\n\\[x](missing-escaped)\n[real](a.md)\n[ordinary text]\n")
        rows=checkLinks(project,J.obj().put("symbols",J.arr()),false)
        linkExpect(rows.items.size==1 && rows.items[0].get("status").s()=="PASS","exclude code/comments/escaped punctuation/plain brackets")
        writeText(join(temp,"README.md"), "[x][  mixed\t label ]\n[MiXeD label]:\n  a.md\n[MiXeD label]: missing.md\n")
        rows=checkLinks(project,J.obj().put("symbols",J.arr()),false)
        linkExpect(rows.items.size==1 && rows.items[0].get("status").s()=="PASS","first definition wins; whitespace/case normalized; next-line destination")
        let extra=markdownLinks("[x](a.md (title))\n[x](a.md?raw=1#same)\n[x](a&#38;b.md)\n[x](a.md \"title\\\" escaped\")\n[long](\n<a.md>\n)\n")
        linkExpect(extra.items.size==5,"parenthesized/escaped titles, numeric entity and multiline inline")
        for(r in extra.items){linkExpect(linkCheck(project,"README.md",r.get("target").s(),true).get("status").s()=="PASS","extra parsed local " + r.dump())}
        linkExpect(markdownLinks("[text](a.md invalid title)\n[text](<a.md)\n").items.size==0,"invalid inline syntax remains text")
        linkExpect(linkCheck(project,"README.md","a&unknown;.md",true).get("status").s()=="UNVERIFIED","unknown entities explicitly unverified")
        writeText(join(temp,"README.md"),"[unknown](a&unknown;.md)\n[external](HTTPS://example.com)\n")
        rows=checkLinks(project,J.obj().put("symbols",J.arr()),false)
        linkExpect(rows.items.size==2 && rows.items[0].get("status").s()=="UNVERIFIED" && !rows.items[1].get("required").b(),"unknown entity does not abort whole report and scheme is case insensitive")
        linkExpect(markdownLinks("> > [x](missing.md)\n").items.size==1,"nested quote links retained")
        linkExpect(markdownLinks("- item\n\n    [x](missing.md)\n").items.size==1,"list continuation links retained")
        linkExpect(markdownLinks("<!--\n```\n-->\n[x](missing.md)\n").items.size==1,"comment fence does not hide later link")
        linkExpect(markdownLinks("`\n[x]: missing.md\n`\n[x]\n").items.size==0,"multiline inline code cannot define references")
        for(code in ["\\<a id='ghost'>","<id='ghost'>","<a id='ghost>"]){linkExpect(!markdownAnchors(code).contains("ghost"),"fake HTML anchor rejected: " + code)}
        linkExpect(markdownAnchors("# valid\n# &copy;\n").contains("valid"),"unrelated unknown entity does not discard good anchor")
        linkExpect(markdownLinks("<a\tstyle=\"color:red\">hello</a>").items.size==0,"HTML attributes not autolinks")
        linkExpect(headingSlug("foo_bar")=="foo_bar","intra-word underscore kept")
        linkExpect(headingSlug("[Title][ref]")=="titleref","undefined reference heading is literal text")
        linkExpect(!markdownAnchors("`\n# ghost\n`\n").contains("ghost"),"multiline inline code cannot create heading")
        linkExpect(markdownAnchors("# `Code` heading\n").contains("code-heading"),"inline code in real heading remains displayed text")
        linkExpect(markdownAnchors("# [Title][ref]\n[ref]: a.md\n").contains("title"),"resolved reference heading uses display text")
        linkExpect(!markdownAnchors("# [Title][ref]\n").contains("title"),"unresolved reference cannot create shorter false anchor")
        linkExpect(markdownAnchors("# [Title][ref]\n").contains("titleref"),"unresolved reference correct literal heading anchor")
        writeText(join(temp,"UPPER.MD"),"# Upper\n")
        linkExpect(linkCheck(project,"README.md","UPPER.MD#upper",true).get("status").s()=="PASS","Markdown extension case insensitive")
        linkExpect(markdownAnchors("<p>中文</p><h2 id='真实'>标题</h2>",isMarkdown:false).contains("真实"),"HTML tag followed by Unicode has safe byte boundaries")
        let symbol=J.obj().put("id",J.str("s-test")).put("name",J.str("sample")).put("source",J.str("lib.cj")).put("declaration",J.str("public func sample(): Unit")).put("parameters",J.arr()).put("returns",J.str("Unit")).put("status",J.str("SUPPORTED"))
        let generatedApi=J.obj().put("symbols",J.arr().add(symbol)).put("files",J.arr()).put("diagnostics",J.arr())
        let generated=J.obj().put("api",generatedApi).put("manifest",J.obj().put("fingerprint",J.str("test")).put("files",J.arr())).put("project",J.obj().put("name",J.str("中文报告"))).put("environments",J.arr()).put("results",J.arr()).put("history",J.arr()).put("links",J.arr()).put("diagnostics",J.arr()).put("summary",J.obj())
        writeReports(project.output,generated)
        let indexRows=checkLinks(project,generatedApi,true)
        var indexOk=false
        for(row in indexRows.items){if(row.get("from").s()==".index"){indexOk=row.get("status").s()=="PASS"}}
        linkExpect(indexOk,"real generated report index anchors checked end to end")
        linkExpect(!markdownAnchors("[hidden](<a id=\"ghost\">)\n[probe](#ghost)\n").contains("ghost"),"destination HTML is not a real anchor")
        linkExpect(!markdownAnchors("[hidden](a.md \"<a id='ghost'>\")\n").contains("ghost"),"title HTML is not a real anchor")
        linkExpect(!markdownAnchors("[hidden]: <a id=\"ghost\">\n[hidden]\n").contains("ghost"),"reference-definition HTML is not a real anchor")
        linkExpect(markdownAnchors("[<span id='real'>visible</span>](a.md)\n").contains("real"),"real HTML in link label retains its anchor")
        let multiline="Title\nwith continuation\n---\n"
        linkExpect(markdownAnchors(multiline).contains("title-with-continuation"),"multiline Setext keeps whole paragraph")
        linkExpect(!markdownAnchors(multiline).contains("with-continuation"),"multiline Setext rejects truncated anchor")
        writeText(join(temp,"multi.md"),multiline)
        linkExpect(linkCheck(project,"README.md","multi.md#title-with-continuation",true).get("status").s()=="PASS","multiline Setext real link passes")
        linkExpect(linkCheck(project,"README.md","multi.md#with-continuation",true).get("status").s()=="FAIL","truncated Setext real link fails")
        for(text in ["First\n\nSecond\n---\n", "First\n***\nSecond\n---\n", "First\n- - -\nSecond\n---\n"]){
            let a=markdownAnchors(text);linkExpect(a.contains("second") && !a.contains("first-second"),"Setext paragraph boundaries")
        }
        linkExpect(markdownAnchors("---\n").size==0,"standalone thematic break not heading")
        linkExpect(!markdownAnchors("Title\n- - -\n").contains("title"),"spaced dashes thematic break not Setext")
        for(text in ["> Title\n> continuation\n> ---\n", "- Title\n  continuation\n  ---\n"]){linkExpect(markdownAnchors(text).contains("title-continuation"),"container multiline Setext")}
        linkExpect(markdownAnchors("> # Quoted\n- # Listed\n").contains("quoted") && markdownAnchors("> # Quoted\n- # Listed\n").contains("listed"),"container ATX headings")
        linkExpect(markdownAnchors("Title\ncontinuation\n---\nTitle\ncontinuation\n===\n").contains("title-continuation-1"),"duplicate multiline Setext numbering")
        for(text in ["```\nHidden\n---\n```\n", "    Hidden\n    ---\n", "`\nHidden\n---\n`\n"]){linkExpect(!markdownAnchors(text).contains("hidden"),"code cannot create Setext")}
        let html=htmlLinks("<!-- <a href='comment'> -->\n<A HREF=\"a&amp;b.md\">ok</A><link href='theme.css'><script src='app.js'>const fake=\"<a href='ghost'>\";</script>\n<style>a{content: '<img src=ghost>'}</style><img src='pic.png'><source src=movie.mp4><a href='#ok' href='#missing'><span data-x=\"<a href='fake'>\"></span>")
        linkExpect(html.items.size==7,"actual HTML href/src includes duplicates but excludes comments/raw bodies/quoted fake tags")
        linkExpect(html.items[0].get("target").s()=="a&amp;b.md" && number(html.items[0],"line",0)==2 && html.items[0].get("syntax").s()=="html-href","HTML encoded target spelling and source line")
        linkExpect(targetCount(html,"#ok")==1 && targetCount(html,"#missing")==1,"duplicate href never drops bad target")
        linkExpect(linkCheck(project,"README.md",html.items[0].get("target").s(),true).get("status").s()=="PASS","HTML quoted entity decoded by link qualification")
        linkExpect(htmlLinks("<script>fake </scriptx><a href='ghost'></script><a href='real'>").items.size==1,"raw-text closing tag must match full name")
        linkExpect(number(htmlLinks("<a\n href='a.md'><img\n src='pic.png'>").items[1],"line",0)==3,"multiline HTML attribute line")
        linkExpect(html.items[5].get("ambiguous").b() && html.items[6].get("ambiguous").b(),"both duplicate attributes explicitly ambiguous")
        linkExpect(!html.items[0].get("ambiguous").b(),"unique attribute unambiguous")
        linkExpect(markdownAnchors("- First\n- Second\n  ---\n").contains("second") && !markdownAnchors("- First\n- Second\n  ---\n").contains("first-second"),"new list item starts a fresh paragraph")
        linkExpect(markdownAnchors("> First\nSecond\n---\n").contains("second"),"explicit quote boundary starts a fresh paragraph")
        linkExpect(markdownAnchors("Title `code`\ncontinuation\n---\n").contains("title-code-continuation"),"single-line inline code contributes displayed heading text")
        linkExpect(htmlLinks("<a href='中文.md'><img src=图片.png>").items.size==2,"HTML Unicode targets preserve byte boundaries")
        let candidates=htmlLinks("<base href='assets/'><img srcset='small.png 1x, large.png 2x'>")
        linkExpect(candidates.items.size==2 && candidates.items[0].get("tag").s()=="base","HTML tag retained for base semantics")
        linkExpect(candidates.items[1].get("unsupported").b() && candidates.items[1].get("target").s()=="small.png 1x, large.png 2x" && candidates.items[1].get("syntax").s()=="html-srcset","srcset candidates exposed explicitly unsupported")
        println("PASS native links " + linkAssertions.toString() + " assertions")
        return 0
    } finally { removeIfExists(temp, recursive: true) }
}
