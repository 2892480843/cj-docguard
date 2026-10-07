import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("record_demo", ROOT / "scripts/record_demo.py")
record_demo = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(record_demo)


class DemoCaptureControls(unittest.TestCase):
    def test_expected_nonzero_is_recorded_with_raw_logs(self):
        with tempfile.TemporaryDirectory() as directory:
            capture = record_demo.Capture(Path(directory), ROOT, {})
            stdout = capture.run("expected-refusal", [sys.executable, "-c",
                "import sys; print('refused'); print('detail', file=sys.stderr); sys.exit(1)"], expected=1)
            self.assertEqual(stdout, "refused\n")
            row = json.loads((Path(directory) / "commands.json").read_text())[0]
            self.assertEqual((row["exit_code"], row["expected_exit"]), (1, 1))
            self.assertEqual((Path(directory) / "expected-refusal.stdout").read_text(), "refused\n")
            self.assertEqual((Path(directory) / "expected-refusal.stderr").read_text(), "detail\n")

    def test_unexpected_exit_is_recorded_before_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            capture = record_demo.Capture(Path(directory), ROOT, {})
            with self.assertRaisesRegex(AssertionError, "unexpected.*exit"):
                capture.run("bad", [sys.executable, "-c", "raise SystemExit(2)"], expected=1)
            self.assertEqual(json.loads((Path(directory) / "commands.json").read_text())[0]["exit_code"], 2)

    def test_timeout_records_partial_raw_output_and_nonpassing_command(self):
        with tempfile.TemporaryDirectory() as directory:
            capture = record_demo.Capture(Path(directory), ROOT, {})
            child = ("import sys, time; "
                     "sys.stdout.buffer.write(b'partial-out\\xff\\n'); sys.stdout.flush(); "
                     "sys.stderr.buffer.write(b'partial-err\\xfe\\n'); sys.stderr.flush(); "
                     "time.sleep(5)")
            command = [sys.executable, "-c", child]
            with self.assertRaises(subprocess.TimeoutExpired):
                capture.run("timed-out", command, timeout=0.2)
            self.assertEqual((Path(directory) / "timed-out.stdout").read_bytes(), b"partial-out\xff\n")
            self.assertEqual((Path(directory) / "timed-out.stderr").read_bytes(), b"partial-err\xfe\n")
            row = json.loads((Path(directory) / "commands.json").read_text())[0]
            self.assertEqual(row["command"], command)
            self.assertEqual(row["cwd"], str(ROOT))
            self.assertIsNone(row["exit_code"])
            self.assertEqual(row["expected_exit"], 0)
            self.assertEqual(row["timeout_seconds"], 0.2)
            self.assertTrue(row["timed_out"])
            self.assertFalse(row["passed"])
            self.assertGreaterEqual(row["seconds"], 0)

    def test_latest_failed_attempt_must_be_preserved(self):
        report = {"results": [
            {"example_id": "arithmetic", "sdk_version": "1.1.3", "sequence": 1,
             "status": "RUN_VERIFIED"},
            {"example_id": "arithmetic", "sdk_version": "1.1.3", "sequence": 2,
             "status": "ASSERTION_FAILED", "run": {"stdout": "-2\n"},
             "assertions": [{"kind": "stdout", "expected": "42\n", "actual": "-2\n", "passed": False}]},
        ]}
        failed = record_demo.require_failed_attempt(report, "arithmetic", "1.1.3", "-2\n", "42\n")
        self.assertEqual(failed["sequence"], 2)
        report["results"].reverse()
        self.assertEqual(record_demo.require_failed_attempt(report, "arithmetic", "1.1.3", "-2\n", "42\n")["sequence"], 2)
        report["results"].append({"example_id": "arithmetic", "sdk_version": "1.1.3",
                                  "sequence": 3, "status": "RUN_VERIFIED"})
        with self.assertRaises(AssertionError):
            record_demo.require_failed_attempt(report, "arithmetic", "1.1.3", "-2\n", "42\n")

    def test_query_checks_exact_eligibility_and_rejection(self):
        current = {"items": [{"example_id": "arithmetic", "eligible": True}], "rejected": []}
        stale = {"items": [], "rejected": [{"example_id": "arithmetic", "freshness": "STALE"}]}
        record_demo.require_query(current, "current")
        record_demo.require_query(stale, "STALE")
        with self.assertRaises(AssertionError):
            record_demo.require_query({"items": [], "rejected": [{"example_id": "other", "freshness": "STALE"}]}, "STALE")

    def test_output_must_be_new_and_within_build_gap_closure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / "build/gap-closure"
            base.mkdir(parents=True)
            record_demo.prepare_output(root, base / "new")
            with self.assertRaises(FileExistsError):
                record_demo.prepare_output(root, base / "new")
            with self.assertRaises(ValueError):
                record_demo.prepare_output(root, root / "examples/healthy")
            with self.assertRaises(ValueError):
                record_demo.prepare_output(root, root.parent / "outside")
            self.assertEqual(record_demo.prepare_output(root, Path("build/gap-closure/relative")),
                             (base / "relative").resolve())

    def test_mcp_uses_active_interpreter(self):
        self.assertEqual(record_demo.mcp_command(Path("/tmp/config"), Path("/tmp/cli"))[0], sys.executable)


if __name__ == "__main__":
    unittest.main()
