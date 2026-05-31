"""NEW-design tool catalog (workflow-revamp aligned, NOT old backend code).

Source of truth: documents/version-1.2/adhoc-topic-documents/workflow-revamp/00-12.

NEW design key facts:
- Workflow = 5 node types: trigger / agent / tool / case / approval (NOT old 14)
- case node = CEL expression + named branches (cyclic — can loop back)
- agent = first-class forge entity (ag_xxx), thin node wrapper (agentRef only)
- tool node = callable ref (fn_xxx / hd_xxx.method / mcp:server/tool / ag_xxx) + args
- function has kind = normal | polling
- control-flow expression language = CEL
"""

from __future__ import annotations

import json
import re
from typing import Any


def tool(name: str, description: str, required: list[str], props: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": {
                "type": "object",
                "required": required,
                "properties": props,
                "additionalProperties": False,
            },
        },
    }


# ============================================================
# Section 1: Workflow 编排 — the 最恶心 case (4 variants)
# ============================================================
# NEW design: 5 node types, case with CEL, callable refs, cyclic graph.

# Shared node-type explainer reused by richer variants.
_NODE_TYPES_TEACHING = """NODE TYPES (only these 5 exist):
  trigger  — workflow entry. config: {kind: cron|fsnotify|webhook|polling|manual, payloadSchema?}
  agent    — LLM step. config: {agentRef: "ag_xxx"}  (thin wrapper; prompt/tools live on the agent entity)
  tool     — call a forge callable. config: {callable: <ref>, args: {...}}
             callable ref: "fn_xxx" | "hd_xxx.method" | "mcp:server/tool" | "ag_xxx"
  case     — route by per-branch `when` guards. config: {branches: {<name>: {when: <bool CEL>, to: <nodeId>, emit?: {<field>: <CEL>}}}}
             First branch whose `when` is true wins; add a final branch with when:"true" as the default.
             A branch's `to` may point UPSTREAM → loop (cyclic ok). NO expression-value-to-key matching —
             you just write ONE boolean condition per branch (over payload/ctx, null-safe with has()).
  approval — wait for user yes/no. config: {prompt: <markdown>, branches: {approved:{to}, rejected:{to}}}

DATA FLOW & ROUTING (the most common mistakes — avoid ALL):
  1. ★ Each case branch has its OWN `when` boolean guard — write ONE boolean CEL per branch; the FIRST
     branch whose `when` is true wins; a final branch with when:"true" is the default. Example:
       branches: { high: {when:"payload.amount >= 1000", to:"manual"}, low: {when:"true", to:"auto"} }
     Do NOT try to match a single expression's value to branch keys — just give each branch a condition.
  2. case / approval nodes route ONLY through their `branches` (each branch's `to` IS the edge).
     NEVER also add a `connect` edge out of a case/approval node — that duplicates/contradicts the branches.
     (Plain tool/agent nodes DO use `connect` for their single outgoing edge.)
  3. A node only sees the message emitted to it from upstream. Data must be PRODUCED before it's used.
     A `cron`/`manual` trigger carries NO business data (cron emits only {firedAt}). So if the workflow
     PROCESSES data (classify emails, summarize todos, ...), the FIRST node after the trigger MUST be a
     `tool` node that FETCHES that data (e.g. fn_fetch_unread_emails) — reference such a fetch callable
     even if it must be forged. NEVER wire a cron straight into an agent/classifier (it would get an empty
     payload and cannot work). Fetch FIRST, then process.
  4. Terminal paths: a branch that ENDS the flow simply OMITS `to` (or points to an explicit end node).
     NEVER write `to: null`. Every non-terminal branch `to` must be a real node id (no dangling).
  5. approval nodes that can time out: set timeoutBehavior + a timeout branch target (don't leave it dangling).
"""

