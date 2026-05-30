"""Composite end-to-end scenarios — the ultimate confidence test.

Multi-turn chains using the CONVERGED tool descriptions together. Tests whether the
LLM strings the forged tools correctly on realistic multi-step tasks:
  1. diagnosis chain: investigate failed workflow → events → dead-letters → replay
  2. multi-entity forge: create agent + function, then wire a workflow

Usage: python3 composite_forge.py 15
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from chain_runner import run_chain
from catalog_v2 import agent_tools, function_tools, workflow_tools, tool
from forge_runner import RESULTS_DIR

MAXW = 5
SYS = """You are the Forgify chat AI engineer. Manage forge entities (function/handler/agent/workflow)
and diagnose workflow runs. Use search_* to find entities by id, then act. Plan multi-step tasks,
emit one tool call per turn, verify each result before the next."""

# Converged tool roster (subset, with forged descriptions)
def composite_tools():
    t = []
    t += workflow_tools("V2-enum-types")        # create/edit_workflow (forged)
    t += agent_tools("V3-full")                  # create/edit/run agent (forged)
    t += function_tools("V5-combined")           # create_function (forged)
    # diagnosis + lifecycle + search tools (concise)
    for name, req, desc in [
        ("search_workflows", ["query"], "Search workflows by name."),
        ("search_flowruns", ["workflow_id"], "List flowrun history for a workflow."),
        ("query_events", ["workflow_id"], "Query events (handler_crash/trigger_exhausted/etc)."),
        ("get_flowrun_trace", ["id"], "Get a flowrun's message causality trace."),
        ("list_dead_letters", ["workflow_id"], "List dead-letter messages."),
        ("get_dead_letter", ["message_id"], "Get a dead-letter's payload/ctx/stack."),
        ("replay_message", ["message_id"], "Replay a dead-letter message."),
        ("accept_pending_workflow", ["id"], "Promote pending workflow version to active."),
        ("activate_workflow", ["id"], "Activate a workflow (register listeners)."),
        ("accept_pending_agent", ["id"], "Promote pending agent version."),
        ("accept_pending_function", ["id"], "Promote pending function version."),
    ]:
        props = {p: ({"type": "object"} if p in ("args",) else {"type": "string"}) for p in req}
        t.append(tool(name, desc, req, props))
    return t

TOOLS = composite_tools()

SCEN = [
    {
        "id": "comp-diagnosis",
        "user_prompt": "workflow wf_orders 昨天有几个 flowrun 挂了,帮我查清楚为什么,如果是死信导致的,把第一条死信 replay 一下。",
        "required_any_order": ["search_flowruns", "query_events", "list_dead_letters", "replay_message"],
        "min_required": 3,  # search/diagnose + replay
    },
    {
        "id": "comp-multi-forge",
        "user_prompt": "帮我建一个邮件分类 agent ag(分 invoice/inquiry/spam),再建一个 normal function 解析发票 fn_parse_invoice,然后建一个 workflow:手动触发 → 这个 agent 分类 → case 路由 invoice 到一个调 fn_parse_invoice 的 tool 节点。",
        "required_any_order": ["create_agent", "create_function", "create_workflow"],
        "min_required": 3,
    },
    {
        "id": "comp-deploy",
        "user_prompt": "把 workflow wf_daily 接受待定版本然后上线让它自动跑。",
        "required_any_order": ["search_workflows", "accept_pending_workflow", "activate_workflow"],
        "min_required": 2,  # accept + activate (search optional)
    },
]


def run_scen(scen, reps):
    def _one(i):
        try:
            rec = run_chain({**scen, "system_prompt": SYS, "tools": TOOLS,
                             "expect": {"required_tools": scen["required_any_order"]}},
                            {"id": "comp"}, rep_idx=i, max_turns=8, disable_thinking=True)
            called = []
            for t in rec.turns:
                for c in t.assistant_message.get("tool_calls", []) or []:
                    fn = c.get("function") or c
                    n = fn.get("name") if isinstance(fn, dict) else None
                    if n:
                        called.append(n)
            hit = sum(1 for req in scen["required_any_order"] if req in called)
            ok = hit >= scen["min_required"]
            return {"ok": ok, "hit": hit, "called": called, "turns": rec.total_turns}
        except Exception as e:
            return {"ok": False, "hit": 0, "called": [], "error": str(e)}
    rows = []
    with ThreadPoolExecutor(max_workers=MAXW) as ex:
        for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
            rows.append(f.result())
    return rows


def main():
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    out = {}
    for scen in SCEN:
        rows = run_scen(scen, reps)
        ok = sum(1 for r in rows if r["ok"])
        out[scen["id"]] = (ok, len(rows))
        avg_t = sum(r.get("turns", 0) for r in rows) / len(rows) if rows else 0
        bad = next((r for r in rows if not r["ok"]), None)
        print(f"{scen['id']:18s} {ok}/{reps} (turns~{avg_t:.1f})" + (f"  e.g. called={bad['called']}" if bad else ""), flush=True)
    (RESULTS_DIR / "composite_summary.json").write_text(json.dumps(out, indent=2))
    tot = (sum(v for v, _ in out.values()), sum(n for _, n in out.values()))
    print(f"\nCOMPOSITE: {tot[0]}/{tot[1]} ({tot[0]*100//tot[1]}%)")


if __name__ == "__main__":
    main()
