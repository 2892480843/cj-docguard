package docguard

var assertionCount: Int64 = 0

func expect(ok: Bool, label: String): Unit {
    assertionCount++
    if (!ok) { throw Exception("FAIL: " + label) }
}
func rejectsJson(source: String): Unit {
    var rejected = false
    try { parseJson(source) } catch (_: Exception) { rejected = true }
    expect(rejected, "reject JSON " + source)
}
func rejectsToml(source: String): Unit {
    var rejected = false
    try { parseToml(source) } catch (_: Exception) { rejected = true }
    expect(rejected, "reject TOML " + source)
}
main(): Int64 {
    expect(sha256("".toArray()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA256 empty")
    expect(sha256("abc".toArray()) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA256 abc")
    expect(sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".toArray()) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", "SHA256 multiblock")
    expect(sha256(Array<Byte>(1000000, repeat: 97)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0", "SHA256 million a")
    expect(sha256(Array<Byte>(55, repeat: 97)) == "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318", "SHA256 padding 55")
    expect(sha256(Array<Byte>(56, repeat: 97)) == "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a", "SHA256 padding 56")
    expect(sha256(Array<Byte>(63, { i => UInt8(i % 256) })) == "29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488", "SHA256 binary length 63")
    expect(sha256(Array<Byte>(64, { i => UInt8(i % 256) })) == "fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108", "SHA256 binary length 64")
    expect(sha256(Array<Byte>(65, { i => UInt8(i % 256) })) == "4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781", "SHA256 binary length 65")
    expect(sha256(Array<Byte>(256, { i => UInt8(i % 256) })) == "40aff2e9d2d8922e47afd4648e6967497158785fbd1da870e7110266bf944880", "SHA256 binary length 256")
    expect(sha256(Array<Byte>(1024, { i => UInt8(i % 256) })) == "785b0751fc2c53dc14a4ce3d800e69ef9ce1009eb327ccf458afe09c242c26c9", "SHA256 binary length 1024")
    let j = parseJson("{\"中文\":\"a\\n\\t\\\"\\\\\\u4e2d\\ud83d\\ude00\",\"n\":-42,\"b\":true,\"a\":[null,false,1.25e+2]}")
    expect(j.get("中文").s() == "a\n\t\"\\中😀", "Unicode and escapes")
    expect(j.get("n").i() == -42 && j.get("b").b(), "strict reads")
    expect(j.get("a").items.size == 3 && j.get("absent").kind == "null", "array and absent")
    expect(parseJson(j.dump()).get("中文").s() == j.get("中文").s(), "roundtrip")
    expect(J.obj().put("a", J.arr().add(J.num(5))).get("a").items[0].i() == 5, "chain")
    var strict = false
    try { parseJson("1.0").i() } catch (_: Exception) { strict = true }
    expect(strict, "fraction must not coerce to integer")
    strict = false
    try { J.str("1").i() } catch (_: Exception) { strict = true }
    expect(strict, "string must not coerce to integer")
    for (bad in ["{\"x\":1,\"x\":2}", "[1,]", "{\"x\":}", "01", "1.", "1e", "true false", "\"\\ud800\"", "\"\\udc00\"", "\"\\x\"", "\"\n\"", "[", "{", "NaN", "\"unterminated"]) { rejectsJson(bad) }
    expect(parseJson("9223372036854775807").i() == Int64.Max, "int maximum")
    expect(parseJson("-9223372036854775808").i() == Int64.Min, "int minimum")
    strict = false
    try { parseJson("9223372036854775808").i() } catch (_: Exception) { strict = true }
    expect(strict, "integer overflow")
    let cfg = parseToml("# config\n[project]\nname = \"中文 # name\" # comment\ntrusted = true\nsources = [\"src\", 'lib']\ncount = -42\n[[sdks]]\nversion = '1.1.3'\n[[sdks]]\nversion = \"1.2.0\"\n[[examples]]\nid = \"run\"\nstdout = \"ok\\n\"\n")
    expect(cfg.get("project").get("name").s() == "中文 # name", "TOML quoted comments")
    expect(cfg.get("project").get("sources").items[1].s() == "lib", "TOML string array")
    expect(cfg.get("project").get("count").i() == -42 && cfg.get("project").get("trusted").b(), "TOML primitives")
    expect(cfg.get("sdks").items.size == 2 && cfg.get("sdks").items[1].get("version").s() == "1.2.0", "TOML array of tables")
    expect(cfg.get("examples").items[0].get("stdout").s() == "ok\n", "TOML escapes")
    for (bad in ["a=1\na=2", "[p]\na=1\n[p]\nb=2", "[p]\n[[p]]", "a=1.2", "a=2026-10-06", "a={x=1}", "a=[1]", "a.b=1", "[a.b]", "a=01", "a=\"\\q\"", "a='unterminated", "a=[\"x\",]", "a=0x12", "p=[]\n[[p]]\nx=1", "p=[\"x\"]\n[[p]]\nx=1"]) { rejectsToml(bad) }
    expect(parseToml("[p]\r\ns=\"\\u4e2d\\U0001f600\"\r\n").get("p").get("s").s() == "中😀", "TOML Unicode and CRLF")
    expect(parseToml("s='C:\\raw'\n").get("s").s() == "C:\\raw", "TOML literal backslash")
    for (bad in ["s=\"\\ud800\"", "s=\"\\U00110000\"", "s=\"\\/\"", "x=+1", "x=1_000", "x=9223372036854775808", "[p]\nx=1\nx=2", "[[p]]\nx=1\nx=2", "[p]\n[[p]]", "[[p]]\n[p]"]) { rejectsToml(bad) }
    for (bad in ["+1", ".1", "-", "00", "1e+", "[true false]", "{\"x\":1,}", "{x:1}", "\"\\u12g4\"", "\"\\ud800\\u1234\""]) { rejectsJson(bad) }
    expect(parseJson("-0").i() == 0, "negative zero")
    expect(parseJson("1e-9999").dump() == "1e-9999", "number lexeme retained")
    expect(J.obj().put("z", J.num(1)).put("a", J.num(2)).dump() == "{\"a\":2,\"z\":1}", "stable object serialization")
    strict = false
    try { J.num(1).s() } catch (_: Exception) { strict = true }
    expect(strict, "s rejects number")
    strict = false
    try { J.str("true").b() } catch (_: Exception) { strict = true }
    expect(strict, "b rejects string")
    var nested = "0"
    for (_ in 0..258) { nested = "[" + nested + "]" }
    rejectsJson(nested)
    let cycle = J.arr(); cycle.add(cycle)
    strict = false
    try { cycle.dump() } catch (_: Exception) { strict = true }
    expect(strict, "cyclic serialization bounded")
    println("PASS native primitives: " + assertionCount.toString() + " assertions; SHA256 vectors, JSON strict parsing/Unicode/types, TOML subset/errors")
    return 0
}