_CEL_TEACHING = """CEL expressions (case node `expression` + branch `emit`):
  - Read only `payload` and `ctx`. No side effects, no LLM calls, no HTTP.
  - Null-safe: use has(payload.user) && payload.user.email != "" before deref.
  - Examples:
      payload.category == "invoice"
      payload.attempt > 5 || payload.confidence >= 0.9
      has(payload.items) && payload.items.size() > 0
  - Retry loop with `when` branches:
      branches: {
        retry: { when: "!payload.ok && (has(payload.attempt) ? payload.attempt : 0) < 3",
                 to: call_node, emit: { attempt: "(has(payload.attempt) ? payload.attempt : 0) + 1" } },
        dead:  { when: "true", to: dead_node } }
    ⚠️ THREE things the retry branch MUST have, or the loop is broken:
      (1) the bound in the `when`: attempt < N  (N retries);
      (2) the emit incrementing attempt — WITHOUT IT the counter stays 0, `when` is always true → INFINITE LOOP;
      (3) (has(x) ? x : 0) defaulting so the FIRST failure (attempt unset) still retries.
"""

_WF_EXAMPLE = """Example (classify-and-route workflow):
  create_workflow(name="email-triage", ops=[
    {"op":"add_node","node":{"id":"t","type":"trigger","config":{"kind":"manual","payloadSchema":{"text":"string"}}}},
    {"op":"add_node","node":{"id":"clf","type":"agent","config":{"agentRef":"ag_classifier"}}},
    {"op":"add_node","node":{"id":"route","type":"case","config":{
        "expression":"payload.category",
        "branches":{
          "invoice":{"to":"handle"},
          "spam":{"to":"drop"},
          "_default":{"to":"human"}
        }}}},
    {"op":"add_node","node":{"id":"handle","type":"tool","config":{"callable":"fn_process_invoice","args":{"raw":"{{ payload.text }}"}}}},
    {"op":"connect","from":"t","to":"clf"},
    {"op":"connect","from":"clf","to":"route"}
  ])
"""


def workflow_tools(variant: str) -> list[dict[str, Any]]:
    """Return create_workflow + edit_workflow (+ split tools for V4) per variant."""
    ops_prop_generic = {
        "type": "array",
        "description": "Sequence of graph ops.",
        "items": {"type": "object"},
    }

    if variant == "V1-generic":
        desc_create = "Create a workflow by applying graph ops (add_node / connect / etc.)."
        desc_edit = "Edit a workflow by applying graph ops."
        ops_prop = ops_prop_generic

    elif variant == "V2-enum-types":
        desc_create = (
            "Create a workflow by applying graph ops.\n" + _NODE_TYPES_TEACHING
        )
        desc_edit = "Edit a workflow by applying graph ops (same op shapes as create_workflow)."
        ops_prop = {
            "type": "array",
            "description": "Graph ops. Each op.op ∈ {add_node, remove_node, connect, disconnect, update_config}.",
            "items": {
                "type": "object",
                "required": ["op"],
                "properties": {
                    "op": {"type": "string", "enum": ["add_node", "remove_node", "connect", "disconnect", "update_config"]},
                    "node": {"type": "object", "description": "for add_node: {id, type∈[trigger,agent,tool,case,approval], config}"},
                    "from": {"type": "string"},
                    "to": {"type": "string"},
                    "nodeId": {"type": "string"},
                    "config": {"type": "object"},
                },
            },
        }

    elif variant == "V3-full-teaching":
        desc_create = (
            "Create a workflow by applying graph ops.\n\n"
            + _NODE_TYPES_TEACHING + "\n" + _CEL_TEACHING + "\n" + _WF_EXAMPLE
        )
        desc_edit = "Edit a workflow by applying graph ops (same op shapes + node types + CEL rules as create_workflow)."
        ops_prop = {
            "type": "array",
            "description": "Graph ops. Each op.op ∈ {add_node, remove_node, connect, disconnect, update_config}.",
            "items": {
                "type": "object",
                "required": ["op"],
                "properties": {
                    "op": {"type": "string", "enum": ["add_node", "remove_node", "connect", "disconnect", "update_config"]},
                    "node": {"type": "object"},
                    "from": {"type": "string"},
                    "to": {"type": "string"},
                    "nodeId": {"type": "string"},
                    "config": {"type": "object"},
                },
            },
        }

    else:
        raise ValueError(f"unknown workflow variant {variant}")

    create = tool("create_workflow", desc_create, ["name", "ops"], {
        "name": {"type": "string"},
        "ops": ops_prop,
    })
    edit = tool("edit_workflow", desc_edit, ["id", "ops"], {
        "id": {"type": "string"},
        "ops": ops_prop,
    })
    return [create, edit]


