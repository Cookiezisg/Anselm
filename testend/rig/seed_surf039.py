#!/usr/bin/env python3
"""Seed real Approval support entities for SURF-039's Entities rail path.

The fixture uses only the public HTTP API and is idempotent by approval name. The three forms
exercise typed inputs, markdown interpolation, allow-reason, and both timeout/no-timeout shapes.
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


def find_approval(api: API, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", "/api/v1/approvals?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected approvals response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def ensure_approval(api: API, spec: dict[str, Any]) -> str:
    existing = find_approval(api, spec["name"])
    if existing:
        return str(existing["id"])
    response = data(api.must("POST", "/api/v1/approvals", spec))
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected approval create response: {response!r}")
    return response["id"]


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    approvals = [
        {
            "name": "surf039_refund_gate",
            "description": "Review a refund request before it is issued.",
            "inputs": [
                {"name": "requestId", "type": "string", "description": "refund request"},
                {"name": "amount", "type": "number", "description": "refund amount"},
            ],
            "template": "# Refund review\n\nApprove refund **{{ input.amount }}** for `{{ input.requestId }}`?",
            "allowReason": True,
            "timeout": "2h",
            "timeoutBehavior": "reject",
            "changeReason": "SURF-039 real Approval rail fixture",
        },
        {
            "name": "surf039_publish_gate",
            "description": "Review a release before publishing it.",
            "inputs": [{"name": "release", "type": "string", "description": "release tag"}],
            "template": "## Publish review\n\nApprove release **{{ input.release }}**?",
            "allowReason": False,
            "timeout": "30d",
            "timeoutBehavior": "approve",
            "changeReason": "SURF-039 real Approval rail fixture",
        },
        {
            "name": "surf039_note_gate",
            "description": "Ask for a human review of a free-form note.",
            "inputs": [{"name": "note", "type": "string", "description": "note to review"}],
            "template": "### Review note\n\n{{ input.note }}",
            "allowReason": True,
            "timeout": "",
            "changeReason": "SURF-039 real Approval rail fixture",
        },
    ]
    result = []
    for spec in approvals:
        approval_id = ensure_approval(api, spec)
        approval = data(api.must("GET", f"/api/v1/approvals/{approval_id}"))
        active = approval.get("activeVersion") if isinstance(approval, dict) else None
        result.append(
            {
                "id": approval_id,
                "name": spec["name"],
                "version": active.get("version") if isinstance(active, dict) else None,
                "inputs": len(active.get("inputs", [])) if isinstance(active, dict) else None,
                "timeout": active.get("timeout") if isinstance(active, dict) else None,
            }
        )
    print(json.dumps({"workspace": args.workspace, "approvals": result}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf039: {exc}", file=sys.stderr)
        raise
