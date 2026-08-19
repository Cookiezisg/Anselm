#!/usr/bin/env python3
"""Seed real Trigger entities for SURF-040's Entities rail path.

The fixture uses only public HTTP APIs and is idempotent by entity name. One cron trigger is
attached to an active workflow so the rail has a real hot listener; the other source kinds stay
quiet while still exercising their detail configuration and pause semantics.
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
            with urllib.request.urlopen(request, timeout=60) as response:
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


def find_named(api: API, path: str, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", path))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected list response for {path}: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def ensure_function(api: API, name: str) -> str:
    existing = find_named(api, "/api/v1/functions?limit=200", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/functions",
            {
                "name": name,
                "description": "SURF-040 trigger fixture function",
                "code": "def surface_probe() -> dict:\n    return {\"level\": 0}\n",
            },
        )
    )
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected function create response: {response!r}")
    return response["id"]


def ensure_trigger(api: API, spec: dict[str, Any]) -> str:
    existing = find_named(api, "/api/v1/triggers?limit=200", spec["name"])
    if existing:
        return str(existing["id"])
    response = data(api.must("POST", "/api/v1/triggers", spec))
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected trigger create response: {response!r}")
    return response["id"]


def ensure_workflow(api: API, name: str, trigger_id: str, function_id: str) -> str:
    existing = find_named(api, "/api/v1/workflows?limit=200", name)
    if existing:
        workflow_id = str(existing["id"])
        if existing.get("active") is not True and existing.get("lifecycleState") != "active":
            api.must("POST", f"/api/v1/workflows/{workflow_id}:activate", {})
        return workflow_id

    response = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": name,
                "ops": [
                    {
                        "op": "add_node",
                        "node": {"id": "start", "kind": "trigger", "ref": trigger_id},
                    },
                    {
                        "op": "add_node",
                        "node": {"id": "step", "kind": "action", "ref": function_id},
                    },
                    {
                        "op": "add_edge",
                        "edge": {"id": "e1", "from": "start", "to": "step"},
                    },
                ],
            },
        )
    )
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected workflow create response: {response!r}")
    workflow_id = response["id"]
    api.must("POST", f"/api/v1/workflows/{workflow_id}:activate", {})
    return workflow_id


def ensure_paused(api: API, trigger_id: str) -> None:
    detail = data(api.must("GET", f"/api/v1/triggers/{trigger_id}"))
    if not isinstance(detail, dict):
        raise RuntimeError(f"unexpected trigger detail response: {detail!r}")
    if detail.get("paused") is not True:
        api.must("POST", f"/api/v1/triggers/{trigger_id}:pause", {})


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api, "surf040_surface_probe")
    hot_cron_id = ensure_trigger(
        api,
        {
            "name": "surf040_hot_cron",
            "description": "A live daily schedule with one active workflow listener.",
            "kind": "cron",
            "config": {"expression": "0 0 * * *", "misfirePolicy": "skip"},
        },
    )
    webhook_id = ensure_trigger(
        api,
        {
            "name": "surf040_cold_webhook",
            "description": "An inbound release webhook waiting for its first workflow.",
            "kind": "webhook",
            "config": {
                "path": "surf040/incoming",
                "secret": "surf040-hook-secret",
                "signatureAlgo": "hmac-sha256-hex",
            },
        },
    )
    paused_fs_id = ensure_trigger(
        api,
        {
            "name": "surf040_paused_fs",
            "description": "A paused file watcher kept for a deliberate stop state.",
            "kind": "fsnotify",
            "config": {
                "path": "/tmp/anselm-surf040-watch",
                "events": ["create", "write"],
                "pattern": "*.json",
            },
        },
    )
    sensor_id = ensure_trigger(
        api,
        {
            "name": "surf040_cold_sensor",
            "description": "A quiet CEL probe with no active listener.",
            "kind": "sensor",
            "config": {
                "targetKind": "function",
                "targetId": function_id,
                "intervalSec": 60,
                "condition": "payload.level > 10",
                "output": '{"level": payload.level}',
            },
        },
    )
    workflow_id = ensure_workflow(api, "surf040_hot_cron_pipe", hot_cron_id, function_id)
    ensure_paused(api, paused_fs_id)

    result = []
    for trigger_id, name in (
        (hot_cron_id, "surf040_hot_cron"),
        (webhook_id, "surf040_cold_webhook"),
        (paused_fs_id, "surf040_paused_fs"),
        (sensor_id, "surf040_cold_sensor"),
    ):
        detail = data(api.must("GET", f"/api/v1/triggers/{trigger_id}"))
        result.append(
            {
                "id": trigger_id,
                "name": name,
                "kind": detail.get("kind"),
                "listening": detail.get("listening"),
                "paused": detail.get("paused"),
                "refCount": detail.get("refCount"),
            }
        )
    print(json.dumps({"workspace": args.workspace, "workflow": workflow_id, "triggers": result}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf040: {exc}", file=sys.stderr)
        raise
