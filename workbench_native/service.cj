package docguard

import std.collection.*
import std.fs.*
import std.sync.*
import std.process.*

class NativeWorkbench {
    let root: String
    let state: String
    let timeoutMs: Int64
    let token: String
    let mutex = Mutex()
    let projects = HashMap<String,J>()
    let jobs = HashMap<String,J>()
    let processes = HashMap<String,SubProcess>()
    var active = ""
    var closing = false
    init(root: String, state: String, timeoutMs: Int64) {
        this.root=canonicalize(root).toString(); mkdir(state); this.state=canonicalize(state).toString()
        this.timeoutMs=timeoutMs; token=wbId()
        let registry=join(this.state,"projects.json")
        if (exists(registry)) { for (p in parseJson(readText(registry)).items) { projects[p.get("id").s()]=p } }
        let demo=join(this.state,"projects/demo")
        if (!exists(demo)) { wbCopyTree(join(this.root,"examples/healthy"),demo) }
        register(join(demo,"docguard.toml"),demo: true)
    }
    func project(id: String): J { synchronized(mutex) { return projects.get(id) ?? throw WbError("project not found",status:404) } }
    func record(p: J): J {
        let result=parseJson(p.dump())
        try { let c=parseToml(readText(p.get("config").s())); let versions=J.arr(); for (sdk in array(c,"sdks").items) { versions.add(v(sdk,"version")) }
            result.put("name",J.str(text(v(c,"project"),"name",Path(p.get("root").s()).fileName))).put("sdk_versions",versions).put("trusted",J.boolean(flag(v(c,"project"),"trusted",false)))
        } catch (e: Exception) { result.put("error",J.str(e.message)).put("trusted",J.boolean(false)).put("sdk_versions",J.arr()) }
        return result
    }
    func persist(): Unit { let all=J.arr(); for ((_,p) in projects) { all.add(p) }; wbAtomic(join(state,"projects.json"),all.dump()) }
    func register(config: String, demo!: Bool = false, requireIdle!: Bool = false): J {
        if (!Path(config).isAbsolute() || !config.endsWith(".toml") || !exists(config) || !FileInfo(config).isRegular()) { throw WbError("existing absolute TOML path required") }
        let path=canonicalize(config).toString(); Project(path)
        synchronized(mutex) {
        if (requireIdle) { idle() }
        for ((_,p) in projects) { if (text(p,"config","")==path) { return record(p) } }
        let id=wbId()[0..32]; let p=J.obj().put("id",J.str(id)).put("config",J.str(path)).put("root",J.str(Path(path).parent.toString())).put("demo",J.boolean(demo))
        projects[id]=p; persist(); return record(p)
        }
    }
    func idle(): Unit { if (closing) { throw WbError("service is shutting down",status:409) }; if (!active.isEmpty()) { throw WbError("native operation already running",status:409) } }
    func report(id: String): J {
        let p=project(id); let c=parseToml(readText(p.get("config").s())); let target=resolved(p.get("root").s(),join(text(v(c,"project"),"output",".docguard"),"report.json"))
        let result=J.obj().put("report",J.nil()).put("snapshot",J.boolean(true)).put("config",c)
        if (exists(target)) { try { let r=parseJson(readText(target)); if (r.kind!="object") { throw WbError("report must be a JSON object") }; result.put("report",r) } catch(e: Exception) { result.put("error",J.str(e.message)) } }
        return result
    }
    func sourcePath(p: J, relative: String): String {
        let projectRoot=p.get("root").s()
        let target=resolved(projectRoot,relative)
        // Check both the supplied name and canonical destination, so aliases cannot
        // expose private directories through an otherwise registered source tree.
        for (path in [relative,if (target==projectRoot) { "" } else { target[projectRoot.size+1..] }]) {
            for (part in path.split("/")) {
                if ([".git",".docguard","target"].contains(part) || part.startsWith(".env")) {
                    throw WbError("private source path is unavailable",status:403)
                }
            }
        }
        if (!exists(target) || !FileInfo(target).isRegular()) { throw WbError("source not found",status:404) }
        let config=parseToml(readText(p.get("config").s())); let pr=v(config,"project")
        let output=resolved(projectRoot,text(pr,"output",".docguard"))
        if (inside(target,output)) { throw WbError("generated output is unavailable as source",status:403) }
        for (excluded in array(pr,"exclude").items) {
            if (inside(target,resolved(projectRoot,excluded.s()))) { throw WbError("excluded source is unavailable",status:403) }
        }
        var allowed=target==p.get("config").s()
        for (item in array(pr,"sources").items) {
            let base=resolved(projectRoot,item.s())
            if (target.endsWith(".cj") && (target==base ||
                (exists(base) && FileInfo(base).isDirectory() && inside(target,base)))) { allowed=true }
        }
        // Non-Cangjie files must be individually registered, never inherited
        // merely because they share a directory with source or documentation.
        for (item in array(pr,"documents").items) {
            if (target==resolved(projectRoot,item.s())) { allowed=true }
        }
        for (item in array(config,"examples").items) {
            for (key in ["file","wrapper"]) {
                let value=text(item,key,"")
                if (!value.isEmpty() && target==resolved(projectRoot,value)) { allowed=true }
            }
        }
        if (!allowed) { throw WbError("path is not registered source",status:403) }
        if (FileInfo(target).size>524288) { throw WbError("source exceeds 512 KiB") }
        return target
    }
    func reply(data: J): WbResponse { WbResponse(200,data.dump().toArray(),"application/json; charset=utf-8") }
    func replyArchive(data: J): WbResponse {
        // History grows independently of active clients. Streaming serialization
        // avoids ArrayList growth plus full String/Byte copies of the response.
        let parent = join(state, "responses"); mkdir(parent)
        let directory = Directory.createTemp(parent).toString()
        try {
            writeJsonFile(join(directory, "response.json"), data)
            let response = WbResponse(200, Array<Byte>(0, repeat: 0), "application/json; charset=utf-8")
            response.spoolDirectory = directory
            return response
        } catch (e: Exception) {
            removeIfExists(directory, recursive: true)
            throw e
        }
    }
    func handle(request: WbRequest): WbResponse {
        try { return dispatch(request) } catch(e: WbError) { return WbResponse(e.status,J.obj().put("error",J.str(e.message)).dump().toArray(),"application/json; charset=utf-8") } catch(e: Exception) { return WbResponse(400,J.obj().put("error",J.str(e.message)).dump().toArray(),"application/json; charset=utf-8") }
    }
    func dispatch(r: WbRequest): WbResponse {
        let post=r.method=="POST"; if (r.method!="GET" && !post) { throw WbError("method not allowed",status:405) }
        var body=J.obj()
        if (post) {
            let host=r.headers.get("host") ?? ""
            if ((r.headers.get("origin") ?? "")!="http://"+host) { throw WbError("same-origin request required",status:403) }
            if (!wbTokenEqual(r.headers.get("x-docguard-token") ?? "",token)) { throw WbError("invalid session token",status:403) }
            body=parseJson(r.body); if (body.kind!="object") { throw WbError("JSON object required") }
        }
        let queryParts=r.target.split("?"); let path=wbDecode(queryParts[0]); let parts=path.split("/")
        if (path=="/api/bootstrap" && !post) {
            let all=J.arr(); var activeSnapshot=J.nil(); synchronized(mutex) { for ((_,p) in projects) { all.add(record(p)) }; if (let Some(job) <- jobs.get(active)) { activeSnapshot=parseJson(job.dump()) } }
            let actions=J.arr(); for (s in ["build","check","demo_break","demo_restore","doctor","export","query","verify"]) { actions.add(J.str(s)) }
            return reply(J.obj().put("token",J.str(token)).put("implementation",J.str("Cangjie")).put("projects",all).put("platform",J.str(wbPlatform())).put("active_job",activeSnapshot).put("capabilities",J.obj().put("actions",actions).put("native_server",J.boolean(true)).put("lock_recovery",J.boolean(true)).put("native_available",J.boolean(exists(join(root,"build/cj-docguard")))).put("snapshot",J.boolean(true))))
        }
        if (path=="/api/projects" && post) { return reply(register(body.get("config").s(),requireIdle:true)) }
        if (path=="/api/projects/init" && post) { return reply(wbInitialize(this,body)) }
        if (parts.size==5 && parts[1]=="api" && parts[2]=="projects") {
            let id=parts[3]; let op=parts[4]; let p=project(id)
            if (op=="report" && !post) { return replyArchive(report(id)) }
            if (op=="lock" && !post) { synchronized(mutex) { return reply(wbLockInfo(p)) } }
            if (op=="recover-lock" && post) {
                if (!flag(body,"acknowledge",false)) { throw WbError("acknowledge:true is required") }
                synchronized(mutex) { idle(); return reply(wbRecoverLock(p)) }
            }
            if (op=="history" && !post) { let items=array(v(report(id),"report"),"history"); for (item in items.items) { item.put("freshness",J.str("FROZEN")).put("eligible",J.boolean(false)) }; return replyArchive(J.obj().put("items",items).put("scope",J.str("FROZEN_ARCHIVE_NOT_CURRENT"))) }
            if (op=="config") { if (post) { synchronized(mutex) { idle(); let content=body.get("content").s(); wbValidateConfig(p.get("config").s(),content); wbAtomic(p.get("config").s(),content); return reply(record(p)) } }; return reply(J.obj().put("content",J.str(readText(p.get("config").s())))) }
            if (op=="jobs" && post) { return reply(wbStartJob(this,p,body)) }
            if (op=="compare" && post) { return reply(wbCompare(body.get("old"),body.get("new"))) }
            if (op=="source") {
                var relative=""
                if (post) { relative=body.get("path").s() } else if (queryParts.size>1) { for (pair in queryParts[1].split("&")) { let kv=pair.split("="); if (kv.size==2 && kv[0]=="path") { relative=wbDecode(kv[1]) } } }
                let file=sourcePath(p,relative)
                if (post) { synchronized(mutex) { idle(); sourcePath(p,relative); let content=body.get("content").s(); if (content.toArray().size>524288) { throw WbError("source exceeds 512 KiB") }; let expected=text(body,"expected_sha256",""); if (expected.isEmpty()) { throw WbError("expected_sha256 required") }; if (expected!=sha256File(file)) { throw WbError("source changed; reload before saving",status:409) }; if (file==p.get("config").s()) { wbValidateConfig(file,content) }; wbAtomic(file,content) } }
                let contents=readText(file)
                return reply(J.obj().put("path",J.str(relative)).put("content",J.str(contents)).put("sha256",J.str(sha256(contents.toArray()))).put("editable",J.boolean(true)))
            }
        }
        if (path=="/api/jobs" && !post) { return reply(J.obj().put("items",wbListJobs(this))) }
        if (parts.size>=4 && parts[1]=="api" && parts[2]=="jobs") { if (parts.size==4 && !post) { return reply(wbGetJob(this,parts[3])) }; if (parts.size==5 && parts[4]=="cancel" && post) { return reply(wbCancel(this,parts[3])) } }
        if (parts.size==4 && parts[1]=="api" && parts[2]=="artifacts" && !post) { let job=wbGetJob(this,parts[3]); if (text(job,"status","")!="succeeded" || text(job,"artifact_url","").isEmpty()) { throw WbError("artifact not available",status:404) }; let response=WbResponse(200,File.readFrom(resolved(state,"artifacts/"+parts[3]+"/export.zip")),"application/zip"); response.download=true; return response }
        if (!post && !path.startsWith("/api/")) { let web=canonicalize(join(root,"web")).toString(); let file=resolved(web,if (path=="/") { "index.html" } else { path[1..] }); if (!exists(file) || !FileInfo(file).isRegular()) { throw WbError("not found",status:404) }; let kind=if (file.endsWith(".html")) { "text/html; charset=utf-8" } else if (file.endsWith(".js")) { "text/javascript; charset=utf-8" } else if (file.endsWith(".css")) { "text/css; charset=utf-8" } else { "application/octet-stream" }; return WbResponse(200,File.readFrom(file),kind) }
        throw WbError("not found",status:404)
    }
    func shutdown(): Unit { wbShutdown(this) }
}
