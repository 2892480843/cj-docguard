package docguard
import std.fs.*
import std.process.*
import std.collection.*

var platformAssertions: Int64 = 0
func pfExpect(ok:Bool,message:String):Unit {
    platformAssertions++
    if (!ok) { throw Exception("platform test failed: " + message) }
}
func pfEnv():HashMap<String,String> {
    let env=HashMap<String,String>()
    env["PATH"]="/usr/bin:/bin:/usr/sbin:/sbin"
    env["LANG"]="C"; env["LC_ALL"]="C"
    return env
}
main():Unit {
    let runner=envValue("CJ_DOCGUARD_RUNNER")
    let home=envValue("CJ_DOCGUARD_SDK_1_1_3")
    pfExpect(!runner.isEmpty() && !home.isEmpty(),"test SDK/runner registered")
    let dir=Directory.createTemp("/tmp").toString()
    let env=pfEnv()
    let normal=runCommand(runner,["/bin/sh","-c","printf 'hello\\n'; printf 'warning\\n' >&2"],dir,dir,env,2000)
    pfExpect(normal.get("stdout").s()=="hello\n" && normal.get("stderr").s()=="warning\n","actual stdout/stderr text")
    pfExpect(normal.get("exit_code").i()==0 && !normal.get("timed_out").b(),"successful exit")
    pfExpect(!normal.get("started_at").s().isEmpty() && !normal.get("finished_at").s().isEmpty(),"timestamps")
    pfExpect(normal.get("argv").items[0].s()=="/bin/sh", "exact argv")
    let nonzero=runCommand(runner,["/bin/sh","-c","exit 7"],dir,dir,env,2000)
    pfExpect(nonzero.get("exit_code").i()==7,"nonzero status retained")
    pfExpect(nonzero.get("log_dir").s()!=normal.get("log_dir").s(),"unique logs per invocation")
    let timeout=runCommand(runner,["/bin/sh","-c","sleep 10"],dir,dir,env,100)
    pfExpect(timeout.get("timed_out").b() && timeout.get("exit_code").i()!=0,"timeout classification")
    pfExpect(timeout.get("elapsed_ms").i()<3000,"prompt process group cleanup")
    let interrupted=runCommand(runner,["/bin/sh","-c","kill -TERM \"$PPID\"; sleep 10"],dir,dir,env,2000)
    pfExpect(interrupted.get("interrupted").b() && interrupted.get("exit_code").i()!=0,"supervisor interruption classification")
    let orphan=runCommand(runner,["/bin/sh","-c","sleep 10 & exit 0"],dir,dir,env,2000)
    pfExpect(orphan.get("elapsed_ms").i()<1000 && !orphan.get("timed_out").b(),"descendants cleaned after normal parent exit")
    let missingCommand=runCommand(runner,["/missing/program"],dir,dir,env,1000)
    pfExpect(missingCommand.get("exit_code").i()==127 && !missingCommand.get("stderr").s().isEmpty(),"child exec failure retained")
    let stdin=runCommand(runner,["/bin/sh","-c","read value || printf 'eof\\n'"],dir,dir,env,1000)
    pfExpect(stdin.get("stdout").s()=="eof\n", "child standard input closed")
    let truncated=runCommand(runner,["/bin/sh","-c","yes x"],dir,dir,env,3000)
    pfExpect(truncated.get("truncated").b(),"output limit classification")
    pfExpect(FileInfo(truncated.get("stdout_path").s()).size<=1048576,"bounded logs")
    var rejected=false
    try { runCommand("/missing/runner",["/bin/true"],dir,dir,env,100) } catch(_:Exception) { rejected=true }
    pfExpect(rejected,"missing supervisor is explicit exception")
    rejected=false
    try { runCommand(runner,[],dir,dir,env,100) } catch(_:Exception) { rejected=true }
    pfExpect(rejected,"empty command rejected")
    rejected=false
    try { runCommand("/bin/true",["/bin/true"],dir,dir,env,100) } catch(_:Exception) { rejected=true }
    pfExpect(rejected,"missing evidence is explicit exception")
    rejected=false
    try { runCommand(runner,["/bin/true"],dir,"/dev/null",env,100) } catch(_:Exception) { rejected=true }
    pfExpect(rejected,"evidence I/O failure is explicit exception")
    Process.current.setEnv("DOCGUARD_TEST_CREDENTIAL","must-not-inherit")
    let clean=runCommand(runner,["/usr/bin/env"],dir,dir,env,2000)
    Process.current.removeEnv("DOCGUARD_TEST_CREDENTIAL")
    pfExpect(!clean.get("stdout").s().contains("DOCGUARD_TEST_CREDENTIAL"),"ambient credentials not inherited")
    pfExpect(clean.get("environment_hashes").get("PATH").s()==digestText(env["PATH"]),"execution environment values hashed")
    let sdk=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(home)),runner,dir)
    pfExpect(sdk.get("available").b() && sdk.get("version").s()=="1.1.3","actual SDK version inspected")
    pfExpect(sdk.get("fingerprint").s().size==64,"content fingerprint")
    pfExpect(!sdk.get("platform").s().isEmpty(),"actual platform")
    pfExpect(sdk.get("environment").get("CANGJIE_HOME").s()==canonicalize(home).toString(),"explicit canonical SDK environment")
    let registered=inspectSdk(J.obj().put("version",J.str("1.1.3")),runner,dir)
    pfExpect(registered.get("available").b() && registered.get("fingerprint").s()==sdk.get("fingerprint").s(),"environment registration and stable identity")
    let sdk2=inspectSdk(J.obj().put("version",J.str("1.2.0")).put("home",J.str(envValue("CJ_DOCGUARD_SDK_1_2_0"))),runner,dir)
    pfExpect(sdk2.get("available").b() && sdk2.get("version").s()=="1.2.0", "second real SDK version inspected")
    let missing=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(join(dir,"missing"))),runner,dir)
    pfExpect(!missing.get("available").b() && !missing.get("reason").s().isEmpty(),"missing SDK")
    let mismatch=inspectSdk(J.obj().put("version",J.str("1.2.0")).put("home",J.str(home)),runner,dir)
    pfExpect(!mismatch.get("available").b() && mismatch.get("version").s()=="1.1.3","declared version mismatch rejected")
    let fake=join(dir,"fake-sdk")
    for(part in ["bin","modules","lib","runtime","third_party"]) { mkdir(join(fake,part)) }
    let wrapper=join(fake,"bin/cjc")
    writeText(wrapper,"#!/bin/sh\nprintf 'Cangjie Compiler: 1.1.3 (cjnative)\\n'\n# a\n")
    runCommand(runner,["/bin/chmod","+x",wrapper],dir,dir,env,2000)
    writeText(join(fake,"modules/core.cjo"),"AAAA")
    writeText(join(fake,"runtime/library.dat"),"CCCC")
    writeText(join(fake,"third_party/linker.dat"),"EEEE")
    let reference=join(dir,"wrapper-reference")
    runCommand(runner,["/bin/cp","-p",wrapper,reference],dir,dir,env,2000)
    let before=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(fake)),runner,dir)
    pfExpect(before.get("available").b(),"safe fake wrapper supports identity mutation test")
    writeText(wrapper,"#!/bin/sh\nprintf 'Cangjie Compiler: 1.1.3 (cjnative)\\n'\n# b\n")
    runCommand(runner,["/usr/bin/touch","-r",reference,wrapper],dir,dir,env,2000)
    pfExpect(FileInfo(wrapper).lastModificationTime==FileInfo(reference).lastModificationTime,"compiler mutation preserves mtime")
    let changed=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(fake)),runner,dir)
    pfExpect(changed.get("fingerprint").s()!=before.get("fingerprint").s(),"same-size compiler content mutation changes identity")
    writeText(join(fake,"modules/core.cjo"),"BBBB")
    let moduleChanged=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(fake)),runner,dir)
    pfExpect(moduleChanged.get("fingerprint").s()!=changed.get("fingerprint").s(),"module content mutation changes identity")
    writeText(join(fake,"runtime/library.dat"),"DDDD")
    let runtimeChanged=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(fake)),runner,dir)
    pfExpect(runtimeChanged.get("fingerprint").s()!=moduleChanged.get("fingerprint").s(),"runtime content mutation changes identity")
    writeText(join(fake,"third_party/linker.dat"),"FFFF")
    let linkerChanged=inspectSdk(J.obj().put("version",J.str("1.1.3")).put("home",J.str(fake)),runner,dir)
    pfExpect(linkerChanged.get("fingerprint").s()!=runtimeChanged.get("fingerprint").s(),"bundled linker content mutation changes identity")
    let hashFile=join(dir,"hash.dat")
    for(size in [0,1,55,56,63,64,65,65535,65536,65537,1000000]) {
        let data=Array<Byte>(size,{ i=>UInt8(i % 251) })
        File.writeTo(hashFile,data)
        pfExpect(sha256File(hashFile)==sha256(data),"stream/array SHA parity ${size}")
    }
    println("PASS native platform: ${platformAssertions} assertions; SDK identity, bounded execution, timeout, truncation, environment, streaming SHA")
}
