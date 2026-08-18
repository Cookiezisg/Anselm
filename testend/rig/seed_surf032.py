#!/usr/bin/env python3
"""Seed a real, deactivated workflow for SURF-032's full-screen graph editor.

The fixture deliberately equips the graph with trigger, action, control and approval nodes, plus an
Agent target for the add-node/ref-picker path, so the editor's canvas, node inspector, input map,
retry control and edge-port picker have real references to resolve. It uses only public HTTP APIs and
never writes SQLite rows.
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
    parser.add_argument("--base", default="http://127.0.0.1:9040")
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
    rows = data(api.must("GET", f"/api/v1/{kind}?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected {kind} list response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def ensure_function(api: API) -> str:
    name = "surf032_editor_action"
    existing = find_entity(api, "functions", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/functions",
            {
                "name": name,
                "description": "SURF-032 graph editor action reference",
                "code": (
                    "def run(message: str, amount: int) -> dict:\n"
                    "    return {'message': message, 'amount': amount, 'ok': True}\n"
                ),
                "inputs": [
                    {"name": "message", "type": "string", "description": "editor input"},
                    {"name": "amount", "type": "number", "description": "editor input"},
                ],
                "outputs": [
                    {"name": "message", "type": "string"},
                    {"name": "amount", "type": "number"},
                    {"name": "ok", "type": "boolean"},
                ],
                "changeReason": "SURF-032 real graph editor fixture",
            },
        )
    )
    return str(response["id"])


def ensure_trigger(api: API) -> str:
    name = "surf032_editor_trigger"
    existing = find_entity(api, "triggers", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/triggers",
            {
                "name": name,
                "description": "SURF-032 graph editor trigger reference",
                "kind": "webhook",
                "config": {"path": "surf032-editor"},
            },
        )
    )
    return str(response["id"])


def ensure_control(api: API) -> str:
    name = "surf032_editor_router"
    existing = find_entity(api, "controls", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/controls",
            {
                "name": name,
                "description": "SURF-032 graph editor routing reference",
                "inputs": [{"name": "amount", "type": "number", "description": "route input"}],
                "branches": [
                    {"port": "large", "when": "input.amount > 100", "emit": {"tier": "'large'"}},
                    {"port": "default", "when": "true"},
                ],
            },
        )
    )
    return str(response["id"])


def ensure_approval(api: API) -> str:
    name = "surf032_editor_approval"
    existing = find_entity(api, "approvals", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/approvals",
            {
                "name": name,
                "description": "SURF-032 graph editor approval reference",
                "inputs": [{"name": "amount", "type": "number", "description": "amount to review"}],
                "template": "Approve SURF-032 amount {{ input.amount }}?",
                "allowReason": True,
                "timeout": "2d",
                "timeoutBehavior": "reject",
            },
        )
    )
    return str(response["id"])


def ensure_agent(api: API) -> str:
    name = "surf032_editor_agent"
    existing = find_entity(api, "agents", name)
    if existing:
        return str(existing["id"])
    response = data(
        api.must(
            "POST",
            "/api/v1/agents",
            {
                "name": name,
                "description": "SURF-032 graph editor agent reference",
                "prompt": "Return one short sentence for the editor fixture. Do not use tools.",
                "inputs": [{"name": "request", "type": "string", "description": "editor input"}],
                "outputs": [{"name": "answer", "type": "string"}],
                "changeReason": "SURF-032 real graph editor fixture",
            },
        )
    )
    return str(response["id"])


def ensure_workflow(api: API, function_id: str, trigger_id: str, control_id: str, approval_id: str) -> str:
    name = "surf032_workflow_editor"
    existing = find_entity(api, "workflows", name)
    if existing:
        return str(existing["id"])
    ops = [
        {"op": "set_meta", "concurrency": "allow_all"},
        {
            "op": "add_node",
            "node": {
                "id": "start",
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
                "input": {"message": "start.body.message", "amount": "start.body.amount"},
                "retry": {"maxAttempts": 3},
                "pos": {"x": 340, "y": 180},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "route",
                "kind": "control",
                "ref": control_id,
                "input": {"amount": "work.amount"},
                "pos": {"x": 600, "y": 180},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "review",
                "kind": "approval",
                "ref": approval_id,
                # The control emits an optional routing label, not the action payload amount.
                # 控制节点只发可选路由标签，不是 action 的 amount；审批必须读取真实上游字段。
                "input": {"amount": "work.amount"},
                "pos": {"x": 860, "y": 120},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "finish",
                "kind": "action",
                "ref": function_id,
                "input": {"message": "review.reason", "amount": "review.amount"},
                "pos": {"x": 1120, "y": 120},
            },
        },
        {
            "op": "add_node",
            "node": {
                "id": "fallback",
                "kind": "action",
                "ref": function_id,
                # The default branch has no emit payload, so it cannot provide route.tier.
                # default 分支没有 emit 载荷，不能读取 route.tier；回退动作沿用 work 的真实消息。
                "input": {"message": "work.message", "amount": "work.amount"},
                "pos": {"x": 860, "y": 300},
            },
        },
        {"op": "add_edge", "edge": {"id": "start-work", "from": "start", "to": "work"}},
        {"op": "add_edge", "edge": {"id": "work-route", "from": "work", "to": "route"}},
        {"op": "add_edge", "edge": {"id": "route-large", "from": "route", "to": "review", "fromPort": "large"}},
        {"op": "add_edge", "edge": {"id": "route-default", "from": "route", "to": "fallback", "fromPort": "default"}},
        {"op": "add_edge", "edge": {"id": "review-finish", "from": "review", "to": "finish", "fromPort": "yes"}},
    ]
    response = data(
        api.must(
            "POST",
            "/api/v1/workflows",
            {
                "name": name,
                "description": "SURF-032 full-screen graph editor fixture",
                "ops": ops,
                "changeReason": "SURF-032 real graph editor fixture",
            },
        )
    )
    return str(response["id"])


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    trigger_id = ensure_trigger(api)
    control_id = ensure_control(api)
    approval_id = ensure_approval(api)
    agent_id = ensure_agent(api)
    workflow_id = ensure_workflow(api, function_id, trigger_id, control_id, approval_id)
    workflow = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "workflow": workflow_id,
                "workflowName": "surf032_workflow_editor",
                "active": workflow.get("active"),
                "lifecycleState": workflow.get("lifecycleState"),
                "function": function_id,
                "trigger": trigger_id,
                "control": control_id,
                "approval": approval_id,
                "agent": agent_id,
                "graph": {"nodes": 6, "edges": 5, "kinds": ["trigger", "action", "control", "approval"]},
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf032: {exc}", file=sys.stderr)
        raise
