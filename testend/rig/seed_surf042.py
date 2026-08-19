#!/usr/bin/env python3
"""Seed a real graph-editor fixture for SURF-042.

The graph deliberately exposes every inspector branch that can be inspected without running the
workflow: action function and handler-method refs, an agent ref, a control with two ports, and an
approval with yes/no edges. It stays deactivated so this fixture cannot create scheduler history
while the acceptance pass is editing the graph. Only public HTTP APIs are used; SQLite is never
written directly.
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
    parser.add_argument("--base", default="http://127.0.0.1:9070")
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


def find_named(api: API, collection: str, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", f"/api/v1/{collection}?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected {collection} list response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def create_named(api: API, collection: str, spec: dict[str, Any]) -> str:
    existing = find_named(api, collection, str(spec["name"]))
    if existing:
        return str(existing["id"])
    response = data(api.must("POST", f"/api/v1/{collection}", spec))
    if not isinstance(response, dict) or not isinstance(response.get("id"), str):
        raise RuntimeError(f"unexpected {collection} create response: {response!r}")
    return response["id"]


def ensure_function(api: API) -> str:
    return create_named(
        api,
        "functions",
        {
            "name": "surf042_inspector_function",
            "description": "Function target for the SURF-042 workflow editor inspector.",
            "code": (
                "def inspect(message, amount):\n"
                "    return {'message': message, 'amount': amount, 'ok': True}\n"
            ),
            "inputs": [
                {"name": "message", "type": "string", "description": "editor message"},
                {"name": "amount", "type": "number", "description": "editor amount"},
            ],
            "outputs": [
                {"name": "message", "type": "string"},
                {"name": "amount", "type": "number"},
                {"name": "ok", "type": "boolean"},
            ],
            "changeReason": "SURF-042 graph editor inspector fixture",
        },
    )


def ensure_handler(api: API) -> str:
    return create_named(
        api,
        "handlers",
        {
            "name": "surf042_inspector_handler",
            "description": "Handler target with a selectable method for SURF-042.",
            "initBody": "self.calls = 0",
            "methods": [
                {
                    "name": "inspect",
                    "description": "Return a durable inspection result.",
                    "inputs": [{"name": "label", "type": "string"}],
                    "outputs": [{"name": "ok", "type": "boolean"}],
                    "body": (
                        "self.calls += 1\n"
                        "return {'label': label, 'calls': self.calls, 'ok': True}\n"
                    ),
                },
                {
                    "name": "summarize",
                    "description": "Return a second member for the member dropdown.",
                    "inputs": [{"name": "message", "type": "string"}],
                    "outputs": [{"name": "summary", "type": "string"}],
                    "body": "return {'summary': message}\n",
                },
            ],
            "changeReason": "SURF-042 graph editor inspector fixture",
        },
    )


def ensure_agent(api: API) -> str:
    return create_named(
        api,
        "agents",
        {
            "name": "surf042_inspector_agent",
            "description": "Agent target for the SURF-042 node-kind/ref inspector path.",
            "prompt": "Return one concise sentence. Do not use tools.",
            "inputs": [{"name": "request", "type": "string", "description": "agent request"}],
            "outputs": [{"name": "answer", "type": "string"}],
            "changeReason": "SURF-042 graph editor inspector fixture",
        },
    )


def ensure_trigger(api: API) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": "surf042_inspector_trigger",
            "description": "Webhook target for the SURF-042 graph editor.",
            "kind": "webhook",
            "config": {"path": "surf042-inspector"},
        },
    )


def ensure_control(api: API) -> str:
    return create_named(
        api,
        "controls",
        {
            "name": "surf042_inspector_control",
            "description": "Two-port control for the edge-port inspector.",
            "inputs": [{"name": "amount", "type": "number", "description": "route amount"}],
            "branches": [
                {"port": "pass", "when": "input.amount >= 0", "emit": {"tier": "'pass'"}},
                {"port": "retry", "when": "true", "emit": {"tier": "'retry'"}},
            ],
        },
    )


def ensure_approval(api: API) -> str:
    return create_named(
        api,
        "approvals",
        {
            "name": "surf042_inspector_approval",
            "description": "Approval target for the yes/no edge-port inspector.",
            "inputs": [{"name": "amount", "type": "number", "description": "amount to review"}],
            "template": "Approve SURF-042 amount {{ input.amount }}?",
            "allowReason": True,
            "timeout": "2d",
            "timeoutBehavior": "reject",
        },
    )


def ensure_workflow(
    api: API,
    function_id: str,
    handler_id: str,
    agent_id: str,
    trigger_id: str,
    control_id: str,
    approval_id: str,
) -> str:
    name = "surf042_inspector_workflow"
    existing = find_named(api, "workflows", name)
    if existing:
        workflow_id = str(existing["id"])
    else:
        ops = [
            {"op": "set_meta", "concurrency": "allow_all"},
            {
                "op": "add_node",
                "node": {
                    "id": "entry",
                    "kind": "trigger",
                    "ref": trigger_id,
                    "pos": {"x": 80, "y": 240},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "functionAction",
                    "kind": "action",
                    "ref": function_id,
                    "input": {"message": "entry.body.message", "amount": "entry.body.amount"},
                    "retry": {"maxAttempts": 3},
                    "pos": {"x": 350, "y": 240},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "handlerAction",
                    "kind": "action",
                    "ref": f"{handler_id}.inspect",
                    "input": {"label": "functionAction.message"},
                    "retry": {"maxAttempts": 2},
                    "pos": {"x": 620, "y": 240},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "agentAction",
                    "kind": "agent",
                    "ref": agent_id,
                    "input": {"request": "functionAction.message"},
                    "pos": {"x": 890, "y": 240},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "route",
                    "kind": "control",
                    "ref": control_id,
                    "input": {"amount": "functionAction.amount"},
                    "pos": {"x": 1160, "y": 240},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "review",
                    "kind": "approval",
                    "ref": approval_id,
                    "input": {"amount": "functionAction.amount"},
                    "pos": {"x": 1430, "y": 150},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "finish",
                    "kind": "action",
                    "ref": f"{handler_id}.summarize",
                    "input": {"message": "review.reason"},
                    "retry": {"maxAttempts": 2},
                    "pos": {"x": 1700, "y": 150},
                },
            },
            {
                "op": "add_node",
                "node": {
                    "id": "fallback",
                    "kind": "action",
                    "ref": function_id,
                    "input": {"message": "agentAction.answer", "amount": "functionAction.amount"},
                    "pos": {"x": 1430, "y": 360},
                },
            },
            {"op": "add_edge", "edge": {"id": "entry-function", "from": "entry", "to": "functionAction"}},
            {
                "op": "add_edge",
                "edge": {"id": "function-handler", "from": "functionAction", "to": "handlerAction"},
            },
            {"op": "add_edge", "edge": {"id": "handler-agent", "from": "handlerAction", "to": "agentAction"}},
            {"op": "add_edge", "edge": {"id": "agent-route", "from": "agentAction", "to": "route"}},
            {
                "op": "add_edge",
                "edge": {"id": "route-pass", "from": "route", "to": "review", "fromPort": "pass"},
            },
            {
                "op": "add_edge",
                "edge": {"id": "route-retry", "from": "route", "to": "fallback", "fromPort": "retry"},
            },
            {
                "op": "add_edge",
                "edge": {"id": "review-yes", "from": "review", "to": "finish", "fromPort": "yes"},
            },
            {
                "op": "add_edge",
                "edge": {"id": "review-no", "from": "review", "to": "fallback", "fromPort": "no"},
            },
        ]
        response = data(
            api.must(
                "POST",
                "/api/v1/workflows",
                {
                    "name": name,
                    "description": "SURF-042 full graph-editor inspector fixture",
                    "ops": ops,
                    "changeReason": "SURF-042 graph editor inspector fixture",
                },
            )
        )
        if not isinstance(response, dict) or not isinstance(response.get("id"), str):
            raise RuntimeError(f"unexpected workflow create response: {response!r}")
        workflow_id = response["id"]

    workflow = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(workflow, dict):
        raise RuntimeError(f"unexpected workflow detail: {workflow!r}")
    graph = workflow.get("activeVersion", {}).get("graphParsed", {})
    nodes = graph.get("nodes", []) if isinstance(graph, dict) else []
    edges = graph.get("edges", []) if isinstance(graph, dict) else []
    agent_node = next((node for node in nodes if isinstance(node, dict) and node.get("id") == "agentAction"), None)
    expected_agent_input = {"request": "functionAction.message"}
    if isinstance(agent_node, dict) and agent_node.get("input") != expected_agent_input:
        api.must(
            "POST",
            f"/api/v1/workflows/{workflow_id}:edit",
            {
                "ops": [
                    {
                        "op": "update_node",
                        "id": "agentAction",
                        "patch": {"input": expected_agent_input},
                    }
                ],
                "changeReason": "SURF-042 remove unresolved inspector fixture input",
            },
        )
        workflow = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
        graph = workflow.get("activeVersion", {}).get("graphParsed", {})
        nodes = graph.get("nodes", []) if isinstance(graph, dict) else []
        edges = graph.get("edges", []) if isinstance(graph, dict) else []
    node_ids = {node.get("id") for node in nodes if isinstance(node, dict)}
    edge_ids = {edge.get("id") for edge in edges if isinstance(edge, dict)}
    expected_nodes = {
        "entry",
        "functionAction",
        "handlerAction",
        "agentAction",
        "route",
        "review",
        "finish",
        "fallback",
    }
    expected_edges = {
        "entry-function",
        "function-handler",
        "handler-agent",
        "agent-route",
        "route-pass",
        "route-retry",
        "review-yes",
        "review-no",
    }
    if not expected_nodes.issubset(node_ids) or not expected_edges.issubset(edge_ids):
        raise RuntimeError(
            f"existing {name} has the wrong graph; nodes={sorted(node_ids)!r}, edges={sorted(edge_ids)!r}"
        )
    if workflow.get("active") is True or workflow.get("lifecycleState") == "active":
        raise RuntimeError(f"{name} must remain deactivated for editor acceptance: {workflow!r}")
    return workflow_id


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    handler_id = ensure_handler(api)
    agent_id = ensure_agent(api)
    trigger_id = ensure_trigger(api)
    control_id = ensure_control(api)
    approval_id = ensure_approval(api)
    workflow_id = ensure_workflow(
        api,
        function_id,
        handler_id,
        agent_id,
        trigger_id,
        control_id,
        approval_id,
    )
    workflow = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    graph = workflow.get("activeVersion", {}).get("graphParsed", {})
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "workflow": workflow_id,
                "workflowName": "surf042_inspector_workflow",
                "active": workflow.get("active"),
                "lifecycleState": workflow.get("lifecycleState"),
                "function": function_id,
                "handler": handler_id,
                "agent": agent_id,
                "trigger": trigger_id,
                "control": control_id,
                "approval": approval_id,
                "graph": {
                    "nodes": len(graph.get("nodes", [])),
                    "edges": len(graph.get("edges", [])),
                    "kinds": ["trigger", "action", "agent", "control", "approval"],
                },
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf042: {exc}", file=sys.stderr)
        raise
