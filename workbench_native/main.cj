package docguard

import std.collection.*
import std.env.*
import std.fs.*

foreign {
    func cjdg_install_signals(): Int32
    func cjdg_stop_requested(): Int32
    func cjdg_pid_state(pid: Int64): Int32
}

main(args: Array<String>): Int64 {
    try {
        let options = HashMap<String, String>()
        var i: Int64 = 0
        while (i < args.size) {
            let key = args[i]
            if (key == "--help" || key == "-h") {
                println("CJ-DocGuard native Cangjie workbench\n--host 127.0.0.1|localhost --port 8765 --root PATH --state-dir PATH --system-sdk PATH\nLoopback only; 16 clients; 16 KiB headers; 2 MiB request bodies.")
                return 0
            }
            if (key == "--version") { println("CJ-DocGuard Workbench 0.1.0 (Cangjie)"); return 0 }
            if (!["--host", "--port", "--root", "--state-dir", "--system-sdk"].contains(key) || options.contains(key) || i+1 >= args.size) {
                throw Exception("unknown/duplicate option or missing value: " + key)
            }
            options[key] = args[i+1]; i += 2
        }
        let host = options.get("--host") ?? "127.0.0.1"
        if (host != "127.0.0.1" && host != "localhost") { throw Exception("--host must be 127.0.0.1 or localhost") }
        let portText = options.get("--port") ?? "8765"
        var port: Int64 = 0
        if (portText.isEmpty() || portText.size > 5) { throw Exception("invalid --port") }
        for (b in portText.toArray()) {
            if (b < 48 || b > 57) { throw Exception("invalid --port") }
            port = port*10+Int64(b-48)
        }
        if (port < 1 || port > 65535) { throw Exception("--port must be 1..65535") }
        let root = canonicalize(options.get("--root") ?? ".").toString()
        if (!FileInfo(root).isDirectory()) { throw Exception("--root must be a directory") }
        let state = options.get("--state-dir") ?? join(root, "build/workbench")
        if (let Some(sdk) <- options.get("--system-sdk")) {
            let path = canonicalize(sdk).toString()
            if (!exists(join(path, "usr/lib/libSystem.tbd"))) { throw Exception("invalid --system-sdk") }
            setVariable("CJ_DOCGUARD_SYSTEM_SDKROOT", path)
        }
        if (unsafe { cjdg_install_signals() } != 0) { throw Exception("cannot install shutdown signal handlers") }
        let app = NativeWorkbench(root, state, 600000)
        WorkbenchHttp(app, "127.0.0.1", UInt16(port)).serve()
        return 0
    } catch (e: Exception) { println("workbench error: " + e.message); return 2 }
}
