package docguard

func assertEvidence(ok: Bool, label: String): Unit {
    if (!ok) { throw Exception("FAIL " + label) }
}
func goodRecord(sequence: Int64): J {
    return J.obj().put("sequence", J.num(sequence)).put("example_id", J.str("add"))
        .put("sdk_version", J.str("1.1.3")).put("platform", J.str("macOS-arm64"))
        .put("status", J.str("RUN_VERIFIED")).put("execution_state", J.str("COMPLETED"))
        .put("project_fingerprint", J.str("project")).put("environment_fingerprint", J.str("environment"))
        .put("compile", J.obj().put("exit_code", J.num(0)).put("timed_out", J.boolean(false))
            .put("interrupted", J.boolean(false)).put("io_error", J.boolean(false)).put("truncated", J.boolean(false)).put("stdout", J.str("")).put("stderr", J.str(""))
            .put("argv", J.arr().add(J.str("cjc"))))
        .put("run", J.obj().put("exit_code", J.num(0)).put("timed_out", J.boolean(false))
            .put("interrupted", J.boolean(false)).put("io_error", J.boolean(false)).put("truncated", J.boolean(false)).put("stdout", J.str("3\n")).put("stderr", J.str(""))
            .put("argv", J.arr().add(J.str("program"))))
        .put("assertions", J.arr().add(J.obj().put("kind", J.str("stdout"))
            .put("expected", J.str("3\n")).put("actual", J.str("3\n")).put("required", J.boolean(true)).put("passed", J.boolean(true))))
}
main(): Int64 {
    assertEvidence(eligible(goodRecord(1), "project", "environment", "1.1.3", "macOS-arm64", true), "complete matching success")
    for (status in ["COMPILE_ONLY", "COMPILE_FAILED", "RUN_FAILED", "ASSERTION_FAILED", "SKIPPED", "ENV_UNAVAILABLE", "UNSUPPORTED", "NOT_RUN"]) {
        let r = goodRecord(1).put("status", J.str(status))
        assertEvidence(!eligible(r, "project", "environment", "1.1.3", "macOS-arm64", true), "reject " + status)
    }
    assertEvidence(!eligible(goodRecord(1), "changed", "environment", "1.1.3", "macOS-arm64", true), "source change")
    assertEvidence(!eligible(goodRecord(1), "project", "changed", "1.1.3", "macOS-arm64", true), "SDK/environment change")
    assertEvidence(!eligible(goodRecord(1), "project", "environment", "1.2.0", "macOS-arm64", true), "SDK mismatch")
    assertEvidence(!eligible(goodRecord(1), "project", "environment", "1.1.3", "Linux-x64", true), "platform mismatch")
    assertEvidence(!eligible(goodRecord(1), "project", "environment", "1.1.3", "macOS-arm64", false), "unknown closure")
    assertEvidence(!eligible(goodRecord(1).put("assertions", J.arr()), "project", "environment", "1.1.3", "macOS-arm64", true), "no assertions")
    let corrupt = goodRecord(1)
    corrupt.get("run").put("truncated", J.boolean(true))
    assertEvidence(!eligible(corrupt, "project", "environment", "1.1.3", "macOS-arm64", true), "truncated log")
    let missingExit = goodRecord(1)
    missingExit.get("run").fields.remove("exit_code")
    assertEvidence(!eligible(missingExit, "project", "environment", "1.1.3", "macOS-arm64", true), "missing runtime exit code")
    let forged = goodRecord(1)
    forged.get("assertions").items[0].put("actual", J.str("wrong"))
    assertEvidence(!eligible(forged, "project", "environment", "1.1.3", "macOS-arm64", true), "passed marker cannot hide actual assertion mismatch")
    let interrupted = goodRecord(1)
    interrupted.get("run").put("interrupted", J.boolean(true))
    assertEvidence(!eligible(interrupted, "project", "environment", "1.1.3", "macOS-arm64", true), "interrupted execution")
    let failed = goodRecord(2).put("status", J.str("RUN_FAILED"))
    let records = J.arr().add(goodRecord(1)).add(failed)
    assertEvidence(latestAttempt(records, "add", "1.1.3").get("sequence").i() == 2, "latest failure wins")
    assertEvidence(!eligible(latestAttempt(records, "add", "1.1.3"), "project", "environment", "1.1.3", "macOS-arm64", true), "never fall back to earlier success")
    let pending = goodRecord(3).put("execution_state", J.str("RUNNING"))
    records.add(pending)
    assertEvidence(!eligible(latestAttempt(records, "add", "1.1.3"), "project", "environment", "1.1.3", "macOS-arm64", true), "pending blocks history")
    records.add(goodRecord(4))
    assertEvidence(eligible(latestAttempt(records, "add", "1.1.3"), "project", "environment", "1.1.3", "macOS-arm64", true), "new success recovers")
    println("PASS native evidence: valid records, stale environments, missing assertions, latest failure/pending precedence")
    return 0
}
