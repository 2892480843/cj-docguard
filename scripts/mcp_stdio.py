#!/usr/bin/env python3
"""Read-only MCP stdio bridge to the native CJ-DocGuard query command.

Protocol references (version intentionally pinned, not a claim of latest support):
https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle
https://modelcontextprotocol.io/specification/2025-06-18/server/tools
https://www.jsonrpc.org/specification

Project/config and executable are operator-controlled startup options, never tool
arguments. Every accepted call executes a new native query; no report cache or
Python evidence eligibility logic is used. Unit fixtures are not native evidence.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

PROTOCOL_VERSION = "2025-06-18"
MAX_LINE_BYTES = 1024 * 1024
MAX_NATIVE_OUTPUT = 16 * 1024 * 1024
QUERY_TIMEOUT = 30
FILTERS = ("symbol", "example", "sdk", "platform")
TOOL_NAMES = ("list_symbols", "get_verified_examples", "get_evidence")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError("nonfinite JSON number")


def finite_float(value):
    number = float(value)
    if not math.isfinite(number):
        raise ValueError("nonfinite JSON number")
    return number


def strict_json(source):
    return json.loads(source, object_pairs_hook=unique_object, parse_constant=reject_constant,
                      parse_float=finite_float)


def error(identifier, code, message):
    return {"jsonrpc": "2.0", "id": identifier, "error": {"code": code, "message": message}}


def result(identifier, value):
    return {"jsonrpc": "2.0", "id": identifier, "result": value}


def tool_error(message):
    return {"content": [{"type": "text", "text": message}], "isError": True}


def valid_filter(value):
    if not isinstance(value, str) or not value.strip() or len(value) > 1024 or value.startswith("-"):
        return False
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        return False
    try:
        value.encode("utf-8", errors="strict")
    except UnicodeError:
        return False
    return True


def schema_for(name):
    allowed = ("symbol",) if name == "list_symbols" else FILTERS
    properties = {}
    descriptions = {
        "symbol": "符号名称或ID，只作原生查询的字面过滤值。",
        "example": "示例ID，只作字面过滤值。",
        "sdk": "必须提供精确仓颉SDK版本；不回退到其他版本。",
        "platform": "必须提供精确平台标识；不回退到其他平台。",
    }
    for key in allowed:
        properties[key] = {"type": "string", "minLength": 1, "maxLength": 1024,
                           "pattern": r"^(?!-)[^\x00-\x1f\x7f]+$",
                           "description": descriptions[key]}
    return {"type": "object", "properties": properties,
            "required": [] if name == "list_symbols" else ["sdk", "platform"],
            "additionalProperties": False}


def tools():
    descriptions = {
        "list_symbols": "只读列出固定登记项目的接口符号。",
        "get_verified_examples": "只读查询精确SDK/平台的当前有效示例；每次由原生引擎重新检查，缺证据返回原生原因。",
        "get_evidence": "只读查询精确SDK/平台的证据与原因；不触发编译或验证。",
    }
    return [{"name": name, "description": descriptions[name], "inputSchema": schema_for(name),
             "annotations": {"readOnlyHint": True, "destructiveHint": False,
                             "idempotentHint": True, "openWorldHint": False}}
            for name in TOOL_NAMES]


class Server:
    def __init__(self, config, binary):
        self.config = Path(config).resolve()
        self.binary = Path(binary).resolve()
        self.initialized = False
        self.ready = False

    def native_query(self, name, arguments):
        if not self.config.is_file():
            return tool_error("fixed config is missing or is not a file")
        if not self.binary.is_file() or not os.access(self.binary, os.X_OK):
            return tool_error("native binary is missing or is not executable")
        argv = [str(self.binary), "query", "--config", str(self.config), "--tool", name]
        for key in FILTERS:
            if key in arguments:
                argv.extend(["--" + key, arguments[key]])
        # Keep only SDK/runtime-related environment, not unrelated credentials.
        allowed = {"PATH", "CANGJIE_HOME", "DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH", "SDKROOT", "LANG", "LC_ALL", "TZ", "CJ_DOCGUARD_RUNNER"}
        environment = {key: value for key, value in os.environ.items()
                       if key in allowed or re.fullmatch(r"CJ_DOCGUARD_SDK_[0-9_]+", key)}
        try:
            completed = subprocess.run(argv, cwd=self.config.parent, env=environment,
                                       stdin=subprocess.DEVNULL, capture_output=True,
                                       timeout=QUERY_TIMEOUT, check=False)
        except subprocess.TimeoutExpired:
            return tool_error("native query timeout after 30 seconds")
        except OSError as exc:
            return tool_error("native query could not start: " + str(exc))
        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout)[:8192].decode("utf-8", errors="replace").strip()
            return tool_error("native query failed (exit " + str(completed.returncode) + "): " + detail)
        if len(completed.stdout) > MAX_NATIVE_OUTPUT:
            return tool_error("native query JSON output exceeds adapter limit")
        try:
            payload = strict_json(completed.stdout.decode("utf-8", errors="strict"))
        except (ValueError, UnicodeError, RecursionError):
            return tool_error("native query did not return valid JSON")
        encoded = json.dumps(payload, ensure_ascii=True, allow_nan=False, separators=(",", ":"))
        reply = {"content": [{"type": "text", "text": encoded}], "isError": False}
        if isinstance(payload, dict):
            reply["structuredContent"] = payload
        return reply

    def handle(self, message):
        if not isinstance(message, dict) or message.get("jsonrpc") != "2.0" or not isinstance(message.get("method"), str):
            return error(None, -32600, "Invalid Request")
        identifier = message.get("id")
        has_id = "id" in message
        if has_id and (type(identifier) not in (int, str)):
            return error(None, -32600, "Invalid request identifier")
        if isinstance(identifier, str):
            try:
                identifier.encode("utf-8")
            except UnicodeError:
                return error(None, -32600, "Invalid request identifier")
        if "result" in message or "error" in message:
            return error(identifier if has_id else None, -32600, "Invalid Request")
        params = message.get("params", {})
        if not isinstance(params, dict):
            return error(identifier, -32602, "Parameters must be an object") if has_id else None
        method = message["method"]
        # Tool calls are requests. A notification must never execute native code.
        if not has_id:
            if method == "notifications/initialized" and self.initialized:
                self.ready = True
            return None
        if method == "ping":
            return result(identifier, {})
        if method == "initialize":
            if self.initialized:
                return error(identifier, -32600, "Already initialized")
            client = params.get("clientInfo")
            if (not isinstance(params.get("protocolVersion"), str) or not params["protocolVersion"]
                    or not isinstance(params.get("capabilities"), dict)
                    or not isinstance(client, dict)
                    or not isinstance(client.get("name"), str) or not isinstance(client.get("version"), str)):
                return error(identifier, -32602, "Invalid initialize parameters")
            self.initialized = True
            return result(identifier, {"protocolVersion": PROTOCOL_VERSION,
                                      "capabilities": {"tools": {"listChanged": False}},
                                      "serverInfo": {"name": "cj-docguard-readonly", "version": "0.1.0"},
                                      "instructions": "固定登记项目的只读查询。每次调用原生引擎，不缓存静态报告；SDK和平台必须精确匹配，缺证据不能视为已验证。"})
        if not self.ready:
            return error(identifier, -32002, "Server is not initialized")
        if method == "tools/list":
            if any(key != "_meta" for key in params):
                return error(identifier, -32602, "Tool pagination is not supported")
            return result(identifier, {"tools": tools()})
        if method != "tools/call":
            return error(identifier, -32601, "Method not found")
        if any(key not in ("name", "arguments", "_meta") for key in params):
            return error(identifier, -32602, "Unknown tools/call parameter")
        name = params.get("name")
        if name not in TOOL_NAMES:
            return error(identifier, -32602, "Unknown read-only tool")
        arguments = params.get("arguments", {})
        allowed = schema_for(name)["properties"]
        if not isinstance(arguments, dict) or any(key not in allowed for key in arguments):
            return error(identifier, -32602, "Unknown tool argument")
        if any(not valid_filter(value) for value in arguments.values()):
            return error(identifier, -32602, "Tool filters must be nonempty literal strings without control characters or leading hyphens")
        if any(key not in arguments for key in schema_for(name)["required"]):
            return error(identifier, -32602, "Exact sdk and platform are required")
        return result(identifier, self.native_query(name, arguments))


def emit(value):
    sys.stdout.write(json.dumps(value, ensure_ascii=True, allow_nan=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser(description="CJ-DocGuard read-only MCP stdio adapter")
    parser.add_argument("--config", required=True, help="Fixed registered project config")
    parser.add_argument("--binary", required=True, help="Fixed native CJ-DocGuard executable")
    args = parser.parse_args()
    server = Server(args.config, args.binary)
    stream = sys.stdin.buffer
    while True:
        line = stream.readline(MAX_LINE_BYTES + 1)
        if not line:
            return 0
        if len(line) > MAX_LINE_BYTES:
            while not line.endswith(b"\n"):
                line = stream.readline(MAX_LINE_BYTES + 1)
                if not line:
                    break
            emit(error(None, -32700, "JSON message exceeds adapter limit"))
            continue
        try:
            message = strict_json(line.decode("utf-8", errors="strict"))
        except (ValueError, UnicodeError, RecursionError):
            emit(error(None, -32700, "Parse error"))
            continue
        try:
            reply = server.handle(message)
        except (ValueError, TypeError, OSError, RecursionError):
            # Do not leak tracebacks or break stdout framing on malformed input.
            reply = error(message.get("id") if isinstance(message, dict) else None,
                          -32603, "Internal adapter error")
        if reply is not None:
            emit(reply)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (BrokenPipeError, KeyboardInterrupt):
        sys.exit(0)
