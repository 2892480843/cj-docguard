package docguard

import std.collection.*
import std.fs.*

// A deliberately small JSON tree. Scalar access never silently coerces types.
public class J {
    public let kind: String
    public let text: String
    public let items = ArrayList<J>()
    public let fields = HashMap<String, J>()
    public init(kind: String, text: String) { this.kind = kind; this.text = text }
    public static func str(s: String): J { J("string", s) }
    public static func num(n: Int64): J { J("number", n.toString()) }
    public static func boolean(b: Bool): J { J("boolean", if (b) { "true" } else { "false" }) }
    public static func arr(): J { J("array", "") }
    public static func obj(): J { J("object", "") }
    public static func nil(): J { J("null", "") }
    public func get(k: String): J {
        if (kind != "object") { throw Exception("JSON object required") }
        return fields.get(k) ?? J.nil()
    }
    public func s(): String {
        if (kind != "string") { throw Exception("JSON string required") }
        return text
    }
    public func i(): Int64 {
        if (kind != "number") { throw Exception("JSON integer required") }
        return strictInt(text)
    }
    public func b(): Bool {
        if (kind != "boolean" || (text != "true" && text != "false")) { throw Exception("JSON boolean required") }
        return text == "true"
    }
    public func add(j: J): J {
        if (kind != "array") { throw Exception("JSON array required") }
        items.add(j)
        return this
    }
    public func put(k: String, j: J): J {
        if (kind != "object") { throw Exception("JSON object required") }
        fields[k] = j
        return this
    }
    public func dump(): String { renderJ(this, 0) }
}

func digit(b: Byte): Bool { b >= 48 && b <= 57 }
func strictInt(s: String): Int64 {
    let bytes = s.toArray()
    if (bytes.size == 0) { throw Exception("empty integer") }
    let negative = bytes[0] == 45
    var p: Int64 = if (negative) { 1 } else { 0 }
    if (p == bytes.size) { throw Exception("missing integer digits") }
    if (bytes[p] == 48 && p + 1 != bytes.size) { throw Exception("leading zero") }
    var value: Int64 = 0
    // Accumulate negatively so Int64.Min remains representable.
    let limit = if (negative) { Int64.Min } else { -Int64.Max }
    while (p < bytes.size) {
        if (!digit(bytes[p])) { throw Exception("noninteger number") }
        let d = Int64(bytes[p] - 48)
        if (value < limit / 10 || value * 10 < limit + d) { throw Exception("integer overflow") }
        value = value * 10 - d
        p++
    }
    return if (negative) { value } else { -value }
}

func appendQuotedJson(out: ArrayList<Byte>, s: String): Unit {
    out.add(34)
    let hex = "0123456789abcdef".toArray()
    for (b in s.toArray()) {
        if (b == 34 || b == 92) { out.add(92); out.add(b) }
        else if (b < 32) {
            for (c in "\\u00".toArray()) { out.add(c) }
            out.add(hex[Int64(b >> 4)]); out.add(hex[Int64(b & 15)])
        } else { out.add(b) }
    }
    out.add(34)
}
func appendJson(out: ArrayList<Byte>, j: J, depth: Int64): Unit {
    if (depth > 256) { throw Exception("JSON nesting exceeds 256 (or cyclic tree)") }
    if (j.kind == "string") { appendQuotedJson(out, j.text); return }
    if (j.kind == "null") { for (b in "null".toArray()) { out.add(b) }; return }
    if (j.kind == "boolean") { j.b(); for (b in j.text.toArray()) { out.add(b) }; return }
    if (j.kind == "number") {
        let checked = parseJson(j.text)
        if (checked.kind != "number") { throw Exception("invalid JSON number") }
        for (b in j.text.toArray()) { out.add(b) }
        return
    }
    if (j.kind == "array") {
        out.add(91)
        var first = true
        for (v in j.items) {
            if (!first) { out.add(44) }; first = false
            appendJson(out, v, depth + 1)
        }
        out.add(93)
        return
    }
    if (j.kind != "object") { throw Exception("unknown JSON kind") }
    // Stable ordering is needed for reproducible fingerprints and reports.
    let keys = ArrayList<String>()
    for ((k, _) in j.fields) { keys.add(k) }
    for (i in 0..keys.size) {
        var p = i
        while (p > 0 && keys[p] < keys[p - 1]) {
            let tmp = keys[p]; keys[p] = keys[p - 1]; keys[p - 1] = tmp; p--
        }
    }
    out.add(123)
    var first = true
    for (k in keys) {
        if (!first) { out.add(44) }; first = false
        appendQuotedJson(out, k)
        out.add(58)
        appendJson(out, j.get(k), depth + 1)
    }
    out.add(125)
}
func renderJ(j: J, depth: Int64): String {
    let out = ArrayList<Byte>()
    appendJson(out, j, depth)
    return String.fromUtf8(out.toArray())
}

