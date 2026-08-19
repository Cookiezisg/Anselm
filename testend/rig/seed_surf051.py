#!/usr/bin/env python3
"""Seed the installed Skill inspector fixture for SURF-051.

The fixture deliberately uses the real inspect-source/install path instead of POST /skills:
the installed skill must carry provenance, equip edges, nested files, and a trustworthy
allowed-tools request. The tarball is served by a short-lived local HTTP server so the
backend's production fetcher is exercised without an external dependency.
"""

from __future__ import annotations

import argparse
import io
import json
import tarfile
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


SKILL_NAME = "surf051-inspector"
FUNCTION_NAME = "surf051_inspector_function"
HANDLER_NAME = "surf051_inspector_handler"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9080")
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


def rows(response: Any, *, key: str | None = None) -> list[dict[str, Any]]:
    value = data(response)
    if key is not None and isinstance(value, dict):
        value = value.get(key)
    if not isinstance(value, list):
        raise RuntimeError(f"expected a row list, got {value!r}")
    return value


def find_named(api: API, collection: str, name: str) -> dict[str, Any] | None:
    return next(
        (row for row in rows(api.must("GET", f"/api/v1/{collection}?limit=200")) if row.get("name") == name),
        None,
    )


def create_named(api: API, collection: str, spec: dict[str, Any]) -> str:
    existing = find_named(api, collection, str(spec["name"]))
    if existing is not None:
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
            "name": FUNCTION_NAME,
            "description": "A real function bound to the SURF-051 Skill inspector.",
            "code": "def inspect(label):\n    return {'label': label, 'ok': True}\n",
            "inputs": [{"name": "label", "type": "string", "description": "inspection label"}],
            "outputs": [{"name": "ok", "type": "boolean"}],
            "changeReason": "SURF-051 installed Skill inspector fixture",
        },
    )


def ensure_handler(api: API) -> str:
    return create_named(
        api,
        "handlers",
        {
            "name": HANDLER_NAME,
            "description": "A real handler bound to the SURF-051 Skill inspector.",
            "initBody": "self.calls = 0",
            "methods": [
                {
                    "name": "inspect",
                    "description": "Return one inspection result.",
                    "inputs": [{"name": "label", "type": "string"}],
                    "outputs": [{"name": "ok", "type": "boolean"}],
                    "body": "self.calls += 1\nreturn {'label': label, 'calls': self.calls, 'ok': True}\n",
                }
            ],
            "changeReason": "SURF-051 installed Skill inspector fixture",
        },
    )


def build_archive(function_id: str, handler_id: str) -> bytes:
    manifest = f"""---
name: {SKILL_NAME}
description: Inspect a result and produce a grounded next action.
license: MIT
compatibility: Python 3.12
metadata:
  surface: library-inspector
  campaign: SURF-051
allowed-tools:
  - {function_id}
  - {handler_id}
  - Read
context: inline
arguments:
  - focus
disable-model-invocation: false
user-invocable: true
---
# SURF-051 Skill Inspector

Use the bound capabilities to inspect one result and explain the next action.

## Purpose

Prefer durable evidence over assumptions.

### Inputs

Read the requested focus before making a recommendation.

## Output contract

Return one concise action and one caveat.
""".encode()
    files = {
        "SKILL.md": manifest,
        "references/inspection-guide.md": b"# Inspection guide\n\nRecord the evidence before the recommendation.\n",
        "scripts/inspect.py": b"print('SURF-051 inspection')\n",
        "templates/report.md": b"# Report\n\n- Evidence:\n- Next action:\n",
    }
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as archive:
        for relative, content in files.items():
            info = tarfile.TarInfo(f"bundle/{SKILL_NAME}/{relative}")
            info.size = len(content)
            archive.addfile(info, io.BytesIO(content))
    return buf.getvalue()


class _ArchiveHandler(BaseHTTPRequestHandler):
    archive: bytes = b""

    def do_GET(self) -> None:  # noqa: N802 - stdlib handler hook
        if self.path != "/surf051.tgz":
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/gzip")
        self.send_header("Content-Length", str(len(self.archive)))
        self.end_headers()
        self.wfile.write(self.archive)

    def log_message(self, _format: str, *_args: Any) -> None:
        return


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    function_id = ensure_function(api)
    handler_id = ensure_handler(api)
    _ArchiveHandler.archive = build_archive(function_id, handler_id)
    server = ThreadingHTTPServer(("127.0.0.1", 0), _ArchiveHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    source = f"http://127.0.0.1:{server.server_port}/surf051.tgz"
    try:
        preview = rows(api.must("POST", "/api/v1/skills:inspect-source", {"source": source}))
        candidate = next((row for row in preview if row.get("name") == SKILL_NAME), None)
        if candidate is None or not candidate.get("installable"):
            raise RuntimeError(f"unexpected install preview: {preview!r}")
        result = data(
            api.must(
                "POST",
                "/api/v1/skills:install",
                {"source": source, "names": [SKILL_NAME], "force": True},
            )
        )
        if not isinstance(result, dict) or SKILL_NAME not in result.get("installed", []):
            raise RuntimeError(f"install did not land the fixture: {result!r}")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)

    skill = data(api.must("GET", f"/api/v1/skills/{SKILL_NAME}"))
    if not isinstance(skill, dict) or skill.get("source") != "installed":
        raise RuntimeError(f"installed source did not round-trip: {skill!r}")
    allowed = skill.get("frontmatter", {}).get("allowedTools", [])
    if function_id not in allowed or handler_id not in allowed:
        raise RuntimeError(f"allowed-tools lost entity refs: {allowed!r}")
    files = rows(api.must("GET", f"/api/v1/skills/{SKILL_NAME}/files"))
    if {row.get("path") for row in files} != {
        "SKILL.md",
        "references/inspection-guide.md",
        "scripts/inspect.py",
        "templates/report.md",
    }:
        raise RuntimeError(f"unexpected skill files: {files!r}")
    relations = rows(
        api.must(
            "GET",
            f"/api/v1/relations?fromKind=skill&fromId={SKILL_NAME}&kind=equip&limit=100",
        ),
        key="items",
    )
    bound_ids = {row.get("toId") for row in relations}
    if bound_ids != {function_id, handler_id}:
        raise RuntimeError(f"unexpected skill equip edges: {relations!r}")
    print(
        json.dumps(
            {
                "workspace": args.workspace,
                "skill": SKILL_NAME,
                "source": skill.get("source"),
                "function": function_id,
                "handler": handler_id,
                "files": [row.get("path") for row in files],
                "bindings": [
                    {"kind": row.get("toKind"), "id": row.get("toId"), "name": row.get("toName")}
                    for row in relations
                ],
                "preview": {
                    "installable": candidate.get("installable"),
                    "fileCount": candidate.get("fileCount"),
                    "allowedTools": candidate.get("allowedTools"),
                },
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
