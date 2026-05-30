"""Master experiment definitions: all scenarios + variants for 4 priorities.

Defines ~24 scenarios × ~13 variants. Programmatic over YAML for easier
maintenance + shared tool catalog.

Run all Pass 1 (default reps=10):
    python3 experiments.py pass1

Run only one priority:
    python3 experiments.py pass1 --priority lazy
    python3 experiments.py pass1 --priority tool_desc
    python3 experiments.py pass1 --priority schema
    python3 experiments.py pass1 --priority chain

Run Pass 2 deep dive (reps=30 on top variants):
    python3 experiments.py pass2

Show budget so far:
    python3 experiments.py status
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from deepseek_client import BudgetExhausted, cumulative_cost_rmb
from runner import RESULTS_DIR, run_single

MAX_PARALLEL_REPS = 5  # Concurrent reps per cell

# ====================================================================
# Section A: Shared tool catalog
# ====================================================================
# Canonical Forgify tools used across experiments. Each variant may override
# description / parameters for specific experiments.


def _tool(name: str, description: str, params_required: list[str], params: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": {
                "type": "object",
                "required": params_required,
                "properties": params,
                "additionalProperties": False,
            },
        },
    }


# -- Forge: function (5 mutate + 5 use)
T_CREATE_FUNCTION = _tool(
    "create_function",
    "Create a new Forgify function.",
    ["name", "kind", "code", "description"],
    {
        "name": {"type": "string", "description": "snake_case identifier"},
        "kind": {"type": "string", "enum": ["normal", "polling"]},
        "code": {"type": "string", "description": "Python source"},
        "description": {"type": "string"},
        "polling_interval": {"type": "string", "description": "e.g. 60s, required if kind=polling"},
    },
)

T_EDIT_FUNCTION = _tool(
    "edit_function",
    "Edit an existing function via ops array.",
    ["id", "ops"],
    {
        "id": {"type": "string", "description": "fn_xxx"},
        "ops": {"type": "array", "items": {"type": "object"}},
    },
)

T_DELETE_FUNCTION = _tool(
    "delete_function",
    "Delete a function (soft-delete).",
    ["id"],
    {"id": {"type": "string"}},
)

T_ACCEPT_FUNCTION = _tool(
    "accept_pending_function",
    "Promote pending function version to active.",
    ["id"],
    {"id": {"type": "string"}},
)

T_REVERT_FUNCTION = _tool(
    "revert_function",
    "Revert function to a prior version.",
    ["id", "target_version"],
    {"id": {"type": "string"}, "target_version": {"type": "integer"}},
)

T_GET_FUNCTION = _tool(
    "get_function",
    "Get function details (active version code + signature).",
    ["id"],
    {"id": {"type": "string"}},
)

T_RUN_FUNCTION = _tool(
    "run_function",
    "Test-run a function with given args.",
    ["id", "args"],
    {"id": {"type": "string"}, "args": {"type": "object"}},
)

T_SEARCH_FUNCTIONS = _tool(
    "search_functions",
    "Search functions by name/tag/description.",
    ["query"],
    {"query": {"type": "string"}, "kind": {"type": "string", "enum": ["normal", "polling"]}},
)

T_SEARCH_FUNCTION_EXECUTIONS = _tool(
    "search_function_executions",
    "Search past function execution records.",
    ["id"],
    {"id": {"type": "string"}, "since": {"type": "string"}},
)

T_GET_FUNCTION_EXECUTION = _tool(
    "get_function_execution",
    "Get details of a specific function execution.",
    ["execution_id"],
    {"execution_id": {"type": "string"}},
)

# -- Forge: handler (6 mutate + 5 use)
T_CREATE_HANDLER = _tool(
    "create_handler",
    "Create a new Forgify handler (stateful Python class).",
    ["name", "code", "init_schema", "methods_schema"],
    {
        "name": {"type": "string"},
        "code": {"type": "string"},
        "init_schema": {"type": "object"},
        "methods_schema": {"type": "object"},
    },
)
T_EDIT_HANDLER = _tool(
    "edit_handler",
    "Edit a handler via ops array.",
    ["id", "ops"],
    {"id": {"type": "string"}, "ops": {"type": "array"}},
)
T_DELETE_HANDLER = _tool("delete_handler", "Delete a handler.", ["id"], {"id": {"type": "string"}})
T_ACCEPT_HANDLER = _tool("accept_pending_handler", "Promote pending handler version.", ["id"], {"id": {"type": "string"}})
T_REVERT_HANDLER = _tool("revert_handler", "Revert handler.", ["id", "target_version"], {"id": {"type": "string"}, "target_version": {"type": "integer"}})
T_UPDATE_HANDLER_CONFIG = _tool(
    "update_handler_config",
    "Update handler's init args/secrets (AES-encrypted).",
    ["id", "config"],
    {"id": {"type": "string"}, "config": {"type": "object"}},
)
T_GET_HANDLER = _tool("get_handler", "Get handler class definition + schemas.", ["id"], {"id": {"type": "string"}})
T_CALL_HANDLER = _tool(
    "call_handler",
    "Test-call a handler method.",
    ["id", "method", "args"],
    {"id": {"type": "string"}, "method": {"type": "string"}, "args": {"type": "object"}},
)
T_SEARCH_HANDLERS = _tool("search_handlers", "Search handlers.", ["query"], {"query": {"type": "string"}})
T_SEARCH_HANDLER_CALLS = _tool("search_handler_calls", "Search past handler calls.", ["id"], {"id": {"type": "string"}, "since": {"type": "string"}})
T_GET_HANDLER_CALL = _tool("get_handler_call", "Get details of one handler call.", ["call_id"], {"call_id": {"type": "string"}})

# -- Forge: agent (5 mutate + 5 use)
T_CREATE_AGENT = _tool(
    "create_agent",
    "Create a new Forgify agent (LLM ReAct loop config).",
    ["name", "prompt"],
    {
        "name": {"type": "string"},
        "prompt": {"type": "string"},
        "skill": {"type": "string"},
        "knowledge": {"type": "array", "items": {"type": "string"}},
        "tools": {"type": "array", "items": {"type": "string"}},
        "model": {"type": "string"},
    },
)
T_EDIT_AGENT = _tool("edit_agent", "Edit agent via ops.", ["id", "ops"], {"id": {"type": "string"}, "ops": {"type": "array"}})
T_DELETE_AGENT = _tool("delete_agent", "Delete agent.", ["id"], {"id": {"type": "string"}})
T_ACCEPT_AGENT = _tool("accept_pending_agent", "Promote pending agent version.", ["id"], {"id": {"type": "string"}})
T_REVERT_AGENT = _tool("revert_agent", "Revert agent.", ["id", "target_version"], {"id": {"type": "string"}, "target_version": {"type": "integer"}})
T_GET_AGENT = _tool("get_agent", "Get agent config.", ["id"], {"id": {"type": "string"}})
T_RUN_AGENT = _tool("run_agent", "Test-run agent with payload.", ["id", "payload"], {"id": {"type": "string"}, "payload": {"type": "object"}})
T_SEARCH_AGENTS = _tool("search_agents", "Search agents.", ["query"], {"query": {"type": "string"}})
T_SEARCH_AGENT_EXECUTIONS = _tool("search_agent_executions", "Search agent executions.", ["id"], {"id": {"type": "string"}, "since": {"type": "string"}})
T_GET_AGENT_EXECUTION = _tool("get_agent_execution", "Get one agent execution.", ["execution_id"], {"execution_id": {"type": "string"}})

# -- Workflow (6 craft + 7 run + 8 debug)
T_CREATE_WORKFLOW = _tool(
    "create_workflow",
    "Create a new workflow (initial v1 auto-accept).",
    ["name", "graph"],
    {"name": {"type": "string"}, "graph": {"type": "object"}},
)
T_EDIT_WORKFLOW = _tool(
    "edit_workflow",
    "Edit workflow graph via ops (add_node/connect/etc.).",
    ["id", "ops"],
    {"id": {"type": "string"}, "ops": {"type": "array"}},
)
T_DELETE_WORKFLOW = _tool("delete_workflow", "Delete workflow.", ["id"], {"id": {"type": "string"}})
T_ACCEPT_WORKFLOW = _tool("accept_pending_workflow", "Promote pending workflow version.", ["id"], {"id": {"type": "string"}})
T_REVERT_WORKFLOW = _tool("revert_workflow", "Revert workflow.", ["id", "target_version"], {"id": {"type": "string"}, "target_version": {"type": "integer"}})
T_CAPABILITY_CHECK_WORKFLOW = _tool("capability_check_workflow", "Pre-validate workflow callables.", ["id"], {"id": {"type": "string"}})
T_GET_WORKFLOW = _tool("get_workflow", "Get workflow graph.", ["id"], {"id": {"type": "string"}})
T_ACTIVATE_WORKFLOW = _tool("activate_workflow", "Activate workflow (register listeners).", ["id"], {"id": {"type": "string"}})
T_DEACTIVATE_WORKFLOW = _tool("deactivate_workflow", "Deactivate workflow.", ["id"], {"id": {"type": "string"}})
T_TRIGGER_WORKFLOW = _tool(
    "trigger_workflow",
    "Manually trigger workflow at specific trigger node.",
    ["id", "trigger_node_id"],
    {"id": {"type": "string"}, "trigger_node_id": {"type": "string"}, "payload": {"type": "object"}},
)
T_SEARCH_FLOWRUNS = _tool("search_flowruns", "List flowrun history.", ["workflow_id"], {"workflow_id": {"type": "string"}, "status": {"type": "string"}, "since": {"type": "string"}})
T_GET_FLOWRUN = _tool("get_flowrun", "Get flowrun overview.", ["id"], {"id": {"type": "string"}})
T_GET_FLOWRUN_TRACE = _tool("get_flowrun_trace", "Get message causality trace.", ["id"], {"id": {"type": "string"}})
T_GET_FLOWRUN_NODES = _tool("get_flowrun_nodes", "Per-node status.", ["id"], {"id": {"type": "string"}})
T_CANCEL_FLOWRUN = _tool("cancel_flowrun", "Cancel a stuck flowrun.", ["id"], {"id": {"type": "string"}})
T_QUERY_EVENTS = _tool(
    "query_events",
    "Query event stream (handler_crash / trigger_exhausted / etc.).",
    ["workflow_id"],
    {"workflow_id": {"type": "string"}, "type": {"type": "string"}, "since": {"type": "string"}},
)
T_LIST_DEAD_LETTERS = _tool("list_dead_letters", "List dead-letter messages.", ["workflow_id"], {"workflow_id": {"type": "string"}, "since": {"type": "string"}})
T_GET_DEAD_LETTER = _tool("get_dead_letter", "Get dead-letter details (payload + ctx + stack).", ["message_id"], {"message_id": {"type": "string"}})
T_REPLAY_MESSAGE = _tool("replay_message", "Replay a dead-letter message.", ["message_id"], {"message_id": {"type": "string"}, "from_node": {"type": "string"}})
T_CLEAR_DEAD_LETTERS = _tool("clear_dead_letters", "Bulk clear dead letters.", ["workflow_id"], {"workflow_id": {"type": "string"}})
T_SEARCH_WORKFLOWS = _tool("search_workflows", "Search workflows.", ["query"], {"query": {"type": "string"}, "active": {"type": "boolean"}})

# -- MCP (4)
T_CALL_MCP_TOOL = _tool("call_mcp_tool", "Call an installed MCP tool.", ["server", "tool", "args"], {"server": {"type": "string"}, "tool": {"type": "string"}, "args": {"type": "object"}})
T_LIST_MCP_SERVERS = _tool("list_mcp_servers", "List installed MCP servers.", [], {})
T_INSTALL_MCP = _tool("install_mcp_from_registry", "Install MCP from registry.", ["server"], {"server": {"type": "string"}})
T_HEALTH_CHECK_MCP = _tool("health_check_mcp", "Health-check an MCP server.", ["server"], {"server": {"type": "string"}})
T_SEARCH_MCP_TOOLS = _tool("search_mcp_tools", "Search MCP tool catalog.", ["query"], {"query": {"type": "string"}})

# -- Document (6 + 1 search)
T_LIST_DOCUMENTS = _tool("list_documents", "List documents (with tree).", [], {"path": {"type": "string"}})
T_READ_DOCUMENT = _tool("read_document", "Read document content.", ["path"], {"path": {"type": "string"}})
T_CREATE_DOCUMENT = _tool("create_document", "Create new document.", ["path", "content"], {"path": {"type": "string"}, "content": {"type": "string"}})
T_EDIT_DOCUMENT = _tool("edit_document", "Edit document.", ["path", "content"], {"path": {"type": "string"}, "content": {"type": "string"}})
T_MOVE_DOCUMENT = _tool("move_document", "Move/rename document.", ["from_path", "to_path"], {"from_path": {"type": "string"}, "to_path": {"type": "string"}})
T_DELETE_DOCUMENT = _tool("delete_document", "Delete document.", ["path"], {"path": {"type": "string"}})
T_SEARCH_DOCUMENTS = _tool("search_documents", "Search documents.", ["query"], {"query": {"type": "string"}})

# -- Skill (3)
T_GET_SKILL = _tool("get_skill", "Get skill content.", ["name"], {"name": {"type": "string"}})
T_ACTIVATE_SKILL = _tool("activate_skill", "Activate skill for current conv.", ["name"], {"name": {"type": "string"}})
T_SEARCH_SKILLS = _tool("search_skills", "Search skills.", ["query"], {"query": {"type": "string"}})

# -- Memory (3)
T_READ_MEMORY = _tool("read_memory", "Read user memory entries.", ["query"], {"query": {"type": "string"}})
T_WRITE_MEMORY = _tool("write_memory", "Write a memory entry.", ["name", "content"], {"name": {"type": "string"}, "content": {"type": "string"}})
T_FORGET_MEMORY = _tool("forget_memory", "Forget a memory entry.", ["name"], {"name": {"type": "string"}})

# ====================================================================
# Section B: Tool groupings (for Lazy decision)
# ====================================================================

# 18-group fine split (most fine-grained baseline)
GROUPS_18: dict[str, list[dict[str, Any]]] = {
    "function-edit": [T_CREATE_FUNCTION, T_EDIT_FUNCTION, T_DELETE_FUNCTION, T_ACCEPT_FUNCTION, T_REVERT_FUNCTION],
    "function-use": [T_GET_FUNCTION, T_RUN_FUNCTION, T_SEARCH_FUNCTION_EXECUTIONS, T_GET_FUNCTION_EXECUTION],
    "handler-edit": [T_CREATE_HANDLER, T_EDIT_HANDLER, T_DELETE_HANDLER, T_ACCEPT_HANDLER, T_REVERT_HANDLER, T_UPDATE_HANDLER_CONFIG],
    "handler-use": [T_GET_HANDLER, T_CALL_HANDLER, T_SEARCH_HANDLER_CALLS, T_GET_HANDLER_CALL],
    "agent-edit": [T_CREATE_AGENT, T_EDIT_AGENT, T_DELETE_AGENT, T_ACCEPT_AGENT, T_REVERT_AGENT],
    "agent-use": [T_GET_AGENT, T_RUN_AGENT, T_SEARCH_AGENT_EXECUTIONS, T_GET_AGENT_EXECUTION],
    "workflow-craft": [T_CREATE_WORKFLOW, T_EDIT_WORKFLOW, T_DELETE_WORKFLOW, T_ACCEPT_WORKFLOW, T_REVERT_WORKFLOW, T_CAPABILITY_CHECK_WORKFLOW],
    "workflow-deploy": [T_ACTIVATE_WORKFLOW, T_DEACTIVATE_WORKFLOW, T_TRIGGER_WORKFLOW],
    "workflow-observe": [T_GET_WORKFLOW, T_SEARCH_FLOWRUNS, T_GET_FLOWRUN, T_GET_FLOWRUN_NODES],
    "workflow-debug": [T_GET_FLOWRUN_TRACE, T_CANCEL_FLOWRUN, T_QUERY_EVENTS],
    "workflow-deadletter": [T_LIST_DEAD_LETTERS, T_GET_DEAD_LETTER, T_REPLAY_MESSAGE, T_CLEAR_DEAD_LETTERS],
    "mcp-call": [T_CALL_MCP_TOOL],
    "mcp-admin": [T_LIST_MCP_SERVERS, T_INSTALL_MCP, T_HEALTH_CHECK_MCP],
    "document-tree": [T_LIST_DOCUMENTS, T_READ_DOCUMENT],
    "document-edit": [T_CREATE_DOCUMENT, T_EDIT_DOCUMENT, T_MOVE_DOCUMENT, T_DELETE_DOCUMENT],
    "skill-meta": [T_GET_SKILL, T_ACTIVATE_SKILL],
    "memory-meta": [T_READ_MEMORY, T_WRITE_MEMORY, T_FORGET_MEMORY],
    "history-trace": [],  # placeholder (already in workflow-debug)
}

# 11-group proposal (doc 12)
GROUPS_11: dict[str, list[dict[str, Any]]] = {
    "function-edit": [T_CREATE_FUNCTION, T_EDIT_FUNCTION, T_DELETE_FUNCTION, T_ACCEPT_FUNCTION, T_REVERT_FUNCTION],
    "function-use": [T_GET_FUNCTION, T_RUN_FUNCTION, T_SEARCH_FUNCTION_EXECUTIONS, T_GET_FUNCTION_EXECUTION],
    "handler-edit": [T_CREATE_HANDLER, T_EDIT_HANDLER, T_DELETE_HANDLER, T_ACCEPT_HANDLER, T_REVERT_HANDLER, T_UPDATE_HANDLER_CONFIG],
    "handler-use": [T_GET_HANDLER, T_CALL_HANDLER, T_SEARCH_HANDLER_CALLS, T_GET_HANDLER_CALL],
    "agent-edit": [T_CREATE_AGENT, T_EDIT_AGENT, T_DELETE_AGENT, T_ACCEPT_AGENT, T_REVERT_AGENT],
    "agent-use": [T_GET_AGENT, T_RUN_AGENT, T_SEARCH_AGENT_EXECUTIONS, T_GET_AGENT_EXECUTION],
    "workflow-edit": [T_CREATE_WORKFLOW, T_EDIT_WORKFLOW, T_DELETE_WORKFLOW, T_ACCEPT_WORKFLOW, T_REVERT_WORKFLOW, T_CAPABILITY_CHECK_WORKFLOW],
    "workflow-run": [T_GET_WORKFLOW, T_ACTIVATE_WORKFLOW, T_DEACTIVATE_WORKFLOW, T_TRIGGER_WORKFLOW, T_SEARCH_FLOWRUNS, T_GET_FLOWRUN, T_GET_FLOWRUN_NODES],
    "workflow-debug": [T_GET_FLOWRUN_TRACE, T_CANCEL_FLOWRUN, T_QUERY_EVENTS, T_LIST_DEAD_LETTERS, T_GET_DEAD_LETTER, T_REPLAY_MESSAGE, T_CLEAR_DEAD_LETTERS],
    "mcp": [T_CALL_MCP_TOOL, T_LIST_MCP_SERVERS, T_INSTALL_MCP, T_HEALTH_CHECK_MCP],
    "document": [T_LIST_DOCUMENTS, T_READ_DOCUMENT, T_CREATE_DOCUMENT, T_EDIT_DOCUMENT, T_MOVE_DOCUMENT, T_DELETE_DOCUMENT],
}

# 6-group current Forgify (baseline)
GROUPS_6: dict[str, list[dict[str, Any]]] = {
    "function": [T_CREATE_FUNCTION, T_EDIT_FUNCTION, T_DELETE_FUNCTION, T_ACCEPT_FUNCTION, T_REVERT_FUNCTION, T_GET_FUNCTION, T_RUN_FUNCTION, T_SEARCH_FUNCTION_EXECUTIONS, T_GET_FUNCTION_EXECUTION],
    "handler": [T_CREATE_HANDLER, T_EDIT_HANDLER, T_DELETE_HANDLER, T_ACCEPT_HANDLER, T_REVERT_HANDLER, T_UPDATE_HANDLER_CONFIG, T_GET_HANDLER, T_CALL_HANDLER, T_SEARCH_HANDLER_CALLS, T_GET_HANDLER_CALL],
    "workflow": [T_CREATE_WORKFLOW, T_EDIT_WORKFLOW, T_DELETE_WORKFLOW, T_ACCEPT_WORKFLOW, T_REVERT_WORKFLOW, T_CAPABILITY_CHECK_WORKFLOW, T_GET_WORKFLOW, T_ACTIVATE_WORKFLOW, T_DEACTIVATE_WORKFLOW, T_TRIGGER_WORKFLOW, T_SEARCH_FLOWRUNS, T_GET_FLOWRUN, T_GET_FLOWRUN_NODES, T_GET_FLOWRUN_TRACE, T_CANCEL_FLOWRUN, T_QUERY_EVENTS, T_LIST_DEAD_LETTERS, T_GET_DEAD_LETTER, T_REPLAY_MESSAGE, T_CLEAR_DEAD_LETTERS],
    "mcp": [T_CALL_MCP_TOOL, T_LIST_MCP_SERVERS, T_INSTALL_MCP, T_HEALTH_CHECK_MCP],
    "document": [T_LIST_DOCUMENTS, T_READ_DOCUMENT, T_CREATE_DOCUMENT, T_EDIT_DOCUMENT, T_MOVE_DOCUMENT, T_DELETE_DOCUMENT],
    "skill": [T_GET_SKILL, T_ACTIVATE_SKILL],
}


def _activate_tool_meta(categories: list[str]) -> dict[str, Any]:
    return _tool(
        "activate_tools",
        f"Activate a tool group for this conversation. Categories: {', '.join(categories)}.",
        ["category"],
        {"category": {"type": "string", "enum": categories}},
    )


# Resident tools (always offered)
RESIDENT = [
    T_SEARCH_FUNCTIONS, T_SEARCH_HANDLERS, T_SEARCH_AGENTS, T_SEARCH_WORKFLOWS,
    T_SEARCH_MCP_TOOLS, T_SEARCH_SKILLS, T_SEARCH_DOCUMENTS,
]


def build_lazy_offering(group_scheme: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    """For Lazy experiments: offer Resident + activate_tools(categories)."""
    return RESIDENT + [_activate_tool_meta(list(group_scheme.keys()))]


# ====================================================================
# Section C: Scenarios per priority
# ====================================================================


SYSTEM_PROMPT_BASE = """You are an AI engineer assistant for Forgify, a local-first AI workflow platform.
Forgify manages 4 forge entity types: function (Python callables), handler (stateful classes),
agent (LLM ReAct loop configs), and workflow (orchestration graphs).