class JsonChunkWriter {
    let file: File
    var bytes = ArrayList<Byte>()
    init(file: File) { this.file = file }
    func add(b: Byte): Unit {
        bytes.add(b)
        if (bytes.size >= 65536) { flush() }
    }
    func append(data: Array<Byte>): Unit { for (b in data) { add(b) } }
    func flush(): Unit {
        if (bytes.size > 0) { file.write(bytes.toArray()); bytes = ArrayList<Byte>() }
    }
}

func writeJsonNode(writer: JsonChunkWriter, j: J, depth: Int64): Unit {
    if (depth > 256) { throw Exception("JSON nesting exceeds 256 (or cyclic tree)") }
    if (j.kind != "array" && j.kind != "object") {
        let scalar = ArrayList<Byte>()
        appendJson(scalar, j, depth)
        writer.append(scalar.toArray())
        return
    }
    if (j.kind == "array") {
        writer.add(91)
        var first = true
        for (item in j.items) {
            if (!first) { writer.add(44) }; first = false
            writeJsonNode(writer, item, depth + 1)
        }
        writer.add(93)
        return
    }
    writer.add(123)
    let keys = ArrayList<String>()
    for ((key, _) in j.fields) { keys.add(key) }
    for (i in 0..keys.size) {
        var p = i
        while (p > 0 && keys[p] < keys[p - 1]) {
            let tmp = keys[p]; keys[p] = keys[p - 1]; keys[p - 1] = tmp; p--
        }
    }
    var first = true
    for (key in keys) {
        if (!first) { writer.add(44) }; first = false
        let quoted = ArrayList<Byte>()
        appendQuotedJson(quoted, key)
        writer.append(quoted.toArray())
        writer.add(58)
        writeJsonNode(writer, j.get(key), depth + 1)
    }
    writer.add(125)
}

public func writeJsonFile(path: String, j: J): Unit {
    let file = File.create(path)
    try {
        let writer = JsonChunkWriter(file)
        writeJsonNode(writer, j, 0)
        writer.flush()
    } finally { file.close() }
}

