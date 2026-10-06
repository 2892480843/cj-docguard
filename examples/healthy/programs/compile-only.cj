package docguard_demo

// 只验证类型与编译，不登记运行成功。
main(): Unit {
    println(clamp(factorial(5), 0, 100))
}
