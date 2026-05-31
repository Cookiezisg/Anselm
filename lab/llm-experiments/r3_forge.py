"""Round 3 — edit_X ops + structured-args tools (args quality, not just selection).

Entity id is GIVEN in the prompt (isolates args-quality from search-first).
All thinking-off. Validators check the structured args are correct.

Usage: python3 r3_forge.py editops 20    |    python3 r3_forge.py structargs 20
"""

from __future__ import annotations

import json
import sys
from typing import Any

from catalog_v2 import CALLABLE_RE, tool
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = "You are an AI engineer for Forgify. The entity id is given; call the right tool with correct args."

# ---------------- edit_X ops (enum-discriminated) ----------------

def _ops_schema(kinds: list[str]) -> dict:
    return {"type": "array",
            "description": f"Each op: {{op, ...}}. op ∈ {{{', '.join(kinds)}}}.",
            "items": {"type": "object", "required": ["op"],
                      "properties": {"op": {"type": "string", "enum": kinds}, "value": {}}}}

EDIT_TOOLS = [
    tool("edit_function", "Edit a function via ops.", ["id", "ops"],
         {"id": {"type": "string"}, "ops": _ops_schema(["rename", "update_code", "update_kind", "update_description"])}),
    tool("edit_handler", "Edit a handler via ops.", ["id", "ops"],
         {"id": {"type": "string"}, "ops": _ops_schema(["rename", "update_code", "update_method", "update_init_schema"])}),
    tool("edit_agent", "Edit an agent via ops.", ["id", "ops"],
         {"id": {"type": "string"}, "ops": _ops_schema(["set_prompt", "set_skill", "set_knowledge", "set_tools", "set_output_schema", "set_model"])}),
]

EDITOPS_SCEN = [
    {"id": "ef-rename", "target_tool": "edit_function", "system_prompt": SYS,
     "user_prompt": "function fn_abc01 改名叫 check_inbox。", "want_ops": {"rename"}},
    {"id": "ef-kind", "target_tool": "edit_function", "system_prompt": SYS,
     "user_prompt": "function fn_check 改成 polling 模式,30秒一次。", "want_ops": {"update_kind"}},
    {"id": "ef-multi", "target_tool": "edit_function", "system_prompt": SYS,
     "user_prompt": "function fn_xyz 一次做三件:改名 fetch_user、代码加 retry、description 改成 'Fetch user with retry'。", "want_ops": {"rename", "update_code", "update_description"}},
    {"id": "eh-method", "target_tool": "edit_handler", "system_prompt": SYS,
     "user_prompt": "handler hd_db 加一个 method 叫 count,返回行数。", "want_ops": {"update_method"}},
    {"id": "ea-prompt", "target_tool": "edit_agent", "system_prompt": SYS,
     "user_prompt": "agent ag_clf 的 prompt 改严格点,只输出三类之一。", "want_ops": {"set_prompt"}},
    {"id": "ea-tools", "target_tool": "edit_agent", "system_prompt": SYS,
     "user_prompt": "agent ag_clf 加挂一个工具:function fn_lookup。", "want_ops": {"set_tools"}},
]


def editops_validate(called, args, scen):
    if called != scen["target_tool"]:
        return False, [f"called {called!r} not {scen['target_tool']!r}"]
    if not args:
        return False, ["no args"]
    ops = args.get("ops")
    if not isinstance(ops, list) or not ops:
        return False, ["ops not a non-empty list"]
    seen = set()
    errs = []
    for i, op in enumerate(ops):
        if not isinstance(op, dict):
            errs.append(f"op[{i}] not object"); continue
        if "op" not in op and "type" in op:
            errs.append(f"op[{i}] uses 'type' not 'op'")
        seen.add(op.get("op") or op.get("type"))
    for w in scen["want_ops"]:
        if w not in seen:
            errs.append(f"missing op {w} (got {seen})")
    # agent set_tools must be valid refs
    for op in ops:
        if (op.get("op") == "set_tools"):
            v = op.get("value")
            if isinstance(v, list):
                for t in v:
                    if not CALLABLE_RE.match(str(t)):
                        errs.append(f"bad tool ref {t!r}")
    return len(errs) == 0, errs


# ---------------- structured-args tools ----------------