def workflow_split_tools() -> list[dict[str, Any]]:
    """V4: edit_workflow split into focused tools."""
    add_node = tool(
        "add_workflow_node",
        "Add ONE node to a workflow.\n" + _NODE_TYPES_TEACHING,
        ["id", "node"],
        {"id": {"type": "string", "description": "workflow id"},
         "node": {"type": "object", "description": "{id, type∈[trigger,agent,tool,case,approval], config}"}},
    )
    connect = tool(
        "connect_workflow_nodes",
        "Connect two workflow nodes (directed edge). For case/approval source, edges are defined via the node's branches instead.",
        ["id", "from", "to"],
        {"id": {"type": "string"}, "from": {"type": "string"}, "to": {"type": "string"}},
    )
    set_case = tool(
        "set_case_branches",
        "Configure a case node's CEL expression + branches.\n" + _CEL_TEACHING,
        ["id", "nodeId", "expression", "branches"],
        {"id": {"type": "string"}, "nodeId": {"type": "string"},
         "expression": {"type": "string", "description": "CEL expression"},
         "branches": {"type": "object", "description": "{<name>: {to: <nodeId>, emit?: {<field>: <CEL>}}}"}},
    )
    return [add_node, connect, set_case]


# ============================================================
# Section 2: Agent forging (NEW first-class entity)
# ============================================================

_AGENT_TEACHING = """An agent is a forge entity = a configured LLM ReAct loop (a "worker").
Mounts (set via ops):
  prompt        — one instruction block (NOT split system/user); supports {{ payload.* }} / {{ ctx.* }}
  skill         — 0 or 1 skill name (pre-activated methodology)
  knowledge     — list of document refs (injected directly, no RAG)
  tools         — forge callables only: fn_xxx | hd_xxx.method | mcp:server/tool | ag_xxx
                  (NEVER platform tools — no fs/shell/web/memory/ask/subagent)
                  If the user wants a capability like file access / web search / notes,
                  FORGE a function for it (create_function) and mount that fn_xxx —
                  never put a bare "filesystem"/"web"/"memory" in tools.
  outputSchema  — enum | json_schema | free_text
  model         — {apiKeyId, modelId} (optional; falls back)

CRITICAL — never write a prompt that assumes a capability the agent has no tool for.
  An agent with no web/db tool CANNOT fetch live data; telling it to "look up the current rate /
  fetch the latest X" makes it HALLUCINATE. If the task needs external data, either:
    (a) take that data as a {{ payload.* }} input (the caller/upstream provides it), or
    (b) mount a forge fn that provides it (and create that fn first if it doesn't exist).
  Always reference the task's inputs via {{ payload.* }} in the prompt.
"""


