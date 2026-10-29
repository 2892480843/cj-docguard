"""Protocol unit tests using an explicitly labelled mock native executable.

The fixture validates adapter behavior; it is not SDK/evidence integration proof.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "scripts/mcp_stdio.py"


def request(method, params=None, identifier=1):
    value = {"jsonrpc": "2.0", "id": identifier, "method": method}
    if params is not None:
        value["params"] = params
    return value


INITIALIZE = request("initialize", {
    "protocolVersion": "2025-06-18", "capabilities": {},
    "clientInfo": {"name": "unit-fixture-client", "version": "1.0"},
})
INITIALIZED = {"jsonrpc": "2.0", "method": "notifications/initialized"}


class McpUnitFixtureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cjdg-mcp-unit-")
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.config = self.directory / "project.toml"
        self.config.write_text("# Unit fixture only, not a real verified project\n", encoding="utf-8")
        self.log = self.directory / "fixture-calls.jsonl"
        self.binary = self.directory / "mock-native-unit-fixture"
        self.binary.write_text(
            f"#!{sys.executable}\n"
            "# Unit fixture only: not the native engine or real verification evidence.\n"
            "import json, pathlib, sys\n"
            f"log = pathlib.Path({str(self.log)!r})\n"
            "previous = log.read_text().splitlines() if log.exists() else []\n"
            "with log.open('a') as stream: stream.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            "args = sys.argv[1:]\n"
            "if 'native-fail' in args: print('unit fixture native failure', file=sys.stderr); sys.exit(7)\n"
            "if 'bad-json' in args: print('not JSON'); sys.exit(0)\n"
            "print(json.dumps({'fixture': 'unit only', 'call': len(previous)+1, 'argv': args, 'results': []}))\n",
            encoding="utf-8",
        )
        self.binary.chmod(0o755)

    def run_messages(self, messages, *, binary=None, config=None, raw=False):
        source = messages if raw else "\n".join(json.dumps(m) for m in messages) + "\n"
        proc = subprocess.run(
            [sys.executable, str(ADAPTER), "--binary", str(binary or self.binary),
             "--config", str(config or self.config)],
            input=source.encode(), capture_output=True, timeout=8,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr.decode())
        lines = proc.stdout.decode().splitlines()
        return [json.loads(line) for line in lines]

    def initialized(self, *messages, **kwargs):
        return self.run_messages([INITIALIZE, INITIALIZED, *messages], **kwargs)

    def call(self, name, arguments=None, identifier=2):
        return request("tools/call", {"name": name, "arguments": arguments or {}}, identifier)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_handshake_ping_notifications_and_exact_readonly_tools(self):
        responses = self.initialized(request("ping", identifier="p"), request("tools/list", identifier=3))
        self.assertEqual([r["id"] for r in responses], [1, "p", 3])
        info = responses[0]["result"]
        self.assertEqual(info["protocolVersion"], "2025-06-18")
        self.assertEqual(info["capabilities"], {"tools": {"listChanged": False}})
        self.assertEqual(responses[1]["result"], {})
        tools = responses[2]["result"]["tools"]
        self.assertEqual({t["name"] for t in tools}, {"list_symbols", "get_verified_examples", "get_evidence"})
        for tool in tools:
            self.assertTrue(tool["annotations"]["readOnlyHint"])
            self.assertFalse(tool["inputSchema"]["additionalProperties"])
            if tool["name"] != "list_symbols":
                self.assertEqual(set(tool["inputSchema"]["required"]), {"sdk", "platform"})
        self.assertEqual(self.calls(), [])

    def test_each_call_runs_fresh_native_query_with_fixed_paths(self):
        responses = self.initialized(self.call("list_symbols"), self.call("list_symbols", identifier=3))
        results = [r["result"] for r in responses[1:]]
        self.assertEqual([json.loads(r["content"][0]["text"])["call"] for r in results], [1, 2])
        for result in results:
            self.assertFalse(result["isError"])
        for argv in self.calls():
            self.assertEqual(argv[:5], ["query", "--config", str(self.config.resolve()), "--tool", "list_symbols"])

    def test_sdk_platform_and_literal_symbol_are_forwarded_without_shell(self):
        marker = self.directory / "SHOULD_NOT_EXIST"
        symbol = f"文档函数; touch {marker}; $(echo injection)"
        args = {"symbol": symbol, "example": "demo", "sdk": "1.1.3", "platform": "Darwin-arm64"}
        response = self.initialized(self.call("get_verified_examples", args))[-1]
        self.assertFalse(response["result"]["isError"])
        argv = self.calls()[0]
        self.assertEqual(argv[argv.index("--symbol") + 1], symbol)
        self.assertEqual(argv[argv.index("--sdk") + 1], "1.1.3")
        self.assertEqual(argv[argv.index("--platform") + 1], "Darwin-arm64")
        self.assertFalse(marker.exists())

    def test_unknown_tools_and_mutating_methods_never_execute(self):
        for name in ["verify", "build", "init", "exec", "list_symbols; whoami"]:
            with self.subTest(name=name):
                r = self.initialized(self.call(name))[-1]
                self.assertEqual(r["error"]["code"], -32602)
        r = self.initialized(request("verify", identifier=2))[-1]
        self.assertEqual(r["error"]["code"], -32601)
        self.assertEqual(self.calls(), [])

    def test_arguments_require_exact_environment_and_refuse_path_or_command_override(self):
        invalid = [{}, {"sdk": "1.1.3"}, {"platform": "Darwin-arm64"},
                   {"sdk": "", "platform": "Darwin-arm64"},
                   {"sdk": "1.1.3", "platform": "Darwin-arm64", "config": "/etc/passwd"},
                   {"sdk": "1.1.3", "platform": "Darwin-arm64", "binary": "/bin/sh"},
                   {"sdk": "1.1.3", "platform": "Darwin-arm64", "command": "echo unsafe"}]
        for name in ["get_verified_examples", "get_evidence"]:
            for args in invalid:
                with self.subTest(name=name, args=args):
                    self.assertEqual(self.initialized(self.call(name, args))[-1]["error"]["code"], -32602)
        for symbol in ["--config", "x\x00y", "x\ny", 12, True, "\ud800"]:
            self.assertEqual(self.initialized(self.call("list_symbols", {"symbol": symbol}))[-1]["error"]["code"], -32602)
        self.assertEqual(self.calls(), [])

    def test_missing_binary_and_config_are_clear_tool_errors(self):
        for options, expected in [({"binary": self.directory / "absent"}, "binary"),
                                  ({"config": self.directory / "absent.toml"}, "config")]:
            with self.subTest(options=options):
                result = self.initialized(self.call("list_symbols"), **options)[-1]["result"]
                self.assertTrue(result["isError"])
                self.assertIn(expected, result["content"][0]["text"])
        self.assertEqual(self.calls(), [])

    def test_native_nonzero_and_invalid_json_are_not_success(self):
        for symbol, expected in [("native-fail", "exit 7"), ("bad-json", "JSON")]:
            result = self.initialized(self.call("list_symbols", {"symbol": symbol}))[-1]["result"]
            self.assertTrue(result["isError"])
            self.assertIn(expected, result["content"][0]["text"])

    def test_protocol_validation_and_recovery(self):
        malformed = ["{", '{"jsonrpc":"2.0","id":1,"id":2,"method":"ping"}',
                     '{"jsonrpc":"2.0","id":NaN,"method":"ping"}']
        for source in malformed:
            replies = self.run_messages(source + "\n" + json.dumps(request("ping", identifier=8)) + "\n", raw=True)
            self.assertEqual(replies[0]["error"]["code"], -32700)
            self.assertEqual(replies[1]["result"], {})
        for value in [[], 1, {"jsonrpc": "1.0", "id": 2, "method": "ping"},
                      {"jsonrpc": "2.0", "id": True, "method": "ping"},
                      {"jsonrpc": "2.0", "id": None, "method": "ping"},
                      {"jsonrpc": "2.0", "id": 2, "method": 1}]:
            self.assertEqual(self.run_messages([value])[0]["error"]["code"], -32600)
        self.assertEqual(self.calls(), [])

    def test_initialization_required_and_tool_notifications_do_not_execute(self):
        reply = self.run_messages([request("tools/list")])[0]
        self.assertEqual(reply["error"]["code"], -32002)
        invalid_init = request("initialize", {"protocolVersion": 12}, identifier=2)
        self.assertEqual(self.run_messages([invalid_init])[0]["error"]["code"], -32602)
        notification = {"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "list_symbols", "arguments": {}}}
        responses = self.initialized(notification)
        self.assertEqual(len(responses), 1)
        self.assertEqual(self.calls(), [])

    def test_version_negotiation_duplicate_initialize_and_parameter_shapes(self):
        changed = dict(INITIALIZE, params=dict(INITIALIZE["params"], protocolVersion="2099-01-01"))
        self.assertEqual(self.run_messages([changed])[0]["result"]["protocolVersion"], "2025-06-18")
        self.assertEqual(self.initialized(INITIALIZE)[-1]["error"]["code"], -32600)
        for message in [request("tools/list", {"cursor": "arbitrary"}, 2),
                        request("tools/call", {"name": "list_symbols", "arguments": []}, 2),
                        request("tools/call", {"name": "list_symbols", "arguments": {}, "config": "/tmp/override"}, 2),
                        request("tools/call", [], 2)]:
            self.assertEqual(self.initialized(message)[-1]["error"]["code"], -32602)
        self.assertEqual(self.calls(), [])

    def test_oversize_and_invalid_utf8_are_parse_errors_with_frame_recovery(self):
        source = json.dumps({"x": "a" * (1024 * 1024)}) + "\n" + json.dumps(request("ping", identifier=8)) + "\n"
        replies = self.run_messages(source, raw=True)
        self.assertEqual(replies[0]["error"]["code"], -32700)
        self.assertEqual(replies[1]["result"], {})
        proc = subprocess.run([sys.executable, str(ADAPTER), "--binary", str(self.binary), "--config", str(self.config)],
                              input=b"\xff\n", capture_output=True, timeout=8)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(json.loads(proc.stdout)["error"]["code"], -32700)

    def test_native_environment_does_not_inherit_unrelated_credentials_unit_mock(self):
        spec = importlib.util.spec_from_file_location("mcp_env_test", ADAPTER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        server = module.Server(self.config, self.binary)
        completed = subprocess.CompletedProcess([], 0, stdout=b"{}", stderr=b"")
        with patch.dict(os.environ, {"UNRELATED_SECRET": "unit-only-secret", "CJ_DOCGUARD_SDK_1_1_3": "/unit/sdk", "CJ_DOCGUARD_RUNNER": "/unit/runner", "CJ_DOCGUARD_SYSTEM_SDKROOT": "/unit/system-sdk"}):
            with patch.object(module.subprocess, "run", return_value=completed) as mocked:
                self.assertFalse(server.native_query("list_symbols", {})["isError"])
        environment = mocked.call_args.kwargs["env"]
        self.assertNotIn("UNRELATED_SECRET", environment)
        self.assertEqual(environment["CJ_DOCGUARD_SDK_1_1_3"], "/unit/sdk")
        self.assertEqual(environment["CJ_DOCGUARD_RUNNER"], "/unit/runner")
        self.assertEqual(environment["CJ_DOCGUARD_SYSTEM_SDKROOT"], "/unit/system-sdk")
        self.assertEqual(mocked.call_args.kwargs["stdin"], subprocess.DEVNULL)

    def test_native_timeout_is_tool_error_unit_mock(self):
        spec = importlib.util.spec_from_file_location("mcp_stdio_test", ADAPTER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        server = module.Server(self.config, self.binary)
        with patch.object(module.subprocess, "run", side_effect=subprocess.TimeoutExpired("unit fixture", 30)):
            result = server.native_query("list_symbols", {})
        self.assertTrue(result["isError"])
        self.assertIn("timeout", result["content"][0]["text"])


class NativeMcpIntegrationTests(unittest.TestCase):
    """Actual native CLI query only; never run verify through MCP."""
    def test_real_native_query_registered_runner_and_exact_environment_filters(self):
        binary = ROOT / "build/cj-docguard"
        if not binary.is_file():
            self.fail("build the actual native binary before running integration tests")
        spec = importlib.util.spec_from_file_location("docguard_dev_for_mcp", ROOT / "scripts/dev.py")
        dev = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(dev)
        try:
            environment = dev.sdk_env("1.1.3")
        except RuntimeError as exc:
            self.skipTest(str(exc))
        temporary = tempfile.TemporaryDirectory(prefix="docguard-mcp-real-")
        self.addCleanup(temporary.cleanup)
        project = Path(temporary.name)
        # Install the supplied guide only inside this isolated integration project.
        # This checks the documented file workflow, not an AI model's behaviour.
        installed_skill = project / ".assistant/skills/cj-docguard/SKILL.md"
        installed_skill.parent.mkdir(parents=True)
        installed_skill.write_bytes((ROOT / "skills/cj-docguard/SKILL.md").read_bytes())
        self.assertIn("get_verified_examples", installed_skill.read_text(encoding="utf-8"))
        (project / "lib.cj").write_text("package demo\npublic func add(a: Int64, b: Int64): Int64 { a+b }\n", encoding="utf-8")
        (project / "example.cj").write_text("package demo\nmain(): Int64 { println(add(1,2)); return 0 }\n", encoding="utf-8")
        config = project / "docguard.toml"
        config.write_text('[project]\nname="MCP real integration"\nsources=["lib.cj"]\ndocuments=[]\noutput=".docguard"\ntrusted=true\nclosed_inputs=true\n[[sdks]]\nversion="1.1.3"\n[[examples]]\nid="add"\nfile="example.cj"\nsymbol="add"\nstdout="3\\n"\nexpected_exit=0\n', encoding="utf-8")
        # Explicit audited test setup uses CLI; the MCP server itself stays read-only.
        setup = subprocess.run([str(binary), "verify", "--config", str(config)], env=environment,
                               capture_output=True, text=True, timeout=90)
        self.assertEqual(setup.returncode, 0, setup.stdout + setup.stderr)
        platform = subprocess.check_output(["/usr/bin/uname", "-s"], text=True).strip() + "-" + subprocess.check_output(["/usr/bin/uname", "-m"], text=True).strip()
        messages = [INITIALIZE, INITIALIZED,
                    request("tools/call", {"name": "list_symbols", "arguments": {"symbol": "add"}}, 2),
                    request("tools/call", {"name": "get_verified_examples", "arguments": {"sdk": "1.1.3", "platform": platform}}, 3),
                    request("tools/call", {"name": "get_evidence", "arguments": {"sdk": "1.1.3", "platform": "wrong-platform"}}, 4),
                    request("tools/call", {"name": "get_verified_examples", "arguments": {"sdk": "1.2.0", "platform": platform}}, 5)]
        process = subprocess.run([sys.executable, str(ADAPTER), "--config", str(config), "--binary", str(binary)],
                                 input="\n".join(json.dumps(m) for m in messages) + "\n",
                                 capture_output=True, text=True, env=environment, timeout=90)
        self.assertEqual(process.returncode, 0, process.stderr)
        responses = [json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual([r["id"] for r in responses], [1, 2, 3, 4, 5])
        for response in responses[1:4]:
            self.assertFalse(response["result"]["isError"], response)
        symbols = json.loads(responses[1]["result"]["content"][0]["text"])
        self.assertTrue(symbols["items"])
        self.assertTrue(all(s["name"] == "add" for s in symbols["items"]))
        verified = json.loads(responses[2]["result"]["content"][0]["text"])
        self.assertEqual((verified["sdk_version"], verified["platform"]), ("1.1.3", platform))
        self.assertEqual(len(verified["items"]), 1, "must prove a positive current result, not a vacuous empty filter")
        for record in verified["items"]:
            self.assertEqual((record["sdk_version"], record["platform"]), ("1.1.3", platform))
            self.assertEqual((record["status"], record["freshness"]), ("RUN_VERIFIED", "CURRENT"))
            self.assertTrue(record["eligible"])
        wrong = json.loads(responses[3]["result"]["content"][0]["text"])
        self.assertEqual(wrong["items"], [])
        self.assertEqual(wrong["platform"], "wrong-platform")
        self.assertTrue(responses[4]["result"]["isError"])
        self.assertIn("selected SDK is not declared", responses[4]["result"]["content"][0]["text"])

        def current_examples():
            exchange = [INITIALIZE, INITIALIZED, request("tools/call", {
                "name": "get_verified_examples", "arguments": {"sdk": "1.1.3", "platform": platform}
            }, 2)]
            result = subprocess.run([sys.executable, str(ADAPTER), "--config", str(config), "--binary", str(binary)],
                                    input="\n".join(json.dumps(m) for m in exchange) + "\n",
                                    capture_output=True, text=True, env=environment, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr)
            response = json.loads(result.stdout.splitlines()[-1])["result"]
            self.assertFalse(response["isError"], response)
            return json.loads(response["content"][0]["text"])

        library = project / "lib.cj"
        original = library.read_text(encoding="utf-8")
        library.write_text(original.replace("a+b", "a-b"), encoding="utf-8")
        self.assertEqual(current_examples()["items"], [], "MCP must refuse evidence after a project edit")
        failed = subprocess.run([str(binary), "verify", "--config", str(config)], env=environment,
                                capture_output=True, text=True, timeout=90)
        self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
        self.assertEqual(current_examples()["items"], [], "a new assertion failure cannot revive old success")
        library.write_text(original, encoding="utf-8")
        self.assertEqual(current_examples()["items"], [], "restoring input still cannot hide a newer failure")
        restored = subprocess.run([str(binary), "verify", "--config", str(config)], env=environment,
                                  capture_output=True, text=True, timeout=90)
        self.assertEqual(restored.returncode, 0, restored.stdout + restored.stderr)
        self.assertEqual(len(current_examples()["items"]), 1, "only actual re-verification restores evidence")


if __name__ == "__main__":
    unittest.main()
