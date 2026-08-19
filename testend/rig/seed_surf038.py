#!/usr/bin/env python3
"""Seed real Control support entities for SURF-038's Entities rail path.

The fixture uses only the public HTTP API and is idempotent by entity name. It deliberately creates
three different branch shapes so the rail count/search path and the detail page's port/when/emit
presentation are exercised without inventing SQLite rows.
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


def find_control(api: API, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", "/api/v1/controls?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected controls response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def ensure_control(
    api: API,
    *,
    name: str,
    description: str,
    inputs: list[dict[str, str]],
    branches: list[dict[str, Any]],
) -> str:
    existing = find_control(api, name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/controls",
            {
                "name": name,
                "description": description,
                "inputs": inputs,
                "branches": branches,
                "changeReason": "SURF-038 real Control rail fixture",
            },
        )
    )
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected control create response: {response!r}")
    return response["id"]


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    controls = [
        {
            "name": "surf038_customer_router",
            "description": "Choose a customer lane from score and region.",
            "inputs": [
                {"name": "score", "type": "number", "description": "customer score"},
                {"name": "region", "type": "string", "description": "customer region"},
            ],
            "branches": [
                {
                    "port": "priority",
                    "when": "input.score >= 0.8",
                    "emit": {"lane": "'priority'", "score": "input.score"},
                },
                {
                    "port": "domestic",
                    "when": "input.region == 'us'",
                    "emit": {"lane": "'domestic'"},
                },
                {"port": "default", "when": "true"},
            ],
        },
        {
            "name": "surf038_review_router",
            "description": "Route a review to approve or inspect.",
            "inputs": [{"name": "score", "type": "number", "description": "review score"}],
            "branches": [
                {
                    "port": "approve",
                    "when": "input.score >= 0.9",
                    "emit": {"decision": "'approve'"},
                },
                {"port": "inspect", "when": "true"},
            ],
        },
        {
            "name": "surf038_default_router",
            "description": "A minimal catch-all routing rule.",
            "inputs": [{"name": "message", "type": "string", "description": "message"}],
            "branches": [{"port": "default", "when": "true"}],
        },
    ]
    result = []
    for spec in controls:
        control_id = ensure_control(api, **spec)
        control = data(api.must("GET", f"/api/v1/controls/{control_id}"))
        active = control.get("activeVersion") if isinstance(control, dict) else None
        result.append(
            {
                "id": control_id,
                "name": spec["name"],
                "version": active.get("version") if isinstance(active, dict) else None,
                "branches": len(active.get("branches", [])) if isinstance(active, dict) else None,
            }
        )
    print(json.dumps({"workspace": args.workspace, "controls": result}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf038: {exc}", file=sys.stderr)
        raise
