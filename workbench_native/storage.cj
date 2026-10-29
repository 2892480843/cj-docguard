package docguard

import std.fs.*
import std.collection.*
import std.process.*

class WbError <: Exception {
    let status: Int64
    init(message: String, status!: Int64 = 400) { super(message); this.status = status }
}
func wbId(): String {
    let file = File("/dev/urandom", OpenMode.Read)
    let bytes = Array<Byte>(32, repeat: 0)
    try { var n: Int64 = 0; while (n < 32) {
        let part = Array<Byte>(32 - n, repeat: 0)
        let count = file.read(part)
        if (count == 0) { throw Exception("secure random source unavailable") }
        for (i in 0..count) { bytes[n+i] = part[i] }; n += count
    } } finally { file.close() }
    let hex = "0123456789abcdef".toArray(); let out = ArrayList<Byte>()
    for (b in bytes) { out.add(hex[Int64(b >> 4)]); out.add(hex[Int64(b & 15)]) }
    return String.fromUtf8(out.toArray())
}
func wbAtomic(path: String, content: String): Unit {
    let tmp = path + "." + wbId() + ".tmp"
    writeText(tmp, content)
    try { rename(tmp, to: path, overwrite: true) } finally { if (exists(tmp)) { remove(tmp) } }
}
func wbCopyTree(source: String, target: String): Unit {
    mkdir(target)
    Directory.walk(source, { entry =>
        let path = entry.path.toString()
        let rel = path[source.size + 1..]
        if (rel == ".docguard" || rel.startsWith(".docguard/")) { return true }
        if (FileInfo(path).isSymbolicLink()) { throw WbError("symbolic link in demo") }
        if (FileInfo(path).isDirectory()) { wbCopyTree(path,resolved(target, rel)) }
        else if (FileInfo(path).isRegular()) { let dest = resolved(target, rel); mkdir(Path(dest).parent.toString()); File.writeTo(dest, File.readFrom(path)) }
        return true
    })
}
func wbDecode(raw: String): String {
    let input = raw.toArray(); let out = ArrayList<Byte>(); var i: Int64 = 0
    while (i < input.size) {
        if (input[i] == 37) {
            if (i + 2 >= input.size) { throw WbError("invalid URL escape") }
            var value: Int64 = 0
            for (p in [i+1,i+2]) { let b = input[p]; let n = if (b>=48 && b<=57) { Int64(b-48) } else if (b>=65 && b<=70) { Int64(b-55) } else if (b>=97 && b<=102) { Int64(b-87) } else { -1 }; if (n < 0) { throw WbError("invalid URL escape") }; value=value*16+n }
            if (value == 0) { throw WbError("NUL in URL") }; out.add(UInt8(value)); i+=3
        } else { out.add(input[i]); i++ }
    }
    return String.fromUtf8(out.toArray())
}
func wbCompare(old: J, newer: J): J {
    if (old.kind != "object" || newer.kind != "object") { throw WbError("old and new report objects required") }
    let left = HashMap<String,J>(); let right = HashMap<String,J>()
    for ((report, table) in [(old,left),(newer,right)]) { for (item in array(report,"results").items) {
        if (item.kind != "object") { throw WbError("report results must be objects") }
        table[J.arr().add(v(item,"example_id")).add(v(item,"sdk_version")).add(v(item,"platform")).dump()] = item
    } }
    let keys = HashSet<String>(); for ((k,_) in left) { keys.add(k) }; for ((k,_) in right) { keys.add(k) }
    let changes = J.arr()
    for (key in keys) { let before=left.get(key) ?? J.nil(); let after=right.get(key) ?? J.nil(); if (before.dump()!=after.dump()) {
        let bits=parseJson(key).items; changes.add(J.obj().put("example_id",bits[0]).put("sdk_version",bits[1]).put("platform",bits[2]).put("before",before).put("after",after))
    } }
    let ls=HashMap<String,J>(); let rs=HashMap<String,J>()
    for ((report,table) in [(old,ls),(newer,rs)]) { for (item in array(v(report,"api"),"symbols").items) { if (item.kind!="object") { throw WbError("symbols must be objects") }; table[v(item,"id").dump()]=item } }
    let added=J.arr(); let removed=J.arr(); for ((k,item) in rs) { if (!ls.contains(k)) { added.add(item) } }; for ((k,item) in ls) { if (!rs.contains(k)) { removed.add(item) } }
    let om=v(old,"manifest"); let nm=v(newer,"manifest")
    if ((om.kind!="object" && om.kind!="null") || (nm.kind!="object" && nm.kind!="null")) { throw WbError("manifest must be object") }
    return J.obj().put("scope",J.str("SUPPLIED_SNAPSHOTS_ONLY")).put("changes",changes).put("old_summary",v(old,"summary")).put("new_summary",v(newer,"summary")).put("symbols_added",added).put("symbols_removed",removed).put("old_fingerprint",v(om,"fingerprint")).put("new_fingerprint",v(nm,"fingerprint")).put("inputs_changed",J.boolean(v(om,"fingerprint").dump()!=v(nm,"fingerprint").dump()))
}
func wbPlatform(): String {
    let p=launch("/usr/bin/uname",["-sm"],stdIn:ProcessRedirect.Discard,stdOut:ProcessRedirect.Pipe,stdErr:ProcessRedirect.Pipe)
    let (code,out,_) = p.waitOutput()
    if (code!=0) { return "unknown" }
    return String.fromUtf8(out).trimAscii().replace(" ","-")
}
func wbValidateConfig(path: String, content: String): Unit {
    parseToml(content)
    let temporary=Path(path).parent.toString()+"/.docguard-config-"+wbId()+".toml"
    try { writeText(temporary,content); Project(temporary) } finally { if (exists(temporary)) { remove(temporary) } }
}
func wbTokenEqual(a: String,b: String): Bool {
    let aa=a.toArray(); let bb=b.toArray(); if (aa.size!=bb.size) { return false }
    var mismatch: UInt8=0
    for (i in 0..aa.size) { mismatch=mismatch | (aa[i] ^ bb[i]) }
    return mismatch==0
}

