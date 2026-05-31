"""Full 91-tool catalog — candidate FINAL Description() text for the design spec (doc 14 §3).

Descriptions are crafted per validated master findings: concise > verbose, search-first,
entity-type disambiguation, when-to-use. Used by the wave-3 USAGE selection sweep (offer the
FULL set, check the model picks the right tool among ~91 — the realistic condition where the
11% content-leak / wrong-family-pick risk shows).

Forge CRUD/teaching deep text lives in catalog_v2.py + wave2_build.py; here we give every tool a
crisp selection-grade Description so the whole 91-tool set can be offered at once.
"""

from __future__ import annotations

import json
from typing import Any


def tool(name: str, desc: str, required: list[str] | None = None, props: dict | None = None) -> dict:
    return {"type": "function", "function": {
        "name": name, "description": desc,
        "parameters": {"type": "object", "required": required or [], "properties": props or {}, "additionalProperties": False},
    }}


S = {"type": "string"}
O = {"type": "object"}

# ============================================================
# FORGE CRUD — function(11) handler(12) agent(11) workflow(10)
# (create/edit deep teaching is in catalog_v2 / wave2_build; crisp here for selection)
# ============================================================
FUNCTION = [
    tool("search_functions", "Find functions by name/tag/description (optional kind filter). Returns ids. Use before get/edit when you don't have the id; returns empty if none exist.", ["query"], {"query": S, "kind": {"type": "string", "enum": ["normal", "polling"]}}),
    tool("get_function", "Get a function's active version: code + signature + kind. Read before editing.", ["id"], {"id": S}),
    tool("get_function_versions", "List a function's version history (who/when/change reason). Use to compare or pick a revert target.", ["id"], {"id": S}),
    tool("create_function", "Create a stateless Python function. kind=normal (on-demand callable) | polling (system runs on interval; must accept last_cursor, return {events,next_cursor}).", ["name", "kind", "code"], {"name": S, "kind": {"type": "string", "enum": ["normal", "polling"]}, "code": S, "polling_interval": S}),
    tool("edit_function", "Edit a function via ops (update_code replaces the body; update_kind/update_polling_interval/update_description). Preserve existing behavior unless asked.", ["id", "ops"], {"id": S, "ops": {"type": "array", "items": O}}),
    tool("accept_pending_function", "Promote a function's pending version to active. Call after create/edit once satisfied.", ["id"], {"id": S}),
    tool("revert_function", "Revert a function to a previous version (creates a new pending from it).", ["id", "targetVersion"], {"id": S, "targetVersion": S}),
    tool("delete_function", "Soft-delete a function. Fails if still referenced by a workflow/agent.", ["id"], {"id": S}),
    tool("run_function", "Test-run a function with args (polling: platform supplies a mock last_cursor). Use to verify before wiring.", ["id", "args"], {"id": S, "args": O}),
    tool("search_function_executions", "List a function's past executions (filter by time).", ["id"], {"id": S, "since": S}),
    tool("get_function_execution", "Get one function execution's detail (args, result, timing, error).", ["executionId"], {"executionId": S}),
]
HANDLER = [
    tool("search_handlers", "Find stateful handlers by name/tag/description. Returns ids.", ["query"], {"query": S}),
    tool("get_handler", "Get a handler's class definition + init schema + methods schema. Read before editing.", ["id"], {"id": S}),
    tool("get_handler_versions", "List a handler's version history.", ["id"], {"id": S}),
    tool("create_handler", "Create a stateful Python class handler (holds connections/cache/tokens). Body uses BARE-NAMED params on __init__ and each method (not a dict).", ["name", "code", "init_schema", "methods_schema"], {"name": S, "code": S, "init_schema": O, "methods_schema": O}),
    tool("edit_handler", "Edit a handler via ops (update_code / update schemas). Mind state persistence + thread safety.", ["id", "ops"], {"id": S, "ops": {"type": "array", "items": O}}),
    tool("accept_pending_handler", "Promote a handler's pending version to active.", ["id"], {"id": S}),
    tool("revert_handler", "Revert a handler to a previous version.", ["id", "targetVersion"], {"id": S, "targetVersion": S}),
    tool("delete_handler", "Soft-delete a handler (fails if referenced).", ["id"], {"id": S}),
    tool("call_handler", "Test-call one handler method (instantiates with init args, then calls). Use to verify behavior.", ["id", "method", "args"], {"id": S, "method": S, "args": O}),
    tool("update_handler_config", "Set a handler's init args / secrets (stored encrypted). Separate from code edits.", ["id", "config"], {"id": S, "config": O}),
    tool("search_handler_calls", "List a handler's past calls (filter by time).", ["id"], {"id": S, "since": S}),
    tool("get_handler_call", "Get one handler call's detail.", ["callId"], {"callId": S}),
]
AGENT = [
    tool("search_agents", "Find agents (configured LLM workers) by name/tag/description. Returns ids.", ["query"], {"query": S}),
    tool("get_agent", "Get an agent's active config: prompt / skill / knowledge / tools / outputSchema / model. Read before editing.", ["id"], {"id": S}),
    tool("get_agent_versions", "List an agent's version history.", ["id"], {"id": S}),
    tool("create_agent", "Create an agent (configured LLM worker). Mounts: prompt, skill(0-1), knowledge(docs), tools(fn/hd/mcp only — never platform tools, never another agent), outputSchema(enum|json_schema|free_text), model.", ["name", "ops"], {"name": S, "ops": {"type": "array", "items": O}}),
    tool("edit_agent", "Edit an agent via ops. set_tools REPLACES the list — include existing tools to keep them.", ["id", "ops"], {"id": S, "ops": {"type": "array", "items": O}}),
    tool("accept_pending_agent", "Promote an agent's pending version to active.", ["id"], {"id": S}),
    tool("revert_agent", "Revert an agent to a previous version.", ["id", "targetVersion"], {"id": S, "targetVersion": S}),
    tool("delete_agent", "Soft-delete an agent (fails if referenced).", ["id"], {"id": S}),
    tool("run_agent", "Test-run an agent with a payload; returns output + tokens + latency. Verify before wiring.", ["id", "payload"], {"id": S, "payload": O}),
    tool("search_agent_executions", "List an agent's past runs.", ["id"], {"id": S, "since": S}),
    tool("get_agent_execution", "Get one agent run's detail (prompt, tool-call chain, output).", ["executionId"], {"executionId": S}),
]
WORKFLOW = [
    tool("search_workflows", "Find workflows by name/tag/description (optional active filter). Returns ids + active state.", ["query"], {"query": S, "active": {"type": "boolean"}}),
    tool("get_workflow", "Get a workflow's full graph (nodes + edges + each node config). Read before editing.", ["id"], {"id": S}),
    tool("get_workflow_versions", "List a workflow's version history.", ["id"], {"id": S}),
    tool("create_workflow", "Create a workflow graph (5 node types: trigger/agent/tool/case/approval) via ops. Initial version auto-accepts.", ["name", "ops"], {"name": S, "ops": {"type": "array", "items": O}}),
    tool("edit_workflow", "Edit a workflow graph via ops (add_node/remove_node/connect/disconnect/update_config). Reference existing node ids.", ["id", "ops"], {"id": S, "ops": {"type": "array", "items": O}}),
    tool("accept_pending_workflow", "Promote a workflow's pending version to active.", ["id"], {"id": S}),
    tool("revert_workflow", "Revert a workflow to a previous version.", ["id", "targetVersion"], {"id": S, "targetVersion": S}),
    tool("delete_workflow", "Soft-delete a workflow.", ["id"], {"id": S}),
    tool("capability_check_workflow", "Pre-check a workflow before activating: every callable ref exists + kinds match + payload schemas flow. Returns first blocking problem.", ["id"], {"id": S}),
]
# ============================================================
# LIFECYCLE(3) RUNTIME(5) DIAGNOSIS(5)
# ============================================================
LIFECYCLE = [
    tool("activate_workflow", "Activate a workflow: register its triggers/listeners, set active=true. Fails capability_check if it references missing callables.", ["id"], {"id": S}),
    tool("deactivate_workflow", "Deactivate a workflow: remove listeners, destroy owner=workflow instances, set active=false.", ["id"], {"id": S}),
    tool("trigger_workflow", "Fire a workflow from a specific trigger node with a payload. Use for manual nodes (product) or to test-fire a cron/webhook node (debug).", ["id", "triggerNodeId", "payload"], {"id": S, "triggerNodeId": S, "payload": O}),
]
RUNTIME = [
    tool("search_flowruns", "List a workflow's runs (filter status/time). Start here to find failed runs.", ["workflowId"], {"workflowId": S, "status": {"type": "string", "enum": ["running", "completed", "failed"]}, "since": S}),
    tool("get_flowrun", "Get one run's summary (status / which node failed / timing).", ["id"], {"id": S}),
    tool("get_flowrun_trace", "Get a run's message causal chain (node-by-node, with errors). Use to see WHERE/WHY it failed.", ["id"], {"id": S}),
    tool("get_flowrun_nodes", "Get per-node state of a run (running/completed/failed/approval-pending).", ["id"], {"id": S}),
    tool("cancel_flowrun", "Cancel a stuck/running flowrun.", ["id"], {"id": S}),
]
DIAGNOSIS = [
    tool("query_events", "Query a workflow's event log (handler_crash / message_failed / trigger_exhausted / dead_letter_created). Spot recurring failure types.", ["workflowId"], {"workflowId": S, "type": S, "since": S}),
    tool("list_dead_letters", "List dead-lettered messages (retries exhausted) for a workflow.", ["workflowId"], {"workflowId": S}),
    tool("get_dead_letter", "Get a dead letter's detail (payload + ctx + failure reason + stack). Root-cause here.", ["messageId"], {"messageId": S}),
    tool("replay_message", "Replay a dead-lettered/failed message (from its node or whole run). ONLY after the root cause is fixed.", ["messageId"], {"messageId": S, "fromNode": S}),
    tool("clear_dead_letters", "Bulk-clear a workflow's dead letters (after handling them).", ["workflowId"], {"workflowId": S}),
]
# ============================================================
# ASSET — mcp(5) skill(3) document(7) memory(3)
# ============================================================
MCP = [
    tool("search_mcp_tools", "Search installed MCP servers' tools by capability. Returns server/tool names.", ["query"], {"query": S}),
    tool("call_mcp_tool", "Call an MCP tool (server + tool + args). The mcp group must be activated first.", ["server", "tool", "args"], {"server": S, "tool": S, "args": O}),
    tool("list_mcp_servers", "List installed MCP servers + their tools + health.", [], {}),
    tool("install_mcp_from_registry", "Install an MCP server from the registry by name. Use when a needed integration isn't installed yet.", ["name"], {"name": S}),
    tool("health_check_mcp", "Check one MCP server's health/connectivity.", ["server"], {"server": S}),
]
SKILL = [
    tool("search_skills", "Find skills (reusable methodologies) by name/description.", ["query"], {"query": S}),
    tool("get_skill", "Read a skill's full content/instructions.", ["name"], {"name": S}),
    tool("activate_skill", "Activate a skill into the current conversation (loads its methodology). For chat use; agents pin a skill on the entity instead.", ["name"], {"name": S}),
]
DOCUMENT = [
    tool("search_documents", "Find documents by content/title/tag. Returns ids.", ["query"], {"query": S}),
    tool("list_documents", "List documents in a folder/path.", [], {"path": S}),
    tool("read_document", "Read a document's full content.", ["id"], {"id": S}),
    tool("create_document", "Create a knowledge document (markdown). Use for notes/knowledge an agent can mount, NOT for code (forge a function/handler).", ["title", "content"], {"title": S, "content": S, "path": S}),
    tool("edit_document", "Edit a document's content.", ["id", "content"], {"id": S, "content": S}),
    tool("move_document", "Move/rename a document.", ["id", "path"], {"id": S, "path": S}),
    tool("delete_document", "Soft-delete a document.", ["id"], {"id": S}),
]
MEMORY = [
    tool("read_memory", "Read long-term memory entries matching a query (cross-conversation facts the chat boss remembers).", ["query"], {"query": S}),
    tool("write_memory", "Save a durable fact/preference to long-term memory. Use for things to remember across conversations, NOT transient task state.", ["name", "content"], {"name": S, "content": S}),
    tool("forget_memory", "Delete a long-term memory entry.", ["name"], {"name": S}),
]
# ============================================================
# MAIN-CHAT BASE — file(5) shell(3) web(2) task(4) interaction(2) meta(1)
# (existing/shared tools; offered to the chat boss — NOT mountable on agents)
# ============================================================
BASE = [
    tool("Read", "Read a local file from disk. For the user's own files — NOT for Forgify entities (use get_function/get_workflow/read_document).", ["file_path"], {"file_path": S}),
    tool("Write", "Write/overwrite a local file on disk.", ["file_path", "content"], {"file_path": S, "content": S}),
    tool("Edit", "Edit a local file by string replacement.", ["file_path", "old_string", "new_string"], {"file_path": S, "old_string": S, "new_string": S}),
    tool("Glob", "Find files by glob pattern.", ["pattern"], {"pattern": S}),
    tool("Grep", "Search file contents by regex.", ["pattern"], {"pattern": S, "path": S}),
    tool("Bash", "Run a shell command on the user's machine. For local system tasks — to give a workflow shell capability, forge a function instead.", ["command"], {"command": S}),
    tool("BashOutput", "Get output from a running background shell.", ["bash_id"], {"bash_id": S}),
    tool("KillShell", "Kill a background shell.", ["shell_id"], {"shell_id": S}),
    tool("WebFetch", "Fetch + extract content from a URL. For the chat boss's research — to give a workflow web access, forge a function.", ["url"], {"url": S}),
    tool("WebSearch", "Search the web. For the chat boss's research.", ["query"], {"query": S}),
    tool("TodoCreate", "Create a todo to track multi-step work in THIS conversation.", ["items"], {"items": {"type": "array", "items": S}}),
    tool("TodoList", "List this conversation's todos.", [], {}),
    tool("TodoGet", "Get one todo's detail.", ["id"], {"id": S}),
    tool("TodoUpdate", "Update a todo's status.", ["id", "status"], {"id": S, "status": S}),
    tool("AskUserQuestion", "Ask the user a clarifying question when genuinely blocked on a decision only they can make. Don't ask what you can decide or look up.", ["question"], {"question": S}),
    tool("Subagent", "Spawn a subagent for a parallel/independent exploration. Chat-boss only.", ["prompt"], {"prompt": S}),
    tool("activate_tools", "Load a lazy tool group (function/handler/workflow/mcp/document/skill) into your available tools. Activate ONLY the group the immediate task needs; don't speculatively activate several.", ["category"], {"category": {"type": "string", "enum": ["function", "handler", "workflow", "mcp", "document", "skill"]}}),
]

FAMILIES = {
    "function": FUNCTION, "handler": HANDLER, "agent": AGENT, "workflow": WORKFLOW,
    "lifecycle": LIFECYCLE, "runtime": RUNTIME, "diagnosis": DIAGNOSIS,
    "mcp": MCP, "skill": SKILL, "document": DOCUMENT, "memory": MEMORY, "base": BASE,
}
ALL_TOOLS = [t for fam in FAMILIES.values() for t in fam]
BY_NAME = {t["function"]["name"]: t for t in ALL_TOOLS}


def count() -> dict:
    c = {k: len(v) for k, v in FAMILIES.items()}
    c["TOTAL"] = len(ALL_TOOLS)
    return c


if __name__ == "__main__":
    print(json.dumps(count(), indent=1))
    assert len(ALL_TOOLS) == len(BY_NAME), "duplicate tool name!"
    print("unique names:", len(BY_NAME))
