package leven4cj

// Same-package integration harness; upstream implementation is copied byte-for-byte.
main(): Unit {
    println(leven("kitten", "sitting"))
    println(leven("因为我是中国人所以我会说中文", "因为我是英国人所以我会说英文"))
    println(leven("", "abc"))
}
