"""All-tool description sweep — one canonical scenario per tool, measure first-call.

Covers the full post-revamp tool roster (Quadrinity CRUD + lifecycle + runtime +
diagnosis + mcp/skill/document/memory). Each tool: a "user wants X" prompt where
THIS tool is the correct first call. Validator = called the right tool + required args.

Surviving-old + new, all together (this is what the chat agent actually sees).

Usage: python3 tool_sweep.py 15
"""

from __future__ import annotations

import sys
from typing import Any

from catalog_v2 import tool
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = """You are the Forgify chat AI. You manage forge entities and assets.
Entity-type legend (the id prefix tells you which tool family to use):
  fn_  = function (use *_function tools)        hd_ = handler (use *_handler tools)
  ag_  = agent (use *_agent tools)              wf_ = workflow (use *_workflow tools)
  skills are by name (use *_skill tools)        memory is by name (use *_memory tools)
  mcp tools are mcp:server/tool (use *_mcp tools)
Use search_*/get_* to find an entity, then act with the tool matching its TYPE."""


# (tool_name, required_params, one-line description, canonical user prompt, must-include-arg-substr)
ROSTER: list[tuple] = [
    # --- function (read/lifecycle; create/edit covered in fnhd_forge) ---
    ("search_functions", ["query"], "Search functions by name/tag/desc.", "找一下有没有跟发邮件相关的 function。", None),
    ("get_function", ["id"], "Get a function's active code + signature.", "看一下 fn_send_email 这个 function 的代码。", "fn_send_email"),
    ("run_function", ["id", "args"], "Test-run a function.", "试跑一下 fn_add,传 a=2 b=3。", "fn_add"),
    ("accept_pending_function", ["id"], "Promote pending function version to active.", "把 fn_send_email 的待定版本接受上线。", "fn_send_email"),
    ("revert_function", ["id", "target_version"], "Revert a function to a prior version.", "把 fn_send_email 回退到第 2 版。", "fn_send_email"),
    ("delete_function", ["id"], "Delete a function.", "删掉 fn_old_unused 这个 function。", "fn_old_unused"),
    # --- handler ---
    ("search_handlers", ["query"], "Search handlers.", "找一下有没有数据库相关的 handler。", None),
    ("get_handler", ["id"], "Get a handler's class def + schemas.", "看一下 hd_db 这个 handler 的定义。", "hd_db"),
    ("call_handler", ["id", "method", "args"], "Call a method on a HANDLER (hd_ entity, stateful class). For functions (fn_) use run_function.", "调一下 hd_db 的 query 方法,sql 是 'select 1'。", "hd_db"),
    ("update_handler_config", ["id", "config"], "Update a HANDLER (hd_) init args/secrets.", "更新 hd_db 的配置,把 db_url 改成新地址。", "hd_db"),
    ("accept_pending_handler", ["id"], "Promote pending handler version.", "接受 hd_db 的待定版本。", "hd_db"),
    ("delete_handler", ["id"], "Delete a handler.", "删掉 hd_unused。", "hd_unused"),
    # --- agent (read/lifecycle; create/edit in agent_forge) ---
    ("search_agents", ["query"], "Search agents.", "找一下有没有做分类的 agent。", None),
    ("get_agent", ["id"], "Get an agent's config.", "看一下 ag_classifier 的配置。", "ag_classifier"),
    ("run_agent", ["id", "payload"], "Test-run an agent.", "试跑一下 ag_classifier,给它一封测试邮件。", "ag_classifier"),
    ("accept_pending_agent", ["id"], "Promote pending agent version.", "接受 ag_classifier 的待定版本。", "ag_classifier"),
    ("delete_agent", ["id"], "Delete an agent.", "删掉 ag_old。", "ag_old"),
    # --- workflow (read/lifecycle; create/edit in workflow_forge) ---
    ("search_workflows", ["query"], "Search workflows.", "找一下跟邮件相关的 workflow。", None),
    ("get_workflow", ["id"], "Get a workflow's graph.", "看一下 wf_report 的图结构。", "wf_report"),
    ("capability_check_workflow", ["id"], "Pre-validate a workflow's callables.", "检查一下 wf_report 引用的工具都还在不在。", "wf_report"),
    ("accept_pending_workflow", ["id"], "Promote pending workflow version.", "接受 wf_report 的待定版本。", "wf_report"),
    ("delete_workflow", ["id"], "Delete a workflow.", "删掉 wf_old。", "wf_old"),
    # --- lifecycle ---
    ("activate_workflow", ["id"], "Activate a workflow (register listeners).", "把 wf_report 上线,让它自动跑。", "wf_report"),
    ("deactivate_workflow", ["id"], "Deactivate a workflow.", "把 wf_report 下线,先别让它自动跑了。", "wf_report"),
    ("trigger_workflow", ["id", "trigger_node_id"], "Manually trigger a workflow at a node.", "手动跑一下 wf_report 的 manual_start 节点。", "wf_report"),
    # --- runtime observation ---
    ("search_flowruns", ["workflow_id"], "List flowrun history.", "看一下 wf_report 最近跑了几次。", "wf_report"),
    ("get_flowrun", ["id"], "Get a flowrun overview.", "看一下 fr_abc123 这次运行的概况。", "fr_abc123"),
    ("get_flowrun_trace", ["id"], "Get message causality trace of a flowrun.", "看一下 fr_abc123 的消息流追踪。", "fr_abc123"),
    ("get_flowrun_nodes", ["id"], "Per-node status of a flowrun.", "看一下 fr_abc123 每个节点的状态。", "fr_abc123"),
    ("cancel_flowrun", ["id"], "Cancel a stuck flowrun.", "fr_abc123 卡住了,取消它。", "fr_abc123"),
    # --- error diagnosis ---
    ("query_events", ["workflow_id"], "Query event stream (crash/exhausted/etc).", "查一下 wf_report 有没有 handler 崩溃的事件。", "wf_report"),
    ("list_dead_letters", ["workflow_id"], "List dead-letter messages.", "看一下 wf_report 有哪些死信。", "wf_report"),
    ("get_dead_letter", ["message_id"], "Get a dead-letter's detail.", "看一下死信 msg_xyz 的详情。", "msg_xyz"),
    ("replay_message", ["message_id"], "Replay a dead-letter message.", "重放一下死信 msg_xyz。", "msg_xyz"),
    ("clear_dead_letters", ["workflow_id"], "Bulk clear dead letters.", "把 wf_report 的死信全清了。", "wf_report"),
    # --- mcp ---
    ("call_mcp_tool", ["server", "tool", "args"], "Call an installed MCP tool (mcp:server/tool). Find servers via list_mcp_servers first.", "用 mcp 的 slack 服务器 post 工具发条消息到 #general。", "slack"),
    ("list_mcp_servers", [], "List installed MCP servers.", "看看装了哪些 mcp 服务器。", None),
    ("install_mcp_from_registry", ["server"], "Install an MCP from registry.", "从市场装一个 github 的 mcp 服务器。", "github"),
    ("health_check_mcp", ["server"], "Health-check an MCP server.", "检查一下 slack mcp 服务器还通不通。", "slack"),
    ("search_mcp_tools", ["query"], "Search the MCP tool catalog.", "搜一下 mcp 里有没有发 slack 消息的工具。", None),
    # --- skill ---
    ("search_skills", ["query"], "Search skills.", "找一下有没有写作相关的 skill。", None),
    ("get_skill", ["name"], "Get a skill's content.", "看一下 'invoice-extract' 这个 skill 的内容。", "invoice-extract"),
    ("activate_skill", ["name"], "Activate a skill (by name) for this conversation.", "激活 'invoice-extract' skill。", "invoice-extract"),
    # --- document ---
    ("search_documents", ["query"], "Search documents.", "搜一下文档库里有没有关于报销政策的。", None),
    ("list_documents", [], "List documents (tree).", "列一下我的文档都有哪些。", None),
    ("read_document", ["path"], "Read a document.", "读一下 /policies/refund.md 这个文档。", "refund"),
    ("create_document", ["path", "content"], "Create a document.", "新建一个文档 /notes/meeting.md,写上今天会议纪要。", "meeting"),
    ("edit_document", ["path", "content"], "Edit a document.", "把 /notes/meeting.md 文档加一段决议。", "meeting"),
    ("move_document", ["from_path", "to_path"], "Move/rename a document.", "把 /notes/meeting.md 移到 /archive/meeting.md。", "meeting"),
    ("delete_document", ["path"], "Delete a document.", "删掉 /notes/old.md。", "old"),
    # --- memory ---
    ("read_memory", ["query"], "Read user memory entries.", "看看我之前记过关于发布流程的笔记没。", None),
    ("write_memory", ["name", "content"], "Write a memory entry.", "记一下:我喜欢用 deepseek 模型。", None),
    ("forget_memory", ["name"], "Delete a memory entry (by name). Find it via read_memory first.", "把关于旧 API key 的记忆删掉。", None),
]


