#!/usr/bin/env python3
"""Seed the real Scheduler Overview battery for SURF-052.

This fixture uses only public HTTP APIs. It creates independent cron-backed workflows so the
Overview has real lanes, then creates failed, completed, parked and deliberately slow runs. The
slow run is left alive in ``prepare`` for the Computer Use pass and is cancelled by ``settle``.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any


CRON = "0 */6 * * *"
FUNCTION_NAME = "surf052_overview_outcome"
APPROVAL_NAME = "surf052_overview_approval"


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
    if isinstance(response, dict) and "data" in response:
        return response["data"]
    return response


def rows(response: Any) -> list[dict[str, Any]]:
    value = data(response)
    if not isinstance(value, list):
        raise RuntimeError(f"expected a row list, got {value!r}")
    return value


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
            "description": "One real function used to make Scheduler Overview outcomes visible.",
            "code": (
                "import time\n"
                "def run(mode, index):\n"
                "    if mode == 'slow':\n"
                "        time.sleep(240)\n"
                "    if mode == 'fail':\n"
                "        raise RuntimeError('SURF-052 deliberate failed run')\n"
                "    print('SURF-052 outcome', mode, index)\n"
                "    return {'ok': True, 'mode': mode, 'index': index}\n"
            ),
            "inputs": [
                {"name": "mode", "type": "string", "description": "fixture outcome"},
                {"name": "index", "type": "number", "description": "fixture sequence"},
            ],
            "outputs": [
                {"name": "ok", "type": "boolean"},
                {"name": "mode", "type": "string"},
                {"name": "index", "type": "number"},
            ],
            "changeReason": "SURF-052 Scheduler Overview fixture",
        },
    )


def ensure_approval(api: API) -> str:
    return create_named(
        api,
        "approvals",
        {
            "name": APPROVAL_NAME,
            "description": "Approval parked in the Scheduler Overview waiting zone.",
            "inputs": [
                {"name": "index", "type": "number", "description": "run sequence"},
                {"name": "mode", "type": "string", "description": "run mode"},
            ],
            "template": "### SURF-052 review\n\nApprove Scheduler run **{{ input.index }}** in mode `{{ input.mode }}`?",
            "allowReason": True,
            "timeout": "6h",
            "timeoutBehavior": "reject",
            "changeReason": "SURF-052 Scheduler Overview fixture",
        },
    )


def ensure_trigger(api: API, name: str) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": name,
            "description": f"SURF-052 six-hour schedule for {name}.",
            "kind": "cron",
            "config": {"expression": CRON, "misfirePolicy": "skip"},
        },
    )


def ensure_workflow(
    api: API,
    name: str,
    trigger_id: str,
    function_id: str,
    approval_id: str | None = None,
) -> str:
    existing = find_named(api, "workflows", name)
    if existing is not None:
        return str(existing["id"])

    nodes: list[dict[str, Any]] = [
        {
            "op": "add_node",
            "node": {"id": "entry", "kind": "trigger", "ref": trigger_id, "pos": {"x": 80, "y": 180}},
        },
        {
            "op": "add_node",
            "node": {
                "id": "work",
                "kind": "action",
                "ref": function_id,
                "input": {"mode": "entry.body.mode", "index": "entry.body.index"},
                "pos": {"x": 360, "y": 180},
            },
        },
    ]
    edges: list[dict[str, Any]] = [{"op": "add_edge", "edge": {"id": "entry-work", "from": "entry", "to": "work"}}]
    if approval_id is not None:
        nodes.append(
            {
                "op": "add_node",
                "node": {
                    "id": "gate",
                    "kind": "approval",
                    "ref": approval_id,
                    "input": {"index": "work.index", "mode": "work.mode"},
                    "pos": {"x": 640, "y": 180},
                },
            }
        )
        edges.append({"op": "add_edge", "edge": {"id": "work-gate", "from": "work", "to": "gate"}})

    created = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": name,
                "description": f"SURF-052 Scheduler Overview state: {name}",
                "ops": [{"op": "set_meta", "concurrency": "allow_all"}, *nodes, *edges],
                "changeReason": "SURF-052 Scheduler Overview fixture",
            },
        )
    )
    if not isinstance(created, dict) or not isinstance(created.get("id"), str):
        raise RuntimeError(f"unexpected workflow create response: {created!r}")
    return created["id"]


def get_workflow(api: API, workflow_id: str) -> dict[str, Any]:
    result = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(result, dict):
        raise RuntimeError(f"unexpected workflow detail: {result!r}")
    return result


def activate(api: API, workflow_id: str) -> None:
    current = get_workflow(api, workflow_id)
    if current.get("active") is True or current.get("lifecycleState") == "active":
        return
    api.must("POST", f"/api/v1/workflows/{workflow_id}:activate", {})


def start_run(api: API, workflow_id: str, mode: str, index: int) -> dict[str, Any]:
    result = data(
        api.must(
            "POST",
            "/api/v1/flowruns",
            {"workflowId": workflow_id, "payload": {"body": {"mode": mode, "index": index}}},
        )
    )
    if not isinstance(result, dict) or not isinstance(result.get("flowrun"), dict):
        raise RuntimeError(f"unexpected flowrun start response: {result!r}")
    return result["flowrun"]


def workflow_runs(api: API, workflow_id: str) -> list[dict[str, Any]]:
    return rows(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=200"))


def flowrun_detail(api: API, run_id: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    result = data(api.must("GET", f"/api/v1/flowruns/{run_id}?limit=100"))
    if not isinstance(result, dict):
        raise RuntimeError(f"unexpected flowrun detail: {result!r}")
    head = result.get("flowrun", result)
    nodes = result.get("nodes", [])
    if not isinstance(head, dict) or not isinstance(nodes, list):
        raise RuntimeError(f"unexpected flowrun detail shape: {result!r}")
    return head, [node for node in nodes if isinstance(node, dict)]


def parked_node(nodes: list[dict[str, Any]]) -> dict[str, Any] | None:
    return next((node for node in nodes if node.get("status") == "parked"), None)


def wait_for_status(api: API, run_id: str, wanted: set[str], timeout: float) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    latest: dict[str, Any] = {}
    while time.monotonic() < deadline:
        latest, nodes = flowrun_detail(api, run_id)
        if latest.get("status") in wanted or ("parked" in wanted and parked_node(nodes) is not None):
            return latest
        time.sleep(0.5)
    raise RuntimeError(f"run {run_id} did not reach {wanted}: {latest!r}")


def start_outcome_runs(api: API, workflow_id: str, mode: str, count: int, timeout: float, start_index: int) -> list[dict[str, Any]]:
    out = []
    for index in range(start_index, start_index + count):
        run = start_run(api, workflow_id, mode, index)
        wanted = {"failed"} if mode == "fail" else {"completed"}
        out.append(wait_for_status(api, str(run["id"]), wanted, timeout))
    return out


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    approval_id = ensure_approval(api)

    specs = {
        "running": ("surf052_running", True, None),
        "waiting": ("surf052_waiting", True, approval_id),
        "failed": ("surf052_failed", True, None),
        "healthy": ("surf052_healthy", True, None),
        "never": ("surf052_never_ran", True, None),
        "inactive": ("surf052_inactive", False, None),
    }
    workflows: dict[str, str] = {}
    triggers: dict[str, str] = {}
    for key, (name, should_activate, approval) in specs.items():
        trigger_id = ensure_trigger(api, f"{name}_cron")
        workflow_id = ensure_workflow(api, name, trigger_id, function_id, approval)
        triggers[key] = trigger_id
        workflows[key] = workflow_id
        if should_activate:
            activate(api, workflow_id)

    if args.phase == "prepare":
        failed = start_outcome_runs(api, workflows["failed"], "fail", 5, args.timeout, 1)
        healthy = start_outcome_runs(api, workflows["healthy"], "complete", 3, args.timeout, 20)
        waiting = start_run(api, workflows["waiting"], "complete", 40)
        waiting = wait_for_status(api, str(waiting["id"]), {"parked"}, args.timeout)
        _, waiting_nodes = flowrun_detail(api, str(waiting["id"]))
        running = start_run(api, workflows["running"], "slow", 60)
        running = wait_for_status(api, str(running["id"]), {"running"}, args.timeout)
        print(
            json.dumps(
                {
                    "phase": "prepare",
                    "workspace": args.workspace,
                    "function": function_id,
                    "approval": approval_id,
                    "workflows": workflows,
                    "triggers": triggers,
                    "failed": [{"id": r.get("id"), "status": r.get("status")} for r in failed],
                    "healthy": [{"id": r.get("id"), "status": r.get("status")} for r in healthy],
                    "waiting": {
                        "id": waiting.get("id"),
                        "status": waiting.get("status"),
                        "nodeStatus": (parked_node(waiting_nodes) or {}).get("status"),
                    },
                    "running": {"id": running.get("id"), "status": running.get("status")},
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return

    cleaned: list[dict[str, Any]] = []
    for key in ("running", "waiting"):
        for run in workflow_runs(api, workflows[key]):
            status = str(run.get("status"))
            if status == "running":
                _, nodes = flowrun_detail(api, str(run["id"]))
                if parked_node(nodes) is not None:
                    result = data(api.must("POST", f"/api/v1/flowruns/{run['id']}/approvals/gate:decide", {"decision": "yes", "reason": "SURF-052 cleanup"}))
                    cleaned.append({"id": run["id"], "action": "approve", "result": result})
                    continue
                result = data(api.must("POST", f"/api/v1/flowruns/{run['id']}:cancel", {}))
                cleaned.append({"id": run["id"], "action": "cancel", "result": result})
            elif status == "parked":
                result = data(api.must("POST", f"/api/v1/flowruns/{run['id']}/approvals/gate:decide", {"decision": "yes", "reason": "SURF-052 cleanup"}))
                cleaned.append({"id": run["id"], "action": "approve", "result": result})
    for key, workflow_id in workflows.items():
        if key != "inactive":
            current = get_workflow(api, workflow_id)
            if current.get("active") is True or current.get("lifecycleState") in {"active", "draining"}:
                api.must("POST", f"/api/v1/workflows/{workflow_id}:deactivate", {})
    print(json.dumps({"phase": "settle", "cleaned": cleaned}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf052: {exc}", file=sys.stderr)
        raise
