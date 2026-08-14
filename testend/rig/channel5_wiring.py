#!/usr/bin/env python3
"""Validate that persisted managed gateway keys cross this session's llmtap."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any


def expected_base_url(port: int | str) -> str:
    """Return the local gateway prefix that must own the managed traffic."""
    try:
        normalized = int(port)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"invalid llmtap port: {port!r}") from exc
    if not 1 <= normalized <= 65535:
        raise ValueError(f"invalid llmtap port: {port!r}")
    return f"http://127.0.0.1:{normalized}"


def evaluate(payload: Any, port: int | str) -> tuple[str, str]:
    """Classify an API-key response as pending, valid, bypassing, or invalid.

    A workspace without an anselm key is still in onboarding and is allowed. Once
    a managed key exists, every such row must point at this run's local tap. The
    caller must treat ``invalid`` and ``bypass`` as startup failures.
    """
    if not isinstance(payload, dict):
        return "invalid", "API response is not an object"
    rows = payload.get("data")
    if not isinstance(rows, list):
        return "invalid", "API response data is not a list"
    if any(not isinstance(row, dict) for row in rows):
        return "invalid", "API response contains a non-object key row"

    managed = [row for row in rows if row.get("provider") == "anselm"]
    if not managed:
        return "pending", "no managed key"

    expected = expected_base_url(port)
    bases: list[str] = []
    for row in managed:
        base = row.get("baseUrl")
        if not isinstance(base, str) or not base:
            return "invalid", "managed key has no non-empty baseUrl"
        bases.append(base)

    bypass = [base for base in bases if not (base == expected or base.startswith(expected + "/"))]
    if bypass:
        return "bypass", f"persisted baseUrl(s) {bypass!r}; expected prefix {expected!r}"
    return "ok", f"{len(bases)} managed key(s) point at {expected}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, type=int)
    args = parser.parse_args(argv)
    try:
        payload = json.load(sys.stdin)
        status, detail = evaluate(payload, args.port)
    except (json.JSONDecodeError, OSError, ValueError) as exc:
        print(f"invalid\t{exc}")
        return 2
    print(f"{status}\t{detail}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
