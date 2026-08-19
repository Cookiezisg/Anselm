#!/usr/bin/env python3
"""Seed the document-tree fixture used by SURF-048 through the public API only.

The shape deliberately contains empty and written pages, a nested branch, and several roots so the
real Library rail can exercise create-child, rename, duplicate, drag/reparent, and subtree delete.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any


ROOT_NAME = "SURF-048 Library Root"
WRITTEN_NAME = "SURF-048 Written Page"
REORDER_NAME = "SURF-048 Reorder Me"
CHILD_NAME = "SURF-048 Child Note"
LEAF_NAME = "SURF-048 Empty Leaf"
GRANDCHILD_NAME = "SURF-048 Grandchild"


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
    return response.get("data") if isinstance(response, dict) and "data" in response else response


def tree(api: API) -> list[dict[str, Any]]:
    rows = data(api.must("GET", "/api/v1/documents/tree"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected document tree response: {rows!r}")
    return rows


def ensure_document(
    api: API,
    rows: list[dict[str, Any]],
    *,
    name: str,
    parent_id: str | None,
    content: str,
    description: str,
    tags: list[str],
) -> tuple[dict[str, Any], str]:
    row = next((item for item in rows if item.get("name") == name), None)
    action = "verified"
    if row is None:
        row = data(
            api.must(
                "POST",
                "/api/v1/documents",
                {
                    "name": name,
                    "parentId": parent_id,
                    "content": content,
                    "description": description,
                    "tags": tags,
                },
            )
        )
        action = "created"
    else:
        detail = data(api.must("GET", f"/api/v1/documents/{row['id']}"))
        patch: dict[str, Any] = {}
        if detail.get("content") != content:
            patch["content"] = content
        if detail.get("description") != description:
            patch["description"] = description
        if detail.get("tags") != tags:
            patch["tags"] = tags
        if patch:
            row = data(api.must("PATCH", f"/api/v1/documents/{row['id']}", patch))
            action = "updated"
        if row.get("parentId") != parent_id:
            row = data(
                api.must(
                    "POST",
                    f"/api/v1/documents/{row['id']}:move",
                    {"parentId": parent_id},
                )
            )
            action = "reparented"
    if not isinstance(row, dict) or not isinstance(row.get("id"), str):
        raise RuntimeError(f"unexpected document response for {name}: {row!r}")
    return row, action


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9075")
    parser.add_argument("--workspace", required=True)
    args = parser.parse_args()
    api = API(args.base, args.workspace)

    specs = [
        (ROOT_NAME, None, "", "An empty root that owns a visible nested branch.", ["acceptance", "library"]),
        (
            WRITTEN_NAME,
            None,
            "# SURF-048 Written Page\n\nA written root page for the library rail acceptance pass.\n",
            "A written root page for CRUD and selection checks.",
            ["acceptance", "library", "written"],
        ),
        (REORDER_NAME, None, "", "A root page used as a drag target.", ["acceptance", "library", "reorder"]),
    ]
    rows = tree(api)
    actions: dict[str, str] = {}
    ids: dict[str, str] = {}
    for name, parent_id, content, description, tags in specs:
        row, action = ensure_document(
            api,
            rows,
            name=name,
            parent_id=parent_id,
            content=content,
            description=description,
            tags=tags,
        )
        ids[name] = row["id"]
        actions[name] = action
        rows = tree(api)

    child_specs = [
        (
            CHILD_NAME,
            ids[ROOT_NAME],
            "## Child note\n\nThis child proves that a page can also be a parent.\n",
            "A written child page.",
            ["acceptance", "library", "child"],
        ),
        (LEAF_NAME, ids[ROOT_NAME], "", "An empty leaf page.", ["acceptance", "library", "empty"]),
    ]
    for name, parent_id, content, description, tags in child_specs:
        row, action = ensure_document(
            api,
            rows,
            name=name,
            parent_id=parent_id,
            content=content,
            description=description,
            tags=tags,
        )
        ids[name] = row["id"]
        actions[name] = action
        rows = tree(api)

    row, action = ensure_document(
        api,
        rows,
        name=GRANDCHILD_NAME,
        parent_id=ids[CHILD_NAME],
        content="### Grandchild\n\nA second level keeps the delete operation observable as a subtree.\n",
        description="A nested grandchild page.",
        tags=["acceptance", "library", "grandchild"],
    )
    ids[GRANDCHILD_NAME] = row["id"]
    actions[GRANDCHILD_NAME] = action

    final_rows = tree(api)
    present = {item.get("name") for item in final_rows}
    expected = {ROOT_NAME, WRITTEN_NAME, REORDER_NAME, CHILD_NAME, LEAF_NAME, GRANDCHILD_NAME}
    missing = sorted(expected - present)
    if missing:
        raise RuntimeError(f"fixture did not round-trip; missing {missing!r}")
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "actions": actions,
                "documents": len(final_rows),
                "ids": ids,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf048: {exc}", file=sys.stderr)
        raise
