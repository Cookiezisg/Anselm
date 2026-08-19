#!/usr/bin/env python3
"""Seed the real Scheduler workflow-home battery for SURF-053.

The fixture creates one workflow with three real trigger branches and a small but expressive run
history. It uses only public HTTP APIs so the Scheduler page is judged against the same contracts a
user and an external webhook caller use.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any


WORKFLOW_NAME = "SURF-053 Operations Home"
FUNCTION_NAME = "surf053_home_outcome"
CRON_NAME = "surf053_home_cron"
WEBHOOK_NAME = "surf053_home_webhook"
PAUSED_CRON_NAME = "surf053_home_paused"
WEBHOOK_PATH = "surf053-home-events"


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
            "description": "Small deterministic outcomes for the Scheduler workflow home.",
            "code": (
                "import time\n"
                "def run(mode, index):\n"
                "    if mode == 'slow':\n"
                "        time.sleep(240)\n"
                "    if mode == 'fail':\n"
                "        raise RuntimeError('SURF-053 deliberate failure for triage')\n"
                "    print('SURF-053 outcome', mode, index)\n"
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
            "changeReason": "SURF-053 workflow home fixture",
        },
    )


def ensure_trigger(api: API, name: str, kind: str, config: dict[str, Any]) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": name,
            "description": f"SURF-053 workflow-home source: {name}.",
            "kind": kind,
            "config": config,
        },
    )


def ensure_workflow(api: API, function_id: str, trigger_ids: dict[str, str]) -> str:
    existing = find_named(api, "workflows", WORKFLOW_NAME)
    if existing is not None:
        return str(existing["id"])

    nodes = [
        {"op": "set_meta", "concurrency": "allow_all"},
        {
            "op": "add_node",
            "node": {"id": "cron_entry", "kind": "trigger", "ref": trigger_ids["cron"], "pos": {"x": 60, "y": 80}},
        },
        {
            "op": "add_node",
            "node": {"id": "hook_entry", "kind": "trigger", "ref": trigger_ids["webhook"], "pos": {"x": 60, "y": 260}},
        },
        {
            "op": "add_node",
            "node": {"id": "paused_entry", "kind": "trigger", "ref": trigger_ids["paused"], "pos": {"x": 60, "y": 440}},
        },
        {
            "op": "add_node",
            "node": {
                "id": "cron_work",
                "kind": "action",
                "ref": function_id,
                "input": {
                    "mode": "has(cron_entry.body) ? cron_entry.body.mode : 'ok'",
                    "index": "has(cron_entry.body) ? cron_entry.body.index : 0",
                },
                "pos": {"x": 360, "y": 80},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "hook_work",
                "kind": "action",
                "ref": function_id,
                "input": {
                    "mode": "has(hook_entry.body) ? hook_entry.body.mode : 'ok'",
                    "index": "has(hook_entry.body) ? hook_entry.body.index : 0",
                },
                "pos": {"x": 360, "y": 260},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "paused_work",
                "kind": "action",
                "ref": function_id,
                "input": {
                    "mode": "has(paused_entry.body) ? paused_entry.body.mode : 'ok'",
                    "index": "has(paused_entry.body) ? paused_entry.body.index : 0",
                },
                "pos": {"x": 360, "y": 440},
            },
        },
        {"op": "add_edge", "edge": {"id": "cron-to-work", "from": "cron_entry", "to": "cron_work"}},
        {"op": "add_edge", "edge": {"id": "hook-to-work", "from": "hook_entry", "to": "hook_work"}},
        {"op": "add_edge", "edge": {"id": "paused-to-work", "from": "paused_entry", "to": "paused_work"}},
    ]
    created = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": WORKFLOW_NAME,
                "description": "A real multi-source operations home fixture for SURF-053.",
                "ops": nodes,
                "changeReason": "SURF-053 workflow home fixture",
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


def pause(api: API, trigger_id: str) -> None:
    current = next(
        (row for row in rows(api.must("GET", "/api/v1/triggers?limit=200")) if row.get("id") == trigger_id),
        None,
    )
    if current and current.get("paused") is True:
        return
    api.must("POST", f"/api/v1/triggers/{trigger_id}:pause", {})


def start_run(api: API, workflow_id: str, entry_node: str, mode: str, index: int) -> str:
    result = data(
        api.must(
            "POST",
            "/api/v1/flowruns",
            {
                "workflowId": workflow_id,
                "entryNode": entry_node,
                "payload": {"body": {"mode": mode, "index": index}},
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
        raise RuntimeError(f"unexpected flowrun shape: {result!r}")
    return head, [node for node in nodes if isinstance(node, dict)]


def wait_for(api: API, run_id: str, wanted: set[str], timeout: float) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    latest: dict[str, Any] = {}
    while time.monotonic() < deadline:
        latest, _ = flowrun(api, run_id)
        if latest.get("status") in wanted:
            return latest
        time.sleep(0.4)
    raise RuntimeError(f"run {run_id} did not reach {wanted}: {latest!r}")


def webhook_run(
    api: API,
    trigger_id: str,
    workflow_id: str,
    mode: str,
    index: int,
    timeout: float,
    existing_ids: set[str],
) -> str:
    body = json.dumps({"mode": mode, "index": index}).encode()
    request = urllib.request.Request(
        f"{api.base}/api/v1/webhooks/{trigger_id}/{WEBHOOK_PATH}",
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-Anselm-Workspace-ID": api.workspace,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            if response.status >= 400:
                raise RuntimeError(f"webhook returned HTTP {response.status}")
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"webhook returned HTTP {error.code}: {error.read().decode(errors='replace')}") from error

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        candidates = rows(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=50"))
        for row in candidates:
            if (
                str(row.get("id")) not in existing_ids
                and row.get("origin") == "webhook"
                and row.get("status") in {"completed", "failed", "running"}
            ):
                return str(row["id"])
        time.sleep(0.4)
    raise RuntimeError("webhook did not produce a flowrun")


def list_runs(api: API, workflow_id: str) -> list[dict[str, Any]]:
    return rows(api.must("GET", f"/api/v1/flowruns?workflowId={workflow_id}&limit=200"))


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    trigger_ids = {
        "cron": ensure_trigger(api, CRON_NAME, "cron", {"expression": "*/30 * * * *", "misfirePolicy": "skip"}),
        "webhook": ensure_trigger(api, WEBHOOK_NAME, "webhook", {"path": WEBHOOK_PATH}),
        "paused": ensure_trigger(api, PAUSED_CRON_NAME, "cron", {"expression": "15 * * * *", "misfirePolicy": "skip"}),
    }
    workflow_id = ensure_workflow(api, function_id, trigger_ids)

    if args.phase == "prepare":
        activate(api, workflow_id)
        pause(api, trigger_ids["paused"])
        existing_ids = {str(row.get("id")) for row in list_runs(api, workflow_id)}

        completed_manual = start_run(api, workflow_id, "cron_entry", "ok", 1)
        wait_for(api, completed_manual, {"completed"}, args.timeout)
        failed_manual = start_run(api, workflow_id, "cron_entry", "fail", 2)
        wait_for(api, failed_manual, {"failed"}, args.timeout)
        completed_webhook = webhook_run(
            api, trigger_ids["webhook"], workflow_id, "ok", 3, args.timeout, existing_ids
        )
        existing_ids.add(completed_webhook)
        wait_for(api, completed_webhook, {"completed"}, args.timeout)
        failed_webhook = webhook_run(
            api, trigger_ids["webhook"], workflow_id, "fail", 4, args.timeout, existing_ids
        )
        existing_ids.add(failed_webhook)
        wait_for(api, failed_webhook, {"failed"}, args.timeout)
        running = webhook_run(
            api, trigger_ids["webhook"], workflow_id, "slow", 5, args.timeout, existing_ids
        )
        wait_for(api, running, {"running"}, args.timeout)

        print(
            json.dumps(
                {
                    "phase": "prepare",
                    "workspace": args.workspace,
                    "workflow": workflow_id,
                    "function": function_id,
                    "triggers": trigger_ids,
                    "existingRunIdsBeforeSeed": sorted(existing_ids),
                    "runs": {
                        "completedManual": completed_manual,
                        "failedManual": failed_manual,
                        "completedWebhook": completed_webhook,
                        "failedWebhook": failed_webhook,
                        "running": running,
                    },
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return

    cleaned: list[dict[str, Any]] = []
    for row in list_runs(api, workflow_id):
        if row.get("status") == "running":
            run_id = str(row["id"])
            result = data(api.must("POST", f"/api/v1/flowruns/{run_id}:cancel", {}))
            cleaned.append({"id": run_id, "action": "cancel", "result": result})
    current = workflow(api, workflow_id)
    if current.get("active") is True or current.get("lifecycleState") in {"active", "draining"}:
        api.must("POST", f"/api/v1/workflows/{workflow_id}:deactivate", {})
    print(json.dumps({"phase": "settle", "cleaned": cleaned}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf053: {exc}", file=sys.stderr)
        raise
