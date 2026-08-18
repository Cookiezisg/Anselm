#!/usr/bin/env python3
"""Seed real execution history for SURF-028's generic logs tab.

The fixture uses the public HTTP surface only. It is idempotent: an existing entity is
reused and only the missing target counts are executed. This keeps the log rows tied to
real function/handler/agent execution records rather than synthetic SQLite projections.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9034")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--function-name", default="surf028_log_function")
    parser.add_argument("--handler-name", default="surf028_log_handler")
    parser.add_argument("--agent-name", default="surf028_log_agent")
    parser.add_argument("--function-ok", type=int, default=20)
    parser.add_argument("--function-failed", type=int, default=4)
    parser.add_argument("--handler-ok", type=int, default=6)
    parser.add_argument("--handler-failed", type=int, default=2)
    parser.add_argument("--agent-runs", type=int, default=2)
    return parser.parse_args()


class API:
    def __init__(self, base: str, workspace: str) -> None:
        self.base = base.rstrip("/")
        self.workspace = workspace

    def request(self, method: str, path: str, body: Any = None) -> tuple[int, Any]:
        payload = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            self.base + path,
            data=payload,
            method=method,
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json",
                "X-Anselm-Workspace-ID": self.workspace,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                raw = response.read()
                return response.status, json.loads(raw or b"{}")
        except urllib.error.HTTPError as error:
            raw = error.read()
            try:
                parsed = json.loads(raw or b"{}")
            except json.JSONDecodeError:
                parsed = raw.decode(errors="replace")
            return error.code, parsed

    def must(self, method: str, path: str, body: Any = None) -> Any:
        status, response = self.request(method, path, body)
        if status >= 400:
            raise RuntimeError(f"{method} {path} -> HTTP {status}: {response}")
        return response


def data(response: Any) -> Any:
    if isinstance(response, dict) and "data" in response:
        return response["data"]
    return response


def find_entity(api: API, kind: str, name: str) -> dict[str, Any] | None:
    response = data(api.must("GET", f"/api/v1/{kind}?limit=200"))
    if not isinstance(response, list):
        raise RuntimeError(f"unexpected {kind} list response: {response!r}")
    return next((item for item in response if item.get("name") == name), None)


def ensure_function(api: API, name: str) -> str:
    existing = find_entity(api, "functions", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/functions",
            {
                "name": name,
                "description": "SURF-028 real logs fixture",
                "code": (
                    "def inspect_log(mode: str, index: int) -> dict:\n"
                    "    print(f'SURF-028 function begin {index}')\n"
                    "    if mode == 'fail':\n"
                    "        print(f'SURF-028 function before failure {index}')\n"
                    "        raise RuntimeError(f'SURF-028 deliberate failure {index}')\n"
                    "    print(f'SURF-028 function finish {index}')\n"
                    "    return {'index': index, 'mode': mode, 'ok': True}\n"
                ),
                "inputs": [
                    {"name": "mode", "type": "string", "description": "ok or fail"},
                    {"name": "index", "type": "number", "description": "fixture sequence"},
                ],
                "outputs": [{"name": "ok", "type": "boolean"}],
                "changeReason": "SURF-028 real logs fixture",
            },
        )
    )
    return str(response["id"])


def executions(api: API, function_id: str) -> list[dict[str, Any]]:
    response = data(api.must("GET", f"/api/v1/functions/{function_id}/executions?limit=200"))
    if not isinstance(response, dict) or not isinstance(response.get("executions"), list):
        raise RuntimeError(f"unexpected function execution response: {response!r}")
    return response["executions"]


def ensure_function_runs(api: API, function_id: str, ok_target: int, failed_target: int) -> None:
    rows = executions(api, function_id)
    ok_count = sum(row.get("status") == "ok" for row in rows)
    failed_count = sum(row.get("status") == "failed" for row in rows)
    next_index = len(rows)
    while ok_count < ok_target:
        api.must(
            "POST",
            f"/api/v1/functions/{function_id}:run",
            {"args": {"mode": "ok", "index": next_index}},
        )
        ok_count += 1
        next_index += 1
    while failed_count < failed_target:
        api.must(
            "POST",
            f"/api/v1/functions/{function_id}:run",
            {"args": {"mode": "fail", "index": next_index}},
        )
        failed_count += 1
        next_index += 1


def ensure_handler(api: API, name: str) -> str:
    existing = find_entity(api, "handlers", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/handlers",
            {
                "name": name,
                "description": "SURF-028 real logs fixture",
                "initBody": "self.calls = 0",
                "methods": [
                    {
                        "name": "emit",
                        "description": "write one durable handler call log",
                        "inputs": [{"name": "index", "type": "number"}],
                        "outputs": [{"name": "ok", "type": "boolean"}],
                        "body": (
                            "self.calls += 1\n"
                            "print(f'SURF-028 handler call {index}')\n"
                            "if index < 0:\n"
                            "    raise RuntimeError('SURF-028 deliberate handler failure')\n"
                            "return {'ok': True, 'calls': self.calls}\n"
                        ),
                    }
                ],
                "changeReason": "SURF-028 real logs fixture",
            },
        )
    )
    return str(response["id"])


def calls(api: API, handler_id: str) -> list[dict[str, Any]]:
    response = data(api.must("GET", f"/api/v1/handlers/{handler_id}/calls?limit=200"))
    if not isinstance(response, dict) or not isinstance(response.get("calls"), list):
        raise RuntimeError(f"unexpected handler call response: {response!r}")
    return response["calls"]


def ensure_handler_calls(api: API, handler_id: str, ok_target: int, failed_target: int) -> None:
    rows = calls(api, handler_id)
    ok_count = sum(row.get("status") == "ok" for row in rows)
    failed_count = sum(row.get("status") == "failed" for row in rows)
    while ok_count < ok_target:
        api.must("POST", f"/api/v1/handlers/{handler_id}:call", {"method": "emit", "args": {"index": ok_count}})
        ok_count += 1
    while failed_count < failed_target:
        before = failed_count
        status, response = api.request(
            "POST",
            f"/api/v1/handlers/{handler_id}:call",
            {"method": "emit", "args": {"index": -failed_count - 1}},
        )
        if status < 400:
            raise RuntimeError(f"handler failure probe unexpectedly succeeded: {response}")
        failed_count = sum(row.get("status") == "failed" for row in calls(api, handler_id))
        if failed_count <= before:
            raise RuntimeError(
                f"handler failure probe returned HTTP {status} without a durable failed row: {response}"
            )


def ensure_agent(api: API, name: str) -> str:
    existing = find_entity(api, "agents", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/agents",
            {
                "name": name,
                "description": "SURF-028 real logs fixture",
                "prompt": "Answer the user's input with one short sentence. Do not use tools.",
                "inputs": [{"name": "request", "type": "string", "description": "request"}],
                "changeReason": "SURF-028 real logs fixture",
            },
        )
    )
    return str(response["id"])


def agent_executions(api: API, agent_id: str) -> list[dict[str, Any]]:
    response = data(api.must("GET", f"/api/v1/agents/{agent_id}/executions?limit=200"))
    if not isinstance(response, dict) or not isinstance(response.get("executions"), list):
        raise RuntimeError(f"unexpected agent execution response: {response!r}")
    return response["executions"]


def ensure_agent_runs(api: API, agent_id: str, target: int) -> None:
    rows = agent_executions(api, agent_id)
    while len(rows) < target:
        before = len(rows)
        status, response = api.request(
            "POST",
            f"/api/v1/agents/{agent_id}:invoke",
            {"input": {"request": f"SURF-028 fixture run {len(rows) + 1}"}},
        )
        if status >= 400:
            print(f"agent invoke returned HTTP {status}: {response}", file=sys.stderr)
        rows = agent_executions(api, agent_id)
        if len(rows) <= before:
            raise RuntimeError(
                f"agent invoke returned HTTP {status} without a durable execution row: {response}"
            )


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api, args.function_name)
    ensure_function_runs(api, function_id, args.function_ok, args.function_failed)
    handler_id = ensure_handler(api, args.handler_name)
    ensure_handler_calls(api, handler_id, args.handler_ok, args.handler_failed)
    agent_id = ensure_agent(api, args.agent_name)
    ensure_agent_runs(api, agent_id, args.agent_runs)
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "function": {"id": function_id, "executions": len(executions(api, function_id))},
                "handler": {"id": handler_id, "calls": len(calls(api, handler_id))},
                "agent": {"id": agent_id, "executions": len(agent_executions(api, agent_id))},
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
