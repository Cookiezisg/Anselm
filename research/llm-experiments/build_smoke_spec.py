"""Build a realistic create_workflow ReAct spec → /tmp/smoke_spec.json (chain smoke)."""
import json
from pathlib import Path

import catalog_v2 as cat

tools = cat.workflow_tools("V3-full-teaching")

SYSTEM = """You are Forgify's chat agent — the user's personal AI automation engineer.
You forge automation entities (functions, handlers, agents) and orchestrate them into workflows.

A workflow is a message-queue + actor graph (NOT a DAG): nodes consume a message, do work, and emit a
message downstream. There are exactly 5 node types (trigger / agent / tool / case / approval).

When the user describes an automation, DESIGN the full graph, then call create_workflow with the complete
ops array (all nodes + all edges in one call). Reference existing callables by id (fn_xxx / hd_xxx.method /
mcp:server/tool / ag_xxx); reference agents by ag_xxx. Do not invent platform tools.

Every tool call must include a `summary` (one sentence: what you're doing and why)."""

USER = ("每天早上 9 点，拉取我未读的邮件，用一个 AI 步骤把每封分类成 invoice / inquiry / spam；"
        "分类为 invoice 的交给处理函数 fn_process_invoice 处理，其余的发给我做人工审批确认。"
        "帮我把这个 workflow 建好。已有 agent ag_email_classifier 可以用来分类。")

spec = {
    "messages": [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": USER},
    ],
    "tools": tools,
    "scenario": "smoke_wf_create",
    "variant": "V3-full-teaching",
    "max_tokens": 8000,
    "disable_thinking": False,
}
Path("/tmp/smoke_spec.json").write_text(json.dumps(spec, ensure_ascii=False))
print("offered tools:", [t["function"]["name"] for t in tools])
print("spec written: /tmp/smoke_spec.json")
