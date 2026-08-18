#!/usr/bin/env python3
"""Seed real firing dispositions for SURF-031's trigger Dispatch tab.

The fixture uses only the public HTTP surface. One webhook trigger fans out to four workflows:
an allow-all fast path, a skip policy, a buffer_one policy, and a serial policy. The latter three
use a deliberately slow function so the prepare phase leaves the durable inbox in a mixed state:
started, skipped, superseded, and pending. The operator can inspect that state in the real App;
the settle phase then kills the serial workflow so its pending firing becomes shed and deactivates
the remaining listeners. No SQLite rows are fabricated.
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
    parser.add_argument("--base", default="http://127.0.0.1:9040")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--phase", choices=("prepare", "settle"), default="prepare")
    parser.add_argument("--function-name", default="surf031_dispatch_slow")
    parser.add_argument("--quick-function-name", default="surf031_dispatch_quick")
    parser.add_argument("--trigger-name", default="surf031_dispatch_trigger")
    parser.add_argument("--timeout", type=float, default=75.0)
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


def ensure_function(api: API, name: str, seconds: int) -> str:
    existing = find_entity(api, "functions", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/functions",
            {
                "name": name,
                "description": f"SURF-031 {seconds}s workflow dispatch fixture",
                "code": (
                    "import time\n"
                    "def run() -> dict:\n"
                    f"    time.sleep({seconds})\n"
                    f"    print('SURF-031 function finished after {seconds}s')\n"
                    f"    return {{'ok': True, 'seconds': {seconds}}}\n"
                ),
                "inputs": [],
                "outputs": [
                    {"name": "ok", "type": "boolean"},
                    {"name": "seconds", "type": "number"},
                ],
                "changeReason": "SURF-031 real trigger dispatch fixture",
            },
        )
    )
    if not isinstance(response, dict) or not response.get("id"):
        raise RuntimeError(f"unexpected function create response: {response!r}")
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
                "description": "SURF-031 one trigger fan-out for dispatch dispositions",
                "kind": "webhook",
                "config": {"path": "surf031-dispatch"},
            },
        )
    )
    if not isinstance(response, dict) or not response.get("id"):
        raise RuntimeError(f"unexpected trigger create response: {response!r}")
    return str(response["id"])


def ensure_workflow(api: API, name: str, trigger_id: str, function_id: str, concurrency: str) -> str:
    existing = find_entity(api, "workflows", name)
    if existing:
        api.must("PATCH", f"/api/v1/workflows/{existing['id']}", {"concurrency": concurrency})
        return str(existing["id"])

    response = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": name,
                "description": f"SURF-031 dispatch disposition: {concurrency}",
                "ops": [
                    {"op": "set_meta", "concurrency": concurrency},
                    {
                        "op": "add_node",
                        "node": {
                            "id": "entry",
                            "kind": "trigger",
                            "ref": trigger_id,
                            "pos": {"x": 100, "y": 180},
                        },
                    },
                    {
                        "op": "add_node",
                        "node": {
                            "id": "work",
                            "kind": "action",
                            "ref": function_id,
                            "pos": {"x": 380, "y": 180},
                        },
                    },
                    {"op": "add_edge", "edge": {"id": "entry-work", "from": "entry", "to": "work"}},
                ],
                "changeReason": "SURF-031 real trigger dispatch fixture",
            },
        )
    )
    if not isinstance(response, dict) or not response.get("id"):
        raise RuntimeError(f"unexpected workflow create response: {response!r}")
    return str(response["id"])


def get_workflow(api: API, workflow_id: str) -> dict[str, Any]:
    response = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(response, dict):
        raise RuntimeError(f"unexpected workflow response: {response!r}")
    return response


def activate(api: API, workflow_id: str) -> None:
    current = get_workflow(api, workflow_id)
    if current.get("active"):
        return
    api.must("POST", f"/api/v1/workflows/{workflow_id}:activate")


def deactivate(api: API, workflow_id: str, timeout: float) -> None:
    current = get_workflow(api, workflow_id)
    if not current.get("active") and current.get("lifecycleState") == "inactive":
        return
    api.must("POST", f"/api/v1/workflows/{workflow_id}:deactivate")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        current = get_workflow(api, workflow_id)
        if not current.get("active") and current.get("lifecycleState") == "inactive":
            return
        time.sleep(0.5)
    raise RuntimeError(f"workflow did not settle after deactivate: {current!r}")


def fire(api: API, trigger_id: str) -> None:
    status, response = api.request("POST", f"/api/v1/triggers/{trigger_id}:fire", {})
    if status >= 400:
        raise RuntimeError(f"manual fire -> HTTP {status}: {response}")


def list_firings(api: API, trigger_id: str, status: str | None = None) -> list[dict[str, Any]]:
    query = "?limit=200" if status is None else f"?status={status}&limit=200"
    response = data(api.must("GET", f"/api/v1/triggers/{trigger_id}/firings{query}"))
    if not isinstance(response, list):
        raise RuntimeError(f"unexpected firing response: {response!r}")
    return response


def wait_until(api: API, trigger_id: str, predicate, timeout: float) -> list[dict[str, Any]]:
    deadline = time.monotonic() + timeout
    rows: list[dict[str, Any]] = []
    while time.monotonic() < deadline:
        rows = list_firings(api, trigger_id)
        if predicate(rows):
            return rows
        time.sleep(0.5)
    raise RuntimeError(f"firing state did not settle: {rows!r}")


def summarize(rows: list[dict[str, Any]], workflow_ids: dict[str, str]) -> dict[str, Any]:
    by_workflow: dict[str, dict[str, int]] = {}
    for label, workflow_id in workflow_ids.items():
        by_workflow[label] = {}
        for row in rows:
            if row.get("workflowId") != workflow_id:
                continue
            status = str(row.get("status"))
            by_workflow[label][status] = by_workflow[label].get(status, 0) + 1
    return {"total": len(rows), "byWorkflow": by_workflow}


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    slow_id = ensure_function(api, args.function_name, 45)
    quick_id = ensure_function(api, args.quick_function_name, 0)
    trigger_id = ensure_trigger(api, args.trigger_name)
    workflow_ids = {
        "started": ensure_workflow(api, "surf031_dispatch_started", trigger_id, quick_id, "allow_all"),
        "skipped": ensure_workflow(api, "surf031_dispatch_skipped", trigger_id, slow_id, "skip"),
        "superseded": ensure_workflow(api, "surf031_dispatch_buffer", trigger_id, slow_id, "buffer_one"),
        "shed": ensure_workflow(api, "surf031_dispatch_shed", trigger_id, slow_id, "serial"),
    }

    if args.phase == "prepare":
        for workflow_id in workflow_ids.values():
            activate(api, workflow_id)

        fire(api, trigger_id)
        first = wait_until(
            api,
            trigger_id,
            lambda rows: all(
                any(row.get("workflowId") == workflow_id and row.get("status") == "started" for row in rows)
                for workflow_id in workflow_ids.values()
            ),
            args.timeout,
        )
        # These calls are intentionally back-to-back: the three slow workflows are still in flight,
        # so the scheduler's real overlap policies decide the durable dispositions.
        fire(api, trigger_id)
        fire(api, trigger_id)
        rows = wait_until(
            api,
            trigger_id,
            lambda current: (
                any(row.get("workflowId") == workflow_ids["skipped"] and row.get("status") == "skipped" for row in current)
                and any(row.get("workflowId") == workflow_ids["superseded"] and row.get("status") == "superseded" for row in current)
                and any(row.get("workflowId") == workflow_ids["shed"] and row.get("status") == "pending" for row in current)
            ),
            args.timeout,
        )
        print(json.dumps({"phase": "prepare", "trigger": trigger_id, "workflows": workflow_ids, "first": summarize(first, workflow_ids), "current": summarize(rows, workflow_ids)}, ensure_ascii=False))
        return

    # The serial workflow owns the deliberately pending rows. Kill is the public hard-stop path;
    # it turns accepted pending firings into the neutral durable `shed` disposition.
    api.must("POST", f"/api/v1/workflows/{workflow_ids['shed']}:kill")
    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        rows = list_firings(api, trigger_id)
        if any(row.get("workflowId") == workflow_ids["shed"] and row.get("status") == "shed" for row in rows):
            break
        time.sleep(0.5)
    else:
        raise RuntimeError(f"serial firing was not shed: {rows!r}")

    # The slow runs finish naturally before the listener shutdown is recorded; this leaves the
    # superseded audit row and the skip/shed outcomes intact without background fixture leakage.
    time.sleep(1)
    for label, workflow_id in workflow_ids.items():
        if label != "shed":
            deactivate(api, workflow_id, args.timeout)
    rows = list_firings(api, trigger_id)
    print(json.dumps({"phase": "settle", "trigger": trigger_id, "workflows": workflow_ids, "final": summarize(rows, workflow_ids)}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf031: {exc}", file=sys.stderr)
        raise
