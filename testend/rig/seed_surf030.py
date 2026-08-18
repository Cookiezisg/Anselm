#!/usr/bin/env python3
"""Seed real sensor activation history for SURF-030's trigger activity tab.

The fixture uses the public HTTP surface only. A stateful handler alternates its probe result,
so the sensor writes both non-fired and fired activation rows. Manual fires then bring the fired
side past the UI page size, making the filter and keyset pagination observable in the real app.
The script is idempotent: named entities are reused and only the missing activation target is
created on later runs.
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
    parser.add_argument("--base", default="http://127.0.0.1:9038")
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--handler-name", default="surf030_activity_probe")
    parser.add_argument("--trigger-name", default="surf030_activity_sensor")
    parser.add_argument("--workflow-name", default="surf030_activity_workflow")
    parser.add_argument("--fired-target", type=int, default=22)
    parser.add_argument("--probe-target", type=int, default=6)
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
                "description": "SURF-030 real sensor probe for trigger activity observability",
                "initBody": "self.probes = 0",
                "methods": [
                    {
                        "name": "probe",
                        "description": "alternate a health result for sensor audit rows",
                        "inputs": [],
                        "outputs": [
                            {"name": "ok", "type": "boolean"},
                            {"name": "probe", "type": "number"},
                            {"name": "source", "type": "string"},
                        ],
                        "body": (
                            "self.probes += 1\n"
                            "print(f'SURF-030 sensor probe {self.probes}')\n"
                            "return {'ok': self.probes % 2 == 0, 'probe': self.probes, 'source': 'surf030'}\n"
                        ),
                    }
                ],
                "changeReason": "SURF-030 real trigger activity fixture",
            },
        )
    )
    if not isinstance(response, dict) or not response.get("id"):
        raise RuntimeError(f"unexpected handler create response: {response!r}")
    return str(response["id"])


def ensure_trigger(api: API, name: str, handler_id: str) -> str:
    existing = find_entity(api, "triggers", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/triggers",
            {
                "name": name,
                "description": "SURF-030 alternating sensor with fired and non-fired audit rows",
                "kind": "sensor",
                "config": {
                    "targetKind": "handler",
                    "targetId": handler_id,
                    "method": "probe",
                    "intervalSec": 5,
                    "condition": "payload.ok == true",
                    "output": '{"probe": payload.probe, "source": payload.source}',
                },
            },
        )
    )
    if not isinstance(response, dict) or not response.get("id"):
        raise RuntimeError(f"unexpected trigger create response: {response!r}")
    return str(response["id"])


def ensure_workflow(api: API, name: str, trigger_id: str) -> str:
    existing = find_entity(api, "workflows", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": name,
                "description": "SURF-030 real sensor activity workflow listener",
                "ops": [
                    {"op": "set_meta", "concurrency": "allow_all"},
                    {
                        "op": "add_node",
                        "node": {
                            "id": "entry",
                            "kind": "trigger",
                            "ref": trigger_id,
                            "pos": {"x": 160, "y": 180},
                        },
                    },
                ],
                "changeReason": "SURF-030 real trigger activity fixture",
            },
        )
    )
    if not isinstance(response, dict) or not response.get("id"):
        raise RuntimeError(f"unexpected workflow create response: {response!r}")
    return str(response["id"])


def activations(api: API, trigger_id: str) -> list[dict[str, Any]]:
    response = data(api.must("GET", f"/api/v1/triggers/{trigger_id}/activations?limit=200"))
    if not isinstance(response, list):
        raise RuntimeError(f"unexpected activation response: {response!r}")
    return response


def workflow(api: API, workflow_id: str) -> dict[str, Any]:
    response = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(response, dict):
        raise RuntimeError(f"unexpected workflow response: {response!r}")
    return response


def wait_for_sensor_rows(api: API, trigger_id: str, target: int, timeout: float) -> list[dict[str, Any]]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        rows = activations(api, trigger_id)
        if len(rows) >= target and any(not row.get("fired") for row in rows) and any(row.get("fired") for row in rows):
            return rows
        time.sleep(1)
    rows = activations(api, trigger_id)
    raise RuntimeError(
        f"sensor did not produce both fired states before timeout: total={len(rows)} "
        f"fired={sum(bool(row.get('fired')) for row in rows)} "
        f"notFired={sum(not bool(row.get('fired')) for row in rows)}"
    )


def ensure_fired_rows(api: API, trigger_id: str, target: int) -> list[dict[str, Any]]:
    rows = activations(api, trigger_id)
    fired = sum(bool(row.get("fired")) for row in rows)
    while fired < target:
        status, response = api.request("POST", f"/api/v1/triggers/{trigger_id}:fire")
        if status >= 400:
            raise RuntimeError(f"manual fire -> HTTP {status}: {response}")
        fired += 1
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        rows = activations(api, trigger_id)
        if sum(bool(row.get("fired")) for row in rows) >= target:
            return rows
        time.sleep(0.5)
    raise RuntimeError(f"manual fires did not settle: fired target={target}, rows={rows!r}")


def deactivate(api: API, workflow_id: str, timeout: float) -> None:
    api.must("POST", f"/api/v1/workflows/{workflow_id}:deactivate")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        current = workflow(api, workflow_id)
        if not current.get("active") and current.get("lifecycleState") in {"inactive", "draining"}:
            if current.get("lifecycleState") == "inactive":
                return
        time.sleep(0.5)
    raise RuntimeError(f"workflow did not settle after deactivate: {workflow(api, workflow_id)!r}")


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    handler_id = ensure_handler(api, args.handler_name)
    trigger_id = ensure_trigger(api, args.trigger_name, handler_id)
    workflow_id = ensure_workflow(api, args.workflow_name, trigger_id)

    api.must("POST", f"/api/v1/workflows/{workflow_id}:activate")
    wait_for_sensor_rows(api, trigger_id, args.probe_target, args.timeout)
    rows = ensure_fired_rows(api, trigger_id, args.fired_target)
    deactivate(api, workflow_id, args.timeout)
    rows = activations(api, trigger_id)
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "handler": handler_id,
                "trigger": trigger_id,
                "workflow": workflow_id,
                "workflowState": workflow(api, workflow_id).get("lifecycleState"),
                "activations": len(rows),
                "fired": sum(bool(row.get("fired")) for row in rows),
                "notFired": sum(not bool(row.get("fired")) for row in rows),
                "manualFired": sum(bool(row.get("payload", {}).get("manual")) for row in rows),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf030: {exc}", file=sys.stderr)
        raise
