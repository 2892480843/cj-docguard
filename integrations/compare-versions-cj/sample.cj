package compareVersions

// Full production scope is compiled; no old upstream types/API calls are rewritten.
main(): Unit {
    println(compareVersions("11.1.1", "10.0.0"))
    println(compareVersions("10.0.0", "10.0.0"))
    println(compareVersions("10.0.0", "11.1.1"))
    println(validateStrict("1.0.0-rc.1"))
    println(validateStrict("1.x"))
}