STRUCT_TOOLS = [
    tool("trigger_workflow", "Manually trigger a workflow at a specific trigger node with a payload.",
         ["id", "trigger_node_id"], {"id": {"type": "string"}, "trigger_node_id": {"type": "string"}, "payload": {"type": "object"}}),
    tool("call_handler", "Call a method on a handler (hd_) with args.",
         ["id", "method", "args"], {"id": {"type": "string"}, "method": {"type": "string"}, "args": {"type": "object"}}),
    tool("call_mcp_tool", "Call an MCP tool (server + tool + args).",
         ["server", "tool", "args"], {"server": {"type": "string"}, "tool": {"type": "string"}, "args": {"type": "object"}}),
    tool("run_function", "Run a function (fn_) with args.",
         ["id", "args"], {"id": {"type": "string"}, "args": {"type": "object"}}),
    tool("run_agent", "Run an agent (ag_) with a payload.",
         ["id", "payload"], {"id": {"type": "string"}, "payload": {"type": "object"}}),
    tool("update_handler_config", "Update a handler's (hd_) init config.",
         ["id", "config"], {"id": {"type": "string"}, "config": {"type": "object"}}),
    tool("replay_message", "Replay a dead-letter message by id.",
         ["message_id"], {"message_id": {"type": "string"}, "from_node": {"type": "string"}}),
]

STRUCT_SCEN = [
    {"id": "trig", "target_tool": "trigger_workflow", "system_prompt": SYS,
     "user_prompt": "手动触发 workflow wf_rep 的 manual_start 节点,payload 传 date='2026-05-29'。",
     "args_check": lambda a: a.get("trigger_node_id") == "manual_start" and "date" in json.dumps(a.get("payload", {}))},
    {"id": "callhd", "target_tool": "call_handler", "system_prompt": SYS,
     "user_prompt": "调 handler hd_db 的 query 方法,sql 参数是 'select count(*) from users'。",
     "args_check": lambda a: a.get("method") == "query" and "select" in json.dumps(a.get("args", {})).lower()},
    {"id": "callmcp", "target_tool": "call_mcp_tool", "system_prompt": SYS,
     "user_prompt": "用 mcp 的 slack 服务器 post 工具,发 'hello' 到 #general。",
     "args_check": lambda a: a.get("server") == "slack" and a.get("tool") == "post" and "general" in json.dumps(a.get("args", {}))},
    {"id": "runfn", "target_tool": "run_function", "system_prompt": SYS,
     "user_prompt": "试跑 function fn_add,a=2,b=3。",
     "args_check": lambda a: a.get("args", {}).get("a") in (2, "2") and a.get("args", {}).get("b") in (3, "3")},
    {"id": "runag", "target_tool": "run_agent", "system_prompt": SYS,
     "user_prompt": "试跑 agent ag_clf,payload 给一封邮件 text='invoice attached'。",
     "args_check": lambda a: "invoice" in json.dumps(a.get("payload", {}))},
    {"id": "updcfg", "target_tool": "update_handler_config", "system_prompt": SYS,
     "user_prompt": "更新 handler hd_db 的配置,db_url 改成 'postgres://new'。",
     "args_check": lambda a: "postgres://new" in json.dumps(a.get("config", {}))},
    {"id": "replay", "target_tool": "replay_message", "system_prompt": SYS,
     "user_prompt": "重放死信 msg_abc99。",
     "args_check": lambda a: a.get("message_id") == "msg_abc99"},
]


def struct_validate(called, args, scen):
    if called != scen["target_tool"]:
        return False, [f"called {called!r} not {scen['target_tool']!r}"]
    if not args:
        return False, ["no args"]
    try:
        if scen["args_check"](args):
            return True, []
        return False, [f"args wrong: {json.dumps(args, ensure_ascii=False)[:160]}"]
    except Exception as e:
        return False, [f"check exc {e}: {json.dumps(args, ensure_ascii=False)[:120]}"]


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "editops"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    if mode == "editops":
        tools, scens, validate = EDIT_TOOLS, EDITOPS_SCEN, editops_validate
    else:
        tools, scens, validate = STRUCT_TOOLS, STRUCT_SCEN, struct_validate
    allr = []
    for s in scens:
        rs = run_forge_cell(s, mode, tools, validate, reps=reps, disable_thinking=True)
        allr.extend(rs)
        v = sum(1 for r in rs if r.valid)
        print(f"{s['id']:12s} {v}/{reps}", flush=True)
    save_results(allr, f"r3_{mode}")
    tot = sum(1 for r in allr if r.valid)
    print(f"\nR3 {mode}: {tot}/{len(allr)} ({tot*100//len(allr)}%)")


if __name__ == "__main__":
    main()
