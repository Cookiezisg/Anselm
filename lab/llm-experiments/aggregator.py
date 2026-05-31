"""Aggregate results/*.jsonl into summary tables (CSV + Markdown).

Usage:
    python3 aggregator.py --priority lazy_grouping
    python3 aggregator.py --all
    python3 aggregator.py --report  # write markdown report
"""

from __future__ import annotations

import argparse
import json
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).parent
RESULTS_DIR = SCRIPT_DIR / "results"
REPORTS_DIR = SCRIPT_DIR / "reports"
REPORTS_DIR.mkdir(exist_ok=True)


def load_results(pattern: str = "*.jsonl") -> dict[tuple[str, str], list[dict[str, Any]]]:
    """Return {(scenario_id, variant_id): [records]}."""
    out: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for f in RESULTS_DIR.glob(pattern):
        try:
            for line in f.read_text().strip().split("\n"):
                if not line.strip():
                    continue
                rec = json.loads(line)
                key = (rec.get("scenario_id", "?"), rec.get("variant_id", "?"))
                out[key].append(rec)
        except (json.JSONDecodeError, OSError) as e:
            print(f"skip {f}: {e}")
    return out


def aggregate_cell(records: list[dict[str, Any]]) -> dict[str, Any]:
    """Compute summary stats for one (scenario, variant) cell."""
    n = len(records)
    valid = [r for r in records if "error" not in r]
    n_valid = len(valid)
    if n_valid == 0:
        return {
            "n": n,
            "n_valid": 0,
            "first_tool_correct_rate": None,
            "args_match_rate": None,
            "leaked_rate": None,
            "avg_cost_rmb": None,
            "avg_input_tok": None,
            "avg_output_tok": None,
            "avg_cache_hit_rate": None,
        }

    checks = [r.get("check", {}) for r in valid]

    first_correct = sum(1 for c in checks if c.get("first_tool_correct"))
    args_match = sum(1 for c in checks if c.get("args_match"))
    activated_correct = sum(1 for c in checks if c.get("activated_correct"))
    forbidden_calls = sum(1 for c in checks if c.get("forbidden_tools_called"))
    leaked = sum(1 for c in checks if c.get("leaked"))

    costs = [r.get("cost_rmb", 0) for r in valid]
    input_tok = [
        r.get("cache_hit_tokens", 0) + r.get("cache_miss_tokens", 0) for r in valid
    ]
    output_tok = [r.get("output_tok", 0) for r in valid]
    cache_hit_rates = []
    for r in valid:
        total = r.get("cache_hit_tokens", 0) + r.get("cache_miss_tokens", 0)
        if total:
            cache_hit_rates.append(r.get("cache_hit_tokens", 0) / total)

    return {
        "n": n,
        "n_valid": n_valid,
        "first_tool_correct_rate": first_correct / n_valid,
        "args_match_rate": args_match / n_valid,
        "activated_correct_rate": activated_correct / n_valid,
        "forbidden_call_rate": forbidden_calls / n_valid,
        "leaked_rate": leaked / n_valid,
        "avg_cost_rmb": statistics.mean(costs) if costs else 0,
        "total_cost_rmb": sum(costs),
        "avg_input_tok": statistics.mean(input_tok) if input_tok else 0,
        "avg_output_tok": statistics.mean(output_tok) if output_tok else 0,
        "avg_cache_hit_rate": (
            statistics.mean(cache_hit_rates) if cache_hit_rates else 0
        ),
    }


def render_markdown(
    by_cell: dict[tuple[str, str], list[dict[str, Any]]],
    title: str = "Experiment Summary",
) -> str:
    """Render aggregated stats as markdown table."""
    rows = []
    for (scen, var), records in sorted(by_cell.items()):
        agg = aggregate_cell(records)
        rows.append((scen, var, agg))

    if not rows:
        return f"# {title}\n\n(no data)\n"

    out = [f"# {title}", ""]
    out.append(
        "| Scenario | Variant | N | First correct | Args match | Activated correct | "
        "Forbidden | Leaked | Avg cost ¥ | Avg in tok | Avg out tok | Cache hit |"
    )
    out.append(
        "|---|---|---|---|---|---|---|---|---|---|---|---|"
    )
    for scen, var, agg in rows:
        out.append(
            f"| {scen} | {var} | {agg['n_valid']}/{agg['n']} "
            f"| {_pct(agg['first_tool_correct_rate'])} "
            f"| {_pct(agg['args_match_rate'])} "
            f"| {_pct(agg.get('activated_correct_rate'))} "
            f"| {_pct(agg.get('forbidden_call_rate'))} "
            f"| {_pct(agg['leaked_rate'])} "
            f"| {agg['avg_cost_rmb']:.5f} "
            f"| {agg['avg_input_tok']:.0f} "
            f"| {agg['avg_output_tok']:.0f} "
            f"| {_pct(agg['avg_cache_hit_rate'])} |"
        )
    return "\n".join(out) + "\n"


def _pct(x: float | None) -> str:
    if x is None:
        return "—"
    return f"{x*100:.1f}%"


def summarize_priority(priority: str) -> str:
    """Filter to a single priority and render."""
    by_cell = load_results()
    filtered = {
        k: v
        for k, v in by_cell.items()
        if any(rec.get("scenario_id", "").startswith(f"{priority}-") for rec in v)
        or any(priority in rec.get("scenario_id", "") for rec in v)
    }
    return render_markdown(filtered, title=f"Priority: {priority}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--priority", type=str, default=None)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()

    if args.all or args.report:
        by_cell = load_results()
        md = render_markdown(by_cell, title="All Experiment Results")
        if args.report:
            (REPORTS_DIR / "summary.md").write_text(md)
            print(f"wrote {REPORTS_DIR / 'summary.md'}")
        else:
            print(md)
    elif args.priority:
        print(summarize_priority(args.priority))
    else:
        ap.print_help()
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
