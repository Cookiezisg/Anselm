"""Round 3 — system-prompt machinery (the big E-class gap).

A. Injected standard fields (summary/destructive/execution_group) + tool_conventions
   — does the LLM fill them correctly when schema has them + sys prompt explains them?
B. chainPatternsSection — multi-step plan-first (fresh forge).
C. Catalog rendering — pick the right entity ref from the asset menu format.
D. Section order — rules-first vs rules-last on a critical instruction.

Usage: python3 sysprompt_forge.py A|B|C|D 20
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from catalog_v2 import tool
from deepseek_client import chat_complete

MAXW = 6

# ============ A. Injected fields + tool_conventions ============
TOOL_CONVENTIONS = """## tool_conventions
Every tool call MUST include 3 standard fields alongside the tool's own args:
  summary: string — one sentence: what you're doing and why.
  destructive: bool — true if the action is irreversible (delete, overwrite, send).
  execution_group: int — tools with the same group run in parallel; different groups
    run in ascending order. Omit (or reuse a group) only when ordering doesn't matter.
"""

def field_tool():
    return [tool("delete_function",
                 "Delete a function (soft-delete).",
                 ["id", "summary", "destructive", "execution_group"],
                 {"id": {"type": "string"},
                  "summary": {"type": "string", "description": "One sentence: what you're doing and why."},
                  "destructive": {"type": "boolean"},
                  "execution_group": {"type": "integer"}})]

A_SCEN = [
    ("with_conv", "You are the Forgify chat AI.\n" + TOOL_CONVENTIONS, "删掉 function fn_old01。"),
    ("no_conv", "You are the Forgify chat AI.", "删掉 function fn_old01。"),
]

def a_check(args):
    errs = []
    if not args.get("summary"):
        errs.append("missing summary")
    if args.get("destructive") is not True:
        errs.append(f"destructive should be true for delete, got {args.get('destructive')}")
    if "execution_group" not in args:
        errs.append("missing execution_group")
    return errs

# ============ B. chainPatternsSection ============
CHAIN_SECTION = """## Multi-step Task Patterns
For tasks needing 2+ tool calls: (1) state a 1-2 line plan, (2) emit calls in order,
one per turn, (3) verify each result before the next. If a tool refuses with a
next_step, retry corrected in the same turn — don't re-search."""

def b_tools():
    return [tool(n, d, req, {p: ({"type": "object"} if p in ("args",) else {"type": "string"}) for p in req})
            for n, req, d in [
                ("search_flowruns", ["workflow_id"], "List flowruns."),
                ("query_events", ["workflow_id"], "Query events."),
                ("list_dead_letters", ["workflow_id"], "List dead letters."),
                ("replay_message", ["message_id"], "Replay a dead letter."),
            ]]

# ============ C. Catalog rendering ============
CATALOG_FLAT = "Available agents: ag_clf01, ag_sum02, ag_reply03"
CATALOG_DESC = """Available agents:
  ag_clf01   — classifies emails into invoice/inquiry/spam
  ag_sum02   — summarizes long documents
  ag_reply03 — drafts customer replies"""

def c_tools():
    return [tool("run_agent", "Run an agent by id with a payload.", ["id", "payload"],
                 {"id": {"type": "string"}, "payload": {"type": "object"}})]

# ============ D. Section order ============
RULES = "CRITICAL: never run_agent on ag_sum02 — it is deprecated and will error. Use ag_sum_v2 instead."

def run_A(reps):
    out = {}
    for label, sysp, prompt in A_SCEN:
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": sysp}, {"role": "user", "content": prompt}],
                              tools=field_tool(), scenario=f"sp-A-{label}", variant=label, max_tokens=800,
                              tool_choice="auto", disable_thinking=True)
            tc = r.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc:
                return ["no call"]
            try:
                a = json.loads(tc[0]["function"]["arguments"])
            except Exception:
                return ["malformed"]
            return a_check(a)
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        ok = sum(1 for e in rows if not e)
        out[label] = (ok, reps)
        from collections import Counter
        ec = Counter(e for r in rows for e in r)
        print(f"A injected-fields [{label}]: {ok}/{reps}  top-miss={ec.most_common(2)}", flush=True)
    return out

def run_B(reps):
    prompt = "workflow wf_x 昨天挂了几个 flowrun,查清楚原因,如果有死信就 replay 第一条。"
    for label, sysp in [("raw", "You are the Forgify chat AI."), ("plan", "You are the Forgify chat AI.\n" + CHAIN_SECTION)]:
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": sysp}, {"role": "user", "content": prompt}],
                              tools=b_tools(), scenario=f"sp-B-{label}", variant=label, max_tokens=800,
                              tool_choice="auto", disable_thinking=True)
            tc = r.raw_response["choices"][0]["message"].get("tool_calls")
            return tc[0]["function"]["name"] if tc else None
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        # good first move = search_flowruns or query_events (diagnose), not jumping to replay
        ok = sum(1 for n in rows if n in ("search_flowruns", "query_events", "list_dead_letters"))
        print(f"B chain-plan [{label}]: sensible-first {ok}/{reps}  (first tools: {set(rows)})", flush=True)

def run_C(reps):
    prompt = "跑一下那个给文档做摘要的 agent,payload 给一篇长文。"
    for label, cat in [("flat", CATALOG_FLAT), ("desc", CATALOG_DESC)]:
        sysp = "You are the Forgify chat AI.\n" + cat
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": sysp}, {"role": "user", "content": prompt}],
                              tools=c_tools(), scenario=f"sp-C-{label}", variant=label, max_tokens=600,
                              tool_choice="auto", disable_thinking=True)
            tc = r.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc:
                return None
            try:
                return json.loads(tc[0]["function"]["arguments"]).get("id")
            except Exception:
                return "malformed"
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        ok = sum(1 for x in rows if x == "ag_sum02")  # correct = the summarizer
        print(f"C catalog [{label}]: picked-correct ag_sum02 {ok}/{reps}  (picks: {set(rows)})", flush=True)

def run_D(reps):
    prompt = "用 ag_sum02 给这篇文档做个摘要。"  # asks for the DEPRECATED agent
    base = "You are the Forgify chat AI."
    for label, sysp in [("rules_first", RULES + "\n\n" + base), ("rules_last", base + "\n\n" + RULES)]:
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": sysp}, {"role": "user", "content": prompt}],
                              tools=c_tools(), scenario=f"sp-D-{label}", variant=label, max_tokens=600,
                              tool_choice="auto", disable_thinking=True)
            tc = r.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc:
                return "refused"  # good — honored the rule, didn't call
            try:
                return json.loads(tc[0]["function"]["arguments"]).get("id")
            except Exception:
                return "malformed"
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        # good = did NOT call ag_sum02 (honored the critical rule)
        ok = sum(1 for x in rows if x != "ag_sum02")
        print(f"D section-order [{label}]: honored-rule {ok}/{reps}  (ids: {set(rows)})", flush=True)


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "A"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    {"A": run_A, "B": run_B, "C": run_C, "D": run_D}[which](reps)


if __name__ == "__main__":
    main()
