package docguard

import std.collection.*
import std.net.*
import std.sync.*
import std.time.*

class WbRequest {
    let method: String
    let target: String
    let headers: HashMap<String, String>
    let body: String
    init(method: String, target: String, headers: HashMap<String, String>, body: String) {
        this.method = method; this.target = target; this.headers = headers; this.body = body
    }
}
class WbResponse {
    let status: Int64
    let body: Array<Byte>
    let contentType: String
    var download: Bool = false
    init(status: Int64, body: Array<Byte>, contentType: String) {
        this.status = status; this.body = body; this.contentType = contentType
    }
}
private class HttpFailure <: Exception {
    let status: Int64
    init(status: Int64, message: String) { super(message); this.status = status }
}
private func httpError(status: Int64, message: String): WbResponse {
    WbResponse(status, J.obj().put("error", J.str(message)).dump().toArray(), "application/json; charset=utf-8")
}
private func headerToken(value: String): Bool {
    if (value.isEmpty()) { return false }
    for (b in value.toArray()) {
        if (!((b >= 65 && b <= 90) || (b >= 97 && b <= 122) || (b >= 48 && b <= 57) ||
            "!#$%&'*+-.^_`|~".toArray().contains(b))) { return false }
    }
    return true
}
private func lowerHeader(value: String): String {
    let bytes = value.toArray()
    for (i in 0..bytes.size) { if (bytes[i] >= 65 && bytes[i] <= 90) { bytes[i] += 32 } }
    return String.fromUtf8(bytes)
}
private func httpDecimal(value: String): Int64 {
    if (value.isEmpty() || value.size > 10) { throw HttpFailure(400, "invalid Content-Length") }
    var n: Int64 = 0
    for (b in value.toArray()) {
        if (b < 48 || b > 57) { throw HttpFailure(400, "invalid Content-Length") }
        n = n * 10 + Int64(b - 48)
        if (n > 2097152) { throw HttpFailure(413, "request body exceeds 2 MiB") }
    }
    return n
}
private func readRequest(socket: TcpSocket): WbRequest {
    let bytes = ArrayList<Byte>()
    let one = Array<Byte>(1, repeat: 0)
    let started = DateTime.now().toUnixTimeStamp()
    // Reading headers one byte at a time avoids buffering an unbounded pipelined body.
    while (true) {
        if (DateTime.now().toUnixTimeStamp() - started > Duration.second * 10) { throw HttpFailure(408, "request header deadline exceeded") }
        if (socket.read(one) == 0) { throw HttpFailure(400, "incomplete request headers") }
        bytes.add(one[0])
        if (bytes.size > 16384) { throw HttpFailure(431, "request headers exceed 16 KiB") }
        let n = bytes.size
        if (n >= 4 && bytes[n-4] == 13 && bytes[n-3] == 10 && bytes[n-2] == 13 && bytes[n-1] == 10) { break }
    }
    let lines = String.fromUtf8(bytes.toArray()).split("\r\n")
    let request = lines[0].split(" ")
    if (request.size != 3 || request[2] != "HTTP/1.1" || !headerToken(request[0])) { throw HttpFailure(400, "invalid HTTP/1.1 request line") }
    let target = request[1]
    if (!target.startsWith("/") || target.startsWith("//") || target.contains("#") || target.size > 8192) { throw HttpFailure(400, "invalid request target") }
    for (b in target.toArray()) { if (b <= 32 || b >= 127 || b == 92) { throw HttpFailure(400, "invalid request target") } }
    let headers = HashMap<String, String>()
    for (i in 1..lines.size-2) {
        let line = lines[i]
        var colon: Int64 = -1
        let raw = line.toArray()
        for (j in 0..raw.size) { if (raw[j] == 58) { colon = j; break } }
        if (colon <= 0) { throw HttpFailure(400, "invalid header") }
        let name = lowerHeader(line[..colon])
        if (!headerToken(name) || headers.contains(name)) { throw HttpFailure(400, "invalid or duplicate header") }
        let rawValue = line[colon+1..]
        for (b in rawValue.toArray()) { if ((b < 32 && b != 9) || b == 127) { throw HttpFailure(400, "invalid header value") } }
        headers[name] = rawValue.trimAscii()
        if (headers.size > 100) { throw HttpFailure(431, "too many request headers") }
    }
    if (!headers.contains("host") || headers["host"].isEmpty()) { throw HttpFailure(400, "Host required") }
    if (headers.contains("transfer-encoding")) { throw HttpFailure(400, "Transfer-Encoding unsupported") }
    if (headers.contains("expect")) { throw HttpFailure(417, "Expect unsupported") }
    let length = httpDecimal(headers.get("content-length") ?? "0")
    let body = Array<Byte>(length, repeat: 0)
    var read: Int64 = 0
    let bodyStart = DateTime.now().toUnixTimeStamp()
    while (read < length) {
        if (DateTime.now().toUnixTimeStamp() - bodyStart > Duration.second * 15) { throw HttpFailure(408, "request body deadline exceeded") }
        let chunk = Array<Byte>(min(8192, length-read), repeat: 0)
        let n = socket.read(chunk)
        if (n == 0) { throw HttpFailure(400, "incomplete request body") }
        for (i in 0..n) { body[read+i] = chunk[i] }
        read += n
    }
    return WbRequest(request[0], target, headers, String.fromUtf8(body))
}
private func writeResponse(socket: TcpSocket, response: WbResponse): Unit {
    let reason = match (response.status) {
        case 200 => "OK"
        case 201 => "Created"
        case 202 => "Accepted"
        case 400 => "Bad Request"
        case 403 => "Forbidden"
        case 404 => "Not Found"
        case 408 => "Request Timeout"
        case 409 => "Conflict"
        case 413 => "Content Too Large"
        case 417 => "Expectation Failed"
        case 431 => "Request Header Fields Too Large"
        case 503 => "Service Unavailable"
        case _ => "Error"
    }
    var header = "HTTP/1.1 ${response.status} ${reason}\r\nContent-Type: ${response.contentType}\r\nContent-Length: ${response.body.size}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\n"
    if (response.download) { header += "Content-Disposition: attachment; filename=docguard-export.zip\r\n" }
    socket.write((header + "\r\n").toArray())
    if (!response.body.isEmpty()) { socket.write(response.body) }
}
class WorkbenchHttp {
    let app: NativeWorkbench
    let server: TcpServerSocket
    let active = AtomicInt64(0)
    // Reports retain complete histories. Bound their parsed trees and encoded
    // response buffers to one application response, even with many polling tabs.
    // Keep socket reads outside this gate so incomplete headers cannot block it.
    let responseMutex = Mutex()
    let port: UInt16
    init(app: NativeWorkbench, host: String, port: UInt16) {
        this.app = app; this.port = port
        server = TcpServerSocket(bindAt: IPSocketAddress(host, port))
        server.backlogSize = 32
    }
    func client(socket: TcpSocket): Unit {
        try {
            socket.readTimeout = Duration.second * 5
            socket.writeTimeout = Duration.second * 5
            var response: WbResponse
            try {
                let request = readRequest(socket)
                let authority = request.headers["host"]
                if (authority != "127.0.0.1:${port}" && authority != "localhost:${port}") {
                    throw HttpFailure(403, "Host does not match loopback listener")
                }
                if (let Some(origin) <- request.headers.get("origin")) {
                    if (origin != "http://" + authority) { throw HttpFailure(403, "Origin does not match Host") }
                }
                synchronized(responseMutex) {
                    let ready = app.handle(request)
                    try { writeResponse(socket, ready) }
                    catch (_: Exception) { /* Never append an error to a partial response. */ }
                }
                return
            }
            catch (e: HttpFailure) { response = httpError(e.status, e.message) }
            catch (e: SocketTimeoutException) { response = httpError(408, "request timed out") }
            catch (_: Exception) { response = httpError(400, "invalid request") }
            writeResponse(socket, response)
        } catch (_: Exception) { /* Disconnected clients must not terminate the listener. */ }
        finally { socket.close(); active.fetchSub(1) }
    }
    func serve(): Unit {
        try {
            server.bind()
            println("CJ-DocGuard native Cangjie workbench listening on " + server.localAddress.toString())
            while (unsafe { cjdg_stop_requested() } == 0) {
                var accepted: ?TcpSocket = None
                try { accepted = server.accept(timeout: Duration.second) }
                catch (_: SocketTimeoutException) { continue }
                let socket = accepted.getOrThrow()
                if (active.load() >= 16) {
                    try { socket.writeTimeout = Duration.second; writeResponse(socket, httpError(503, "too many clients")) }
                    catch (_: Exception) {} finally { socket.close() }
                } else {
                    active.fetchAdd(1)
                    spawn { client(socket) }
                }
            }
        } finally {
            server.close()
            app.shutdown()
            // Existing requests have socket deadlines; allow response workers to finish.
            let deadline = DateTime.now().toUnixTimeStamp() + Duration.second * 10
            while (active.load() > 0 && DateTime.now().toUnixTimeStamp() < deadline) {
                sleep(Duration.millisecond * 20)
            }
        }
    }
}