def agent_tools(variant: str) -> list[dict[str, Any]]:
    ops_generic = {"type": "array", "items": {"type": "object"}}
    ops_enum = {
        "type": "array",
        "description": "Each op.op ∈ {set_meta, set_prompt, set_skill, set_knowledge, set_tools, set_output_schema, set_model}.",
        "items": {
            "type": "object",
            "required": ["op"],
            "properties": {
                "op": {"type": "string", "enum": ["set_meta", "set_prompt", "set_skill", "set_knowledge", "set_tools", "set_output_schema", "set_model"]},
                "value": {},
            },
        },
    }
    if variant == "V1-generic":
        desc = "Create a new agent (a configured LLM worker) via ops."
        ops = ops_generic
    elif variant == "V2-enum":
        desc = "Create a new agent via ops.\n" + _AGENT_TEACHING
        ops = ops_enum
    else:  # V3-full
        desc = (
            "Create a new agent (forge entity = configured LLM worker) via ops.\n\n"
            + _AGENT_TEACHING
            + "\nDO NOT mount platform tools (fs/shell/web/memory/ask/subagent) — agents are workers, not bosses.\n"
            + "DO NOT split prompt into system/user — one block only.\n\n"
            + "Example:\n"
            + '  create_agent(name="classifier", ops=[\n'
            + '    {"op":"set_prompt","value":"Classify the email in {{ payload.text }} as invoice|inquiry|spam."},\n'
            + '    {"op":"set_output_schema","value":{"kind":"enum","values":["invoice","inquiry","spam"]}},\n'
            + '    {"op":"set_tools","value":["fn_fetch_sender_history"]}\n'
            + "  ])"
        )
        ops = ops_enum
    create = tool("create_agent", desc, ["name", "ops"], {"name": {"type": "string"}, "ops": ops})
    edit = tool("edit_agent", "Edit an agent via ops (same shapes as create_agent).", ["id", "ops"],
                {"id": {"type": "string"}, "ops": ops})
    run = tool("run_agent", "Test-run an agent with a payload; returns output + tokens + latency.",
               ["id", "payload"], {"id": {"type": "string"}, "payload": {"type": "object"}})
    return [create, edit, run]


# ============================================================
# Section 3: Function with kind (NEW polling)
# ============================================================

_POLLING_TEACHING = """kind:
  normal  — on-demand callable (workflow tool node / agent tool).
  polling — system runs on an interval (requires polling_interval, e.g. "60s").
            A polling function MUST accept last_cursor and return {events: [...], next_cursor: ...}.
            Cursor pattern (copy this):
              def poll(last_cursor):
                  items = fetch_since(last_cursor)   # fetch ONLY items strictly newer than last_cursor
                  return {"events": items, "next_cursor": items[-1].ts if items else last_cursor}
            CRITICAL: emit only items strictly NEWER than last_cursor; advance next_cursor to the newest
            emitted (keep it UNCHANGED when nothing new). Two consecutive polls must never emit the same
            item twice. On the first call last_cursor is None/empty — handle that (treat as "from beginning"
            or "only from now", per the source) without crashing.
"""


def function_tools(variant: str) -> list[dict[str, Any]]:
    props = {
        "name": {"type": "string"},
        "kind": {"type": "string", "enum": ["normal", "polling"]},
        "code": {"type": "string"},
        "description": {"type": "string"},
        "polling_interval": {"type": "string", "description": "e.g. 60s; required if kind=polling"},
    }
    if variant == "V1-terse":
        desc = "Create a new function. kind = normal | polling."
    elif variant == "V3-antipattern":
        desc = ("Create a new function (stateless Python callable).\n"
                "DO NOT use for stateful classes (use create_handler).\n"
                "kind = normal | polling (polling needs polling_interval).")
    else:  # V5-combined
        desc = ("Create a new function (stateless Python callable).\n\n"
                "DO NOT use for stateful classes (use create_handler).\n\n"
                + _POLLING_TEACHING)
    return [tool("create_function", desc, ["name", "kind", "code", "description"], props)]


# ============================================================
# Section 4: Programmatic validators (no sandbox)
# ============================================================

VALID_NODE_TYPES = {"trigger", "agent", "tool", "case", "approval"}
# Entity ids may contain underscores (Forgify hex ids like fn_a3f2... AND
# human-named like fn_send_email both valid). Method/mcp parts allow word chars.
CALLABLE_RE = re.compile(r"^(fn_[a-z0-9_]+|hd_[a-z0-9_]+\.[A-Za-z_]\w*|mcp:[\w-]+/[\w-]+|ag_[a-z0-9_]+)$")


