package docguard

// Resolve against the complete catalog: a file-local match is insufficient for
// members, overloads and packages spread across source files.
func bindingText(value: J, key: String): String {
    let field = if (value.kind == "object") { value.get(key) } else { J.nil() }
    return if (field.kind == "string") { field.s() } else { "" }
}
func resolveBinding(symbols: J, reference: String): J {
    let matches = J.arr()
    for (symbol in symbols.items) {
        let name = bindingText(symbol, "name")
        let pack = bindingText(symbol, "package")
        let owner = bindingText(symbol, "owner")
        let owned = if (owner.isEmpty()) { name } else { owner + "." + name }
        if (!reference.isEmpty() && (reference == bindingText(symbol, "id") || reference == name ||
            reference == pack + "." + name || reference == owned || reference == pack + "." + owned)) {
            matches.add(symbol.get("id"))
        }
    }
    let status = if (matches.items.size == 1) { "RESOLVED" } else if (matches.items.size == 0) { "UNKNOWN" } else { "AMBIGUOUS" }
    return J.obj().put("reference", J.str(reference)).put("status", J.str(status)).put("candidates", matches)
        .put("symbol_id", if (matches.items.size == 1) { matches.items[0] } else { J.nil() })
}
func bindExamples(api: J, examples: J): Unit {
    let bindings = J.arr()
    for (symbol in api.get("symbols").items) { symbol.put("examples", J.arr()) }
    for (example in examples.items) {
        let binding = resolveBinding(api.get("symbols"), bindingText(example, "symbol"))
        binding.put("example_id", example.get("id"))
        bindings.add(binding)
        if (binding.get("status").s() == "RESOLVED") {
            for (symbol in api.get("symbols").items) {
                if (symbol.get("id").s() == binding.get("symbol_id").s()) {
                    // Never mutate configuration: its canonical bytes are fingerprinted.
                    symbol.get("examples").add(parseJson(example.dump()).put("symbol_id", binding.get("symbol_id")))
                }
            }
        } else {
            api.get("diagnostics").add(J.obj().put("code", J.str("EXAMPLE_SYMBOL_" + binding.get("status").s()))
                .put("severity", J.str("error")).put("source", example.get("file"))
                .put("example_id", example.get("id")).put("reference", binding.get("reference"))
                .put("candidates", binding.get("candidates"))
                .put("message", J.str("Example symbol must resolve uniquely; use an owner-qualified name or exact s-ID")))
        }
    }
    api.put("bindings", bindings)
}
func bindingRecordCurrent(binding: J, record: J): Bool {
    return bindingText(binding, "status") == "RESOLVED" && bindingText(record, "binding_status") == "RESOLVED" &&
        bindingText(record, "symbol_id") == bindingText(binding, "symbol_id") &&
        bindingText(record, "symbol") == bindingText(binding, "reference")
}
