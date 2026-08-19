#!/usr/bin/env python3
"""Seed a long document for SURF-045's single-scroll reading page.

The fixture is intentionally created through the public document API. Its repeated headings make
the header-to-editor transition, active outline state, and continuous scroll observable in the real
App without relying on SQLite internals.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any


NAME = "SURF-045 Reading Page"


def content() -> str:
    sections = [
        ("Orientation", "The reading page keeps the page header and the editable body in one scroll surface."),
        ("First Principles", "A reader should be able to move from title to prose without discovering a second scrollbar."),
        ("Navigation", "The breadcrumb identifies the parent path while the outline follows the headings in this page."),
        ("Working Notes", "Metadata remains above the body and should leave the viewport with the same measured motion."),
        ("Review", "The active heading should change as the reading band crosses each section, without a visible jump."),
        ("Long Form", "This section exists to make the real page long enough for several deliberate scroll observations."),
        ("Continuity", "The editor body is still editable after the header has moved out of view."),
        ("Evidence", "The acceptance witness compares the frame, REST response, SSE notification, and frontend console."),
        ("Finishing", "The final heading confirms that the scroll extent ends cleanly and does not expose a blank seam."),
    ]
    blocks = ["# SURF-045 Reading Page", "", "A long-form document used to inspect the co-scrolling reading surface."]
    for index, (heading, sentence) in enumerate(sections, start=1):
        blocks.extend(["", f"## {index}. {heading}", "", sentence, "", f"Paragraph {index}: " + sentence])
        blocks.extend(["", f"### {heading} detail", "", "The detail line gives the editor enough vertical rhythm for a stable active-heading band."])
    return "\n".join(blocks) + "\n"


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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9072")
    parser.add_argument("--workspace", required=True)
    args = parser.parse_args()

    api = API(args.base, args.workspace)
    expected = content()
    rows = data(api.must("GET", "/api/v1/documents?limit=200"))
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected document list response: {rows!r}")
    row = next((item for item in rows if item.get("name") == NAME), None)
    action = "existing"
    if row is None:
        row = data(
            api.must(
                "POST",
                "/api/v1/documents",
                {
                    "name": NAME,
                    "parentId": None,
                    "description": "A long page for the SURF-045 co-scroll acceptance pass.",
                    "content": expected,
                    "tags": ["acceptance", "library", "scroll"],
                },
            )
        )
        action = "created"
    else:
        detail = data(api.must("GET", f"/api/v1/documents/{row['id']}"))
        if detail.get("content") != expected:
            row = data(api.must("PATCH", f"/api/v1/documents/{row['id']}", {"content": expected}))
            action = "updated"
    if not isinstance(row, dict) or not isinstance(row.get("id"), str):
        raise RuntimeError(f"unexpected document response: {row!r}")
    detail = data(api.must("GET", f"/api/v1/documents/{row['id']}"))
    if detail.get("content") != expected:
        raise RuntimeError("SURF-045 fixture content did not round-trip exactly")
    print(
        json.dumps(
            {
                "action": action,
                "workspace": args.workspace,
                "id": row["id"],
                "name": NAME,
                "headings": expected.count("\n## ") + expected.count("\n### "),
                "chars": len(expected),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - command-line fixture failure path
        print(f"seed_surf045: {exc}", file=sys.stderr)
        raise
