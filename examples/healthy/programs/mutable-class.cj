package docguard_demo

main(): Unit {
    let counter = Counter(4)
    println(counter.increment())
    println(counter.increment(step: 2))
    counter.reset()
    println(counter.current)
}
