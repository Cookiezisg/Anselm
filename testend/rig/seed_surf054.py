#!/usr/bin/env python3
"""Seed the real Scheduler run flagship battery for SURF-054.

The fixture uses only public HTTP APIs. It creates one pinned workflow version with four
sequential action nodes, then leaves one completed and one failed run for the single-run
flagship. The completed run is the primary visual target: its node rows and activity rows give
the graph, Gantt, and audit ledger independent facts to reconcile.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any


WORKFLOW_NAME = "SURF-054 Run Flagship"
FUNCTION_NAME = "surf054_flagship_step"
TRIGGER_NAME = "surf054_flagship_webhook"
WEBHOOK_PATH = "surf054-flagship"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9080")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--phase", choices=("prepare", "settle"), default="prepare")
    parser.add_argument("--timeout", type=float, default=45.0)
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
    return response.get("data") if isinstance(response, dict) and "data" in response else response


def rows(response: Any) -> list[dict[str, Any]]:
    value = data(response)
    if not isinstance(value, list):
        raise RuntimeError(f"expected a row list, got {value!r}")
    return [row for row in value if isinstance(row, dict)]


def find_named(api: API, collection: str, name: str) -> dict[str, Any] | None:
    return next(
        (row for row in rows(api.must("GET", f"/api/v1/{collection}?limit=200")) if row.get("name") == name),
        None,
    )


def create_named(api: API, collection: str, spec: dict[str, Any]) -> str:
    existing = find_named(api, collection, str(spec["name"]))
    if existing is not None:
        return str(existing["id"])
    created = data(api.must("POST", f"/api/v1/{collection}", spec))
    if not isinstance(created, dict) or not isinstance(created.get("id"), str):
        raise RuntimeError(f"unexpected {collection} create response: {created!r}")
    return created["id"]


def ensure_function(api: API) -> str:
    return create_named(
        api,
        "functions",
        {
            "name": FUNCTION_NAME,
            "description": "Deterministic four-step execution for the SURF-054 run flagship.",
            "code": (
                "import time\n"
                "def run(step, value, mode):\n"
                "    time.sleep(0.12)\n"
                "    if mode == 'fail' and step == 'validate':\n"
                "        raise RuntimeError('SURF-054 deliberate validation failure')\n"
                "    print('SURF-054 step', step, value)\n"
                "    return {'step': step, 'value': value, 'mode': mode}\n"
            ),
            "inputs": [
                {"name": "step", "type": "string", "description": "execution stage"},
                {"name": "value", "type": "string", "description": "carried business value"},
                {"name": "mode", "type": "string", "description": "fixture outcome"},
            ],
            "outputs": [
                {"name": "step", "type": "string"},
                {"name": "value", "type": "string"},
                {"name": "mode", "type": "string"},
            ],
            "changeReason": "SURF-054 run flagship fixture",
        },
    )


def ensure_trigger(api: API) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": TRIGGER_NAME,
            "description": "Webhook source for the SURF-054 run flagship fixture.",
            "kind": "webhook",
            "config": {"path": WEBHOOK_PATH, "method": "POST"},
        },
    )


def ensure_workflow(api: API, function_id: str, trigger_id: str) -> str:
    existing = find_named(api, "workflows", WORKFLOW_NAME)
    if existing is not None:
        return str(existing["id"])

    stages = ("intake", "validate", "transform", "publish")
    nodes: list[dict[str, Any]] = [
        {
            "op": "set_meta",
            "concurrency": "allow_all",
        },
        {
            "op": "add_node",
            "node": {
                "id": "entry",
                "kind": "trigger",
                "ref": trigger_id,
                "pos": {"x": 80, "y": 220},
            },
        },
    ]
    previous = "entry"
    for index, stage in enumerate(stages):
        node_id = f"stage_{stage}"
        value = "entry.body.value" if previous == "entry" else f"{previous}.value"
        mode = "entry.body.mode" if previous == "entry" else "entry.body.mode"
        nodes.extend(
            [
                {
                    "op": "add_node",
                    "node": {
                        "id": node_id,
                        "kind": "action",
                        "ref": function_id,
                        "input": {"step": f"'{stage}'", "value": value, "mode": mode},
                        "pos": {"x": 340 + index * 240, "y": 220},
                    },
                },
                {
                    "op": "add_edge",
                    "edge": {"id": f"{previous}-{node_id}", "from": previous, "to": node_id},
                },
            ]
        )
        previous = node_id

    created = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": WORKFLOW_NAME,
                "description": "A four-stage run dossier for the Scheduler flagship surface.",
                "ops": nodes,
                "changeReason": "SURF-054 run flagship fixture",
            },
        )
    )
    if not isinstance(created, dict) or not isinstance(created.get("id"), str):
        raise RuntimeError(f"unexpected workflow create response: {created!r}")
    return created["id"]


def workflow(api: API, workflow_id: str) -> dict[str, Any]:
    result = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(result, dict):
        raise RuntimeError(f"unexpected workflow detail: {result!r}")
    return result


def activate(api: API, workflow_id: str) -> None:
    current = workflow(api, workflow_id)
    if current.get("active") is True or current.get("lifecycleState") == "active":
        return
    api.must("POST", f"/api/v1/workflows/{workflow_id}:activate", {})


def runs(api: API, workflow_id: str) -> list[dict[str, Any]]:
    return rows(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=200"))


def start_run(api: API, workflow_id: str, mode: str, value: str) -> str:
    result = data(
        api.must(
            "POST",
            "/api/v1/flowruns",
            {
                "workflowId": workflow_id,
                "entryNode": "entry",
                "payload": {"body": {"mode": mode, "value": value}},
            },
        )
    )
    if not isinstance(result, dict) or not isinstance(result.get("flowrun"), dict):
        raise RuntimeError(f"unexpected flowrun start response: {result!r}")
    run_id = result["flowrun"].get("id")
    if not isinstance(run_id, str):
        raise RuntimeError(f"missing flowrun id: {result!r}")
    return run_id


def flowrun(api: API, run_id: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    result = data(api.must("GET", f"/api/v1/flowruns/{run_id}?limit=100"))
    if not isinstance(result, dict):
        raise RuntimeError(f"unexpected flowrun detail: {result!r}")
    head = result.get("flowrun", result)
    nodes = result.get("nodes", [])
    if not isinstance(head, dict) or not isinstance(nodes, list):
        raise RuntimeError(f"unexpected flowrun detail shape: {result!r}")
    return head, [node for node in nodes if isinstance(node, dict)]


def wait_for(api: API, run_id: str, wanted: str, timeout: float) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    latest: dict[str, Any] = {}
    while time.monotonic() < deadline:
        latest, nodes = flowrun(api, run_id)
        if latest.get("status") == wanted:
            return latest
        if latest.get("status") == "failed" and wanted == "completed":
            raise RuntimeError(f"run {run_id} failed while waiting for completed: {latest!r} / {nodes!r}")
        time.sleep(0.5)
    raise RuntimeError(f"run {run_id} did not reach {wanted}: {latest!r}")


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    trigger_id = ensure_trigger(api)
    workflow_id = ensure_workflow(api, function_id, trigger_id)

    if args.phase == "prepare":
        activate(api, workflow_id)
        existing = runs(api, workflow_id)
        completed = next((r for r in existing if r.get("status") == "completed"), None)
        failed = next((r for r in existing if r.get("status") == "failed"), None)
        completed_id = str(completed["id"]) if completed else start_run(api, workflow_id, "ok", "order-054")
        completed_head = wait_for(api, completed_id, "completed", args.timeout)
        failed_id = str(failed["id"]) if failed else start_run(api, workflow_id, "fail", "order-054-bad")
        failed_head = wait_for(api, failed_id, "failed", args.timeout)
        _, completed_nodes = flowrun(api, completed_id)
        _, failed_nodes = flowrun(api, failed_id)
        print(
            json.dumps(
                {
                    "phase": "prepare",
                    "workspace": args.workspace,
                    "function": function_id,
                    "trigger": trigger_id,
                    "workflow": workflow_id,
                    "completed": {"id": completed_id, "status": completed_head.get("status"), "nodes": len(completed_nodes)},
                    "failed": {"id": failed_id, "status": failed_head.get("status"), "nodes": len(failed_nodes)},
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return

    current = workflow(api, workflow_id)
    if current.get("active") is True or current.get("lifecycleState") in {"active", "draining"}:
        api.must("POST", f"/api/v1/workflows/{workflow_id}:deactivate", {})
    print(json.dumps({"phase": "settle", "workflow": workflow_id}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf054: {exc}", file=sys.stderr)
        raise
