#!/usr/bin/env python3
"""Seed the document inspector fixture used by SURF-050.

The target has real headings, metadata, and two incoming document wikilinks so the inspector's
identity head, glance strip, Outline, Properties, and Backlinks groups all carry signal.
"""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
from typing import Any


TARGET_NAME = "SURF-050 Inspector Target"
LINKER_NAMES = ("SURF-050 Playbook", "SURF-050 Runbook")


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
        return response.get("data") if isinstance(response, dict) and "data" in response else response


def upsert_document(api: API, rows: list[dict[str, Any]], name: str, content: str) -> dict[str, Any]:
    existing = next((row for row in rows if row.get("name") == name), None)
    payload = {
        "name": name,
        "content": content,
        "description": f"{name} acceptance fixture.",
        "tags": ["acceptance", "surf050", "library"],
    }
    if existing is None:
        return api.must("POST", "/api/v1/documents", payload)
    current = api.must("GET", f"/api/v1/documents/{existing['id']}")
    if (
        current.get("content") != content
        or current.get("description") != payload["description"]
        or current.get("tags") != payload["tags"]
    ):
        return api.must("PATCH", f"/api/v1/documents/{existing['id']}", payload)
    return current


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9079")
    parser.add_argument("--workspace", required=True)
    args = parser.parse_args()
    api = API(args.base, args.workspace)

    rows = api.must("GET", "/api/v1/documents/tree")
    target = upsert_document(
        api,
        rows,
        TARGET_NAME,
        "# SURF-050 Inspector Target\n\n"
        "This page exists to exercise the document inspector end to end.\n\n"
        "## Purpose\n\n"
        "The identity, glance, outline, properties, and backlinks must all stay truthful.\n\n"
        "### Details\n\n"
        "A third-level heading keeps the outline visibly hierarchical.\n",
    )
    target_id = target["id"]

    rows = api.must("GET", "/api/v1/documents/tree")
    linkers = []
    for name, section in zip(LINKER_NAMES, ("playbook", "runbook")):
        linkers.append(
            upsert_document(
                api,
                rows,
                name,
                f"# {name}\n\nThis {section} links to [[{target_id}]] so the target shows an incoming backlink.\n",
            )
        )
        rows = api.must("GET", "/api/v1/documents/tree")

    final_rows = api.must("GET", "/api/v1/documents/tree")
    final_target = api.must("GET", f"/api/v1/documents/{target_id}")
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "target": {"id": target_id, "name": final_target.get("name")},
                "linkers": [{"id": row.get("id"), "name": row.get("name")} for row in linkers],
                "documents": len(final_rows),
                "backlinkToken": f"[[{target_id}]]",
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