class JsonReader {
    let bytes: Array<Byte>
    var p: Int64 = 0
    init(s: String) { bytes = s.toArray() }
    func fail(message: String): Nothing { throw Exception("JSON byte " + p.toString() + ": " + message) }
    func peek(): Byte { if (p < bytes.size) { bytes[p] } else { 0 } }
    func ws(): Unit { while (p < bytes.size && (peek() == 32 || peek() == 9 || peek() == 10 || peek() == 13)) { p++ } }
    func eat(b: Byte): Unit { if (p >= bytes.size || bytes[p] != b) { fail("unexpected token") }; p++ }
    func literal(s: String): Unit { for (b in s.toArray()) { eat(b) } }
    func hex(n: Int64): UInt32 {
        var cp: UInt32 = 0
        for (_ in 0..n) {
            let b = peek(); p++
            let d: UInt32 = if (b >= 48 && b <= 57) { UInt32(b - 48) }
                else if (b >= 65 && b <= 70) { UInt32(b - 55) }
                else if (b >= 97 && b <= 102) { UInt32(b - 87) }
                else { fail("invalid Unicode escape") }
            cp = cp * 16 + d
        }
        return cp
    }
    func utf8(out: ArrayList<Byte>, cp: UInt32): Unit {
        if (cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) { fail("invalid Unicode scalar") }
        if (cp < 0x80) { out.add(UInt8(cp)) }
        else if (cp < 0x800) { out.add(UInt8(0xc0 | (cp >> 6))); out.add(UInt8(0x80 | (cp & 63))) }
        else if (cp < 0x10000) {
            out.add(UInt8(0xe0 | (cp >> 12))); out.add(UInt8(0x80 | ((cp >> 6) & 63))); out.add(UInt8(0x80 | (cp & 63)))
        } else {
            out.add(UInt8(0xf0 | (cp >> 18))); out.add(UInt8(0x80 | ((cp >> 12) & 63)))
            out.add(UInt8(0x80 | ((cp >> 6) & 63))); out.add(UInt8(0x80 | (cp & 63)))
        }
    }
    func string(): String {
        eat(34)
        let out = ArrayList<Byte>()
        while (p < bytes.size) {
            let b = bytes[p]; p++
            if (b == 34) { return String.fromUtf8(out.toArray()) }
            if (b < 32) { fail("unescaped control character") }
            if (b != 92) { out.add(b); continue }
            if (p >= bytes.size) { fail("unfinished escape") }
            let e = bytes[p]; p++
            if (e == 34 || e == 92 || e == 47) { out.add(e) }
            else if (e == 98) { out.add(8) }
            else if (e == 102) { out.add(12) }
            else if (e == 110) { out.add(10) }
            else if (e == 114) { out.add(13) }
            else if (e == 116) { out.add(9) }
            else if (e == 117) {
                var cp = hex(4)
                if (cp >= 0xd800 && cp <= 0xdbff) {
                    eat(92); eat(117)
                    let low = hex(4)
                    if (low < 0xdc00 || low > 0xdfff) { fail("invalid surrogate pair") }
                    cp = 0x10000 + ((cp - 0xd800) << 10) + low - 0xdc00
                }
                utf8(out, cp)
            } else { fail("invalid escape") }
        }
        fail("unterminated string")
    }
    func number(): J {
        let start = p
        if (peek() == 45) { p++ }
        if (peek() == 48) { p++ }
        else {
            if (peek() < 49 || peek() > 57) { fail("number requires digits") }
            while (digit(peek())) { p++ }
        }
        if (peek() == 46) {
            p++
            if (!digit(peek())) { fail("fraction requires digits") }
            while (digit(peek())) { p++ }
        }
        if (peek() == 101 || peek() == 69) {
            p++
            if (peek() == 43 || peek() == 45) { p++ }
            if (!digit(peek())) { fail("exponent requires digits") }
            while (digit(peek())) { p++ }
        }
        return J("number", String.fromUtf8(bytes[start..p]))
    }
    func value(depth: Int64): J {
        if (depth > 256) { fail("nesting exceeds 256") }
        ws()
        let b = peek()
        if (b == 34) { return J.str(string()) }
        if (b == 110) { literal("null"); return J.nil() }
        if (b == 116) { literal("true"); return J.boolean(true) }
        if (b == 102) { literal("false"); return J.boolean(false) }
        if (b == 45 || digit(b)) { return number() }
        if (b == 91) {
            p++; ws(); let a = J.arr()
            if (peek() == 93) { p++; return a }
            while (true) {
                a.add(value(depth + 1)); ws()
                if (peek() == 93) { p++; return a }
                eat(44)
            }
        }
        if (b == 123) {
            p++; ws(); let o = J.obj()
            if (peek() == 125) { p++; return o }
            while (true) {
                ws(); let key = string(); ws(); eat(58)
                if (o.fields.contains(key)) { fail("duplicate object key " + key) }
                o.put(key, value(depth + 1)); ws()
                if (peek() == 125) { p++; return o }
                eat(44)
            }
        }
        fail("expected value")
    }
}
public func parseJson(source: String): J {
    let r = JsonReader(source)
    let j = r.value(0)
    r.ws()
    if (r.p != r.bytes.size) { r.fail("trailing content") }
    return j
}

