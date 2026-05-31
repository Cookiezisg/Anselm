"""Paired-lift A/B (SPEC §3 ab). The honesty gate: same scenarios under base vs variant surfaces.

Per (tool, axis): base% / variant% / lift + PAIRED significance (McNemar normal approx, deterministic —
no RNG) + cross-tool regression flags (a global-surface change can help A and hurt B). Only `wins`
(lift>0 AND significant) should be written back; `regressions` block a change.

Absolute %s are Claude's aesthetic, not production truth — trust the paired lift, not the level.
"""
from __future__ import annotations

import math


def _override(val, sid, axis, exec_of):
    if axis == "usage" and sid in exec_of:        # real execution > judge
        return exec_of[sid] == "clean"
    return val


def ab(base_verdicts: list[dict], variant_verdicts: list[dict], traces: list[dict],
       axes: list[str], *, regression_pt: int = 5) -> dict:
    tool_of = {t["id"]: t.get("expected_tool", "?") for t in traces}
    exec_of = {t["id"]: t["exec_result"]["exec"] for t in traces if t.get("exec_result")}
    b_of = {v["id"]: v for v in base_verdicts}
    v_of = {v["id"]: v for v in variant_verdicts}
    shared = [s for s in tool_of if s in b_of and s in v_of]

    pair: dict = {}
    for sid in shared:
        for axis in axes:
            bv = _override(b_of[sid].get(axis), sid, axis, exec_of)
            vv = _override(v_of[sid].get(axis), sid, axis, exec_of)
            if bv is None or vv is None:
                continue
            pair.setdefault((tool_of[sid], axis), []).append((bool(bv), bool(vv)))

    out = []
    for (tool, axis), ps in sorted(pair.items()):
        n = len(ps)
        bpass = sum(b for b, _v in ps)
        vpass = sum(v for _b, v in ps)
        b01 = sum(1 for b, v in ps if b and not v)   # base✓ variant✗
        c01 = sum(1 for b, v in ps if not b and v)   # base✗ variant✓
        disc = b01 + c01
        lift = round(100 * (vpass - bpass) / n) if n else 0
        se = math.sqrt(disc - (c01 - b01) ** 2 / n) / n if (n and disc) else 0.0
        sig = (abs((c01 - b01) / n) > 1.96 * se) if se > 0 else (disc >= 5 and (b01 == 0 or c01 == 0))
        out.append({"tool": tool, "axis": axis, "base": round(100 * bpass / n), "variant": round(100 * vpass / n),
                    "lift": lift, "n": n, "significant": bool(sig)})

    return {"per": out,
            "wins": [r for r in out if r["lift"] > 0 and r["significant"]],
            "regressions": [r for r in out if r["lift"] <= -regression_pt]}


if __name__ == "__main__":  # self-check (no token)
    traces = [{"id": f"t{i}", "expected_tool": "create_workflow"} for i in range(20)]
    # base: 10/20 usage pass; variant: same 10 + 6 more flip to pass, 0 regress → clear win
    base = [{"id": f"t{i}", "usage": i < 10} for i in range(20)]
    var = [{"id": f"t{i}", "usage": i < 16} for i in range(20)]
    r = ab(base, var, traces, ["usage"])
    row = r["per"][0]
    assert row["base"] == 50 and row["variant"] == 80 and row["lift"] == 30 and row["significant"], row
    assert r["wins"] and not r["regressions"]
    print(f"AB OK — base {row['base']}% → variant {row['variant']}% (+{row['lift']}, sig={row['significant']}); paired McNemar wired.")