def validate_workflow_ops(ops: Any, is_edit: bool = False) -> dict[str, Any]:
    """Programmatic check of a workflow ops array. Returns {valid, errors, node_types, ...}.
    is_edit=True: editing an existing graph — the trigger already exists, so ops need not add one."""
    errors: list[str] = []
    node_types: list[str] = []
    node_ids: set[str] = set()
    callables: list[str] = []
    case_branches_seen = False
    if not isinstance(ops, list):
        return {"valid": False, "errors": ["ops not a list"], "node_types": [], "callable_refs": []}

    for i, op in enumerate(ops):
        if not isinstance(op, dict):
            errors.append(f"op[{i}] not object")
            continue
        kind = op.get("op")
        if kind == "add_node":
            node = op.get("node", {})
            nt = node.get("type")
            node_types.append(nt)
            if nt not in VALID_NODE_TYPES:
                errors.append(f"op[{i}] invalid node type: {nt!r} (only {VALID_NODE_TYPES})")
            if node.get("id"):
                node_ids.add(node["id"])
            cfg = node.get("config", {})
            if nt == "tool":
                ref = cfg.get("callable", "")
                callables.append(ref)
                if not CALLABLE_RE.match(str(ref)):
                    errors.append(f"op[{i}] invalid callable ref: {ref!r}")
            if nt == "case":
                # `when:`-branch design (validated wave-10): each branch has its own boolean guard,
                # so an expression is no longer required — branches alone suffice.
                if "expression" not in cfg and "branches" not in cfg:
                    errors.append(f"op[{i}] case node missing branches")
                if "branches" in cfg:
                    case_branches_seen = True
            if nt == "agent":
                if not str(cfg.get("agentRef", "")).startswith("ag_"):
                    errors.append(f"op[{i}] agent node bad agentRef: {cfg.get('agentRef')!r}")
        elif kind in ("connect", "disconnect"):
            if not op.get("from") or not op.get("to"):
                errors.append(f"op[{i}] {kind} missing from/to")
        elif kind in ("remove_node", "update_config"):
            pass
        elif kind is None:
            errors.append(f"op[{i}] missing 'op' key")
        # unknown op kinds tolerated (LLM might invent — counts as soft error)
    has_trigger = "trigger" in node_types
    if not is_edit and not has_trigger and any(o.get("op") == "add_node" for o in ops if isinstance(o, dict)):
        errors.append("no trigger node (every workflow needs an entry)")
    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "node_types": node_types,
        "callable_refs": callables,
        "has_trigger": has_trigger,
        "case_branches_seen": case_branches_seen,
    }


# Minimal CEL sanity check (not a full parser — catches common LLM mistakes)
_CEL_BANNED = ["import ", "lambda ", "def ", "fetch(", "http", "requests.", "os.", "eval("]


def validate_cel(expr: str) -> dict[str, Any]:
    """Heuristic CEL validity: catches obvious non-CEL / side-effect attempts."""
    errors: list[str] = []
    if not isinstance(expr, str) or not expr.strip():
        return {"valid": False, "errors": ["empty expression"]}
    for banned in _CEL_BANNED:
        if banned in expr:
            errors.append(f"contains non-CEL construct: {banned!r}")
    # balanced parens / brackets
    if expr.count("(") != expr.count(")"):
        errors.append("unbalanced parens")
    # references payload or ctx (a valid routing expr usually does)
    references_data = "payload" in expr or "ctx" in expr or expr.strip() in ("true", "false")
    return {"valid": len(errors) == 0, "errors": errors, "references_data": references_data}


def validate_callable_ref(ref: str) -> bool:
    return bool(CALLABLE_RE.match(str(ref)))
