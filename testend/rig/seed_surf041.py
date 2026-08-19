#!/usr/bin/env python3
"""Seed real executable entities and history for SURF-041's run terminal.

The fixture uses only public HTTP APIs and is idempotent by entity name. It leaves durable
success/failure history behind for the recent strip, then drives one live run for each executable
kind so the right-island terminal can be inspected against real ledgers and SSE.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9060")
    parser.add_argument("--workspace", required=True)
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


def find_named(api: API, collection: str, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", f"/api/v1/{collection}?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected {collection} response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def create_named(api: API, collection: str, spec: dict[str, Any]) -> str:
    existing = find_named(api, collection, spec["name"])
    if existing:
        return str(existing["id"])
    response = data(api.must("POST", f"/api/v1/{collection}", spec))
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected {collection} create response: {response!r}")
    return response["id"]


def list_rows(api: API, path: str, key: str) -> list[dict[str, Any]]:
    response = data(api.must("GET", path))
    if not isinstance(response, dict) or not isinstance(response.get(key), list):
        raise RuntimeError(f"unexpected {path} response: {response!r}")
    return response[key]


def ensure_function(api: API) -> str:
    return create_named(
        api,
        "functions",
        {
            "name": "surf041_terminal_function",
            "description": "A real function for the SURF-041 JSON-first run terminal.",
            "code": (
                "def inspect(label, count):\n"
                "    print(f'SURF-041 function begin {label} {count}')\n"
                "    if label == 'fail':\n"
                "        raise RuntimeError('SURF-041 deliberate failure')\n"
                "    print('SURF-041 function finish')\n"
                "    return {'label': label, 'count': count, 'ok': True}\n"
            ),
            "inputs": [
                {"name": "label", "type": "string", "description": "run label"},
                {"name": "count", "type": "number", "description": "sample count"},
            ],
            "outputs": [{"name": "ok", "type": "boolean"}],
            "changeReason": "SURF-041 real run terminal fixture",
        },
    )


def ensure_function_runs(api: API, function_id: str) -> None:
    rows = list_rows(api, f"/api/v1/functions/{function_id}/executions?limit=200", "executions")
    ok_count = sum(row.get("status") == "ok" for row in rows)
    failed_count = sum(row.get("status") == "failed" for row in rows)
    if ok_count < 1:
        api.must(
            "POST",
            f"/api/v1/functions/{function_id}:run",
            {"args": {"label": "warmup", "count": 1}},
        )
        ok_count += 1
    if failed_count < 1:
        status, response = api.request(
            "POST",
            f"/api/v1/functions/{function_id}:run",
            {"args": {"label": "fail", "count": 2}},
        )
        result = data(response)
        if status >= 400 or not isinstance(result, dict) or result.get("ok") is not False:
            raise RuntimeError(f"expected a durable function failure result, got {response!r}")
        failed_count += 1
    if ok_count < 2:
        api.must(
            "POST",
            f"/api/v1/functions/{function_id}:run",
            {"args": {"label": "latest", "count": 3}},
        )


def ensure_handler(api: API) -> str:
    return create_named(
        api,
        "handlers",
        {
            "name": "surf041_terminal_handler",
            "description": "A real stateful handler for the SURF-041 run terminal.",
            "initBody": "self.calls = 0",
            "methods": [
                {
                    "name": "inspect",
                    "description": "Return one stateful inspection result.",
                    "inputs": [{"name": "label", "type": "string"}],
                    "outputs": [{"name": "ok", "type": "boolean"}],
                    "body": (
                        "self.calls += 1\n"
                        "print(f'SURF-041 handler call {self.calls}')\n"
                        "return {'label': label, 'calls': self.calls, 'ok': True}\n"
                    ),
                }
            ],
            "changeReason": "SURF-041 real run terminal fixture",
        },
    )


def ensure_handler_call(api: API, handler_id: str) -> None:
    rows = list_rows(api, f"/api/v1/handlers/{handler_id}/calls?limit=200", "calls")
    if not any(row.get("status") == "ok" for row in rows):
        api.must(
            "POST",
            f"/api/v1/handlers/{handler_id}:call",
            {"method": "inspect", "args": {"label": "latest"}},
        )


def ensure_agent(api: API) -> str:
    return create_named(
        api,
        "agents",
        {
            "name": "surf041_terminal_agent",
            "description": "A concise no-tool agent for the SURF-041 run terminal.",
            "prompt": "Answer the user's input in one concise sentence. Do not use tools.",
            "inputs": [{"name": "request", "type": "string", "description": "request"}],
            "changeReason": "SURF-041 real run terminal fixture",
        },
    )


def ensure_agent_run(api: API, agent_id: str) -> None:
    rows = list_rows(api, f"/api/v1/agents/{agent_id}/executions?limit=200", "executions")
    if rows:
        return
    status, response = api.request(
        "POST",
        f"/api/v1/agents/{agent_id}:invoke",
        {"input": {"request": "Give me a one sentence inspection summary."}},
    )
    rows = list_rows(api, f"/api/v1/agents/{agent_id}/executions?limit=200", "executions")
    if status >= 400 or not rows:
        raise RuntimeError(f"agent invoke did not leave a durable row: HTTP {status}: {response}")


def ensure_trigger(api: API) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": "surf041_terminal_trigger",
            "description": "A webhook source for the SURF-041 workflow run.",
            "kind": "webhook",
            "config": {"path": "surf041-terminal"},
        },
    )


def ensure_workflow(api: API, trigger_id: str, function_id: str) -> str:
    existing = find_named(api, "workflows", "surf041_terminal_workflow")
    if existing:
        workflow_id = str(existing["id"])
    else:
        response = data(
            api.must(
                "POST",
                "/api/v1/workflows",
                {
                    "name": "surf041_terminal_workflow",
                    "description": "A real workflow run for the SURF-041 terminal.",
                    "ops": [
                        {"op": "set_meta", "concurrency": "allow_all"},
                        {
                            "op": "add_node",
                            "node": {"id": "entry", "kind": "trigger", "ref": trigger_id},
                        },
                        {
                            "op": "add_node",
                            "node": {
                                "id": "inspect",
                                "kind": "action",
                                "ref": function_id,
                                "input": {
                                    "label": "entry.body.label",
                                    "count": "entry.body.count",
                                },
                            },
                        },
                        {
                            "op": "add_edge",
                            "edge": {"id": "entry-inspect", "from": "entry", "to": "inspect"},
                        },
                    ],
                    "changeReason": "SURF-041 real run terminal fixture",
                },
            )
        )
        if not isinstance(response, dict) or not isinstance(response.get("id"), str):
            raise RuntimeError(f"unexpected workflow create response: {response!r}")
        workflow_id = response["id"]

    workflow = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(workflow, dict):
        raise RuntimeError(f"unexpected workflow detail: {workflow!r}")
    graph = workflow.get("activeVersion", {}).get("graphParsed", {})
    nodes = graph.get("nodes", []) if isinstance(graph, dict) else []
    inspect = next((node for node in nodes if node.get("id") == "inspect"), None)
    expected_input = {
        "label": "entry.body.label",
        "count": "entry.body.count",
    }
    if isinstance(inspect, dict) and inspect.get("input") != expected_input:
        api.must(
            "POST",
            f"/api/v1/workflows/{workflow_id}:edit",
            {
                "ops": [
                    {
                        "op": "update_node",
                        "id": "inspect",
                        "patch": {
                            "input": expected_input,
                        },
                    }
                ],
                "changeReason": "SURF-041 wire trigger payload into terminal fixture",
            },
        )
    if workflow.get("active") is not True and workflow.get("lifecycleState") != "active":
        api.must("POST", f"/api/v1/workflows/{workflow_id}:activate", {})
    return workflow_id


def ensure_workflow_run(api: API, workflow_id: str) -> str:
    rows = data(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected flowrun list response: {rows!r}")
    if rows and rows[0].get("status") == "completed":
        return str(rows[0]["id"])
    response = data(
        api.must(
            "POST",
            f"/api/v1/workflows/{workflow_id}:trigger",
            {"payload": {"label": "workflow", "count": 4}},
        )
    )
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected workflow trigger response: {response!r}")
    run_id = response["id"]
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        response = data(api.must("GET", f"/api/v1/flowruns/{run_id}"))
        run = response.get("flowrun") if isinstance(response, dict) else None
        if isinstance(run, dict) and run.get("status") in {"completed", "failed", "cancelled", "timeout"}:
            if run.get("status") != "completed":
                raise RuntimeError(f"workflow fixture did not complete: {run!r}")
            return run_id
        time.sleep(0.5)
    raise RuntimeError(f"workflow fixture did not settle: {run_id}")


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    ensure_function_runs(api, function_id)
    handler_id = ensure_handler(api)
    ensure_handler_call(api, handler_id)
    agent_id = ensure_agent(api)
    ensure_agent_run(api, agent_id)
    trigger_id = ensure_trigger(api)
    workflow_id = ensure_workflow(api, trigger_id, function_id)
    flowrun_id = ensure_workflow_run(api, workflow_id)
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "function": function_id,
                "handler": handler_id,
                "agent": agent_id,
                "trigger": trigger_id,
                "workflow": workflow_id,
                "flowrun": flowrun_id,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf041: {exc}", file=sys.stderr)
        raise
