"""Wave-2 build: tool schemas (read/edit/diagnosis/lifecycle/mcp) + per-scenario spec assembly.

The tool Descriptions here are CANDIDATE FINAL TEXT for the design spec (doc 14 §3) —
crafted per validated master findings: concise > verbose, search-first, entity-type guards,
critical-rule-last. Wave-2's multi-turn runner consumes the assembled specs.

Writes /tmp/w2_specs/<id>.json = {id, surface, system, tools, lazy, user, backend_notes,
initial_state, rubric, max_turns, code_followup?}
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import catalog_v2 as cat
from wave2_scenarios import SCENARIOS_W2

SYSTEM = """You are Forgify's chat agent — the user's personal AI automation engineer.
You forge automation entities (functions / handlers / agents) and orchestrate them into workflows.
Capabilities come ONLY from forge entities — there is no platform escape hatch.

Work like an engineer: to CHANGE an existing entity, first READ it (get_*) so you reference real ids
and don't clobber existing config; to DIAGNOSE, investigate broad→specific before concluding; forge a
missing capability before wiring it. Reference entities by their real ids (never invent one). Every tool
call includes `summary` (one sentence: what you're doing and why)."""

T = cat.tool  # (name, description, required, props)

# ---- read / version ----
def _reads():
    return {
        "search_workflows": T("search_workflows", "Find workflows by name / tag / description. Returns ids + active state. Use before editing/activating when you don't already have the id.", ["query"], {"query": {"type": "string"}, "active": {"type": "boolean", "description": "filter by active state"}}),
        "get_workflow": T("get_workflow", "Get a workflow's full graph (nodes + edges + each node's config). READ THIS before editing so your ops reference real node ids and you don't break existing structure.", ["id"], {"id": {"type": "string"}}),
        "search_agents": T("search_agents", "Find agents by name / tag / description. Returns ids.", ["query"], {"query": {"type": "string"}}),
        "get_agent": T("get_agent", "Get an agent's active config (prompt / skill / knowledge / tools / outputSchema / model). READ before editing so you preserve existing fields.", ["id"], {"id": {"type": "string"}}),
        "search_functions": T("search_functions", "Find functions by name / tag / description (kind filter optional). Returns ids. Returns empty if none exist — then you must create one.", ["query"], {"query": {"type": "string"}, "kind": {"type": "string", "enum": ["normal", "polling"]}}),
        "get_function": T("get_function", "Get a function's active version code + signature + kind. READ before editing.", ["id"], {"id": {"type": "string"}}),
    }

# ---- edit (ops) ----
def _edits():
    wf_ops = {"type": "array", "description": "Graph ops. op ∈ {add_node, remove_node, connect, disconnect, update_config}. add_node.node={id,type∈[trigger,agent,tool,case,approval],config}. case/approval route via branches, NOT connect edges.", "items": {"type": "object"}}
    ag_ops = {"type": "array", "description": "op ∈ {set_meta,set_prompt,set_skill,set_knowledge,set_tools,set_output_schema,set_model}. set_tools REPLACES the whole tools list — include existing tools you want to keep.", "items": {"type": "object"}}
    fn_ops = {"type": "array", "description": "op ∈ {update_code, update_kind, update_polling_interval, update_description}. update_code replaces the whole function body.", "items": {"type": "object"}}
    return {
        "edit_workflow": T("edit_workflow", "Edit a workflow by applying graph ops. Reference EXISTING node ids (from get_workflow). " + cat._NODE_TYPES_TEACHING, ["id", "ops"], {"id": {"type": "string"}, "ops": wf_ops}),
        "edit_agent": T("edit_agent", "Edit an agent via ops. NOTE: set_tools REPLACES the entire tools list — to ADD a tool, include the existing ones too (get_agent first). Tools are forge callables only (fn/hd/mcp), never platform tools.", ["id", "ops"], {"id": {"type": "string"}, "ops": ag_ops}),
        "edit_function": T("edit_function", "Edit a function via ops (update_code replaces the body). Preserve existing behavior unless asked to change it.", ["id", "ops"], {"id": {"type": "string"}, "ops": fn_ops}),
        "create_function": cat.function_tools("V5-combined")[0],
        "accept_pending_function": T("accept_pending_function", "Promote a function's pending version to active. Call after create/edit once you're satisfied.", ["id"], {"id": {"type": "string"}}),
    }

# ---- diagnosis / runtime ----
def _diag():
    return {
        "search_flowruns": T("search_flowruns", "List a workflow's runs (filter by status / time). Start here to see which runs failed.", ["workflowId"], {"workflowId": {"type": "string"}, "status": {"type": "string", "enum": ["running", "completed", "failed"]}, "since": {"type": "string"}}),
        "get_flowrun": T("get_flowrun", "Get one run's summary (status / which node failed / timing).", ["id"], {"id": {"type": "string"}}),
        "get_flowrun_trace": T("get_flowrun_trace", "Get the message causal chain of a run (node-by-node, with errors). Use to see WHERE and WHY a run failed.", ["id"], {"id": {"type": "string"}}),
        "query_events": T("query_events", "Query the event log for a workflow (handler_crash / message_failed / trigger_exhausted / dead_letter_created). Good for spotting recurring failure types.", ["workflowId"], {"workflowId": {"type": "string"}, "type": {"type": "string"}, "since": {"type": "string"}}),
        "list_dead_letters": T("list_dead_letters", "List dead-lettered messages (retries exhausted) for a workflow.", ["workflowId"], {"workflowId": {"type": "string"}}),
        "get_dead_letter": T("get_dead_letter", "Get a dead letter's full detail (payload + ctx + failure reason + stack). Use to root-cause.", ["messageId"], {"messageId": {"type": "string"}}),
        "replay_message": T("replay_message", "Replay a dead-lettered / failed message (re-run from its node or the whole flowrun). Only AFTER the root cause is fixed — replaying a still-broken flow just re-fails.", ["messageId"], {"messageId": {"type": "string"}, "fromNode": {"type": "string"}}),
    }

# ---- lifecycle / mcp / meta ----
def _life():
    return {
        "activate_workflow": T("activate_workflow", "Activate a workflow (register its listeners, set active=true). Fails capability_check if it references missing/incompatible callables.", ["id"], {"id": {"type": "string"}}),
        "capability_check_workflow": T("capability_check_workflow", "Pre-check a workflow before activating: verifies every callable ref exists + kinds match + payload schemas flow. Returns the first blocking problem.", ["id"], {"id": {"type": "string"}}),
        "activate_tools": T("activate_tools", "Load a lazy tool group into your available tools. Categories: function / handler / workflow / mcp / document / skill. Call this BEFORE using a tool from a group that isn't available yet. Activate ONLY the single group the immediate task needs — reason about which one (e.g. sending a Slack message → mcp). Do NOT speculatively activate multiple groups; that wastes tokens.", ["category"], {"category": {"type": "string", "enum": ["function", "handler", "workflow", "mcp", "document", "skill"]}}),
    }

def _mcp():
    return {
        "search_mcp_tools": T("search_mcp_tools", "Search installed MCP servers' tools by capability. Returns server/tool names you can then call_mcp_tool.", ["query"], {"query": {"type": "string"}}),
        "list_mcp_servers": T("list_mcp_servers", "List installed MCP servers + their tools + health.", [], {}),
        "call_mcp_tool": T("call_mcp_tool", "Call an MCP tool: server + tool + args. (mcp group must be activated first.)", ["server", "tool", "args"], {"server": {"type": "string"}, "tool": {"type": "string"}, "args": {"type": "object"}}),
    }

ALL = {**_reads(), **_edits(), **_diag(), **_life(), **_mcp()}

# Which tools each scenario offers initially; mcp gated behind activate_tools for the lazy test.
SCENARIO_TOOLS = {
    "edit_wf_add_retry": (["search_workflows", "get_workflow", "edit_workflow"], {}),
    "edit_agent_add_tool": (["search_agents", "get_agent", "edit_agent", "search_functions"], {}),
    "edit_fn_extend": (["search_functions", "get_function", "edit_function", "accept_pending_function"], {}),
    "diag_orders_crash": (["search_flowruns", "get_flowrun", "get_flowrun_trace", "query_events", "list_dead_letters", "get_dead_letter", "replay_message", "get_workflow", "edit_workflow", "get_function", "edit_function"], {}),
    "lazy_mcp_slack": (["activate_tools"], {"mcp": ["search_mcp_tools", "list_mcp_servers", "call_mcp_tool"]}),
    "cross_add_capability": (["search_functions", "create_function", "accept_pending_function", "search_agents", "get_agent", "edit_agent"], {}),
    "recover_capability_check": (["activate_workflow", "capability_check_workflow", "get_workflow", "edit_workflow", "search_functions", "create_function", "accept_pending_function"], {}),
}


def build():
    out = Path("/tmp/w2_specs")
    out.mkdir(exist_ok=True)
    for sc in SCENARIOS_W2:
        tnames, lazy = SCENARIO_TOOLS[sc["id"]]
        tools = [ALL[n] for n in tnames]
        lazy_tools = {grp: [ALL[n] for n in names] for grp, names in lazy.items()}
        spec = {
            "id": sc["id"], "surface": sc["surface"],
            "system": SYSTEM, "user": sc["user"],
            "tools": tools, "lazy": lazy_tools,
            "backend_notes": sc["backend_notes"], "initial_state": sc["initial_state"],
            "rubric": sc["rubric"], "intent": sc["intent"], "max_turns": sc.get("max_turns", 6),
        }
        if sc.get("code_followup"):
            spec["code_followup"] = True
        (out / f"{sc['id']}.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2))
    print(f"built {len(SCENARIOS_W2)} wave-2 specs in {out}/ ; tool registry has {len(ALL)} tools")
    print("tools:", sorted(ALL.keys()))


if __name__ == "__main__":
    build()
