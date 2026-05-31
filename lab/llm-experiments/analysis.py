"""Analysis: winner selection + per-priority synthesis.

Produces:
- per-priority winner table (which variant wins on each scenario)
- overall winner per priority (with confidence note)
- Pass 2 recommendations (which cells to deep-dive)

Usage:
    python3 analysis.py
"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

from aggregator import aggregate_cell, load_results

SCRIPT_DIR = Path(__file__).parent
REPORTS_DIR = SCRIPT_DIR / "reports"
REPORTS_DIR.mkdir(exist_ok=True)


def scenario_priority(scenario_id: str) -> str:
    """Map scenario id prefix → priority name."""
    if scenario_id.startswith("lazy"):
        return "lazy"
    if scenario_id.startswith("tooldesc"):
        return "tool_desc"
    if scenario_id.startswith("schema"):
        return "schema"
    if scenario_id.startswith("chain"):
        return "chain"
    return "unknown"


def metric_for_priority(priority: str) -> str:
    """Which metric matters most per priority."""
    if priority == "lazy":
        return "activated_correct_rate"
    return "first_tool_correct_rate"


def synthesize() -> dict[str, dict[str, Any]]:
    """Return {priority: {scenarios: {scen_id: {variant: rate}}, totals: {variant: rate}}}."""
    by_cell = load_results()
    by_priority: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "scenarios": defaultdict(dict),
            "variants_seen": set(),
            "totals_first": defaultdict(list),  # variant → [rates per scenario]
            "totals_acti": defaultdict(list),
            "totals_args": defaultdict(list),
            "totals_cost": defaultdict(list),
        }
    )
    for (scen, var), recs in by_cell.items():
        pri = scenario_priority(scen)
        agg = aggregate_cell(recs)
        by_priority[pri]["scenarios"][scen][var] = agg
        by_priority[pri]["variants_seen"].add(var)
        if agg.get("first_tool_correct_rate") is not None:
            by_priority[pri]["totals_first"][var].append(agg["first_tool_correct_rate"])
            by_priority[pri]["totals_acti"][var].append(agg.get("activated_correct_rate") or 0)
            by_priority[pri]["totals_args"][var].append(agg.get("args_match_rate") or 0)
            by_priority[pri]["totals_cost"][var].append(agg.get("avg_cost_rmb") or 0)
    return by_priority


def render_priority(priority: str, data: dict[str, Any]) -> str:
    """Markdown synth for one priority."""
    variants = sorted(data["variants_seen"])
    scenarios = sorted(data["scenarios"].keys())
    metric = metric_for_priority(priority)
    metric_label = {
        "first_tool_correct_rate": "First tool correct",
        "activated_correct_rate": "Activated correct",
    }.get(metric, metric)

    lines = [f"## Priority: {priority}", ""]
    lines.append("### Per-scenario win rate (key metric: " + metric_label + ")")
    lines.append("")
    header = "| Scenario | " + " | ".join(variants) + " | Winner |"
    sep = "|---|" + "|".join(["---"] * (len(variants) + 1)) + "|"
    lines.append(header)
    lines.append(sep)

    for scen in scenarios:
        cells = data["scenarios"][scen]
        rates: list[tuple[str, float | None]] = []
        for v in variants:
            agg = cells.get(v)
            rate = agg.get(metric) if agg else None
            rates.append((v, rate))
        # Winner = highest rate (ignore Nones)
        valid = [(v, r) for v, r in rates if r is not None]
        if valid:
            winner = max(valid, key=lambda x: x[1])[0]
            top_rate = max(r for _, r in valid)
            # If multiple variants tie at top
            tied = [v for v, r in valid if r == top_rate]
            winner_str = winner if len(tied) == 1 else f"tie:{','.join(tied)}"
        else:
            winner_str = "—"
        row = [scen]
        for v, r in rates:
            row.append(f"{r*100:.0f}%" if r is not None else "—")
        row.append(winner_str)
        lines.append("| " + " | ".join(row) + " |")

    # Overall summary
    lines.append("")
    lines.append("### Overall (averaged across scenarios)")
    lines.append("")
    lines.append("| Variant | Avg first-tool % | Avg activated % | Avg args-match % | Avg cost ¥ |")
    lines.append("|---|---|---|---|---|")
    avg_table = []
    for v in variants:
        f = data["totals_first"][v]
        a = data["totals_acti"][v]
        m = data["totals_args"][v]
        c = data["totals_cost"][v]
        if not f:
            continue
        avg_first = sum(f) / len(f)
        avg_acti = sum(a) / len(a)
        avg_args = sum(m) / len(m)
        avg_cost = sum(c) / len(c)
        avg_table.append((v, avg_first, avg_acti, avg_args, avg_cost))
        lines.append(
            f"| {v} | {avg_first*100:.1f}% | {avg_acti*100:.1f}% | {avg_args*100:.1f}% | {avg_cost:.5f} |"
        )

    # Winner pick
    if avg_table:
        # Prefer activated_correct_rate for lazy, first_tool_correct_rate elsewhere
        if priority == "lazy":
            best = max(avg_table, key=lambda x: x[2])
            winner = best[0]
            score = best[2]
            criterion = "activated_correct_rate"
        else:
            best = max(avg_table, key=lambda x: x[3] if priority in ("tool_desc", "schema") else x[1])
            winner = best[0]
            score = best[3] if priority in ("tool_desc", "schema") else best[1]
            criterion = "args_match_rate" if priority in ("tool_desc", "schema") else "first_tool_correct_rate"
        lines.append("")
        lines.append(f"**Pass 1 winner**: `{winner}` ({score*100:.1f}% on {criterion})")

    return "\n".join(lines)


def render_pass2_plan(by_priority: dict[str, dict[str, Any]]) -> str:
    """Recommend cells for Pass 2 deep dive."""
    lines = ["# Pass 2 Recommendations", ""]
    for pri, data in by_priority.items():
        lines.append(f"## {pri}")
        scenarios = sorted(data["scenarios"].keys())
        variants = sorted(data["variants_seen"])
        for scen in scenarios:
            cells = data["scenarios"][scen]
            # Find top + second variant
            metric = metric_for_priority(pri)
            valid = [(v, cells[v].get(metric) or 0) for v in variants if v in cells]
            valid.sort(key=lambda x: -x[1])
            if len(valid) < 2:
                continue
            top, second = valid[0], valid[1]
            gap = top[1] - second[1]
            if gap < 0.05:
                lines.append(f"- **{scen}**: {top[0]} ({top[1]*100:.0f}%) vs {second[0]} ({second[1]*100:.0f}%) — too close, deep-dive both with N=30")
            elif gap > 0.20:
                lines.append(f"- {scen}: {top[0]} clear winner ({top[1]*100:.0f}% vs {second[1]*100:.0f}%) — confirm with N=30")
            else:
                lines.append(f"- {scen}: {top[0]} leads ({top[1]*100:.0f}% vs {second[1]*100:.0f}%) — N=30 to confirm gap")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    by_priority = synthesize()
    full = ["# Pass 1 Analysis", ""]
    for pri in ["lazy", "tool_desc", "schema", "chain"]:
        if pri in by_priority:
            full.append(render_priority(pri, by_priority[pri]))
            full.append("")
    full.append("---")
    full.append("")
    full.append(render_pass2_plan(by_priority))

    out = "\n".join(full)
    (REPORTS_DIR / "pass1_analysis.md").write_text(out)
    print(out)
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
