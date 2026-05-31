"""Experiment runner: one scenario × one variant × N reps.

Loads scenario YAML, applies variant overrides, runs N reps against DeepSeek
V4-flash, captures trace + programmatic auto-check, writes JSONL to results/.

Usage:
    python3 runner.py <scenario_path> <variant_path> --reps 10
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from deepseek_client import (
    BudgetExhausted,
    ChatResult,
    chat_complete,
    cumulative_cost_rmb,
)

SCRIPT_DIR = Path(__file__).parent
RESULTS_DIR = SCRIPT_DIR / "results"
RESULTS_DIR.mkdir(exist_ok=True)


# -- Variant application ------------------------------------------------


def deep_set(d: dict[str, Any], path: str, value: Any) -> None:
    """Set d[a][b][c] = value where path is 'a.b.c'."""
    parts = path.split(".")
    cur = d
    for p in parts[:-1]:
        if p not in cur or not isinstance(cur[p], dict):
            cur[p] = {}
        cur = cur[p]
    cur[parts[-1]] = value


def apply_variant(scenario: dict[str, Any], variant: dict[str, Any]) -> dict[str, Any]:
    """Apply variant overrides to a scenario. Returns new scenario dict."""
    out = copy.deepcopy(scenario)
    overrides = variant.get("overrides", {})
    for path, value in overrides.items():
        deep_set(out, path, value)
    # Variants can also replace entire fields
    replacements = variant.get("replace", {})
    for key, value in replacements.items():
        out[key] = value
    return out


# -- Programmatic auto-check --------------------------------------------


@dataclass
class CheckResult:
    first_tool_correct: bool = False
    first_tool_called: str | None = None
    expected_tool: str | None = None
    args_match: bool = False
    arg_mismatches: list[str] = field(default_factory=list)
    forbidden_tools_called: list[str] = field(default_factory=list)
    activated_groups: list[str] = field(default_factory=list)
    activated_correct: bool = False
    finish_reason: str = ""
    leaked: bool = False  # tool call was leaked to content
    notes: str = ""

    def to_dict(self) -> dict[str, Any]:
        d = self.__dict__.copy()
        return d


def check_call(result: ChatResult, expected: dict[str, Any]) -> CheckResult:
    """Run programmatic checks against expected behavior."""
    cr = CheckResult(
        expected_tool=expected.get("first_tool"),
        finish_reason=result.finish_reason,
        leaked=bool(result.leaked_tool_calls) and not result.tool_calls,
    )

    calls = result.effective_tool_calls
    if not calls:
        cr.notes = "no tool call made"
        return cr

    # Extract first call
    first = calls[0]
    fn = first.get("function") or first  # OpenAI-compat structure
    fn_name = fn.get("name") if isinstance(fn, dict) else None
    cr.first_tool_called = fn_name

    expected_tool = expected.get("first_tool")
    if expected_tool:
        cr.first_tool_correct = fn_name == expected_tool

    # Activated groups (for Lazy experiments)
    if fn_name == "activate_tools":
        try:
            args = fn.get("arguments")
            if isinstance(args, str):
                args = json.loads(args)
            cat = args.get("category") if args else None
            if cat:
                cr.activated_groups.append(cat)
        except (json.JSONDecodeError, AttributeError):
            pass

    # Check arguments
    expected_args = expected.get("args_must_include", {})
    if expected_args and fn_name:
        try:
            args = fn.get("arguments")
            if isinstance(args, str):
                args = json.loads(args)
            mismatches = []
            for k, v in expected_args.items():
                if args.get(k) != v:
                    mismatches.append(f"{k}: expected {v!r} got {args.get(k)!r}")
            cr.arg_mismatches = mismatches
            cr.args_match = not mismatches
        except (json.JSONDecodeError, AttributeError):
            cr.arg_mismatches = ["could not parse args"]

    # Activation correctness (for Lazy experiments)
    required_groups = set(expected.get("required_activations", []))
    if required_groups:
        cr.activated_correct = required_groups.issubset(set(cr.activated_groups))

    # Forbidden tools
    forbidden = set(expected.get("forbidden_tools", []))
    if forbidden:
        for c in calls:
            f = c.get("function") or c
            fname = f.get("name") if isinstance(f, dict) else None
            if fname in forbidden:
                cr.forbidden_tools_called.append(fname)

    return cr


# -- Trace + run --------------------------------------------------------


@dataclass
class RunRecord:
    rep_idx: int
    scenario_id: str
    variant_id: str
    user_prompt: str
    messages_sent: list[dict[str, Any]]
    tools_offered_count: int
    raw_response: dict[str, Any]
    check: dict[str, Any]
    cost_rmb: float
    cache_hit_tokens: int
    cache_miss_tokens: int
    output_tok: int
    ts: float


def run_single(
    scenario: dict[str, Any],
    variant: dict[str, Any],
    rep_idx: int = 0,
) -> RunRecord:
    """Run one scenario × variant × 1 rep. Returns RunRecord."""
    s = apply_variant(scenario, variant)

    # Build messages
    messages: list[dict[str, Any]] = []
    if s.get("system_prompt"):
        messages.append({"role": "system", "content": s["system_prompt"]})
    messages.append({"role": "user", "content": s["user_prompt"]})

    tools = s.get("tools", [])

    result = chat_complete(
        messages=messages,
        tools=tools if tools else None,
        scenario=s["id"],
        variant=variant["id"],
        tool_choice="auto",
        max_tokens=s.get("max_tokens", 2048),
    )

    expected = s.get("expected", {})
    check = check_call(result, expected)

    return RunRecord(
        rep_idx=rep_idx,
        scenario_id=s["id"],
        variant_id=variant["id"],
        user_prompt=s["user_prompt"],
        messages_sent=messages,
        tools_offered_count=len(tools),
        raw_response=result.raw_response,
        check=check.to_dict(),
        cost_rmb=result.cost_entry.cost_rmb,
        cache_hit_tokens=result.cost_entry.input_tok_cached,
        cache_miss_tokens=result.cost_entry.input_tok_uncached,
        output_tok=result.cost_entry.output_tok,
        ts=time.time(),
    )


def run_cell(
    scenario_path: Path,
    variant_path: Path,
    reps: int = 10,
    verbose: bool = True,
) -> Path:
    """Run all reps for one scenario × variant cell. Returns results file path."""
    scenario = yaml.safe_load(scenario_path.read_text())
    variant = yaml.safe_load(variant_path.read_text())

    scen_id = scenario["id"]
    var_id = variant["id"]

    out_file = RESULTS_DIR / f"{scen_id}__{var_id}.jsonl"

    records: list[dict[str, Any]] = []
    for i in range(reps):
        try:
            rec = run_single(scenario, variant, rep_idx=i)
            records.append(rec.__dict__)
            if verbose:
                check = rec.check
                status = "✓" if check.get("first_tool_correct") else "✗"
                print(
                    f"  [{i+1}/{reps}] {status} first={check.get('first_tool_called')} "
                    f"expected={check.get('expected_tool')} "
                    f"cost=¥{rec.cost_rmb:.5f}"
                )
        except BudgetExhausted as e:
            print(f"  BUDGET EXHAUSTED: {e}", file=sys.stderr)
            break
        except Exception as e:
            if verbose:
                print(f"  [{i+1}/{reps}] ERROR: {e}", file=sys.stderr)
            records.append(
                {
                    "rep_idx": i,
                    "scenario_id": scen_id,
                    "variant_id": var_id,
                    "error": str(e),
                    "ts": time.time(),
                }
            )

    out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
    if verbose:
        print(f"  → {out_file.name} ({len(records)} records)")
        print(f"  cumulative cost: ¥{cumulative_cost_rmb():.4f}")
    return out_file


# -- CLI ---------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("scenario", type=Path)
    ap.add_argument("variant", type=Path)
    ap.add_argument("--reps", type=int, default=10)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    run_cell(args.scenario, args.variant, reps=args.reps, verbose=not args.quiet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
