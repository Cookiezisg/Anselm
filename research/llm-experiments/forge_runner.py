"""Generic forging runner — the core of iterative淬炼.

For ONE surface variant: run scenarios × N reps on real DeepSeek, extract the
target tool call, run a programmatic validator, and produce a FAILURE DIGEST
(grouped by error reason + sample args) so the human/agent can read root causes
fast and design the next iteration.

Not benchmark-and-pick. This is the test oracle for the design→test→read→fix loop.
"""

from __future__ import annotations

import json
import os
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

from deepseek_client import BudgetExhausted, chat_complete, cumulative_cost_rmb

RESULTS_DIR = Path(__file__).parent / "results"
RESULTS_DIR.mkdir(exist_ok=True)
MAX_WORKERS = 6


def extract_tool_call(result, target_tool: str) -> tuple[str | None, dict[str, Any] | None]:
    """Return (called_tool_name, parsed_args) for the FIRST tool call. None if none."""
    calls = result.effective_tool_calls
    if not calls:
        return None, None
    fn = calls[0].get("function") or calls[0]
    name = fn.get("name") if isinstance(fn, dict) else None
    args = fn.get("arguments")
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except json.JSONDecodeError:
            args = {"__unparseable__": args[:500]}
    return name, args


@dataclass
class ForgeResult:
    scenario_id: str
    variant_id: str
    rep: int
    called_tool: str | None
    target_tool: str
    valid: bool
    errors: list[str]
    args_excerpt: str
    cost_rmb: float
    in_tok: int
    out_tok: int
    leaked: bool

    def to_dict(self) -> dict[str, Any]:
        return self.__dict__


def run_forge_cell(
    scenario: dict[str, Any],
    variant_id: str,
    tools: list[dict[str, Any]],
    validator: Callable[[str | None, dict[str, Any] | None, dict[str, Any]], tuple[bool, list[str]]],
    reps: int = 20,
    system_prompt: str | None = None,
    max_tokens: int = 8000,
    disable_thinking: bool | None = None,
) -> list[ForgeResult]:
    # Global override via env: FORGE_NOTHINK=1 disables thinking for all cells.
    if disable_thinking is None:
        disable_thinking = os.environ.get("FORGE_NOTHINK") == "1"
    """Run one scenario × variant × N reps. validator(called_tool, args, scenario) -> (valid, errors)."""
    messages: list[dict[str, Any]] = []
    sp = system_prompt or scenario.get("system_prompt")
    if sp:
        messages.append({"role": "system", "content": sp})
    messages.append({"role": "user", "content": scenario["user_prompt"]})
    target = scenario["target_tool"]

    def _one(rep: int) -> ForgeResult:
        try:
            res = chat_complete(
                messages=messages, tools=tools,
                scenario=scenario["id"], variant=variant_id,
                tool_choice="auto", max_tokens=max_tokens,
                disable_thinking=disable_thinking,
            )
            name, args = extract_tool_call(res, target)
            valid, errors = validator(name, args, scenario)
            return ForgeResult(
                scenario_id=scenario["id"], variant_id=variant_id, rep=rep,
                called_tool=name, target_tool=target, valid=valid, errors=errors,
                args_excerpt=json.dumps(args, ensure_ascii=False)[:800] if args else "",
                cost_rmb=res.cost_entry.cost_rmb,
                in_tok=res.cost_entry.input_tok_cached + res.cost_entry.input_tok_uncached,
                out_tok=res.cost_entry.output_tok,
                leaked=bool(res.leaked_tool_calls) and not res.tool_calls,
            )
        except BudgetExhausted:
            raise
        except Exception as e:
            return ForgeResult(
                scenario_id=scenario["id"], variant_id=variant_id, rep=rep,
                called_tool=None, target_tool=target, valid=False,
                errors=[f"EXCEPTION: {e}"], args_excerpt="", cost_rmb=0,
                in_tok=0, out_tok=0, leaked=False,
            )

    results: list[ForgeResult] = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = [ex.submit(_one, r) for r in range(reps)]
        for f in as_completed(futures):
            results.append(f.result())
    results.sort(key=lambda r: r.rep)
    return results


def failure_digest(results: list[ForgeResult]) -> str:
    """Group failures by error reason + show sample args. This is what I READ to find root causes."""
    by_scenario: dict[str, list[ForgeResult]] = defaultdict(list)
    for r in results:
        by_scenario[r.scenario_id].append(r)

    lines: list[str] = []
    total_valid = sum(1 for r in results if r.valid)
    lines.append(f"OVERALL: {total_valid}/{len(results)} valid ({total_valid*100//len(results) if results else 0}%)")
    avg_in = sum(r.in_tok for r in results) / len(results) if results else 0
    avg_out = sum(r.out_tok for r in results) / len(results) if results else 0
    lines.append(f"avg tokens: in={avg_in:.0f} out={avg_out:.0f} | cum ¥{cumulative_cost_rmb():.4f}")
    lines.append("")

    for scen, rs in sorted(by_scenario.items()):
        v = sum(1 for r in rs if r.valid)
        lines.append(f"### {scen}: {v}/{len(rs)}")
        # collect error reasons
        err_counter: Counter = Counter()
        for r in rs:
            if not r.valid:
                for e in r.errors:
                    err_counter[e] += 1
        if err_counter:
            for err, cnt in err_counter.most_common():
                lines.append(f"   ✗ [{cnt}×] {err}")
            # show 1 sample failing args per top error
            sample = next((r for r in rs if not r.valid), None)
            if sample:
                lines.append(f"   sample bad args: {sample.args_excerpt[:400]}")
                if sample.called_tool != sample.target_tool:
                    lines.append(f"   (called {sample.called_tool!r}, expected {sample.target_tool!r})")
        lines.append("")
    return "\n".join(lines)


def save_results(results: list[ForgeResult], tag: str) -> Path:
    out = RESULTS_DIR / f"forge_{tag}.jsonl"
    out.write_text("\n".join(json.dumps(r.to_dict(), ensure_ascii=False) for r in results))
    return out
