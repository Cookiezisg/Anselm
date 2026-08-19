#!/usr/bin/env python3
"""Seed the same-label document/skill fixture used by SURF-049.

The duplicate label is intentional: the rail must keep the document row and the flat skill row
addressable through different row ids (`doc_*` versus `skill:<slug>`), routes, and detail providers.
"""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
from typing import Any


SLUG = "surf049-alpha"
SECOND_SLUG = "surf049-beta"
DOC_NAME = SLUG


class API:
    def __init__(self, base: str, workspace: str) -> None:
        self.base = base.rstrip("/")
        self.workspace = workspace

    def request(self, method: str, path: str, body: Any = None) -> tuple[int, Any]:
        payload = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(
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
            with urllib.request.urlopen(req, timeout=60) as response:
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9078")
    parser.add_argument("--workspace", required=True)
    args = parser.parse_args()
    api = API(args.base, args.workspace)

    docs = api.must("GET", "/api/v1/documents/tree")
    if not any(row.get("name") == DOC_NAME for row in docs):
        api.must(
            "POST",
            "/api/v1/documents",
            {
                "name": DOC_NAME,
                "content": "# SURF-049 document\n\nThis is the document with the same visible label.\n",
                "description": "The document twin for the skill row identity check.",
                "tags": ["acceptance", "surf049", "document"],
            },
        )

    specs = [
        (
            SLUG,
            "The skill twin for the same-label rail identity check.",
            "# SURF-049 skill alpha\n\nThis body proves the skill route, not the document route.\n",
        ),
        (
            SECOND_SLUG,
            "A second flat skill for ordering and filter checks.",
            "# SURF-049 skill beta\n\nThis second row must stay flat beside alpha.\n",
        ),
    ]
    actions: dict[str, str] = {}
    rows = api.must("GET", "/api/v1/skills")
    for name, description, body in specs:
        existing = next((row for row in rows if row.get("name") == name), None)
        payload = {
            "description": description,
            "body": body,
            "allowedTools": ["Read"],
            "context": "inline",
            "agent": "",
            "arguments": [],
            "disableModelInvocation": False,
            "userInvocable": True,
        }
        if existing is None:
            api.must(
                "POST",
                "/api/v1/skills",
                {"name": name, **payload},
            )
            actions[name] = "created"
        else:
            current = api.must("GET", f"/api/v1/skills/{name}")
            if current.get("description") != description or current.get("body") != body:
                api.must("PUT", f"/api/v1/skills/{name}", payload)
                actions[name] = "updated"
            else:
                actions[name] = "verified"
        rows = api.must("GET", "/api/v1/skills")

    names = {row.get("name") for row in rows}
    expected = {SLUG, SECOND_SLUG}
    missing = sorted(expected - names)
    if missing:
        raise RuntimeError(f"fixture did not round-trip; missing skills {missing!r}")
    docs = api.must("GET", "/api/v1/documents/tree")
    if not any(row.get("name") == DOC_NAME for row in docs):
        raise RuntimeError("fixture did not round-trip; same-label document is missing")
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "actions": actions,
                "sameLabel": DOC_NAME,
                "skills": sorted(expected),
                "documents": len(docs),
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
