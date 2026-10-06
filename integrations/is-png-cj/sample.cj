package is_png_cj

// Header recognition is tested; this does not prove full PNG decoding or validity.
main(): Unit {
    let png: Array<Byte> = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    let short: Array<Byte> = [0x89, 0x50, 0x4E, 0x47]
    let wrong: Array<Byte> = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0]
    println(isPng(png))
    println(isPng(short))
    println(isPng(wrong))
}
