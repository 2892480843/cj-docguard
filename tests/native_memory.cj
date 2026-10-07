package docguard

import std.fs.*

// A report-sized JSON array exercises repeated serialization without I/O.
main(): Int64 {
    let row = String.fromUtf8(Array<Byte>(10000, repeat: 97))
    let values = J.arr()
    for (_ in 0..3000) { values.add(J.str(row)) }
    let encoded = values.dump()
    if (encoded.toArray().size != 30009001) { throw Exception("unexpected JSON length") }
    let digest = sha256(encoded.toArray())
    if (digest != "2a78f8f5a0bce00d069f9eb930aac8555ca1e5d48a994ac1f85434da2eec256f") { throw Exception("JSON bytes changed") }
    if (!exists("build/test-results")) { Directory.create("build/test-results", recursive: true) }
    let path = "build/test-results/native-memory-json"
    let small = parseJson("{\"z\":[\"中\\n\",-0,true],\"a\":\"😀\"}")
    writeJsonFile(path, small)
    if (String.fromUtf8(File.readFrom(path)) != small.dump()) { throw Exception("streamed JSON differs") }
    removeIfExists(path)
    println("PASS native memory: " + digest)
    return 0
}
