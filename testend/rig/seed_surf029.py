#!/usr/bin/env python3
"""Seed real workflow run history for SURF-029's run cockpit.

The fixture uses only the public HTTP surface. It is idempotent: named entities are reused and
missing run states are added only when the workflow does not already have them.
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
    parser.add_argument("--base", default="http://127.0.0.1:9036")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--function-name", default="surf029_run_action")
    parser.add_argument("--trigger-name", default="surf029_run_trigger")
    parser.add_argument("--approval-name", default="surf029_run_approval")
    parser.add_argument("--workflow-name", default="surf029_run_cockpit")
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
                "description": "SURF-029 real workflow cockpit fixture",
                "code": (
                    "def run(mode: str, index: int) -> dict:\n"
                    "    print(f'SURF-029 action begin {index} ({mode})')\n"
                    "    if mode == 'fail':\n"
                    "        print(f'SURF-029 action before failure {index}')\n"
                    "        raise RuntimeError(f'SURF-029 deliberate failure {index}')\n"
                    "    print(f'SURF-029 action finish {index}')\n"
                    "    return {'index': index, 'mode': mode, 'ok': True}\n"
                ),
                "inputs": [
                    {"name": "mode", "type": "string", "description": "ok or fail"},
                    {"name": "index", "type": "number", "description": "fixture sequence"},
                ],
                "outputs": [
                    {"name": "index", "type": "number"},
                    {"name": "mode", "type": "string"},
                    {"name": "ok", "type": "boolean"},
                ],
                "changeReason": "SURF-029 real workflow cockpit fixture",
            },
        )
    )
    return str(response["id"])


def ensure_trigger(api: API, name: str) -> str:
    existing = find_entity(api, "triggers", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/triggers",
            {
                "name": name,
                "description": "SURF-029 manual and webhook entry",
                "kind": "webhook",
                "config": {"path": "surf029-run"},
            },
        )
    )
    return str(response["id"])


def ensure_approval(api: API, name: str) -> str:
    existing = find_entity(api, "approvals", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/approvals",
            {
                "name": name,
                "description": "SURF-029 approval parked in the run cockpit",
                "inputs": [
                    {"name": "index", "type": "number", "description": "run sequence"},
                    {"name": "mode", "type": "string", "description": "run mode"},
                ],
                "template": "### SURF-029 review\n\nApprove run **{{ input.index }}** in mode `{{ input.mode }}`?",
                "allowReason": True,
                "changeReason": "SURF-029 real workflow cockpit fixture",
            },
        )
    )
    return str(response["id"])


def ensure_workflow(api: API, name: str, trigger_id: str, function_id: str, approval_id: str) -> str:
    existing = find_entity(api, "workflows", name)
    if existing:
        return str(existing["id"])
    ops = [
        {"op": "set_meta", "concurrency": "allow_all"},
        {
            "op": "add_node",
            "node": {
                "id": "entry",
                "kind": "trigger",
                "ref": trigger_id,
                "pos": {"x": 80, "y": 180},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "work",
                "kind": "action",
                "ref": function_id,
                "input": {
                    "mode": "entry.body.mode",
                    "index": "entry.body.index",
                },
                "pos": {"x": 340, "y": 180},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "gate",
                "kind": "approval",
                "ref": approval_id,
                "input": {"index": "work.index", "mode": "work.mode"},
                "pos": {"x": 620, "y": 180},
            },
        },
        {"op": "add_edge", "edge": {"id": "entry-work", "from": "entry", "to": "work"}},
        {"op": "add_edge", "edge": {"id": "work-gate", "from": "work", "to": "gate"}},
    ]
    response = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": name,
                "description": "SURF-029 run board and node debug fixture",
                "ops": ops,
                "changeReason": "SURF-029 real workflow cockpit fixture",
            },
        )
    )
    return str(response["id"])


def workflow_runs(api: API, workflow_id: str) -> list[dict[str, Any]]:
    response = data(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=200"))
    if not isinstance(response, list):
        raise RuntimeError(f"unexpected flowrun list response: {response!r}")
    return response


def start_run(api: API, workflow_id: str, mode: str, index: int) -> dict[str, Any]:
    response = data(
        api.must(
            "POST",
            "/api/v1/flowruns",
            {
                "workflowId": workflow_id,
                "payload": {"body": {"mode": mode, "index": index}},
            },
        )
    )
    if not isinstance(response, dict) or not isinstance(response.get("flowrun"), dict):
        raise RuntimeError(f"unexpected flowrun start response: {response!r}")
    return response["flowrun"]


def ensure_run_states(api: API, workflow_id: str) -> list[dict[str, Any]]:
    rows = workflow_runs(api, workflow_id)
    statuses = {str(row.get("status")) for row in rows}
    next_index = len(rows) + 1

    if "failed" not in statuses:
        start_run(api, workflow_id, "fail", next_index)
        next_index += 1

    rows = workflow_runs(api, workflow_id)
    if not any(row.get("status") in {"running", "parked"} for row in rows):
        start_run(api, workflow_id, "ok", next_index)
        next_index += 1

    rows = workflow_runs(api, workflow_id)
    if "completed" not in {str(row.get("status")) for row in rows}:
        parked = start_run(api, workflow_id, "ok", next_index)
        api.must(
            "POST",
            f"/api/v1/flowruns/{parked['id']}/approvals/gate:decide",
            {"decision": "yes", "reason": "SURF-029 fixture completion"},
        )

    return workflow_runs(api, workflow_id)


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api, args.function_name)
    trigger_id = ensure_trigger(api, args.trigger_name)
    approval_id = ensure_approval(api, args.approval_name)
    workflow_id = ensure_workflow(api, args.workflow_name, trigger_id, function_id, approval_id)
    capability = data(api.must("POST", f"/api/v1/workflows/{workflow_id}:capability-check", {}))
    runs = ensure_run_states(api, workflow_id)
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "function": function_id,
                "trigger": trigger_id,
                "approval": approval_id,
                "workflow": workflow_id,
                "capability": capability,
                "runs": [
                    {"id": row.get("id"), "status": row.get("status"), "origin": row.get("origin")}
                    for row in runs
                ],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # fixture failures must be visible to the conductor
        print(f"seed_surf029: {error}", file=sys.stderr)
        raise
