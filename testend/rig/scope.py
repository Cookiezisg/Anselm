#!/usr/bin/env python3
"""Shared scope guard for scripts that write acceptance authority."""

import os
from pathlib import Path


def explicit_rig_home(tool: str) -> Path:
    """Return an explicitly selected absolute rig home, or fail closed."""
    raw = os.environ.get("RIG_HOME", "").strip()
    if not raw:
        raise SystemExit(
            f"{tool}: REFUSED — RIG_HOME must be explicitly exported; "
            "refusing the personal default ledger"
        )
    path = Path(raw)
    if not path.is_absolute():
        raise SystemExit(
            f"{tool}: REFUSED — RIG_HOME must be an absolute path, got {raw!r}"
        )
    return path
