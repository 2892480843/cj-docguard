#!/usr/bin/env python3
"""Capture an actual CJ-DocGuard demonstration in a new, isolated directory."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
SDKS = ("1.1.3", "1.2.0")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare_output(root: Path, output: Path) -> Path:
    base = (root / "build/gap-closure").resolve()
    destination = (output if output.is_absolute() else root / output).resolve()
    if destination == base or not destination.is_relative_to(base):
        raise ValueError("--out must be a new directory under build/gap-closure")
    base.mkdir(parents=True, exist_ok=True)
    destination.mkdir(parents=True, exist_ok=False)
    return destination


def require_query(value: dict, state: str, example: str = "arithmetic") -> None:
    if state == "current":
        assert len(value["items"]) == 1
        assert value["items"][0]["example_id"] == example
        assert value["items"][0]["eligible"] is True
        assert not value["rejected"]
    else:
        assert value["items"] == []
        assert len(value["rejected"]) == 1
        rejected = value["rejected"][0]
        assert rejected["example_id"] == example
        assert rejected["freshness"] == state or rejected["status"] == state


def require_failed_attempt(report: dict, example: str, sdk: str,
                           actual: str, expected: str) -> dict:
    matches = [row for row in report["results"]
               if row["example_id"] == example and row["sdk_version"] == sdk]
    assert matches, f"no {example}/{sdk} attempt"
    latest = max(matches, key=lambda row: row["sequence"])
    assert latest["status"] == "ASSERTION_FAILED", latest["status"]
    assert latest["run"]["stdout"] == actual
    assert any(a["kind"] == "stdout" and a["expected"] == expected
               and a["actual"] == actual and a["passed"] is False
               for a in latest["assertions"])
    return latest


def mcp_command(config: Path, binary: Path) -> list[str]:
    return [sys.executable, str(ROOT / "scripts/mcp_stdio.py"), "--config", str(config),
            "--binary", str(binary)]


class Capture:
    def __init__(self, output: Path, root: Path, environment: dict[str, str]):
        self.output = output
        self.root = root
        self.environment = environment
        self.rows: list[dict] = []

    def run(self, name: str, argv: list[str], expected: int = 0, *,
            stdin: str | None = None, environment: dict[str, str] | None = None) -> str:
        if not name or not all(c.isascii() and (c.isalnum() or c in "-._") for c in name):
            raise ValueError("unsafe capture command name")
        if any(row["name"] == name for row in self.rows):
            raise ValueError(f"duplicate capture command: {name}")
        started = time.monotonic()
        proc = subprocess.run(argv, cwd=self.root, env=environment if environment is not None else self.environment,
                              input=stdin, capture_output=True, text=True, timeout=600)
        (self.output / f"{name}.stdout").write_text(proc.stdout, encoding="utf-8")
        (self.output / f"{name}.stderr").write_text(proc.stderr, encoding="utf-8")
        self.rows.append({"name": name, "command": argv, "cwd": str(self.root),
                          "exit_code": proc.returncode, "expected_exit": expected,
                          "seconds": round(time.monotonic() - started, 3)})
        (self.output / "commands.json").write_text(
            json.dumps(self.rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{name}: exit {proc.returncode} (expected {expected})", flush=True)
        if proc.returncode != expected:
            raise AssertionError(f"unexpected {name} exit: {proc.returncode} != {expected}")
        return proc.stdout


def load_dev():
    spec = importlib.util.spec_from_file_location("dev", ROOT / "scripts/dev.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def capture_demo(output: Path, source_binary: Path) -> None:
    dev = load_dev()
    environment = dev.sdk_env(SDKS[0])
    platform = "-".join(dev.host_identity())
    project = output / "project"
    shutil.copytree(ROOT / "examples/healthy", project,
                    ignore=shutil.ignore_patterns(".docguard", "__pycache__"))
    binary = output / "native-cli"
    shutil.copy2(source_binary, binary)
    config = project / "docguard.toml"
    recorder = Capture(output, ROOT, environment)
    facts: dict = {"platform": platform, "binary_sha256": digest(binary)}

    def cli(name: str, command: str, *args: str, expected: int = 0) -> str:
        return recorder.run(name, [str(binary), command, "--config", str(config), *args], expected)

    def query(name: str, sdk: str = SDKS[0]) -> dict:
        return json.loads(cli(name, "query", "--tool", "get_verified_examples", "--sdk", sdk,
                              "--platform", platform, "--example", "arithmetic"))

    cli("01-doctor", "doctor")
    cli("02-matrix", "verify", "--matrix")
    cli("03-strict", "check", "--strict")
    report = project / ".docguard/report.json"
    initial = json.loads(report.read_text(encoding="utf-8"))
    facts["initial_summary"] = initial["summary"]
    facts["initial_history"] = len(initial["history"])
    current = query("04-current")
    require_query(current, "current")
    facts["current"] = current

    source = project / "src/demo.cj"
    original = source.read_bytes()
    needle, replacement = b"{ a + b }", b"{ a - b }"
    assert original.count(needle) == 1, "arithmetic mutation precondition changed"
    changed = original.replace(needle, replacement)
    source.write_bytes(changed)
    facts["mutation"] = {"before_sha256": hashlib.sha256(original).hexdigest(),
                         "after_sha256": hashlib.sha256(changed).hexdigest(),
                         "before": "public func add(a: Int64, b: Int64): Int64 { a + b }",
                         "after": "public func add(a: Int64, b: Int64): Int64 { a - b }"}
    try:
        stale = query("05-stale-query")
        require_query(stale, "STALE")
        facts["stale"] = stale
        cli("06-stale-strict", "check", "--strict", expected=1)
        cli("07-broken-verify", "verify", "--sdk", SDKS[0], expected=1)
        failed = query("08-failed-query")
        require_query(failed, "ASSERTION_FAILED")
        facts["failed"] = failed
        broken = json.loads(report.read_text(encoding="utf-8"))
        facts["actual_failure"] = require_failed_attempt(
            broken, "arithmetic", SDKS[0], "-2\n", "42\n")
    finally:
        source.write_bytes(original)

    cli("09-restored-matrix", "verify", "--matrix")
    cli("10-restored-strict", "check", "--strict")
    for name, sdk in (("restored", SDKS[0]), ("restored_1_2", SDKS[1])):
        result = query("11-restored-query" if sdk == SDKS[0] else "12-restored-query-1.2.0", sdk)
        require_query(result, "current")
        facts[name] = result
    history = recorder.run("13-history", [str(binary), "history", "--report", str(report),
                                          "--example", "arithmetic"])
    facts["history"] = json.loads(history)

    messages = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-06-18", "capabilities": {},
            "clientInfo": {"name": "demo-capture", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
            "name": "get_verified_examples", "arguments": {
                "sdk": SDKS[0], "platform": platform, "example": "arithmetic"}}},
    ]
    message_text = "\n".join(json.dumps(item, ensure_ascii=False) for item in messages) + "\n"
    (output / "14-mcp.stdin").write_text(message_text, encoding="utf-8")
    replies_text = recorder.run("14-mcp", mcp_command(config, binary), stdin=message_text)
    replies = [json.loads(line) for line in replies_text.splitlines()]
    assert len(replies) == 3 and replies[2]["result"]["isError"] is False
    require_query(replies[2]["result"]["structuredContent"], "current")
    facts["mcp"] = replies

    facts["exports"] = []
    for sdk in SDKS:
        destination = output / "exports" / f"arithmetic-{sdk}"
        cli(f"15-export-{sdk}", "export", "--example", "arithmetic", "--sdk", sdk,
            "--platform", platform, "--out", str(destination))
        replay_env = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "CJ_SDK_HOME": str(dev.sdk_home(sdk))}
        replay = recorder.run(f"16-replay-{sdk}", ["/bin/sh", str(destination / "build.sh")],
                              environment=replay_env)
        assert replay == "42\n", f"unexpected replay output for {sdk}: {replay!r}"
        manifest = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
        facts["exports"].append({"sdk": sdk, "stdout": replay, "manifest": manifest})
        refusal = output / "exports" / f"compile-only-{sdk}"
        cli(f"17-compile-only-refusal-{sdk}", "export", "--example", "compile-only",
            "--sdk", sdk, "--platform", platform, "--out", str(refusal), expected=1)
        assert not refusal.exists()

    final = json.loads(report.read_text(encoding="utf-8"))
    facts["final_summary"] = final["summary"]
    facts["final_history"] = len(final["history"])
    assert facts["final_summary"]["VERIFIED_CURRENT"] == 26
    assert facts["final_history"] == facts["initial_history"] + 42
    assert digest(binary) == facts["binary_sha256"]
    (output / "facts.json").write_text(json.dumps(facts, ensure_ascii=False, indent=2) + "\n",
                                       encoding="utf-8")
    (output / "frozen-report.json").write_bytes(report.read_bytes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True,
                        help="new capture directory under build/gap-closure")
    parser.add_argument("--binary", type=Path, default=ROOT / "build/cj-docguard")
    args = parser.parse_args()
    binary = args.binary.resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        parser.error(f"native CLI is not executable: {binary}")
    output = prepare_output(ROOT, args.out)
    capture_demo(output, binary)
    print(f"capture complete: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
