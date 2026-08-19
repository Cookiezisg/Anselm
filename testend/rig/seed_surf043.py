#!/usr/bin/env python3
"""Seed the real relation-graph card fixture for SURF-043.

The selected Function is a graph node with a description and a version. An Agent mounts it and a
deactivated Workflow references it, so the card must render hydrated names in its referenced-by
group and still offer the rail detail route. Only public HTTP APIs are used.
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
    return response.get("data") if isinstance(response, dict) and "data" in response else response


def find_named(api: API, collection: str, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", f"/api/v1/{collection}?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected {collection} list response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def create_named(api: API, collection: str, spec: dict[str, Any]) -> str:
    existing = find_named(api, collection, str(spec["name"]))
    if existing:
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
            "name": "surf043_graph_card_function",
            "description": "A deliberately described function for the SURF-043 graph card.",
            "code": "def summarize(label):\n    return {'label': label, 'ok': True}\n",
            "inputs": [{"name": "label", "type": "string", "description": "label to summarize"}],
            "outputs": [
                {"name": "label", "type": "string"},
                {"name": "ok", "type": "boolean"},
            ],
            "changeReason": "SURF-043 relation graph card fixture",
        },
    )


def ensure_agent(api: API, function_id: str) -> str:
    return create_named(
        api,
        "agents",
        {
            "name": "surf043_graph_card_agent",
            "description": "Agent that mounts the SURF-043 graph-card function.",
            "prompt": "Use the mounted function when asked for a summary.",
            "tools": [{"ref": function_id}],
            "inputs": [{"name": "request", "type": "string", "description": "request"}],
            "outputs": [{"name": "answer", "type": "string"}],
            "changeReason": "SURF-043 relation graph card fixture",
        },
    )


def ensure_trigger(api: API) -> str:
    return create_named(
        api,
        "triggers",
        {
            "name": "surf043_graph_card_trigger",
            "description": "A dormant trigger for the graph-card workflow.",
            "kind": "webhook",
            "config": {"path": "surf043-graph-card"},
        },
    )


def ensure_workflow(api: API, function_id: str, trigger_id: str) -> str:
    name = "surf043_graph_card_workflow"
    existing = find_named(api, "workflows", name)
    if existing:
        workflow_id = str(existing["id"])
    else:
        created = data(
            api.must(
                "POST",
                "/api/v1/workflows",
                {
                    "name": name,
                    "description": "A dormant workflow that references the SURF-043 graph-card function.",
                    "ops": [
                        {"op": "set_meta", "concurrency": "allow_all"},
                        {
                            "op": "add_node",
                            "node": {"id": "entry", "kind": "trigger", "ref": trigger_id, "pos": {"x": 80, "y": 180}},
                        },
                        {
                            "op": "add_node",
                            "node": {
                                "id": "summarize",
                                "kind": "action",
                                "ref": function_id,
                                "input": {"label": "entry.body.label"},
                                "pos": {"x": 360, "y": 180},
                            },
                        },
                        {"op": "add_edge", "edge": {"id": "entry-summarize", "from": "entry", "to": "summarize"}},
                    ],
                    "changeReason": "SURF-043 relation graph card fixture",
                },
            )
        )
        if not isinstance(created, dict) or not isinstance(created.get("id"), str):
            raise RuntimeError(f"unexpected workflow create response: {created!r}")
        workflow_id = created["id"]

    workflow = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))
    if not isinstance(workflow, dict):
        raise RuntimeError(f"unexpected workflow detail: {workflow!r}")
    graph = workflow.get("activeVersion", {}).get("graphParsed", {})
    nodes = graph.get("nodes", []) if isinstance(graph, dict) else []
    refs = {node.get("ref") for node in nodes if isinstance(node, dict)}
    if function_id not in refs:
        raise RuntimeError(f"workflow lost function reference: {workflow!r}")
    if workflow.get("active") is True or workflow.get("lifecycleState") == "active":
        raise RuntimeError("SURF-043 workflow must remain deactivated")
    return workflow_id


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    agent_id = ensure_agent(api, function_id)
    trigger_id = ensure_trigger(api)
    workflow_id = ensure_workflow(api, function_id, trigger_id)
    graph = data(api.must("GET", f"/api/v1/workflows/{workflow_id}"))["activeVersion"]["graphParsed"]
    relgraph = data(api.must("GET", "/api/v1/relgraph"))
    edges = relgraph.get("edges", []) if isinstance(relgraph, dict) else []
    referenced_by = [
        edge
        for edge in edges
        if edge.get("toId") == function_id and edge.get("kind") in {"equip", "link"}
    ]
    if len(referenced_by) < 2:
        raise RuntimeError(f"expected agent and workflow relation edges, got {referenced_by!r}")
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "function": function_id,
                "functionName": "surf043_graph_card_function",
                "agent": agent_id,
                "workflow": workflow_id,
                "workflowName": "surf043_graph_card_workflow",
                "graph": {"nodes": len(graph.get("nodes", [])), "edges": len(graph.get("edges", []))},
                "referencedBy": [
                    {"kind": edge.get("fromKind"), "id": edge.get("fromId"), "name": edge.get("fromName")}
                    for edge in referenced_by
                ],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf043: {exc}", file=sys.stderr)
        raise
