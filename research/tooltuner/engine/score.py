"""Aggregate traces + judge verdicts → per-tool per-axis scores (SPEC §3 score). Deterministic.

verdicts: [{id, <axis_key>: bool, ...}] from judge.workflow (one entry per scenario, a bool per axis).
"真执行 > 判官": if a trace has exec_result, it OVERRIDES the `usage` axis (clean run = correct), no judge.
"""
from __future__ import annotations

import math


def _ci(p: float, n: int) -> float:
    return round(1.96 * math.sqrt(p * (1 - p) / n), 3) if n else 0.0


def score(traces: list[dict], verdicts: list[dict], axes: list[str]) -> dict:
    """Return {rows:[{tool,axis,pct,n,ci}], weak:[(tool,axis,pct)], per:{tool:{axis:pct}}}."""
    tool_of = {t["id"]: t.get("expected_tool", "?") for t in traces}
    exec_of = {t["id"]: t.get("exec_result", {}).get("exec") for t in traces if t.get("exec_result")}
    v_of = {v["id"]: v for v in verdicts}

    # collect bools per (tool, axis)
    bucket: dict = {}
    for sid, tool in tool_of.items():
        v = v_of.get(sid, {})
        for axis in axes:
            val = v.get(axis)
            if axis == "usage" and sid in exec_of:        # hard ground truth overrides judge
                val = (exec_of[sid] == "clean")
            if val is None:
                continue
            bucket.setdefault((tool, axis), []).append(bool(val))

    rows, weak, per = [], [], {}
    for (tool, axis), vals in sorted(bucket.items()):
        n = len(vals)
        pct = round(100 * sum(vals) / n) if n else 0
        rows.append({"tool": tool, "axis": axis, "pct": pct, "n": n, "ci": int(_ci(pct / 100, n) * 100)})
        per.setdefault(tool, {})[axis] = pct
        if pct < 80:
            weak.append((tool, axis, pct))
    weak.sort(key=lambda x: x[2])
    return {"rows": rows, "weak": weak, "per": per}