// TOML subset: one-line values, bare keys, single-level tables and array tables.
// Rejecting everything outside the subset prevents a misleading partial config.
class TomlReader {
    let bytes: Array<Byte>
    var p: Int64 = 0
    init(source: String) { bytes = source.toArray() }
    func fail(message: String): Nothing { throw Exception("TOML byte " + p.toString() + ": " + message) }
    func peek(): Byte { if (p < bytes.size) { bytes[p] } else { 0 } }
    func spaces(): Unit { while (peek() == 32 || peek() == 9) { p++ } }
    func take(b: Byte): Unit { if (p >= bytes.size || peek() != b) { fail("unexpected token") }; p++ }
    func key(): String {
        let start = p
        while (digit(peek()) || (peek() >= 65 && peek() <= 90) || (peek() >= 97 && peek() <= 122) || peek() == 95 || peek() == 45) { p++ }
        if (p == start) { fail("bare key required") }
        return String.fromUtf8(bytes[start..p])
    }
    func endLine(): Unit {
        spaces()
        if (peek() == 35) { while (p < bytes.size && peek() != 10 && peek() != 13) { p++ } }
        if (p == bytes.size) { return }
        if (peek() == 13) { p++; take(10) }
        else if (peek() == 10) { p++ }
        else { fail("unsupported syntax or trailing content") }
    }
    func string(): String {
        let delimiter = peek(); p++
        let out = ArrayList<Byte>()
        while (p < bytes.size) {
            let b = peek(); p++
            if (b == delimiter) { return String.fromUtf8(out.toArray()) }
            if ((b < 32 && b != 9) || b == 127) { fail("control character in string") }
            if (b != 92 || delimiter == 39) { out.add(b); continue }
            let e = peek(); p++
            if (e == 34 || e == 92) { out.add(e) }
            else if (e == 98) { out.add(8) }
            else if (e == 102) { out.add(12) }
            else if (e == 110) { out.add(10) }
            else if (e == 114) { out.add(13) }
            else if (e == 116) { out.add(9) }
            else if (e == 117 || e == 85) {
                let helper = JsonReader(String.fromUtf8(bytes[p..bytes.size]))
                let cp = helper.hex(if (e == 117) { 4 } else { 8 })
                helper.utf8(out, cp); p += helper.p
            } else { fail("unsupported string escape") }
        }
        fail("unterminated string")
    }
    func value(): J {
        if (peek() == 34 || peek() == 39) { return J.str(string()) }
        if (peek() == 91) {
            p++; spaces(); let a = J.arr()
            if (peek() == 93) { p++; return a }
            while (true) {
                if (peek() != 34 && peek() != 39) { fail("only string arrays supported") }
                a.add(J.str(string())); spaces()
                if (peek() == 93) { p++; return a }
                take(44); spaces()
            }
        }
        let start = p
        while (p < bytes.size && peek() != 32 && peek() != 9 && peek() != 10 && peek() != 13 && peek() != 35) { p++ }
        let word = String.fromUtf8(bytes[start..p])
        if (word == "true") { return J.boolean(true) }
        if (word == "false") { return J.boolean(false) }
        // This subset excludes plus signs, separators and nondecimal forms.
        return J.num(strictInt(word))
    }
    func parse(): J {
        let root = J.obj()
        var current = root
        let arrayTables = HashSet<String>()
        while (p < bytes.size) {
            spaces()
            if (p == bytes.size) { break }
            if (peek() == 35 || peek() == 10 || peek() == 13) { endLine(); continue }
            if (peek() == 91) {
                p++
                let arrayTable = peek() == 91
                if (arrayTable) { p++ }
                spaces(); let name = key(); spaces(); take(93)
                if (arrayTable) { take(93) }
                endLine()
                if (arrayTable) {
                    if (!arrayTables.contains(name)) {
                        if (root.fields.contains(name)) { fail("table/key type conflict " + name) }
                        root.put(name, J.arr()); arrayTables.add(name)
                    }
                    current = J.obj(); root.get(name).add(current)
                } else {
                    if (root.fields.contains(name)) { fail("duplicate table or key " + name) }
                    current = J.obj(); root.put(name, current)
                }
            } else {
                let name = key(); spaces(); take(61); spaces()
                if (current.fields.contains(name)) { fail("duplicate key " + name) }
                current.put(name, value()); endLine()
            }
        }
        return root
    }
}
public func parseToml(source: String): J { TomlReader(source).parse() }

func rotr(v: UInt32, n: Int64): UInt32 { (v >> n) | (v << (32 - n)) }

