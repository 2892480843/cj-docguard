package docguard

import std.collection.*
import std.fs.*
import std.process.*
import std.sync.*
import std.time.*

func wbEnvironment(app: NativeWorkbench): HashMap<String,String> {
    let result=HashMap<String,String>()
    for (key in ["PATH","CANGJIE_HOME","DYLD_LIBRARY_PATH","LD_LIBRARY_PATH","SDKROOT","CJ_DOCGUARD_SYSTEM_SDKROOT","CJ_DOCGUARD_SDK_1_1_3","CJ_DOCGUARD_SDK_1_2_0"]) {
        let value=envValue(key); if (!value.isEmpty()) { result[key]=value }
    }
    // Full report generation retains archived records; the default runtime heap
    // is too small for long-lived workspaces. Keep the worker ceiling explicit.
    let heap=envValue("CJ_DOCGUARD_HEAP_SIZE")
    if (!heap.isEmpty() && !["256MB","512MB","1GB","2GB"].contains(heap)) {
        throw WbError("CJ_DOCGUARD_HEAP_SIZE must be 256MB, 512MB, 1GB or 2GB")
    }
    result["cjHeapSize"]=if (heap.isEmpty()) { "1GB" } else { heap }
    result["LANG"]="C"; result["LC_ALL"]="C"
    result["CJ_DOCGUARD_RUNNER"]=join(app.root,"build/cjdg-runner")
    return result
}
func wbLog(path: String, tail!: Bool = true): String {
    if (!exists(path)) { return "" }
    if (FileInfo(path).size>16777216) { throw WbError("native output exceeds 16 MiB") }
    let data=File.readFrom(path)
    var text=""
    // A live file can end midway through a UTF-8 sequence; wait for its next bytes.
    for (trim in 0..4) { if (trim>data.size) { break }; try { text=String.fromUtf8(data[..data.size-trim]); break } catch (_: Exception) {} }
    if (!tail || text.toArray().size<=262144) { return text }
    let bytes=text.toArray(); var begin=bytes.size-262144
    while (begin<bytes.size && (bytes[begin]&192)==128) { begin++ }
    return String.fromUtf8(bytes[begin..])
}
func wbRefreshLog(app: NativeWorkbench, job: J): Unit {
    let dir=join(app.state,"jobs/"+job.get("id").s())
    job.put("stdout",J.str(wbLog(join(dir,"stdout.log")))).put("stderr",J.str(wbLog(join(dir,"stderr.log"))))
}
func wbGetJob(app: NativeWorkbench, id: String): J {
    synchronized(app.mutex) {
        let job=app.jobs.get(id) ?? throw WbError("job not found",status:404)
        wbRefreshLog(app,job)
        return parseJson(job.dump())
    }
}
func wbListJobs(app: NativeWorkbench): J {
    synchronized(app.mutex) {
        let ordered=ArrayList<J>()
        for ((_,job) in app.jobs) {
            var at: Int64=0
            while (at<ordered.size && number(ordered[at],"sequence",0)<number(job,"sequence",0)) { at++ }
            ordered.add(job); var index=ordered.size-1
            while (index>at) { ordered[index]=ordered[index-1]; index-- }; ordered[at]=job
        }
        let out=J.arr()
        for (job in ordered) { wbRefreshLog(app,job); out.add(parseJson(job.dump())) }
        return out
    }
}
func wbArguments(app: NativeWorkbench, p: J, body: J): ArrayList<String> {
    let action=body.get("action").s()
    let argv=ArrayList<String>([join(app.root,"build/cj-docguard"),action,"--config",p.get("config").s()])
    if (action=="verify") { let sdk=text(body,"sdk",""); if (sdk.isEmpty()) { argv.add("--matrix") } else { argv.add("--sdk"); argv.add(sdk) } }
    if (action=="check") { argv.add("--strict") }
    if (action=="query") {
        let tool=text(body,"tool","list_symbols")
        if (!["list_symbols","get_verified_examples","get_evidence"].contains(tool)) { throw WbError("unsupported query tool") }
        argv.add("--tool"); argv.add(tool)
        let keys=if (tool=="list_symbols") { ["symbol"] } else { ["symbol","example","sdk","platform"] }
        if (tool!="list_symbols" && (text(body,"sdk","").isEmpty() || text(body,"platform","").isEmpty())) { throw WbError("exact SDK and platform required") }
        for (key in keys) { let value=text(body,key,""); if (!value.isEmpty()) { argv.add("--"+key); argv.add(value) } }
    }
    if (action=="export") { for (key in ["sdk","platform","example"]) { let value=text(body,key,""); if (value.isEmpty()) { throw WbError("export requires example, SDK and platform") }; argv.add("--"+key); argv.add(value) } }
    return argv
}
func wbStartJob(app: NativeWorkbench, p: J, body: J): J {
    let action=body.get("action").s()
    if (!["doctor","build","verify","check","query","export","demo_break","demo_restore"].contains(action)) { throw WbError("unsupported action") }
    for (key in ["sdk","tool","symbol","example","platform"]) { let value=v(body,key); if (value.kind!="null") { let s=value.s(); if (s.toArray().size>1024 || s.toArray().contains(0)) { throw WbError("invalid "+key) } } }
    if (action.startsWith("demo_") && !flag(p,"demo",false)) { throw WbError("fault injection is restricted to owned demo") }
    if (!action.startsWith("demo_")) { wbArguments(app,p,body) }
    let job=J.obj().put("id",J.str(wbId()[..32])).put("project_id",p.get("id")).put("action",J.str(action)).put("status",J.str("queued"))
        .put("started_at",J.nil()).put("finished_at",J.nil()).put("exit_code",J.nil()).put("stdout",J.str("")).put("stderr",J.str("")).put("result",J.nil())
    var queued=J.nil()
    synchronized(app.mutex) {
        app.idle(); job.put("sequence",J.num(app.jobs.size+1)); app.active=job.get("id").s(); app.jobs[app.active]=job; queued=parseJson(job.dump())
    }
    let frozenP=parseJson(p.dump()); let frozenB=parseJson(body.dump())
    spawn { wbRunJob(app,job,frozenP,frozenB) }
    return queued
}
func wbRunJob(app: NativeWorkbench, job: J, p: J, body: J): Unit {
    let id=job.get("id").s(); let action=job.get("action").s(); let logDir=join(app.state,"jobs/"+id)
    try {
        mkdir(logDir)
        synchronized(app.mutex) { job.put("status",J.str("running")).put("started_at",J.str(nowText())) }
        if (action.startsWith("demo_")) {
            let owned=canonicalize(join(app.state,"projects/demo")).toString()
            if (p.get("root").s()!=owned) { throw WbError("not owned demo") }
            if (action=="demo_break") { let pristine=readText(join(app.root,"examples/healthy/programs/arithmetic.cj")); wbAtomic(resolved(owned,"programs/arithmetic.cj"),pristine.replace("add(20, 22)","subtract(20, 22)")) }
            else { wbCopyTree(join(app.root,"examples/healthy"),owned) }
            synchronized(app.mutex) { job.put("exit_code",J.num(0)).put("result",J.obj().put("snapshot_invalidated",J.boolean(true))) }
        } else {
            let argv=wbArguments(app,p,body)
            let artifact=join(app.state,"artifacts/"+id); let nativeOut=join(artifact,"native")
            if (action=="export") { mkdir(nativeOut); argv.add("--out"); argv.add(nativeOut) }
            let runner=join(app.root,"build/cjdg-runner")
            let runnerArgs=ArrayList<String>([app.timeoutMs.toString(),"16777216",p.get("root").s(),join(logDir,"stdout.log"),join(logDir,"stderr.log"),join(logDir,"result.json"),"--"])
            for (arg in argv) { runnerArgs.add(arg) }
            let process=launch(runner,runnerArgs.toArray(),workingDirectory:Path(app.root),environment:wbEnvironment(app),stdIn:ProcessRedirect.Discard,stdOut:ProcessRedirect.Pipe,stdErr:ProcessRedirect.Pipe)
            synchronized(app.mutex) {
                app.processes[id]=process
                if (flag(job,"cancel_requested",false)) { try { process.terminate() } catch (_: Exception) {} }
            }
            let (supervisorExit,_,supervisorError)=process.waitOutput()
            if (supervisorExit!=0 || !exists(join(logDir,"result.json"))) { throw WbError("resource supervisor failed: "+String.fromUtf8(supervisorError)) }
            let control=parseJson(readText(join(logDir,"result.json")))
            let exitCode=control.get("exit_code").i()
            if (flag(control,"timed_out",false)) { throw WbError("native operation timed out") }
            if (flag(control,"truncated",false) || flag(control,"io_error",false)) { throw WbError("native output exceeded limit or log I/O failed") }
            let raw=wbLog(join(logDir,"stdout.log"),tail:false)
            var result=J.nil()
            try { result=parseJson(raw) } catch (_: Exception) { if (action=="query" && exitCode==0) { throw WbError("native query returned invalid JSON") } }
            synchronized(app.mutex) { job.put("exit_code",J.num(exitCode)).put("result",result); wbRefreshLog(app,job) }
            if (action=="export" && exitCode==0) {
                var cancelled=false
                synchronized(app.mutex) { cancelled=flag(job,"cancel_requested",false) }
                if (!cancelled) {
                    let zipDir=join(logDir,"zip"); mkdir(zipDir)
                    let zipArgs=["60000","1048576",nativeOut,join(zipDir,"stdout.log"),join(zipDir,"stderr.log"),join(zipDir,"result.json"),"--","/usr/bin/zip","-q","-r",join(artifact,"export.zip"),"."]
                    let zipper=launch(runner,zipArgs,workingDirectory:Path(app.root),environment:wbEnvironment(app),stdIn:ProcessRedirect.Discard,stdOut:ProcessRedirect.Pipe,stdErr:ProcessRedirect.Pipe)
                    synchronized(app.mutex) { app.processes[id]=zipper; job.put("phase",J.str("packaging")); if (flag(job,"cancel_requested",false)) { try { zipper.terminate() } catch (_: Exception) {} } }
                    let (zipExit,_,_)=zipper.waitOutput()
                    if (zipExit!=0 || !exists(join(zipDir,"result.json"))) { throw WbError("export packaging supervisor failed") }
                    let zipped=parseJson(readText(join(zipDir,"result.json")))
                    if (zipped.get("exit_code").i()!=0 || flag(zipped,"timed_out",false) || flag(zipped,"truncated",false) || flag(zipped,"io_error",false)) { throw WbError("export packaging failed: "+wbLog(join(zipDir,"stderr.log"))) }
                    synchronized(app.mutex) { job.put("artifact_url",J.str("/api/artifacts/"+id)) }
                }
            }
        }
        synchronized(app.mutex) { job.put("status",J.str(if (flag(job,"cancel_requested",false)) { "cancelled" } else if (v(job,"exit_code").kind=="number" && job.get("exit_code").i()==0) { "succeeded" } else { "failed" })) }
    } catch(e: Exception) {
        synchronized(app.mutex) { job.put("status",J.str(if (flag(job,"cancel_requested",false)) { "cancelled" } else { "failed" })).put("error",J.str(e.message)) }
    } finally {
        synchronized(app.mutex) { job.put("finished_at",J.str(nowText())); app.processes.remove(id); app.active="" }
    }
}
func wbCancel(app: NativeWorkbench, id: String): J {
    synchronized(app.mutex) {
        let job=app.jobs.get(id) ?? throw WbError("job not found",status:404)
        if (["queued","running"].contains(text(job,"status",""))) {
            job.put("cancel_requested",J.boolean(true))
            if (let Some(process) <- app.processes.get(id)) { try { process.terminate() } catch (_: Exception) {} }
        }
    }
    return wbGetJob(app,id)
}
func wbShutdown(app: NativeWorkbench): Unit {
    var active=""
    synchronized(app.mutex) { app.closing=true; active=app.active }
    if (active=="initializing") {
        synchronized(app.mutex) { if (let Some(process) <- app.processes.get(active)) { try { process.terminate() } catch (_: Exception) {} } }
    } else if (!active.isEmpty()) { wbCancel(app,active) }
    for (_ in 0..140) {
        synchronized(app.mutex) { if (app.active.isEmpty()) { return } }
        sleep(Duration.millisecond*50)
    }
    synchronized(app.mutex) { for ((_,process) in app.processes) { try { process.terminate(force:true) } catch (_: Exception) {} } }
    for (_ in 0..40) { synchronized(app.mutex) { if (app.active.isEmpty()) { return } }; sleep(Duration.millisecond*50) }
}
func wbInitialize(app: NativeWorkbench, body: J): J {
    let directory=body.get("directory").s(); let name=body.get("name").s()
    if (!Path(directory).isAbsolute() || exists(directory) || name.trimAscii().isEmpty()) { throw WbError("absolute nonexistent directory and name required") }
    synchronized(app.mutex) { app.idle(); app.active="initializing" }
    try {
        mkdir(directory)
        let logDir=join(app.state,"initializations/"+wbId()); mkdir(logDir)
        let arguments=["30000","1048576",app.root,join(logDir,"stdout.log"),join(logDir,"stderr.log"),join(logDir,"result.json"),"--",join(app.root,"build/cj-docguard"),"init","--project",directory]
        let process=launch(join(app.root,"build/cjdg-runner"),arguments,workingDirectory:Path(app.root),environment:wbEnvironment(app),stdIn:ProcessRedirect.Discard,stdOut:ProcessRedirect.Pipe,stdErr:ProcessRedirect.Pipe)
        synchronized(app.mutex) { app.processes["initializing"]=process; if (app.closing) { try { process.terminate() } catch (_: Exception) {} } }
        let (code,_,_)=process.waitOutput()
        if (code!=0 || !exists(join(logDir,"result.json"))) { throw WbError("initialization supervisor failed") }
        let result=parseJson(readText(join(logDir,"result.json")))
        if (result.get("exit_code").i()!=0 || flag(result,"interrupted",false) || flag(result,"timed_out",false) || flag(result,"truncated",false) || flag(result,"io_error",false)) { throw WbError("initialization failed: "+wbLog(join(logDir,"stdout.log"))+wbLog(join(logDir,"stderr.log"))) }
        let path=join(directory,"docguard.toml"); let content=readText(path).replace("name = \"my-cangjie-project\"","name = "+J.str(name).dump())
        wbAtomic(path,content)
        return app.register(path)
    } finally { synchronized(app.mutex) { app.processes.remove("initializing"); app.active="" } }
}
