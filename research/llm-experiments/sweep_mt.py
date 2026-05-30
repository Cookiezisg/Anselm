"""Multi-turn tool sweep — the CORRECT measurement for entity-anchored tools.

Single-turn sweep undercounts: for any tool operating on an existing entity by id,
the LLM correctly calls search_X FIRST (on-ramp), then the target on turn 2+.
This runs up to 3 turns, feeds canned search/get results, and scores success =
target tool called within the chain.

Usage: python3 sweep_mt.py 15
"""

from __future__ import annotations

import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from chain_runner import run_chain
from deepseek_client import cumulative_cost_rmb
from forge_runner import RESULTS_DIR
from tool_sweep import ROSTER, SYS, build_roster_tools

TOOLS = build_roster_tools()
MAXW = 6


def run_tool_mt(target, prompt, arg_substr, reps):
    scen = {"id": f"swmt-{target}", "target_tool": target, "system_prompt": SYS,
            "user_prompt": prompt, "expect": {"required_tools": [target]}}

    def _one(i):
        try:
            rec = run_chain({**scen, "tools": TOOLS}, {"id": "roster"}, rep_idx=i,
                            max_turns=5, disable_thinking=True)
            called = set()
            for t in rec.turns:
                for c in t.assistant_message.get("tool_calls", []) or []:
                    fn = c.get("function") or c
                    n = fn.get("name") if isinstance(fn, dict) else None
                    if n:
                        called.add(n)
            return {"ok": target in called, "called": sorted(called), "turns": rec.total_turns}
        except Exception as e:
            return {"ok": False, "called": [], "error": str(e)}

    rows = []
    with ThreadPoolExecutor(max_workers=MAXW) as ex:
        for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
            rows.append(f.result())
    return rows


def main():
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    # Only re-test the entity-anchored tools that "failed" single-turn (search-first).
    # Reads the single-turn low list dynamically: re-test ALL roster tools multi-turn.
    results = {}
    low = []
    for name, req, desc, prompt, arg in ROSTER:
        rows = run_tool_mt(name, prompt, arg, reps)
        ok = sum(1 for r in rows if r["ok"])
        results[name] = (ok, len(rows))
        flag = "" if ok >= reps * 0.9 else "  <-- LOW"
        avg_turns = sum(r.get("turns", 0) for r in rows) / len(rows) if rows else 0
        print(f"{name:30s} {ok}/{reps} (turns~{avg_turns:.1f}){flag}", flush=True)
        if ok < reps * 0.9:
            low.append(name)
    tot = (sum(v for v, _ in results.values()), sum(n for _, n in results.values()))
    print(f"\nMULTI-TURN SWEEP: {tot[0]}/{tot[1]} ({tot[0]*100//tot[1]}%)  cum ¥{cumulative_cost_rmb():.4f}")
    print("LOW:", low)
    (RESULTS_DIR / "sweep_mt_summary.json").write_text(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
