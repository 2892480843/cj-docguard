#!/usr/bin/env python3
"""Frozen paired pilot: prepare, generate once per cell, score with real Cangjie SDK."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
TASKS = ROOT / "integrations/ai-evaluation/tasks.json"
PROTOCOL = ROOT / "integrations/ai-evaluation/protocol.md"
MODEL = "gpt-6.1-sol"
EFFORT = "low"
SEED = 20261007
SIGNATURE = "public func answer(a: Int64, b: Int64): String"
SDK_VERSION = "1.1.3"
PLATFORM = "Darwin-arm64"
CODEX = Path("/opt/homebrew/bin/codex")
SCHEMA = {"type": "object", "properties": {"source": {"type": "string"}},
          "required": ["source"], "additionalProperties": False}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_dev():
    spec = importlib.util.spec_from_file_location("ai_dev", ROOT / "scripts/dev.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sdk_environment(run_dir: Path) -> dict[str, str]:
    env = load_dev().sdk_env(SDK_VERSION)
    env["CJ_DOCGUARD_RUNNER"] = str(run_dir / "cjdg-runner")
    return env


def build_prompt(task: dict, context: str) -> str:
    # Whitelist fields: identity, reference implementation and hidden scoring stay local.
    return ("Implement this Cangjie function against the public library declarations below.\n"
            "Return JSON with exactly one field, source, containing only one complete function.\n"
            "Do not include package, import, main, additional functions, interface definitions, "
            "code fences, or explanations. Use the named existing library APIs.\n\n"
            "Public library context:\n" + context + "\n\n"
            "Task: " + task["request"] + "\n"
            "Required function signature: " + task["signature"] + "\n")


def strip_comments_strings(source: str) -> str:
    """Mask literals/comments while retaining executable string interpolation."""
    out, i, n = [], 0, len(source)
    strings: list[str] = []
    interpolations: list[int] = []
    in_string = False
    while i < n:
        if in_string:
            if source[i] == "\\":
                j = min(i + 2, n)
                out.extend(" " * (j - i)); i = j
            elif strings[-1] == '"' and source.startswith("${", i):
                out.extend("  "); i += 2
                interpolations.append(1); in_string = False
            elif source[i] == strings[-1]:
                out.append(" "); i += 1
                strings.pop(); in_string = False
            else:
                out.append("\n" if source[i] == "\n" else " "); i += 1
        elif source.startswith("//", i):
            j = source.find("\n", i)
            if j < 0:
                j = n
            out.extend(" " * (j - i)); i = j
        elif source.startswith("/*", i):
            j = source.find("*/", i + 2)
            if j < 0:
                return ""
            j += 2
            out.extend("\n" if c == "\n" else " " for c in source[i:j]); i = j
        elif source[i] in ('"', "'"):
            strings.append(source[i]); in_string = True
            out.append(" "); i += 1
        elif interpolations and source[i] == "{":
            interpolations[-1] += 1
            out.append("{"); i += 1
        elif interpolations and source[i] == "}":
            interpolations[-1] -= 1
            if interpolations[-1] == 0:
                interpolations.pop(); out.append(" "); in_string = True
            else:
                out.append("}")
            i += 1
        else:
            out.append(source[i]); i += 1
    if strings or interpolations:
        return ""
    return "".join(out)


def candidate_issue(source: str, task: dict) -> str | None:
    if not isinstance(source, str) or len(source) > 16000:
        return "invalid source type or size"
    clean = strip_comments_strings(source)
    prefix = re.match(r"^\s*public\s+func\s+answer\s*\(\s*a\s*:\s*Int64\s*,\s*b\s*:\s*Int64\s*\)\s*:\s*String\s*\{", clean)
    if not prefix:
        return "missing required single answer signature"
    depth, end = 0, None
    for i in range(prefix.end() - 1, len(clean)):
        if clean[i] == "{":
            depth += 1
        elif clean[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1; break
            if depth < 0:
                break
    if end is None or clean[end:].strip():
        return "extra top-level content or unbalanced function"
    body = clean[prefix.end():end - 1]
    for symbol in task["required_symbols"]:
        if not re.search(r"\b" + re.escape(symbol) + r"\b", body):
            return "required API token missing: " + symbol
    if re.search(r"\b(?:package|import|main|extern|foreign)\b", clean):
        return "forbidden declaration or operation"
    return None


def has_tool_event(events: list[dict]) -> bool:
    allowed_items = {"agent_message", "reasoning"}
    for event in events:
        if event.get("type", "").startswith("item."):
            item = event.get("item") or {}
            if item.get("type") not in allowed_items:
                return True
    return False


def summarize(tasks: list[dict], scores: dict[tuple[str, str], dict]) -> dict:
    n = len(tasks)
    result = {}
    for arm in ("base", "evidence"):
        success = sum(bool(scores.get((t["id"], arm), {}).get("success",
                            scores.get((t["id"], arm), {}).get("functional_success", False))) for t in tasks)
        functional = sum(bool(scores.get((t["id"], arm), {}).get("functional_success", False)) for t in tasks)
        result[arm] = {"denominator": n, "successes": success, "rate": success / n,
                       "functional_successes": functional}
    paired = {"both_success": 0, "both_fail": 0, "base_only": 0, "evidence_only": 0}
    for task in tasks:
        def passed(arm):
            cell = scores.get((task["id"], arm), {})
            return bool(cell.get("success", cell.get("functional_success", False)))
        b, e = passed("base"), passed("evidence")
        paired["both_success" if b and e else "both_fail" if not b and not e
               else "base_only" if b else "evidence_only"] += 1
    result["paired"] = paired
    result["difference_pp"] = 100 * (result["evidence"]["rate"] - result["base"]["rate"])
    return result


def mcp_query(run_dir: Path) -> tuple[dict, dict]:
    command = [sys.executable, str(ROOT / "scripts/mcp_stdio.py"),
               "--config", str(run_dir / "healthy/docguard.toml"),
               "--binary", str(run_dir / "cj-docguard")]
    messages = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-06-18", "capabilities": {},
            "clientInfo": {"name": "ai-pilot", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {
            "name": "list_symbols", "arguments": {}}},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
            "name": "get_verified_examples", "arguments": {"sdk": SDK_VERSION, "platform": PLATFORM}}},
    ]
    write_json(run_dir / "context-query-command.json", {"command": command, "messages": messages})
    completed = subprocess.run(command, input="".join(json.dumps(x) + "\n" for x in messages),
                               cwd=run_dir, env=sdk_environment(run_dir), text=True,
                               capture_output=True, timeout=180)
    (run_dir / "context-query.stdout").write_text(completed.stdout, encoding="utf-8")
    (run_dir / "context-query.stderr").write_text(completed.stderr, encoding="utf-8")
    if completed.returncode:
        raise RuntimeError("MCP context query failed")
    responses = {x["id"]: x for x in map(json.loads, completed.stdout.splitlines()) if "id" in x}
    for identifier in (2, 3):
        result = responses[identifier]["result"]
        if result.get("isError"):
            raise RuntimeError("MCP context query returned isError")
    return responses[2]["result"]["structuredContent"], responses[3]["result"]["structuredContent"]


def prepare(run_dir: Path) -> None:
    if (run_dir / "lock.json").exists():
        raise RuntimeError("run already locked")
    if (run_dir / "health.exit").read_text().strip() != "0":
        raise RuntimeError("isolated health matrix did not pass")
    tasks_doc = read_json(TASKS); tasks = tasks_doc["tasks"]
    if len(tasks) != 30 or len({t["id"] for t in tasks}) != 30:
        raise RuntimeError("pre-registered task count or IDs changed")
    if digest(TASKS) != "5cd183feb4c488aeaedfbc727c248ab4b95748e1ddef2bf395350a579b17745f":
        raise RuntimeError("pre-registered tasks digest changed")
    symbols, examples = mcp_query(run_dir)
    if len(examples.get("items", [])) != 13 or not all(x.get("eligible") for x in examples["items"]):
        raise RuntimeError("SDK 1.1.3 current run examples are not all eligible")
    public = [{key: item[key] for key in ("declaration", "comment", "owner", "name", "kind") if key in item}
              for item in symbols["items"]]
    if len(public) != 47:
        raise RuntimeError("public symbol count changed")
    base = json.dumps(public, ensure_ascii=False, indent=2)
    evidence_items = []
    for item in examples["items"]:
        evidence_items.append({"example_id": item["example_id"], "symbol": item["symbol"],
                               "code": item["code"],
                               "expected_assertions": [{"kind": a["kind"], "expected": a["expected"]}
                                                       for a in item["assertions"] if a.get("required")]})
    evidence = base + "\n\nCurrent verified examples for macOS arm64 / SDK 1.1.3:\n" + json.dumps(
        evidence_items, ensure_ascii=False, indent=2)
    (run_dir / "context-base.txt").write_text(base, encoding="utf-8")
    (run_dir / "context-evidence.txt").write_text(evidence, encoding="utf-8")
    write_json(run_dir / "response-schema.json", SCHEMA)
    cells = [{"task_id": t["id"], "arm": arm} for t in tasks for arm in ("base", "evidence")]
    random.Random(SEED).shuffle(cells)
    prompts = run_dir / "prompts"; prompts.mkdir()
    for cell in cells:
        task = next(t for t in tasks if t["id"] == cell["task_id"])
        name = cell["task_id"] + "--" + cell["arm"]
        context = base if cell["arm"] == "base" else evidence
        (prompts / (name + ".txt")).write_text(build_prompt(task, context), encoding="utf-8")
    sdk = load_dev().sdk_home(SDK_VERSION)
    paths = {"script": Path(__file__), "tasks": TASKS, "protocol": PROTOCOL,
             "native_cli": run_dir / "cj-docguard", "native_runner": run_dir / "cjdg-runner",
             "sdk_cjc": sdk / "bin/cjc", "library": run_dir / "healthy/src/demo.cj",
             "health_report": run_dir / "healthy/.docguard/report.json",
             "base_context": run_dir / "context-base.txt", "evidence_context": run_dir / "context-evidence.txt",
             "response_schema": run_dir / "response-schema.json", "codex_cli": CODEX}
    lock = {"locked_at": now(), "model": MODEL, "reasoning_effort": EFFORT, "seed": SEED,
            "sdk": SDK_VERSION, "platform": PLATFORM, "generation_timeout_seconds": 180,
            "compile_timeout_seconds": 180, "run_timeout_seconds": 10,
            "cells": cells, "hashes": {k: digest(v) for k, v in paths.items()},
            "paths": {k: str(v.resolve()) for k, v in paths.items()},
            "prompts": {p.stem: digest(p) for p in prompts.glob("*.txt")},
            "codex_command_template": [str(CODEX), "exec", "--ignore-user-config", "--ephemeral",
                 "--skip-git-repo-check", "--sandbox", "read-only", "--color", "never", "-C", "<cell-empty-cwd>",
                 "-c", 'model="gpt-6.1-sol"', "-c", 'model_reasoning_effort="low"',
                 "-o", "<cell-response>", "--json", "--output-schema", str(run_dir / "response-schema.json"), "-"]}
    write_json(run_dir / "lock.json", lock)
    print("LOCKED", run_dir, flush=True)


def check_lock(run_dir: Path, revised_scorer: bool = False) -> dict:
    lock = read_json(run_dir / "lock.json")
    for key, expected in lock["hashes"].items():
        path = run_dir / "scorer-original.py" if revised_scorer and key == "script" else Path(lock["paths"][key])
        if digest(path) != expected:
            raise RuntimeError("locked file changed: " + key)
    for name, expected in lock["prompts"].items():
        if digest(run_dir / "prompts" / (name + ".txt")) != expected:
            raise RuntimeError("locked prompt changed: " + name)
    return lock


def generate(run_dir: Path) -> None:
    lock = check_lock(run_dir)
    for index, cell in enumerate(lock["cells"], 1):
        name = cell["task_id"] + "--" + cell["arm"]
        cell_dir = run_dir / "cells" / name
        if cell_dir.exists():
            raise RuntimeError("generation cell already exists: " + name)
        cell_dir.mkdir(parents=True)
        empty = cell_dir / "empty-cwd"; empty.mkdir()
        response = cell_dir / "response.json"
        command = [str(CODEX), "exec", "--ignore-user-config", "--ephemeral",
                   "--skip-git-repo-check", "--sandbox", "read-only", "--color", "never",
                   "-C", str(empty), "-c", 'model="gpt-6.1-sol"',
                   "-c", 'model_reasoning_effort="low"', "-o", str(response), "--json",
                   "--output-schema", str(run_dir / "response-schema.json"), "-"]
        write_json(cell_dir / "generation-command.json", command)
        started = now(); start = time.monotonic()
        status = "completed"; exit_code = None
        try:
            with (run_dir / "prompts" / (name + ".txt")).open("rb") as stdin, \
                 (cell_dir / "events.jsonl").open("wb") as stdout, \
                 (cell_dir / "generation.stderr").open("wb") as stderr:
                proc = subprocess.run(command, cwd=empty, stdin=stdin, stdout=stdout,
                                      stderr=stderr, timeout=180, check=False)
                exit_code = proc.returncode
        except subprocess.TimeoutExpired:
            status = "timeout"
        except OSError as exc:
            status = "start_error"
            (cell_dir / "start-error.txt").write_text(str(exc), encoding="utf-8")
        write_json(cell_dir / "generation.json", {"started_at": started, "ended_at": now(),
                   "elapsed_seconds": round(time.monotonic() - start, 3), "exit_code": exit_code,
                   "status": status, "task_id": cell["task_id"], "arm": cell["arm"]})
        print(index, "/60", name, status, exit_code, flush=True)


def runner_command(run_dir: Path, cell_dir: Path, stage: str, timeout_ms: int, program: list[str], env: dict) -> dict:
    stage_dir = cell_dir / stage; stage_dir.mkdir()
    command = [str(run_dir / "cjdg-runner"), str(timeout_ms), "1048576", str(cell_dir),
               str(stage_dir / "stdout"), str(stage_dir / "stderr"), str(stage_dir / "result.json"),
               "--", *program]
    write_json(stage_dir / "command.json", command)
    try:
        proc = subprocess.run(command, cwd=cell_dir, env=env, capture_output=True, timeout=timeout_ms / 1000 + 10)
        (stage_dir / "supervisor.stdout").write_bytes(proc.stdout)
        (stage_dir / "supervisor.stderr").write_bytes(proc.stderr)
        if proc.returncode or not (stage_dir / "result.json").exists():
            return {"supervisor_exit": proc.returncode, "exit_code": None, "error": "supervisor failed"}
        return {"supervisor_exit": proc.returncode, **read_json(stage_dir / "result.json")}
    except subprocess.TimeoutExpired:
        return {"supervisor_exit": None, "exit_code": None, "error": "supervisor timeout"}


def render_input(value: int) -> str:
    return "Int64.Min" if value == -(2 ** 63) else str(value)


def score(run_dir: Path) -> None:
    lock = check_lock(run_dir)
    tasks = {t["id"]: t for t in read_json(TASKS)["tasks"]}
    sdk = load_dev().sdk_home(SDK_VERSION)
    env = sdk_environment(run_dir)
    scores = {}
    for index, cell in enumerate(lock["cells"], 1):
        name = cell["task_id"] + "--" + cell["arm"]
        cell_dir = run_dir / "cells" / name
        task = tasks[cell["task_id"]]
        result = {"task_id": cell["task_id"], "arm": cell["arm"], "success": False,
                  "functional_success": False, "api_use_pass": False}
        try:
            generation = read_json(cell_dir / "generation.json")
            if generation["status"] != "completed" or generation["exit_code"] != 0:
                raise ValueError("generation failure: " + generation["status"] + "/" + str(generation["exit_code"]))
            events = [json.loads(line) for line in (cell_dir / "events.jsonl").read_text(encoding="utf-8").splitlines()]
            if has_tool_event(events):
                raise ValueError("tool event during generation")
            payload = read_json(cell_dir / "response.json")
            if not isinstance(payload, dict) or set(payload) != {"source"} or not isinstance(payload["source"], str):
                raise ValueError("invalid response schema")
            source = payload["source"]
            (cell_dir / "candidate.cj.txt").write_text(source, encoding="utf-8")
            issue = candidate_issue(source, task)
            if issue:
                raise ValueError("candidate structure/API token: " + issue)
            result["api_use_pass"] = True  # Lexical gate; later manual audit is separate.
            driver = ("package docguard_demo\n\n" + source + "\n\nmain(): Unit {\n" +
                      "".join("    println(answer(" + render_input(a) + ", " + render_input(b) + "))\n"
                              for a, b in task["hidden_inputs"]) + "}\n")
            (cell_dir / "scoring.cj").write_text(driver, encoding="utf-8")
            binary = cell_dir / "candidate-bin"
            compile_cmd = [str(sdk / "bin/cjc"), str(run_dir / "healthy/src/demo.cj"),
                           str(cell_dir / "scoring.cj"), "-O2", "-Woff", "unused", "-o", str(binary)]
            result["compile"] = runner_command(run_dir, cell_dir, "compile", 180000, compile_cmd, env)
            if result["compile"].get("exit_code") != 0 or result["compile"].get("timed_out") or result["compile"].get("truncated"):
                raise ValueError("compile failed")
            result["run"] = runner_command(run_dir, cell_dir, "run", 10000, [str(binary)], env)
            if result["run"].get("exit_code") != 0 or result["run"].get("timed_out") or result["run"].get("truncated"):
                raise ValueError("run failed")
            stdout = (cell_dir / "run/stdout").read_text(encoding="utf-8")
            stderr = (cell_dir / "run/stderr").read_text(encoding="utf-8")
            result["stdout_matches"] = stdout == task["expected_stdout"]
            result["stderr_empty"] = not stderr
            result["functional_success"] = result["stdout_matches"] and result["stderr_empty"]
            result["success"] = result["functional_success"] and result["api_use_pass"]
            if not result["success"]:
                raise ValueError("output or stderr mismatch")
            result["reason"] = "pass"
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
            result["reason"] = str(exc)
        write_json(cell_dir / "score.json", result)
        scores[(cell["task_id"], cell["arm"])] = result
        print(index, "/60", name, result["reason"], flush=True)
    write_json(run_dir / "summary.json", summarize(list(tasks.values()), scores))


def reconcile(run_dir: Path) -> None:
    """Reapply the unchanged criteria to stored candidates after a lexer bug fix."""
    lock = check_lock(run_dir, revised_scorer=True)
    tasks = {t["id"]: t for t in read_json(TASKS)["tasks"]}
    corrected = {}
    for cell in lock["cells"]:
        name = cell["task_id"] + "--" + cell["arm"]
        directory = run_dir / "cells" / name
        task = tasks[cell["task_id"]]
        original = read_json(directory / "score.json")
        generation = read_json(directory / "generation.json")
        events = [json.loads(line) for line in (directory / "events.jsonl").read_text(encoding="utf-8").splitlines()]
        payload = read_json(directory / "response.json")
        source = payload.get("source") if isinstance(payload, dict) else None
        issue = candidate_issue(source, task)
        supplemental = run_dir / "supplemental" / name / "result.json"
        functional = read_json(supplemental) if supplemental.exists() else original
        compile_result = functional.get("compile", {})
        run_result = functional.get("run", {})
        functional_pass = bool(compile_result.get("exit_code") == 0 and not compile_result.get("timed_out")
                               and not compile_result.get("truncated") and run_result.get("exit_code") == 0
                               and not run_result.get("timed_out") and not run_result.get("truncated")
                               and functional.get("stdout_matches") and functional.get("stderr_empty"))
        tool = has_tool_event(events)
        passed = bool(generation["status"] == "completed" and generation["exit_code"] == 0
                      and issue is None and not tool and functional_pass)
        corrected[(cell["task_id"], cell["arm"])] = {
            "task_id": cell["task_id"], "arm": cell["arm"], "success": passed,
            "functional_success": functional_pass, "api_lexical_issue": issue,
            "tool_event": tool, "generation_exit_code": generation["exit_code"],
            "functional_evidence": str(supplemental.relative_to(run_dir)) if supplemental.exists()
                                   else str((directory / "score.json").relative_to(run_dir)),
            "original_score": str((directory / "score.json").relative_to(run_dir)),
        }
    write_json(run_dir / "corrected-scores.json", {
        "original_scorer_sha256": lock["hashes"]["script"], "corrected_scorer_sha256": digest(Path(__file__)),
        "reason": "String interpolation expressions are executable Cangjie code; original lexer masked them.",
        "cells": list(corrected.values()), "summary": summarize(list(tasks.values()), corrected),
    })


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("prepare", "generate", "score", "reconcile"))
    parser.add_argument("run_dir", type=Path)
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    {"prepare": prepare, "generate": generate, "score": score,
     "reconcile": reconcile}[args.phase](run_dir)


if __name__ == "__main__":
    main()