// Fixed buffers keep file hashing independent of file size and the default heap limit.
private class Sha256State {
    let k: Array<UInt32> = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]
    let h: Array<UInt32> = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
    let w = Array<UInt32>(64, repeat: 0)
    let block = Array<Byte>(64, repeat: 0)
    var used: Int64 = 0
    var byteCount: UInt64 = 0

    func compress(data: Array<Byte>, offset: Int64): Unit {
        for (i in 0..16) {
            let p = offset + i * 4
            w[i] = (UInt32(data[p]) << 24) | (UInt32(data[p+1]) << 16) | (UInt32(data[p+2]) << 8) | UInt32(data[p+3])
        }
        for (i in 16..64) {
            let x = w[i-15]; let y = w[i-2]
            let s0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)
            let s1 = rotr(y, 17) ^ rotr(y, 19) ^ (y >> 10)
            w[i] = UInt32((UInt64(w[i-16]) + UInt64(s0) + UInt64(w[i-7]) + UInt64(s1)) & 0xffffffff)
        }
        var a = h[0]; var b = h[1]; var c = h[2]; var d = h[3]
        var e = h[4]; var f = h[5]; var g = h[6]; var z = h[7]
        for (i in 0..64) {
            let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let ch = (e & f) ^ ((!e) & g)
            let t1 = UInt32((UInt64(z) + UInt64(s1) + UInt64(ch) + UInt64(k[i]) + UInt64(w[i])) & 0xffffffff)
            let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let t2 = UInt32((UInt64(s0) + UInt64(maj)) & 0xffffffff)
            z = g; g = f; f = e; e = UInt32((UInt64(d) + UInt64(t1)) & 0xffffffff)
            d = c; c = b; b = a; a = UInt32((UInt64(t1) + UInt64(t2)) & 0xffffffff)
        }
        h[0] = UInt32((UInt64(h[0]) + UInt64(a)) & 0xffffffff)
        h[1] = UInt32((UInt64(h[1]) + UInt64(b)) & 0xffffffff)
        h[2] = UInt32((UInt64(h[2]) + UInt64(c)) & 0xffffffff)
        h[3] = UInt32((UInt64(h[3]) + UInt64(d)) & 0xffffffff)
        h[4] = UInt32((UInt64(h[4]) + UInt64(e)) & 0xffffffff)
        h[5] = UInt32((UInt64(h[5]) + UInt64(f)) & 0xffffffff)
        h[6] = UInt32((UInt64(h[6]) + UInt64(g)) & 0xffffffff)
        h[7] = UInt32((UInt64(h[7]) + UInt64(z)) & 0xffffffff)
    }

    func update(input: Array<Byte>, count: Int64): Unit {
        byteCount += UInt64(count)
        var p: Int64 = 0
        if (used > 0) {
            while (used < 64 && p < count) { block[used] = input[p]; used++; p++ }
            if (used == 64) { compress(block, 0); used = 0 }
        }
        while (p + 64 <= count) { compress(input, p); p += 64 }
        while (p < count) { block[used] = input[p]; used++; p++ }
    }

    func finish(): String {
        block[used] = 128; used++
        if (used > 56) {
            while (used < 64) { block[used] = 0; used++ }
            compress(block, 0); used = 0
        }
        while (used < 56) { block[used] = 0; used++ }
        let bits = byteCount * 8
        for (i in 0..8) { block[56 + i] = UInt8((bits >> ((7 - i) * 8)) & 255) }
        compress(block, 0)
        let hex = "0123456789abcdef".toArray()
        let out = Array<Byte>(64, repeat: 0)
        var n: Int64 = 0
        for (value in h) {
            for (i in 0..8) { out[n] = hex[Int64((value >> ((7 - i) * 4)) & 15)]; n++ }
        }
        return String.fromUtf8(out)
    }
}

public func sha256(input: Array<Byte>): String {
    let state = Sha256State()
    state.update(input, input.size)
    return state.finish()
}

public func sha256File(path: String): String {
    let file = File(path, OpenMode.Read)
    let state = Sha256State()
    let buffer = Array<Byte>(65536, repeat: 0)
    try {
        while (true) {
            let count = file.read(buffer)
            if (count == 0) { break }
            state.update(buffer, count)
        }
        return state.finish()
    } finally { file.close() }
}
