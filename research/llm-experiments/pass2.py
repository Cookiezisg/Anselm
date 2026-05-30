"""Pass 2: deep dive on Pass 1 winners + chain multi-turn pass.

Usage:
    python3 pass2.py chain --reps 15        # run chain priority with multi-turn
    python3 pass2.py deep --reps 30         # rerun all Pass 1 winners with higher N
    python3 pass2.py extras --reps 20       # run new variants designed after Pass 1

Cells to deep-dive are computed from `reports/pass1_analysis.md` winner list.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

from deepseek_client import BudgetExhausted, cumulative_cost_rmb
from experiments import (
    ALL_SCENARIOS,
    CHAIN_VARIANTS,
    LAZY_VARIANTS,
    SCHEMA_VARIANTS,
    TOOL_DESC_VARIANTS,
    build_scenario_for_run,
    chain_tools_for_variant,
    CHAIN_SYSTEM_PROMPTS,
)
from runner import RESULTS_DIR

# Lazy import for chain runner
def _chain_run_single(composed: dict[str, Any], variant: dict[str, Any], rep_idx: int):
    from chain_runner import run_chain
    return run_chain(composed, variant, rep_idx=rep_idx, max_turns=6)


# ============ Chain multi-turn pass ============


def run_chain_pass(reps: int = 15) -> None:
    """Re-run chain priority with multi-turn chain runner."""
    print(f"##### Chain multi-turn pass (reps={reps}) #####")
    scenarios = ALL_SCENARIOS["chain"]
    variants = CHAIN_VARIANTS

    for v in variants:
        for s in scenarios:
            cell_id = f"chain2-{s['id']}__{v['id']}"
            print(f"\n=== {cell_id} ===")
            print(f"    budget: ¥{cumulative_cost_rmb():.4f}")
            composed = build_scenario_for_run(s, v)
            out_file = RESULTS_DIR / f"{cell_id}.jsonl"
            records: list[dict[str, Any]] = []
            completed = 0
            try:
                for i in range(reps):
                    rec = _chain_run_single(composed, v, i)
                    d = rec.to_dict()
                    records.append(d)
                    if rec.completed:
                        completed += 1
                    if (i + 1) % 5 == 0:
                        print(
                            f"      {i+1}/{reps} done, {completed} completed, "
                            f"avg turns={sum(r['total_turns'] for r in records)/(i+1):.1f}, "
                            f"cum ¥{cumulative_cost_rmb():.4f}"
                        )
            except BudgetExhausted as e:
                print(f"BUDGET: {e}")
                break
            except Exception as e:
                print(f"ERROR: {e}", file=sys.stderr)
            out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
            print(f"    → {completed}/{reps} completed, cum ¥{cumulative_cost_rmb():.4f}")
    print(f"\n##### Chain pass done. Total cumulative: ¥{cumulative_cost_rmb():.4f} #####")


# ============ Deep dive on Pass 1 winners ============


def load_winners() -> list[tuple[str, str, str]]:
    """Parse pass1_analysis.md for winner cells. Returns list of (priority, scen_id, variant_id)."""
    # Hard-coded for now — fill in after Pass 1 done by reading reports/pass1_analysis.md
    # Default: top variant per scenario across priorities lazy/tool_desc/schema
    # Chain uses chain_pass instead
    winners: list[tuple[str, str, str]] = []
    # Will be populated after Pass 1 analysis
    return winners


def deep_dive(reps: int = 30) -> None:
    winners = load_winners()
    if not winners:
        print("No winners loaded — run analysis.py first and edit pass2.py load_winners()")
        return
    print(f"##### Deep dive on {len(winners)} cells (reps={reps}) #####")
    for pri, scen_id, var_id in winners:
        cell_id = f"pass2-{scen_id}__{var_id}"
        print(f"\n=== {cell_id} ===")
        # Find scenario + variant
        scen = next((s for s in ALL_SCENARIOS[pri] if s["id"] == scen_id), None)
        if not scen:
            print(f"  scenario {scen_id} not found")
            continue
        variants_pool = {
            "lazy": LAZY_VARIANTS,
            "tool_desc": TOOL_DESC_VARIANTS,
            "schema": SCHEMA_VARIANTS,
            "chain": CHAIN_VARIANTS,
        }[pri]
        var = next((v for v in variants_pool if v["id"] == var_id), None)
        if not var:
            print(f"  variant {var_id} not found")
            continue
        composed = build_scenario_for_run(scen, var)
        out_file = RESULTS_DIR / f"{cell_id}.jsonl"
        records: list[dict[str, Any]] = []
        correct = 0
        try:
            from runner import run_single
            for i in range(reps):
                rec = run_single(composed, var, rep_idx=i)
                d = rec.__dict__
                records.append(d)
                ok = rec.check.get("first_tool_correct") if pri != "lazy" else rec.check.get("activated_correct")
                if ok:
                    correct += 1
                if (i + 1) % 10 == 0:
                    print(f"      {i+1}/{reps} done, {correct} correct, cum ¥{cumulative_cost_rmb():.4f}")
        except BudgetExhausted as e:
            print(f"BUDGET: {e}")
            break
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
        out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
        print(f"    → {correct}/{reps} correct, cum ¥{cumulative_cost_rmb():.4f}")
    print(f"\n##### Deep dive done. Total cumulative: ¥{cumulative_cost_rmb():.4f} #####")


# ============ Extra variants (designed post Pass 1) ============


def lazy_no_resident_search_offering() -> list[dict[str, Any]]:
    """V4 variant: 11 groups BUT no Resident search tools — force activate first."""
    from experiments import GROUPS_11, _activate_tool_meta
    return [_activate_tool_meta(list(GROUPS_11.keys()))]


def run_lazy_v4_pass(reps: int = 15) -> None:
    """Run lazy scenarios with V4 = 11 groups + no Resident search."""
    print(f"##### Lazy V4 pass: 11 groups + no Resident search (reps={reps}) #####")
    v4_variant = {"id": "V4-11g-no-resident-search", "priority": "lazy", "scheme": "GROUPS_11"}

    for s in ALL_SCENARIOS["lazy"]:
        cell_id = f"{s['id']}__{v4_variant['id']}"
        print(f"\n=== {cell_id} ===")
        composed = dict(s)
        composed["tools"] = lazy_no_resident_search_offering()
        if "alt_activations" in composed["expected"] and "GROUPS_11" in composed["expected"]["alt_activations"]:
            composed["expected"] = dict(composed["expected"])
            composed["expected"]["required_activations"] = composed["expected"]["alt_activations"]["GROUPS_11"]
        out_file = RESULTS_DIR / f"{cell_id}.jsonl"
        records: list[dict[str, Any]] = []
        correct = 0
        try:
            from runner import run_single
            for i in range(reps):
                rec = run_single(composed, v4_variant, rep_idx=i)
                records.append(rec.__dict__)
                if rec.check.get("activated_correct"):
                    correct += 1
                if (i + 1) % 5 == 0:
                    print(f"      {i+1}/{reps}, {correct} activated_correct, ¥{cumulative_cost_rmb():.4f}")
        except BudgetExhausted as e:
            print(f"BUDGET: {e}")
            break
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
        out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
        print(f"    → {correct}/{reps}, ¥{cumulative_cost_rmb():.4f}")
    print(f"\n##### V4 pass done. ¥{cumulative_cost_rmb():.4f} #####")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["chain", "deep", "lazy_v4"])
    ap.add_argument("--reps", type=int, default=15)
    args = ap.parse_args()
    if args.mode == "chain":
        run_chain_pass(reps=args.reps)
    elif args.mode == "deep":
        deep_dive(reps=args.reps)
    elif args.mode == "lazy_v4":
        run_lazy_v4_pass(reps=args.reps)
    return 0


if __name__ == "__main__":
    sys.exit(main())
