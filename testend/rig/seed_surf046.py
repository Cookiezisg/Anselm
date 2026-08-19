#!/usr/bin/env python3
"""Seed the public Skill manifest fixture used by SURF-046.

The fixture intentionally goes through the HTTP API only: the manifest is created by POST and
bundled files are added with the guarded file PUT. Re-running it verifies the existing content.
"""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9074")
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

    def bytes_request(self, method: str, path: str, content: bytes) -> int:
        request = urllib.request.Request(
            self.base + path,
            data=content,
            method=method,
            headers={
                "Content-Type": "text/plain; charset=utf-8",
                "X-Anselm-Workspace-ID": self.workspace,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                response.read()
                return response.status
        except urllib.error.HTTPError as error:
            error.read()
            return error.code

    def must(self, method: str, path: str, body: Any = None) -> Any:
        status, response = self.request(method, path, body)
        if status >= 400:
            raise RuntimeError(f"{method} {path} -> HTTP {status}: {response}")
        return response

    def must_bytes(self, method: str, path: str, content: bytes) -> None:
        status = self.bytes_request(method, path, content)
        if status >= 400:
            raise RuntimeError(f"{method} {path} -> HTTP {status}")


def data(response: Any) -> Any:
    if isinstance(response, dict) and "data" in response:
        return response["data"]
    return response


def find_skill(api: API, name: str) -> dict[str, Any] | None:
    rows = data(api.must("GET", "/api/v1/skills"))
    if isinstance(rows, dict) and isinstance(rows.get("items"), list):
        rows = rows["items"]
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected skills response: {rows!r}")
    return next((row for row in rows if row.get("name") == name), None)


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    name = "surf046-manifest"
    description = "A real manifest used to inspect Skill editing and source mode."
    body = (
        "# SURF-046 Manifest\n\n"
        "Use this skill to review a document carefully and report the useful next action.\n\n"
        "## Purpose\n\n"
        "The output must be concise, grounded, and actionable.\n\n"
        "## Review steps\n\n"
        "1. Read the request.\n"
        "2. Check the relevant evidence.\n"
        "3. Return the next action and one caveat.\n\n"
        "## Output\n\n"
        "Use a short heading followed by two bullets.\n"
    )
    spec = {
        "name": name,
        "description": description,
        "body": body,
        "allowedTools": ["Read"],
        "context": "inline",
        "agent": "",
        "arguments": ["focus"],
        "disableModelInvocation": False,
        "userInvocable": True,
    }
    existing = find_skill(api, name)
    if existing is None:
        api.must("POST", "/api/v1/skills", spec)
        action = "created"
    else:
        current = data(api.must("GET", f"/api/v1/skills/{name}"))
        if not isinstance(current, dict):
            raise RuntimeError(f"unexpected skill response: {current!r}")
        if current.get("description") != description or current.get("body") != body:
            api.must("PUT", f"/api/v1/skills/{name}", spec)
            action = "updated"
        else:
            action = "verified"

    files = {
        "references/review-guide.md": (
            "# Review guide\n\n"
            "Prefer observable evidence over assumptions.\n"
        ).encode(),
        "scripts/check.py": b"print('SURF-046 fixture')\n",
    }
    for path, content in files.items():
        api.must_bytes("PUT", f"/api/v1/skills/{name}/files/{path}", content)
    print(
        json.dumps(
            {
                "action": action,
                "workspace": args.workspace,
                "name": name,
                "headings": 4,
                "files": list(files),
                "bodyChars": len(body),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
