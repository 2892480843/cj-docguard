package docguard
import std.fs.*

var indexAssertions: Int64 = 0
func indexExpect(ok: Bool, label: String): Unit { indexAssertions++; if (!ok) { throw Exception("FAIL index: " + label) } }
func indexRow(rows: J, target: String): J { for(row in rows.items){if(row.get("target").s()==target && text(row,"syntax","").startsWith("html-")){return row}};return J.nil() }
main(): Int64 {
    let root=Directory.createTemp("/tmp").toString()
    try {
        writeText(join(root,"lib.cj"),"package audit\npublic func sample(): Unit {}\n")
        writeText(join(root,"docguard.toml"),"[project]\nname=\"index\"\nsources=[\"lib.cj\"]\ndocuments=[]\n[[sdks]]\nversion=\"1.1.3\"\n[[examples]]\nid=\"sample\"\nfile=\"lib.cj\"\nsymbol=\"sample\"\n")
        let project=Project(join(root,"docguard.toml"));let site=join(project.output,"site/index.html")
        let api=J.obj().put("symbols",J.arr().add(J.obj().put("id",J.str("s-good"))))
        writeText(site,"<article id='s-good'></article><a href='#missing-api'>broken</a><a href='missing.json'>broken</a>")
        var rows=checkLinks(project,api,true)
        indexExpect(indexRow(rows,"#missing-api").kind!="null" && indexRow(rows,"#missing-api").get("status").s()=="FAIL","actual missing index fragment must be enumerated")
        indexExpect(indexRow(rows,"missing.json").get("status").s()=="FAIL","actual missing index file must be enumerated")
        writeText(join(project.output,"report.json"),"{}")
        writeText(join(project.output,"site/scripts/app.js"),"// asset")
        writeText(join(project.output,"site/assets/a b.svg"),"<svg/>")
        writeText(site,"<article id='s-good'></article><a href='../report.json'>report</a><a href='?raw=1#s-good'>local</a><img src='assets/a%20b.svg'><script src='scripts/app.js'>const x=\"<a href='fake'>\";</script><!-- <a href='comment'> -->")
        rows=checkLinks(project,api,true)
        for(target in ["../report.json","?raw=1#s-good","assets/a%20b.svg","scripts/app.js"]){let r=indexRow(rows,target);indexExpect(r.get("status").s()=="PASS" && r.get("from").s()==".docguard/site/index.html","actual index URL resolves from HTML file: "+target)}
        indexExpect(indexRow(rows,"fake").kind=="null" && indexRow(rows,"comment").kind=="null","raw bodies/comments not scanned")
        writeText(site,"<a href='#s-good'>missing expected ID</a>")
        rows=checkLinks(project,api,true)
        var expectedFailed=false;for(row in rows.items){if(text(row,"syntax","")=="index" && row.get("status").s()=="FAIL"){expectedFailed=true}}
        indexExpect(expectedFailed,"expected API anchor checks remain")
        writeText(site,"<article id='s-good'></article><a href='#s-good' href='#s-good'>ambiguous</a>")
        rows=checkLinks(project,api,true)
        indexExpect(indexRow(rows,"#s-good").get("status").s()=="UNVERIFIED" && indexRow(rows,"#s-good").get("required").b(),"duplicate URL attrs cannot count as pass")
        writeText(site,"<base href='https://example.com/'><article id='s-good'></article><a href='#s-good'>base changes context</a>")
        rows=checkLinks(project,api,true)
        indexExpect(indexRow(rows,"#s-good").get("status").s()=="UNVERIFIED" && indexRow(rows,"#s-good").get("required").b(),"unsupported base context cannot count as pass")
        writeText(site,"<article id='s-good'></article><img srcset='a.png 1x, b.png 2x'>")
        rows=checkLinks(project,api,true)
        indexExpect(indexRow(rows,"a.png 1x, b.png 2x").get("status").s()=="UNVERIFIED","unsupported srcset is explicitly recorded")
        writeText(site,"<article id='s-good'></article><script src='javascript:alert(1)'></script><a href='https://example.com'>remote</a>")
        rows=checkLinks(project,api,true)
        indexExpect(indexRow(rows,"javascript:alert(1)").get("status").s()=="FAIL","unsafe resource scheme rejected")
        indexExpect(indexRow(rows,"https://example.com").get("status").s()=="UNVERIFIED" && !indexRow(rows,"https://example.com").get("required").b(),"external URL remains optional offline unknown")
        println("PASS native index " + indexAssertions.toString() + " assertions");return 0
    } finally {removeIfExists(root,recursive:true)}
}