func wbLockPath(p: J): String {
    let configPath=p.get("config").s()
    let root=p.get("root").s()
    let config=parseToml(readText(configPath))
    let output=text(v(config,"project"),"output",".docguard")
    if (Path(output).isAbsolute()) { throw WbError("lock output must remain inside the project",status:409) }
    let path=join(join(root,output),"writer.lock")
    if (!inside(path,root)) { throw WbError("lock output must remain inside the project",status:409) }
    // Preserve the configured lexical path until every ancestor has been
    // inspected: Project resolves existing paths and would erase symlink names.
    var current=root
    let relative=path[root.size+1..]
    for (part in relative.split("/")) {
        current=join(current,part)
        if (exists(current) && FileInfo(current).isSymbolicLink()) { throw WbError("symbolic links are not allowed in the lock path",status:409) }
    }
    Project(configPath)
    return resolved(root,relative)
}
func wbLockInfo(p: J): J {
    let result=J.obj().put("exists",J.boolean(false)).put("recoverable",J.boolean(false)).put("reason",J.str("no writer lock"))
    let path=wbLockPath(p)
    if (!exists(path)) { return result }
    result.put("exists",J.boolean(true))
    if (!FileInfo(path).isDirectory()) { return result.put("reason",J.str("writer lock is not a directory; manual maintenance required")) }
    let metadata=join(path,"owner.json")
    let entries=ArrayList<String>()
    Directory.walk(path,{ item => entries.add(item.path.toString()); true })
    if (entries.size!=1 || entries[0]!=metadata || !exists(metadata) || FileInfo(metadata).isSymbolicLink() || !FileInfo(metadata).isRegular()) { return result.put("reason",J.str("lock has missing metadata or additional files; manual maintenance required")) }
    try {
        if (FileInfo(metadata).size>16384) { throw Exception("owner metadata too large") }
        let owner=parseJson(readText(metadata)); let pid=owner.get("pid").i()
        if (pid<=0 || owner.get("started_at").s().isEmpty()) { throw Exception("invalid owner metadata") }
        result.put("owner",owner)
        if (owner.get("config").s()!=p.get("config").s()) { return result.put("reason",J.str("lock belongs to another configuration; manual maintenance required")) }
        let state=unsafe { cjdg_pid_state(pid) }
        if (state==1) { return result.put("reason",J.str("lock owner process is still alive")) }
        if (state!=0) { return result.put("reason",J.str("lock owner process state is unknown; manual maintenance required")) }
        return result.put("recoverable",J.boolean(true)).put("reason",J.str("owner process no longer exists; explicit recovery is available"))
    } catch(e: Exception) { return result.put("reason",J.str("invalid owner metadata; manual maintenance required: "+e.message)) }
}
func wbRecoverLock(p: J): J {
    let info=wbLockInfo(p)
    if (!info.get("recoverable").b()) { throw WbError(info.get("reason").s(),status:409) }
    let path=wbLockPath(p)
    // A second process-state check immediately precedes deletion. The directory
    // is never recursively removed: unexpected contents make recovery fail.
    let owner=parseJson(readText(join(path,"owner.json")))
    if (owner.dump()!=info.get("owner").dump() || unsafe { cjdg_pid_state(owner.get("pid").i()) }!=0) { throw WbError("lock owner changed; inspect again",status:409) }
    remove(join(path,"owner.json"))
    remove(path)
    return wbLockInfo(p).put("recovered",J.boolean(true))
}
