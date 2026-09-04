#!/usr/bin/env python3
"""Deterministic test operator for confirmation-only interaction decisions.

The operator is deliberately narrower than the product's human-loop broker: callers must name
the exact tool(s) they are authorizing, provide a reason, and write an audit record. It is useful
for unattended black-box runs, but it never counts as evidence that the confirmation surface was
visually accepted.
"""

import argparse
import datetime as dt
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


class OperatorError(RuntimeError):
    pass


def _url(base_url: str, path: str) -> str:
    return base_url.rstrip("/") + "/" + path.lstrip("/")


def _request(base_url: str, path: str, workspace: str, token: str, method: str, body=None):
    headers = {"X-Anselm-Workspace-ID": workspace, "Accept": "application/json"}
    payload = None
    if body is not None:
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(_url(base_url, path), data=payload, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            details = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            details = raw.decode("utf-8", errors="replace")
        raise OperatorError(f"HTTP {exc.code}: {details}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise OperatorError(f"request failed: {exc}") from exc


def pending_interactions(base_url: str, workspace: str, token: str, conversation: str):
    status, payload = _request(
        base_url,
        f"/api/v1/conversations/{conversation}/interactions",
        workspace,
        token,
        "GET",
    )
    if status != 200 or not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
        raise OperatorError(f"unexpected interactions response: HTTP {status}: {payload}")
    return payload["data"]


def _tool_name(row):
    return row.get("tool") or row.get("attrs", {}).get("tool") or ""


def resolve_interaction(base_url: str, workspace: str, token: str, conversation: str, row, action: str):
    tool_call_id = row.get("toolCallId")
    if not isinstance(tool_call_id, str) or not tool_call_id:
        raise OperatorError(f"interaction has no toolCallId: {row}")
    status, payload = _request(
        base_url,
        f"/api/v1/conversations/{conversation}/interactions/{tool_call_id}",
        workspace,
        token,
        "POST",
        {"action": action},
    )
    if status != 204:
        raise OperatorError(f"unexpected resolve response: HTTP {status}: {payload}")
    return tool_call_id


def append_decision(journal: Path, *, conversation: str, row, action: str, reason: str):
    journal.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "event": "interaction_resolved",
        "ts": dt.datetime.now(dt.timezone.utc).isoformat(),
        "actor": "test-operator",
        "conversationId": conversation,
        "toolCallId": row.get("toolCallId"),
        "tool": _tool_name(row),
        "kind": row.get("kind", ""),
        "action": action,
        "reason": reason,
    }
    with journal.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")


def run(args):
    deadline = time.monotonic() + args.timeout
    resolved = 0
    seen = set()
    while True:
        rows = pending_interactions(args.base_url, args.workspace, args.token, args.conversation)
        for row in rows:
            tool = _tool_name(row)
            call_id = row.get("toolCallId")
            if tool not in args.tool or call_id in seen:
                continue
            seen.add(call_id)
            try:
                resolve_interaction(
                    args.base_url,
                    args.workspace,
                    args.token,
                    args.conversation,
                    row,
                    args.action,
                )
            except OperatorError as exc:
                # A concurrent resolver may win the race. Do not turn that into a false pass.
                print(f"operator: resolve failed for {call_id}: {exc}", file=sys.stderr)
                raise
            append_decision(
                args.journal,
                conversation=args.conversation,
                row=row,
                action=args.action,
                reason=args.reason,
            )
            resolved += 1
            print(f"operator: resolved {tool}/{call_id} with {args.action}")
        if resolved:
            return resolved
        if time.monotonic() >= deadline:
            raise OperatorError(
                "timed out waiting for an interaction matching the explicit tool allowlist"
            )
        time.sleep(args.poll_interval)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Resolve explicitly allowlisted test interactions")
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--conversation", required=True)
    parser.add_argument("--tool", action="append", required=True, help="exact tool name; repeatable")
    parser.add_argument(
        "--action",
        required=True,
        choices=("approve", "approve_always", "deny", "accept", "decline"),
    )
    parser.add_argument("--reason", required=True, help="human-readable test authorization reason")
    parser.add_argument("--journal", required=True, type=Path)
    parser.add_argument("--token", default="")
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--poll-interval", type=float, default=0.25)
    args = parser.parse_args(argv)
    if args.timeout <= 0 or args.poll_interval <= 0:
        parser.error("--timeout and --poll-interval must be positive")
    try:
        run(args)
    except OperatorError as exc:
        parser.exit(1, f"operator: {exc}\n")


if __name__ == "__main__":
    main()
