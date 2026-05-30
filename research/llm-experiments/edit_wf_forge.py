"""edit_workflow stress test — the user's stated 最恶心 case.

create_workflow builds from scratch; edit_workflow MODIFIES an existing graph
(insert node mid-chain, rewire edges, change case branches, add loop-back, remove).
Multi-turn: LLM gets the current graph (canned get_workflow), then must emit edit ops
that correctly reference EXISTING node ids.

Usage: python3 edit_wf_forge.py 20
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from catalog_v2 import tool, workflow_tools, validate_workflow_ops
from deepseek_client import chat_complete

MAXW = 6
SYS = """You are an AI engineer for Forgify. Edit an existing workflow with edit_workflow(id, ops).
First call get_workflow to see the current graph, then emit edit ops referencing existing node ids."""

# Existing graph fed via canned get_workflow
EXISTING_GRAPH = {
    "data": {"id": "wf_pipe", "name": "data-pipeline", "nodes": [
        {"id": "trig", "type": "trigger", "config": {"kind": "manual"}},
        {"id": "fetch", "type": "tool", "config": {"callable": "fn_fetch", "args": {}}},
        {"id": "save", "type": "tool", "config": {"callable": "fn_save", "args": {}}},
    ], "edges": [{"from": "trig", "to": "fetch"}, {"from": "fetch", "to": "save"}]}
}

TOOLS = workflow_tools("V2-enum-types") + [
    tool("get_workflow", "Get a workflow's current graph (nodes + edges).", ["id"], {"id": {"type": "string"}})
]

SCEN = [
    {"id": "edit-insert-mid", "wf": "wf_pipe",
     "prompt": "在 wf_pipe 的 fetch 和 save 之间插入一个 agent 节点 ag_clean 清洗数据(fetch → ag_clean → save)。",
     "check": lambda ops: _has_node(ops, "agent") and _connects_to(ops, "save")},
    {"id": "edit-add-case", "wf": "wf_pipe",
     "prompt": "给 wf_pipe 加一个 case 节点 gate 在 fetch 后:payload.count>0 才走 save,否则走一个新的 approval 节点 ask 让用户确认。",
     "check": lambda ops: _has_node(ops, "case") and _has_node(ops, "approval")},
    {"id": "edit-loopback", "wf": "wf_pipe",
     "prompt": "给 wf_pipe 加重试:在 fetch 后加 case 节点 retry_gate,如果 payload.ok 为 false 就回到 fetch 重试(attempt+1),否则继续 save。",
     "check": lambda ops: _has_node(ops, "case") and _loops_to(ops, "fetch")},
    {"id": "edit-rewire", "wf": "wf_pipe",
     "prompt": "wf_pipe 改成:fetch 后先调一个新 tool 节点 validate(callable fn_validate),validate 通过再到 save。即 fetch → validate → save。",
     "check": lambda ops: _has_node(ops, "tool") and _connects_to(ops, "save")},
    {"id": "edit-remove", "wf": "wf_pipe",
     "prompt": "把 wf_pipe 里的 save 节点删掉,改成调 agent ag_report 生成报告(fetch → ag_report)。",
     "check": lambda ops: _removes(ops, "save") or _has_node(ops, "agent")},
]


def _iter_nodes(ops):
    for o in ops:
        if isinstance(o, dict) and o.get("op") == "add_node":
            yield (o.get("node") or {})

def _has_node(ops, ntype):
    return any(n.get("type") == ntype for n in _iter_nodes(ops))

def _connects_to(ops, target):
    for o in ops:
        if isinstance(o, dict) and o.get("op") == "connect" and o.get("to") == target:
            return True
    return False

def _loops_to(ops, target):
    # a case branch or connect pointing back to an existing upstream node
    for o in ops:
        if not isinstance(o, dict):
            continue
        if o.get("op") == "connect" and o.get("to") == target:
            return True
        node = o.get("node") or {}
        if node.get("type") == "case":
            for b in (node.get("config") or {}).get("branches", {}).values():
                if isinstance(b, dict) and b.get("to") == target:
                    return True
    return False

def _removes(ops, nid):
    return any(isinstance(o, dict) and o.get("op") == "remove_node" and (o.get("nodeId") == nid or (o.get("node") or {}).get("id") == nid) for o in ops)


def run_scen(scen, reps):
    def _one(i):
        try:
            msgs = [{"role": "system", "content": SYS}, {"role": "user", "content": scen["prompt"]}]
            # turn 1
            r1 = chat_complete(messages=msgs, tools=TOOLS, scenario=scen["id"], variant="edit",
                               max_tokens=8000, tool_choice="auto", disable_thinking=True)
            tc = r1.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc:
                return {"ok": False, "reason": "turn1 no call"}
            fn = tc[0]["function"]["name"]
            if fn == "edit_workflow":
                # called edit directly
                args = json.loads(tc[0]["function"]["arguments"])
            else:
                # called get_workflow (or other) → feed graph, expect edit next
                msgs.append({"role": "assistant", "content": r1.content or None, "tool_calls": tc})
                msgs.append({"role": "tool", "tool_call_id": tc[0].get("id", "x"), "content": json.dumps(EXISTING_GRAPH, ensure_ascii=False)})
                r2 = chat_complete(messages=msgs, tools=TOOLS, scenario=scen["id"], variant="edit",
                                   max_tokens=8000, tool_choice="auto", disable_thinking=True)
                tc2 = r2.raw_response["choices"][0]["message"].get("tool_calls")
                if not tc2 or tc2[0]["function"]["name"] != "edit_workflow":
                    return {"ok": False, "reason": f"turn2 called {tc2[0]['function']['name'] if tc2 else None}"}
                try:
                    args = json.loads(tc2[0]["function"]["arguments"])
                except Exception:
                    return {"ok": False, "reason": "turn2 malformed json"}
            ops = args.get("ops", [])
            v = validate_workflow_ops(ops, is_edit=True)
            if v["errors"]:
                return {"ok": False, "reason": f"invalid ops: {v['errors'][:1]}"}
            if not scen["check"](ops):
                return {"ok": False, "reason": "semantic check failed", "ops": json.dumps(ops)[:200]}
            return {"ok": True}
        except Exception as e:
            return {"ok": False, "reason": f"EXC {e}"}
    rows = []
    with ThreadPoolExecutor(max_workers=MAXW) as ex:
        for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
            rows.append(f.result())
    return rows


def main():
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    tot = [0, 0]
    for scen in SCEN:
        rows = run_scen(scen, reps)
        ok = sum(1 for r in rows if r["ok"])
        tot[0] += ok; tot[1] += len(rows)
        bad = next((r for r in rows if not r["ok"]), None)
        print(f"{scen['id']:18s} {ok}/{reps}" + (f"  e.g. {bad['reason']}" if bad else ""), flush=True)
    print(f"\nEDIT_WORKFLOW: {tot[0]}/{tot[1]} ({tot[0]*100//tot[1]}%)")


if __name__ == "__main__":
    main()
