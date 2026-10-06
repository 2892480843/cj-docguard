package docguard

func eligible(record: J, projectFingerprint: String, environmentFingerprint: String,
              sdk: String, platform: String, closure: Bool): Bool {
    try {
        if (!closure || projectFingerprint.isEmpty() || environmentFingerprint.isEmpty()) { return false }
        if (record.get("status").s() != "RUN_VERIFIED" || record.get("execution_state").s() != "COMPLETED") { return false }
        if (record.get("project_fingerprint").s() != projectFingerprint || record.get("environment_fingerprint").s() != environmentFingerprint) { return false }
        if (record.get("sdk_version").s() != sdk || record.get("platform").s() != platform) { return false }
        if (record.get("compile").get("exit_code").i() != 0) { return false }
        for (stage in [record.get("compile"), record.get("run")]) {
            stage.get("exit_code").i()
            if (stage.get("timed_out").b() || stage.get("truncated").b() || stage.get("interrupted").b() || stage.get("io_error").b()) { return false }
            if (stage.get("stdout").kind != "string" || stage.get("stderr").kind != "string" || stage.get("argv").items.size == 0) { return false }
        }
        var required = 0
        for (assertion in record.get("assertions").items) {
            if (assertion.get("required").b()) {
                required++
                if (!assertion.get("passed").b() || assertion.get("expected").kind == "null" || assertion.get("expected").dump() != assertion.get("actual").dump()) { return false }
            }
        }
        return required > 0
    } catch (_: Exception) { return false }
}

func latestAttempt(records: J, exampleId: String, sdk: String): J {
    var latest = J.nil()
    var highest: Int64 = -1
    for (record in records.items) {
        if (record.get("example_id").s() == exampleId && record.get("sdk_version").s() == sdk) {
            let seq = record.get("sequence").i()
            if (seq > highest) { highest = seq; latest = record }
        }
    }
    return latest
}

func freshness(record: J, projectFingerprint: String, environmentFingerprint: String, closure: Bool): String {
    if (record.kind == "null") { return "UNKNOWN_CURRENT" }
    if (projectFingerprint.isEmpty() || environmentFingerprint.isEmpty() || !closure) { return "UNKNOWN_CURRENT" }
    if (record.get("project_fingerprint").s() != projectFingerprint || record.get("environment_fingerprint").s() != environmentFingerprint) { return "STALE" }
    return "CURRENT"
}
