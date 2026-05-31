"""The G10-COMPLIANT create_workflow tool schema — what engineers should actually ship.
Encodes all validated fixes in the SCHEMA itself:
  - case = per-branch `when:<bool CEL>` guards (not key-match)         [when: design]
  - node.config pinned PER node-type (trigger.cron, tool.{ref,args}, …) [G10]
  - ops value shape spelled out per op                                  [G10]
Used by R3-C (end-to-end all-fixes re-test) + is a deliverable artifact (paste into Parameters())."""
from __future__ import annotations

NODE_DESC = (
    "A node = {id, type, config}. type ∈ {trigger, tool, agent, case, approval}. config shape PER type:\n"
    "  trigger  → {kind:'cron'|'manual'|'webhook'|'event', cron:'<5-field expr>' (ONLY when kind=cron; key is `cron`, not schedule/expression), payloadSchema?:{...}}\n"
    "  tool     → {ref:'<fn_xxx|hd_xxx.method|mcp:server/tool>', args:{<param>:'{{payload.x}}'|literal}}\n"
    "  agent    → {ref:'ag_xxx', input?:'{{payload}}'}\n"
    "  case     → {branches:{<name>:{when:'<boolean CEL, first-true-wins>', to:'<nodeId>'}}}  (final branch when:'true' = default; null-safe via has() optional — evaluator fails-to-false)\n"
    "  approval → {prompt:'<text, {{payload.x}} ok>', branches:{approved:{to:'<id>'}, rejected:{to:'<id>'}}, timeoutSeconds?:int, onTimeout?:'approved'|'rejected'}"
)

PINNED_CREATE_WORKFLOW = {"type": "function", "function": {
    "name": "create_workflow",
    "description": ("Forge a workflow graph (message-queue + actor model). Build the COMPLETE graph in one call: "
                    "trigger → nodes → edges. Route with case nodes' per-branch `when` guards. A retry loop emits an "
                    "incremented counter on the back-edge and is bounded. Terminal nodes omit `to`."),
    "parameters": {"type": "object", "required": ["name", "ops"], "additionalProperties": False, "properties": {
        "name": {"type": "string"},
        "ops": {"type": "array", "description": (
            "Graph ops. Each op = {op, ...}. op ∈ {add_node, add_edge, set_case_branches}. "
            "add_node → {op, node:{id,type,config}} (config per type below). "
            "add_edge → {op, from:'<nodeId>', to:'<nodeId>'} (linear edges; case routing goes in the case node's branches, NOT add_edge). "
            "set_case_branches → {op, nodeId, branches:{<name>:{when,to}}}.\n" + NODE_DESC),
            "items": {"type": "object", "required": ["op"], "properties": {
                "op": {"type": "string", "enum": ["add_node", "add_edge", "set_case_branches"]},
                "node": {"type": "object", "description": "for add_node — {id, type, config (per-type shape, see ops description)}"},
                "from": {"type": "string"}, "to": {"type": "string"},
                "nodeId": {"type": "string"},
                "branches": {"type": "object", "description": "for set_case_branches — {<name>:{when:'<bool CEL>', to:'<nodeId>'}}"}}}}}}}}


def pinned_workflow_tools():
    return [PINNED_CREATE_WORKFLOW]


if __name__ == "__main__":
    import json
    print(json.dumps(PINNED_CREATE_WORKFLOW, ensure_ascii=False, indent=2))
