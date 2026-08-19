#!/usr/bin/env python3
"""Seed the real Scheduler id-only run relay battery for SURF-055.

The fixture creates one completed run behind a small workflow.  The App receives only the
``fr_`` id through the normal Scheduler rail path; resolving the host and handing over to the
run flagship are therefore exercised by production code, not by a test-only route.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any


WORKFLOW_NAME = "SURF-055 Run Relay"
FUNCTION_NAME = "surf055_relay_step"
TRIGGER_NAME = "surf055_relay_webhook"
WEBHOOK_PATH = "surf055-relay"


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
            "description": "Deterministic output used by the SURF-055 run relay fixture.",
            "code": (
                "import time\n"
                "def run(value):\n"
                "    time.sleep(0.12)\n"
                "    print('SURF-055 relay value', value)\n"
                "    return {'ok': True, 'value': value}\n"
            ),
            "inputs": [{"name": "value", "type": "string", "description": "relay evidence value"}],
            "outputs": [
                {"name": "ok", "type": "boolean"},
                {"name": "value", "type": "string"},
            ],
            "changeReason": "SURF-055 run relay fixture",
        },
    )


def ensure_trigger(api: API) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": TRIGGER_NAME,
            "description": "Webhook source for the SURF-055 run relay fixture.",
            "kind": "webhook",
            "config": {"path": WEBHOOK_PATH, "method": "POST"},
        },
    )


def ensure_workflow(api: API, function_id: str, trigger_id: str) -> str:
    existing = find_named(api, "workflows", WORKFLOW_NAME)
    if existing is not None:
        return str(existing["id"])
    ops = [
        {"op": "set_meta", "concurrency": "allow_all"},
        {
            "op": "add_node",
            "node": {"id": "entry", "kind": "trigger", "ref": trigger_id, "pos": {"x": 80, "y": 180}},
        },
        {
            "op": "add_node",
            "node": {
                "id": "relay_step",
                "kind": "action",
                "ref": function_id,
                "input": {"value": "entry.body.value"},
                "pos": {"x": 360, "y": 180},
            },
        },
        {"op": "add_edge", "edge": {"id": "entry-to-relay", "from": "entry", "to": "relay_step"}},
    ]
    created = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": WORKFLOW_NAME,
                "description": "A real host workflow for the id-only Scheduler run relay.",
                "ops": ops,
                "changeReason": "SURF-055 run relay fixture",
            },
        )
    )
    if not isinstance(created, dict) or not isinstance(created.get("id"), str):
        raise RuntimeError(f"unexpected workflow create response: {created!r}")
    return created["id"]


def workflow(api: API, workflow_id: str) -> dict[str, Any]:
    result = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(result, dict):
        raise RuntimeError(f"unexpected workflow response: {result!r}")
    return result


def activate(api: API, workflow_id: str) -> None:
    current = workflow(api, workflow_id)
    if current.get("active") is True or current.get("lifecycleState") == "active":
        return
    api.must("POST", f"/api/v1/workflows/{workflow_id}:activate", {})


def runs(api: API, workflow_id: str) -> list[dict[str, Any]]:
    return rows(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=200"))


def start_run(api: API, workflow_id: str) -> str:
    result = data(
        api.must(
            "POST",
            "/api/v1/flowruns",
            {
                "workflowId": workflow_id,
                "entryNode": "entry",
                "payload": {"body": {"value": "relay-order-055"}},
            },
        )
    )
    if not isinstance(result, dict) or not isinstance(result.get("flowrun"), dict):
        raise RuntimeError(f"unexpected flowrun start response: {result!r}")
    run_id = result["flowrun"].get("id")
    if not isinstance(run_id, str):
        raise RuntimeError(f"missing flowrun id: {result!r}")
    return run_id


def flowrun(api: API, run_id: str) -> dict[str, Any]:
    result = data(api.must("GET", f"/api/v1/flowruns/{run_id}?limit=100"))
    if not isinstance(result, dict):
        raise RuntimeError(f"unexpected flowrun response: {result!r}")
    return result


def wait_for_completed(api: API, run_id: str, timeout: float) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    latest: dict[str, Any] = {}
    while time.monotonic() < deadline:
        latest = flowrun(api, run_id)
        head = latest.get("flowrun", latest)
        status = head.get("status") if isinstance(head, dict) else None
        if status == "completed":
            return latest
        if status == "failed":
            raise RuntimeError(f"run {run_id} failed: {latest!r}")
        time.sleep(0.5)
    raise RuntimeError(f"run {run_id} did not complete: {latest!r}")


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    trigger_id = ensure_trigger(api)
    workflow_id = ensure_workflow(api, function_id, trigger_id)

    if args.phase == "prepare":
        activate(api, workflow_id)
        existing = runs(api, workflow_id)
        completed = next((row for row in existing if row.get("status") == "completed"), None)
        run_id = str(completed["id"]) if completed else start_run(api, workflow_id)
        result = wait_for_completed(api, run_id, args.timeout)
        head = result.get("flowrun", result)
        nodes = result.get("nodes", [])
        print(
            json.dumps(
                {
                    "phase": "prepare",
                    "workspace": args.workspace,
                    "function": function_id,
                    "trigger": trigger_id,
                    "workflow": workflow_id,
                    "run": {"id": run_id, "status": head.get("status"), "nodes": len(nodes)},
                    "invalidRunId": "fr_0000000000000000",
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
        print(f"seed_surf055: {exc}", file=sys.stderr)
        raise
