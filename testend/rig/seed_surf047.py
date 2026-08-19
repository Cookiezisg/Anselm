#!/usr/bin/env python3
"""Seed the public preview-family fixture used by SURF-047.

The files intentionally exercise each real SkillFilePreview branch through the public API:
markdown, code, image, SVG, CSV, font and the honest "other" information card.
"""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
SKILL_NAME = "surf047-preview-lab"


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
                "Content-Type": "application/octet-stream",
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
    return response.get("data") if isinstance(response, dict) and "data" in response else response


def find_skill(api: API) -> dict[str, Any] | None:
    rows = data(api.must("GET", "/api/v1/skills"))
    if isinstance(rows, dict) and isinstance(rows.get("items"), list):
        rows = rows["items"]
    if not isinstance(rows, list):
        raise RuntimeError(f"unexpected skills response: {rows!r}")
    return next((row for row in rows if row.get("name") == SKILL_NAME), None)


def repo_file(relative: str) -> bytes:
    path = REPO_ROOT / relative
    if not path.is_file():
        raise RuntimeError(f"fixture source file is missing: {path}")
    return path.read_bytes()


def main() -> None:
    args = parse_args()
    api = API(args.base, args.workspace)
    body = (
        "# SURF-047 Preview Lab\n\n"
        "This skill exists to make every bundled-file preview branch observable.\n\n"
        "## Reading the lab\n\n"
        "Open the files in the right island and verify that the center view always explains "
        "what it can show and how to leave it.\n"
    )
    description = "A real fixture for the complete bundled-file preview family."
    spec = {
        "name": SKILL_NAME,
        "description": description,
        "body": body,
        "allowedTools": ["Read"],
        "context": "inline",
        "agent": "",
        "arguments": [],
        "disableModelInvocation": False,
        "userInvocable": True,
    }
    existing = find_skill(api)
    if existing is None:
        action = "created"
        api.must("POST", "/api/v1/skills", spec)
    else:
        current = data(api.must("GET", f"/api/v1/skills/{SKILL_NAME}"))
        if not isinstance(current, dict):
            raise RuntimeError(f"unexpected skill response: {current!r}")
        action = "verified"
        if current.get("description") != description or current.get("body") != body:
            action = "updated"
            api.must("PUT", f"/api/v1/skills/{SKILL_NAME}", spec)

    files = {
        "references/guide.md": (
            "# Preview guide\n\n"
            "## Markdown\n\n"
            "This file should use the rich editor and feed the Outline.\n"
        ).encode(),
        "scripts/check.py": (
            "from pathlib import Path\n\n"
            "print(Path('references/guide.md').name)\n"
        ).encode(),
        "assets/mark.png": repo_file("frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"),
        "assets/mark.svg": (
            '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">'
            '<defs><linearGradient id="g" x1="0" x2="1"><stop stop-color="#17324d"/>'
            '<stop offset="1" stop-color="#d28b52"/></linearGradient></defs>'
            '<rect width="640" height="360" rx="28" fill="url(#g)"/>'
            '<circle cx="320" cy="145" r="74" fill="#f8f2e9" fill-opacity=".9"/>'
            '<path d="M280 145h80M320 105v80" stroke="#17324d" stroke-width="14" stroke-linecap="round"/>'
            '<text x="320" y="285" text-anchor="middle" font-family="sans-serif" font-size="30" fill="#f8f2e9">SURF-047</text>'
            "</svg>"
        ).encode(),
        "data/rows.csv": (
            "kind,owner,status\n"
            "markdown,library,ready\n"
            "image,library,ready\n"
            "system-escape,library,review\n"
        ).encode(),
        "fonts/newsreader.ttf": repo_file("frontend/assets/fonts/Newsreader.ttf"),
        "exports/receipt.pdf": b"%PDF-1.4\n% SURF-047 system-open escape\n",
    }
    for path, content in files.items():
        api.must_bytes("PUT", f"/api/v1/skills/{SKILL_NAME}/files/{path}", content)

    print(
        json.dumps(
            {
                "action": action,
                "workspace": args.workspace,
                "name": SKILL_NAME,
                "files": list(files),
                "bytes": {path: len(content) for path, content in files.items()},
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
