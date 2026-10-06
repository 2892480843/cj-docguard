package docguard_demo

main(): Unit {
    println(divideSafe(12, 3) ?? -1)
    println(divideSafe(12, 0) ?? -1)
}
