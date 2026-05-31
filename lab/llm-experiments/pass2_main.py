"""Pass 2 main launcher: all 4 phases.

Phase A: Lazy V4 (no Resident search) — test force-activate hypothesis
Phase B: Schema multi-turn — proper schema test (after get_function on-ramp)
Phase C: Chain multi-turn — proper chain completion
Phase D: Tool desc V5 (V2 + V3 combined) — test antipattern + examples
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from chain_runner import canned_result, run_chain
from deepseek_client import BudgetExhausted, chat_complete, cumulative_cost_rmb
from experiments import (
    ALL_SCENARIOS,
    CHAIN_SYSTEM_PROMPTS,
    CHAIN_VARIANTS,
    GROUPS_11,
    SCHEMA_SCENARIOS,
    SCHEMA_VARIANTS,
    SYSTEM_PROMPT_BASE,
    SYSTEM_PROMPT_LAZY,
    T_CREATE_FUNCTION,
    T_GET_FUNCTION,
    T_SEARCH_FUNCTIONS,
    T_SEARCH_HANDLERS,
    TOOL_DESC_TEMPLATES,
    TOOL_DESC_VARIANTS,
    _activate_tool_meta,
    _tool,
    build_scenario_for_run,
    schema_tools_for_variant,
    tool_desc_tools_for_variant,
)
from runner import RESULTS_DIR, run_single

MAX_WORKERS = 5


def _parallel_runs(
    composed: dict[str, Any],
    variant: dict[str, Any],
    reps: int,
    multi_turn: bool = False,
) -> list[dict[str, Any]]:
    """Run reps in parallel; return list of record dicts."""

    def _one(i: int) -> dict[str, Any]:
        try:
            if multi_turn:
                rec = run_chain(composed, variant, rep_idx=i, max_turns=6)
                return rec.to_dict()
            else:
                rec = run_single(composed, variant, rep_idx=i)
                return rec.__dict__
        except BudgetExhausted:
            raise
        except Exception as e:
            return {
                "rep_idx": i,
                "scenario_id": composed["id"],
                "variant_id": variant["id"],
                "error": str(e),
                "ts": time.time(),
            }

    records: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = [ex.submit(_one, i) for i in range(reps)]
        for f in as_completed(futures):
            records.append(f.result())
    records.sort(key=lambda r: r.get("rep_idx", 0))
    return records


# ============ Phase A: Lazy V4 (no Resident search) ============


def phase_a_lazy_v4(reps: int = 15) -> None:
    print(f"##### Phase A: Lazy V4 (no Resident search, 11 groups), reps={reps} #####", flush=True)
    v4 = {"id": "V4-11g-no-resident", "priority": "lazy", "scheme": "GROUPS_11"}

    # Tools = only activate_tools meta (no Resident search at all)
    activate_meta = _activate_tool_meta(list(GROUPS_11.keys()))

    for s in ALL_SCENARIOS["lazy"]:
        cell_id = f"{s['id']}__{v4['id']}"
        out_file = RESULTS_DIR / f"{cell_id}.jsonl"
        if out_file.exists():
            print(f"  SKIP {cell_id}", flush=True)
            continue
        print(f"\n=== {cell_id} === (¥{cumulative_cost_rmb():.4f})", flush=True)
        composed = dict(s)
        composed["tools"] = [activate_meta]
        # Use GROUPS_11 expected
        alt = s["expected"].get("alt_activations", {})
        if "GROUPS_11" in alt:
            composed["expected"] = dict(s["expected"])
            composed["expected"]["required_activations"] = alt["GROUPS_11"]
        records = _parallel_runs(composed, v4, reps)
        correct = sum(
            1 for r in records if "error" not in r and r.get("check", {}).get("activated_correct")
        )
        out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
        print(f"  → {correct}/{reps} activated_correct, ¥{cumulative_cost_rmb():.4f}", flush=True)


# ============ Phase B: Schema multi-turn ============


def phase_b_schema_multi_turn(reps: int = 12) -> None:
    print(f"\n##### Phase B: Schema multi-turn, reps={reps} #####", flush=True)
    for v in SCHEMA_VARIANTS:
        for s in SCHEMA_SCENARIOS:
            cell_id = f"schema2-{s['id']}__{v['id']}"
            out_file = RESULTS_DIR / f"{cell_id}.jsonl"
            if out_file.exists():
                print(f"  SKIP {cell_id}", flush=True)
                continue
            print(f"\n=== {cell_id} === (¥{cumulative_cost_rmb():.4f})", flush=True)
            composed = build_scenario_for_run(s, v)
            # Mark scenario id for multi-turn results
            composed = dict(composed)
            composed["id"] = f"schema2-{s['id']}"
            # Set required_tools so chain completion is judged on calling edit_function
            composed.setdefault("expected", {})
            composed["expected"]["required_tools"] = ["edit_function"]
            try:
                records = _parallel_runs(composed, v, reps, multi_turn=True)
            except BudgetExhausted as e:
                print(f"BUDGET: {e}", flush=True)
                return
            completed = sum(1 for r in records if r.get("completed"))
            avg_turns = (
                sum(r.get("total_turns", 0) for r in records) / len(records)
                if records
                else 0
            )
            out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
            print(
                f"  → {completed}/{reps} called edit_function, avg_turns={avg_turns:.1f}, ¥{cumulative_cost_rmb():.4f}",
                flush=True,
            )


# ============ Phase C: Chain multi-turn ============


def phase_c_chain_multi_turn(reps: int = 12) -> None:
    print(f"\n##### Phase C: Chain multi-turn, reps={reps} #####", flush=True)
    chain_scenarios = ALL_SCENARIOS["chain"]
    for v in CHAIN_VARIANTS:
        for s in chain_scenarios:
            cell_id = f"chain2-{s['id']}__{v['id']}"
            out_file = RESULTS_DIR / f"{cell_id}.jsonl"
            if out_file.exists():
                print(f"  SKIP {cell_id}", flush=True)
                continue
            print(f"\n=== {cell_id} === (¥{cumulative_cost_rmb():.4f})", flush=True)
            composed = build_scenario_for_run(s, v)
            composed = dict(composed)
            composed["id"] = f"chain2-{s['id']}"
            # Required tools per scenario (rough heuristic)
            required: list[str] = []
            if "polling" in s["id"]:
                required = ["create_function"]
            elif "edit-workflow" in s["id"] or "cel-null-safety" in s["id"]:
                required = ["edit_workflow"]
            elif "multi-step-debug" in s["id"]:
                required = ["query_events", "list_dead_letters", "replay_message"]
            composed.setdefault("expected", {})
            composed["expected"]["required_tools"] = required
            try:
                records = _parallel_runs(composed, v, reps, multi_turn=True)
            except BudgetExhausted as e:
                print(f"BUDGET: {e}", flush=True)
                return
            completed = sum(1 for r in records if r.get("completed"))
            avg_turns = (
                sum(r.get("total_turns", 0) for r in records) / len(records)
                if records
                else 0
            )
            out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
            print(
                f"  → {completed}/{reps} completed, avg_turns={avg_turns:.1f}, ¥{cumulative_cost_rmb():.4f}",
                flush=True,
            )


# ============ Phase D: Tool desc V5 (V2 + V3 combined) ============


V5_DESC = (
    "Create a Forgify function. Stateless Python callable in sandbox.\n\n"
    "DO NOT use this for stateful classes (use create_handler instead).\n"
    "DO NOT use this for workflow orchestration (use create_workflow).\n"
    "DO NOT set kind=polling without polling_interval.\n\n"
    "kind values:\n"
    "  - normal: executed on-demand by workflow tool nodes\n"
    "  - polling: system runs on an interval. Polling MUST accept last_cursor and return {events, next_cursor}.\n\n"
    "Examples:\n"
    "  Example 1 (minimal normal):\n"
    "    create_function(name='add', kind='normal',\n"
    "                    code='def add(a,b): return a+b',\n"
    "                    description='Adds two numbers')\n\n"
    "  Example 2 (polling with cursor):\n"
    "    create_function(name='poll_inbox', kind='polling', polling_interval='60s',\n"
    "                    code='def poll(last_cursor):\\n"
    "    msgs = fetch_since(last_cursor)\\n"
    "    return {\"events\": msgs, \"next_cursor\": msgs[-1].ts if msgs else last_cursor}',\n"
    "                    description='Polls inbox')"
)


def phase_d_tool_desc_v5(reps: int = 15) -> None:
    print(f"\n##### Phase D: Tool desc V5 (V2+V3 combined), reps={reps} #####", flush=True)
    v5 = {"id": "V5-combined", "priority": "tool_desc"}
    TOOL_DESC_TEMPLATES["V5-combined"] = V5_DESC
    custom_create = _tool(
        "create_function",
        V5_DESC,
        ["name", "kind", "code", "description"],
        T_CREATE_FUNCTION["function"]["parameters"]["properties"],
    )
    tools = [custom_create, T_SEARCH_FUNCTIONS, T_GET_FUNCTION,
             # use a stub create_handler tool for distraction
             _tool("create_handler", "Create a Forgify handler (stateful Python class).",
                   ["name", "code"], {"name": {"type": "string"}, "code": {"type": "string"}}),
             T_SEARCH_HANDLERS]

    for s in ALL_SCENARIOS["tool_desc"]:
        cell_id = f"{s['id']}__{v5['id']}"
        out_file = RESULTS_DIR / f"{cell_id}.jsonl"
        if out_file.exists():
            print(f"  SKIP {cell_id}", flush=True)
            continue
        print(f"\n=== {cell_id} === (¥{cumulative_cost_rmb():.4f})", flush=True)
        composed = dict(s)
        composed["tools"] = tools
        try:
            records = _parallel_runs(composed, v5, reps)
        except BudgetExhausted as e:
            print(f"BUDGET: {e}", flush=True)
            return
        correct = sum(
            1 for r in records if "error" not in r and r.get("check", {}).get("first_tool_correct")
        )
        out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
        print(f"  → {correct}/{reps} first_tool_correct, ¥{cumulative_cost_rmb():.4f}", flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("phase", choices=["a", "b", "c", "d", "all"])
    ap.add_argument("--reps", type=int, default=15)
    args = ap.parse_args()
    if args.phase in ("a", "all"):
        phase_a_lazy_v4(reps=args.reps)
    if args.phase in ("b", "all"):
        phase_b_schema_multi_turn(reps=args.reps)
    if args.phase in ("c", "all"):
        phase_c_chain_multi_turn(reps=args.reps)
    if args.phase in ("d", "all"):
        phase_d_tool_desc_v5(reps=args.reps)
    print(f"\n##### Pass 2 done. Total cumulative: ¥{cumulative_cost_rmb():.4f} #####", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