You have access to tools to manage these entities. Call the appropriate tool to answer the user."""


SYSTEM_PROMPT_LAZY = SYSTEM_PROMPT_BASE + """

Most tools are organized into categories. Use `activate_tools(category=<name>)` first
to load the right category for the user's task, then call the actual tool.
For searching anything, the search_* tools are always available without activation."""


# -- Priority 1: Lazy grouping (H1) --
# 6 scenarios, each expects a specific group to be activated

LAZY_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "lazy-cron-debug",
        "priority": "lazy",
        "system_prompt": SYSTEM_PROMPT_LAZY,
        "user_prompt": "看一下昨天 cron 触发挂掉的情况,workflow id 是 wf_abc123。",
        "expected": {
            "first_tool": "activate_tools",
            "required_activations": ["workflow-debug"],  # for 11/18 schemes
            "alt_activations": {"GROUPS_6": ["workflow"]},  # baseline 6-group equivalent
        },
    },
    {
        "id": "lazy-polling-create",
        "priority": "lazy",
        "system_prompt": SYSTEM_PROMPT_LAZY,
        "user_prompt": "帮我造一个 polling function 监 Gmail 收件箱,60秒一次。",
        "expected": {
            "first_tool": "activate_tools",
            "required_activations": ["function-edit"],
            "alt_activations": {"GROUPS_6": ["function"]},
        },
    },
    {
        "id": "lazy-agent-edit",
        "priority": "lazy",
        "system_prompt": SYSTEM_PROMPT_LAZY,
        "user_prompt": "我想改一下 agent ag_classifier01 的 prompt,让它更严格一些。",
        "expected": {
            "first_tool": "activate_tools",
            "required_activations": ["agent-edit"],
            "alt_activations": {"GROUPS_6": ["function"]},  # 6 groups has no agent group
        },
    },
    {
        "id": "lazy-workflow-deploy",
        "priority": "lazy",
        "system_prompt": SYSTEM_PROMPT_LAZY,
        "user_prompt": "把这个 workflow wf_daily_report 上线,让它每天自动跑。",
        "expected": {
            "first_tool": "activate_tools",
            "required_activations": ["workflow-run"],
            "alt_activations": {"GROUPS_11": ["workflow-run"], "GROUPS_6": ["workflow"], "GROUPS_18": ["workflow-deploy"]},
        },
    },
    {
        "id": "lazy-handler-try",
        "priority": "lazy",
        "system_prompt": SYSTEM_PROMPT_LAZY,
        "user_prompt": "我想试跑一下 handler hd_oauth01 的 refresh 方法,看看能不能正常拿到 token。",
        "expected": {
            "first_tool": "activate_tools",
            "required_activations": ["handler-use"],
            "alt_activations": {"GROUPS_6": ["handler"]},
        },
    },
    {
        "id": "lazy-dead-letter",
        "priority": "lazy",
        "system_prompt": SYSTEM_PROMPT_LAZY,
        "user_prompt": "workflow wf_report 有几条死信,帮我看下并 replay 第一条。",
        "expected": {
            "first_tool": "activate_tools",
            "required_activations": ["workflow-debug"],
            "alt_activations": {"GROUPS_6": ["workflow"], "GROUPS_18": ["workflow-deadletter"]},
        },
    },
]


# -- Priority 2: Tool description (H4) --
# 6 scenarios, all target create_function, different difficulty

TOOL_DESC_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "tooldesc-easy-add",
        "priority": "tool_desc",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "帮我造一个加法函数,名字叫 add_two,输入两个数返回和。",
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "normal"},
            "must_have_fields": ["name", "code", "description"],
        },
    },
    {
        "id": "tooldesc-easy-time",
        "priority": "tool_desc",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "造一个返回当前 UTC 时间字符串的 function,名字叫 now_utc。",
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "normal"},
        },
    },
    {
        "id": "tooldesc-medium-polling-gmail",
        "priority": "tool_desc",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "我想造一个 polling function,定期检查 Gmail 收件箱有没有新邮件,每60秒一次。",
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "polling", "polling_interval": "60s"},
        },
    },
    {
        "id": "tooldesc-hard-polling-rss-cursor",
        "priority": "tool_desc",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "造一个 polling RSS function,interval 60秒,要支持 cursor 防止重复触发。订阅地址我后面会告诉你。",
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "polling", "polling_interval": "60s"},
        },
    },
    {
        "id": "tooldesc-trap-webhook",
        "priority": "tool_desc",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "我想造一个 function 处理外部 webhook 进来的 POST 请求,验证签名后落库。",
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "normal"},
        },
    },
    {
        "id": "tooldesc-medium-random",
        "priority": "tool_desc",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "造一个 function 叫 rand_int,输入 min 和 max,返回区间内的一个随机整数。",
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "normal"},
        },
    },
]


# -- Priority 3: Schema design (H7/H8) --
# 6 scenarios, target edit_function with ops

SCHEMA_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "schema-edit-rename",
        "priority": "schema",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "function fn_abc01 的名字改成 check_inbox。",
        "expected": {
            "first_tool": "edit_function",
            "args_must_include": {"id": "fn_abc01"},
        },
    },
    {
        "id": "schema-edit-code",
        "priority": "schema",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "function fn_calc01 的代码改一下,加上 try/except 包住所有除法。",
        "expected": {
            "first_tool": "edit_function",
            "args_must_include": {"id": "fn_calc01"},
        },
    },
    {
        "id": "schema-edit-kind-to-polling",
        "priority": "schema",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "function fn_check 改成 polling 模式,30秒一次。",
        "expected": {
            "first_tool": "edit_function",
            "args_must_include": {"id": "fn_check"},
        },
    },
    {
        "id": "schema-edit-multi-ops",
        "priority": "schema",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "function fn_xyz 一次性做三件事:重命名为 fetch_user,加上 retry 装饰器,把 description 改成 'Fetch user info with retry'。",
        "expected": {
            "first_tool": "edit_function",
            "args_must_include": {"id": "fn_xyz"},
        },
    },
    {
        "id": "schema-edit-bad-op",
        "priority": "schema",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "function fn_old 我想把 kind 改成 'async' 模式。",  # invalid kind
        "expected": {
            "first_tool": "edit_function",
            "args_must_include": {"id": "fn_old"},
        },
    },
    {
        "id": "schema-edit-description-only",
        "priority": "schema",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": "function fn_send_email 的 description 改成 'Send transactional email via Resend API'。",
        "expected": {
            "first_tool": "edit_function",
            "args_must_include": {"id": "fn_send_email"},
        },
    },
]


# -- Priority 4: Chain prompts (H10/H11/H12) --
# 4 scenarios, multi-step, each requires plan-then-execute

CHAIN_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "chain-polling-cursor",
        "priority": "chain",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": (
            "帮我造一个 polling function 监听 GitHub issue 评论,30秒一次,要正确支持 since cursor 防止重复触发"
            "(每次记录上一条评论的 created_at,下次从那之后查)。"
        ),
        "expected": {
            "first_tool": "create_function",
            "args_must_include": {"kind": "polling", "polling_interval": "30s"},
            "code_must_mention": ["last_cursor", "next_cursor"],  # quality check
        },
    },
    {
        "id": "chain-edit-workflow-5ops",
        "priority": "chain",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": (
            "workflow wf_report 我想做这些改动:1) 加一个 cron trigger 节点每天 9 点;"
            "2) trigger 后接一个 tool 节点调 fn_collect_metrics;3) 再接一个 case 节点判断有没有数据;"
            "4) 有数据走 agent 节点 ag_summarize 生成摘要;5) 没数据接 approval 节点请用户决定是否跳过。"
        ),
        "expected": {
            "first_tool": "edit_workflow",
            "args_must_include": {"id": "wf_report"},
        },
    },
    {
        "id": "chain-multi-step-debug",
        "priority": "chain",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": (
            "workflow wf_orders 昨天有几个 flowrun 挂了,帮我看看为啥,如果是死信导致的,把第一条 replay 一下。"
        ),
        "expected": {
            "first_tool": "search_flowruns",  # or query_events
            "args_must_include": {"workflow_id": "wf_orders"},
        },
    },
    {
        "id": "chain-cel-null-safety",
        "priority": "chain",
        "system_prompt": SYSTEM_PROMPT_BASE,
        "user_prompt": (
            "workflow wf_form 的 case 节点 case_validate 我想加个表达式:"
            "只有当 payload.user 不空、payload.user.email 不空、且 email 长度 > 5 时才往下走,"
            "其他都走 reject 分支。"
        ),
        "expected": {
            "first_tool": "edit_workflow",
            "args_must_include": {"id": "wf_form"},
        },
    },
]


ALL_SCENARIOS: dict[str, list[dict[str, Any]]] = {
    "lazy": LAZY_SCENARIOS,
    "tool_desc": TOOL_DESC_SCENARIOS,
    "schema": SCHEMA_SCENARIOS,
    "chain": CHAIN_SCENARIOS,
}


# ====================================================================
# Section D: Variants per priority
# ====================================================================

# -- Lazy variants (V1=6 / V2=11 / V3=18) --

LAZY_VARIANTS = [
    {"id": "V1-6-groups", "priority": "lazy", "scheme": "GROUPS_6"},
    {"id": "V2-11-groups", "priority": "lazy", "scheme": "GROUPS_11"},
    {"id": "V3-18-groups", "priority": "lazy", "scheme": "GROUPS_18"},
]


def lazy_tools_for_variant(variant: dict[str, Any]) -> list[dict[str, Any]]:
    scheme_name = variant["scheme"]
    scheme = {"GROUPS_6": GROUPS_6, "GROUPS_11": GROUPS_11, "GROUPS_18": GROUPS_18}[scheme_name]
    return build_lazy_offering(scheme)


# -- Tool desc variants (V1 terse / V2 verbose / V3 antipattern / V4 few-shot) --

TOOL_DESC_TEMPLATES = {
    "V1-terse": (
        "Create a new Forgify function."
    ),
    "V2-verbose-examples": (
        "Create a new Forgify function entity.\n\n"
        "A function is a stateless Python callable executed in a sandbox.\n"
        "Two kinds:\n"
        "  - normal: executed on-demand by workflow tool nodes\n"
        "  - polling: system runs it on an interval. Requires `polling_interval` (e.g. '60s').\n"
        "    Polling functions MUST accept `last_cursor` and return {events, next_cursor}.\n\n"
        "Examples:\n"
        "  create_function(name='add', kind='normal', code='def add(a,b): return a+b', description='Adds two numbers')\n"
        "  create_function(name='poll_gmail', kind='polling', polling_interval='60s',\n"
        "                  code='def poll(last_cursor): ...', description='Polls Gmail')"
    ),
    "V3-antipattern": (
        "Create a new Forgify function.\n\n"
        "DO NOT use this for stateful classes (use create_handler instead).\n"
        "DO NOT use this for workflow orchestration (use create_workflow).\n"
        "DO NOT set kind=polling without polling_interval.\n\n"
        "kind values: 'normal' (on-demand) or 'polling' (system-scheduled).\n"
    ),
    "V4-few-shot": (
        "Create a Forgify function. Examples below show all common patterns.\n\n"
        "Example 1 (minimal normal):\n"
        "  create_function(name='echo', kind='normal',\n"
        "                  code='def echo(x): return x',\n"
        "                  description='Returns input unchanged')\n\n"
        "Example 2 (polling with cursor):\n"
        "  create_function(name='poll_inbox', kind='polling', polling_interval='60s',\n"
        "                  code='def poll(last_cursor):\\n"
        "    msgs = fetch_since(last_cursor)\\n"
        "    return {\"events\": msgs, \"next_cursor\": msgs[-1].ts if msgs else last_cursor}',\n"
        "                  description='Polls inbox for new messages, cursor-based')\n\n"
        "Example 3 (normal with deps and error handling):\n"
        "  create_function(name='send_slack', kind='normal',\n"
        "                  code='import slack_sdk\\n"
        "def send(channel, text):\\n"
        "    try:\\n"
        "        client.chat_postMessage(channel=channel, text=text)\\n"
        "    except SlackApiError as e:\\n"
        "        raise',\n"
        "                  description='Send message to Slack channel')"
    ),
}

TOOL_DESC_VARIANTS = [
    {"id": "V1-terse", "priority": "tool_desc"},
    {"id": "V2-verbose-examples", "priority": "tool_desc"},
    {"id": "V3-antipattern", "priority": "tool_desc"},
    {"id": "V4-few-shot", "priority": "tool_desc"},
]


def tool_desc_tools_for_variant(variant: dict[str, Any]) -> list[dict[str, Any]]:
    """Build tools list with target create_function described per variant."""
    desc = TOOL_DESC_TEMPLATES[variant["id"]]
    custom_create = _tool(
        "create_function",
        desc,
        ["name", "kind", "code", "description"],
        T_CREATE_FUNCTION["function"]["parameters"]["properties"],
    )
    # Offer just create_function + search_functions + a few other forge tools
    # to keep context reasonable
    return [
        custom_create,
        T_SEARCH_FUNCTIONS,
        T_GET_FUNCTION,
        T_CREATE_HANDLER,  # distractor — should NOT be called
        T_SEARCH_HANDLERS,
    ]


# -- Schema variants (V1 free / V2 enum / V3 anyOf+strict) --

SCHEMA_VARIANTS = [
    {"id": "V1-free-json", "priority": "schema"},
    {"id": "V2-enum", "priority": "schema"},
    {"id": "V3-anyof-strict", "priority": "schema"},
]


def schema_tools_for_variant(variant: dict[str, Any]) -> list[dict[str, Any]]:
    """edit_function with progressively tighter schemas."""
    base_id = {"type": "string", "description": "Function ID (fn_xxx)"}
    if variant["id"] == "V1-free-json":
        ops_schema = {
            "type": "array",
            "description": "Array of edit operations. Each op is a JSON dict.",
            "items": {"type": "object"},
        }
    elif variant["id"] == "V2-enum":
        ops_schema = {
            "type": "array",
            "description": "Array of edit operations. Each op has 'type' (one of: rename, update_code, update_description, update_kind, update_polling_interval).",
            "items": {
                "type": "object",
                "required": ["type"],
                "properties": {
                    "type": {"type": "string", "enum": ["rename", "update_code", "update_description", "update_kind", "update_polling_interval"]},
                    "value": {"type": "string"},
                },
            },
        }
    else:  # V3-anyof-strict
        ops_schema = {
            "type": "array",
            "items": {
                "anyOf": [
                    {"type": "object", "required": ["type", "new_name"], "properties": {"type": {"const": "rename"}, "new_name": {"type": "string"}}},
                    {"type": "object", "required": ["type", "new_code"], "properties": {"type": {"const": "update_code"}, "new_code": {"type": "string"}}},
                    {"type": "object", "required": ["type", "new_description"], "properties": {"type": {"const": "update_description"}, "new_description": {"type": "string"}}},
                    {"type": "object", "required": ["type", "new_kind"], "properties": {"type": {"const": "update_kind"}, "new_kind": {"type": "string", "enum": ["normal", "polling"]}}},
                    {"type": "object", "required": ["type", "new_interval"], "properties": {"type": {"const": "update_polling_interval"}, "new_interval": {"type": "string"}}},
                ],
            },
        }
    custom_edit = _tool(
        "edit_function",
        "Edit an existing function via an ops array.",
        ["id", "ops"],
        {"id": base_id, "ops": ops_schema},
    )
    return [
        custom_edit,
        T_GET_FUNCTION,
        T_SEARCH_FUNCTIONS,
        T_CREATE_FUNCTION,  # distractor
    ]


# -- Chain variants (V1 raw / V2 inline plan / V3 system prompt plan + few-shot) --

CHAIN_VARIANTS = [
    {"id": "V1-raw", "priority": "chain"},
    {"id": "V2-inline-plan", "priority": "chain"},
    {"id": "V3-system-plan", "priority": "chain"},
]


CHAIN_SYSTEM_PROMPTS = {
    "V1-raw": SYSTEM_PROMPT_BASE,
    "V2-inline-plan": SYSTEM_PROMPT_BASE + "\n\nFor multi-step tasks, first emit a tool call to record your plan in the `summary` field of the first call.",
    "V3-system-plan": (
        SYSTEM_PROMPT_BASE
        + "\n\nFor any task requiring 2+ tool calls:\n"
        + "1. First, state your plan in 1-2 lines.\n"
        + "2. Then emit tool calls in execution order, one per turn.\n"
        + "3. After each tool result, briefly verify before next call.\n\n"
        + "Example: User asks 'check workflow X and replay any dead letters'.\n"
        + "  Plan: search flowruns, then query events for failures, then list dead letters, then replay first.\n"
        + "  Call 1: search_flowruns(workflow_id='X')\n"
        + "  (after result, verify there are failures, then) Call 2: list_dead_letters(workflow_id='X')\n"
        + "  Call 3: replay_message(message_id=...)"
    ),
}


def chain_tools_for_variant(variant: dict[str, Any]) -> list[dict[str, Any]]:
    # Chain experiments use full workflow tool surface
    return [
        T_CREATE_FUNCTION, T_EDIT_FUNCTION, T_GET_FUNCTION, T_RUN_FUNCTION,
        T_CREATE_WORKFLOW, T_EDIT_WORKFLOW, T_GET_WORKFLOW,
        T_SEARCH_FLOWRUNS, T_GET_FLOWRUN, T_GET_FLOWRUN_TRACE,
        T_QUERY_EVENTS, T_LIST_DEAD_LETTERS, T_GET_DEAD_LETTER, T_REPLAY_MESSAGE,
        T_SEARCH_FUNCTIONS, T_SEARCH_WORKFLOWS,
    ]


# ====================================================================
# Section E: Master run loop
# ====================================================================


def build_scenario_for_run(
    scenario: dict[str, Any], variant: dict[str, Any]
) -> dict[str, Any]:
    """Compose the final scenario dict with tools resolved per priority."""
    pri = scenario["priority"]
    out = dict(scenario)
    if pri == "lazy":
        out["tools"] = lazy_tools_for_variant(variant)
    elif pri == "tool_desc":
        out["tools"] = tool_desc_tools_for_variant(variant)
    elif pri == "schema":
        out["tools"] = schema_tools_for_variant(variant)
    elif pri == "chain":
        out["tools"] = chain_tools_for_variant(variant)
        out["system_prompt"] = CHAIN_SYSTEM_PROMPTS[variant["id"]]
    # Lazy needs scheme-specific expected mapping
    if pri == "lazy":
        scheme = variant["scheme"]
        alt = scenario["expected"].get("alt_activations", {})
        if scheme in alt:
            out["expected"] = dict(scenario["expected"])
            out["expected"]["required_activations"] = alt[scheme]
    return out


def run_all_for_priority(
    priority: str,
    reps: int = 10,
    quiet: bool = False,
    skip_existing: bool = True,
) -> dict[tuple[str, str], Path]:
    scenarios = ALL_SCENARIOS[priority]
    variants = {
        "lazy": LAZY_VARIANTS,
        "tool_desc": TOOL_DESC_VARIANTS,
        "schema": SCHEMA_VARIANTS,
        "chain": CHAIN_VARIANTS,
    }[priority]

    out_paths: dict[tuple[str, str], Path] = {}
    total_cells = len(scenarios) * len(variants)
    cell_idx = 0
    for v in variants:
        for s in scenarios:
            cell_idx += 1
            out_file = RESULTS_DIR / f"{s['id']}__{v['id']}.jsonl"
            if skip_existing and out_file.exists():
                # Count completed reps to decide if cell is "done"
                try:
                    existing = [json.loads(l) for l in out_file.read_text().splitlines() if l.strip()]
                    valid = [r for r in existing if "error" not in r]
                    if len(valid) >= reps:
                        if not quiet:
                            print(f"\n=== [{cell_idx}/{total_cells}] {priority} :: {v['id']} :: {s['id']} (SKIP — already has {len(valid)} reps) ===")
                        out_paths[(s["id"], v["id"])] = out_file
                        continue
                except (json.JSONDecodeError, OSError):
                    pass

            if not quiet:
                print(
                    f"\n=== [{cell_idx}/{total_cells}] {priority} :: {v['id']} :: {s['id']} ===",
                    flush=True,
                )
                print(f"    budget: ¥{cumulative_cost_rmb():.4f}", flush=True)
            try:
                composed = build_scenario_for_run(s, v)
                records: list[dict[str, Any]] = []
                correct = 0

                # Parallel reps within cell
                def _one(i: int) -> dict[str, Any]:
                    try:
                        rec = run_single(composed, v, rep_idx=i)
                        return rec.__dict__
                    except BudgetExhausted:
                        raise
                    except Exception as e:
                        return {
                            "rep_idx": i, "scenario_id": s["id"], "variant_id": v["id"],
                            "error": str(e), "ts": time.time(),
                        }

                try:
                    with ThreadPoolExecutor(max_workers=MAX_PARALLEL_REPS) as ex:
                        futures = [ex.submit(_one, i) for i in range(reps)]
                        for f in as_completed(futures):
                            rec = f.result()
                            records.append(rec)
                            if "error" not in rec:
                                check = rec.get("check", {})
                                if priority == "lazy":
                                    ok = check.get("activated_correct") or check.get("first_tool_correct")
                                else:
                                    ok = check.get("first_tool_correct")
                                if ok:
                                    correct += 1
                except BudgetExhausted as e:
                    print(f"BUDGET EXHAUSTED — stopping: {e}", flush=True)
                    out_file.write_text(
                        "\n".join(json.dumps(r, ensure_ascii=False) for r in records)
                    )
                    return out_paths

                # Sort by rep_idx for determinism
                records.sort(key=lambda r: r.get("rep_idx", 0))
                out_file.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records))
                out_paths[(s["id"], v["id"])] = out_file
                if not quiet:
                    print(f"    → {correct}/{reps} correct, cum ¥{cumulative_cost_rmb():.4f}", flush=True)
            except Exception as e:
                print(f"    CELL FAILED: {e}", file=sys.stderr, flush=True)
    return out_paths


def run_all_pass1(reps: int = 10, priority: str | None = None) -> None:
    priorities = [priority] if priority else list(ALL_SCENARIOS.keys())
    for p in priorities:
        print(f"\n##### Priority: {p} #####")
        run_all_for_priority(p, reps=reps)
    print(f"\n##### Pass 1 done. Total cost: ¥{cumulative_cost_rmb():.4f} #####")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["pass1", "pass2", "status"])
    ap.add_argument("--priority", choices=["lazy", "tool_desc", "schema", "chain"])
    ap.add_argument("--reps", type=int, default=10)
    args = ap.parse_args()

    if args.cmd == "status":
        print(f"Cumulative cost: ¥{cumulative_cost_rmb():.4f}")
        return 0

    if args.cmd == "pass1":
        run_all_pass1(reps=args.reps, priority=args.priority)
        return 0

    if args.cmd == "pass2":
        # Pass 2 deep dive: re-run cells where Pass 1 showed promise
        # (we'll fill this in after seeing Pass 1 results)
        print("Pass 2 not yet configured — run pass1 first")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