def build_roster_tools() -> list[dict[str, Any]]:
    """All tools as V5-combined-ish (concise action desc). create_* added from other modules' winners later."""
    tools = []
    for name, req, desc, _prompt, _arg in ROSTER:
        props = {p: ({"type": "object"} if p in ("args", "config", "payload") else {"type": "string"}) for p in req}
        if "target_version" in req:
            props["target_version"] = {"type": "integer"}
        tools.append(tool(name, desc, req, props))
    return tools


def make_validator(target: str, arg_substr: str | None):
    def validate(called, args, scenario):
        if called != target:
            return False, [f"called {called!r} not {target!r}"]
        if arg_substr:
            blob = str(args)
            if arg_substr not in blob:
                return False, [f"missing expected arg substr {arg_substr!r} in {blob[:150]}"]
        return True, []
    return validate


def main() -> int:
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    tools = build_roster_tools()
    all_results = []
    low = []
    for name, req, desc, prompt, arg in ROSTER:
        scen = {"id": f"sweep-{name}", "target_tool": name, "system_prompt": SYS, "user_prompt": prompt}
        rs = run_forge_cell(scen, "roster-v1", tools, make_validator(name, arg), reps=reps)
        all_results.extend(rs)
        v = sum(1 for r in rs if r.valid)
        flag = "" if v >= reps * 0.9 else "  <-- LOW"
        print(f"{name:32s} {v}/{reps}{flag}", flush=True)
        if v < reps * 0.9:
            low.append((name, v, reps))
    save_results(all_results, "tool_sweep")
    print("\n=== LOW (<90%, need iteration) ===")
    for name, v, r in low:
        print(f"  {name}: {v}/{r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
