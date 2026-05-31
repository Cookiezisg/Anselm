"""Callable ref forging — tool node `callable` field syntax.

4 ref kinds: fn_xxx | hd_xxx.method | mcp:server/tool | ag_xxx
Test: given NL "call X", does LLM produce the correct ref string?

Usage: python3 ref_forge.py none|table 20
"""

from __future__ import annotations

import sys
from typing import Any

from catalog_v2 import CALLABLE_RE, tool
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = """You are an AI engineer for Forgify. A workflow `tool` node calls one callable.
You configure it by calling add_tool_node with the callable ref + args."""

_REF_TABLE = """
Callable ref syntax (the `callable` field):
  function       → "fn_<id>"              e.g. fn_send_email
  handler method → "hd_<id>.<method>"     e.g. hd_db.query
  mcp tool       → "mcp:<server>/<tool>"  e.g. mcp:slack/post
  agent          → "ag_<id>"              e.g. ag_summarize
"""


def ref_tool(variant: str) -> list[dict[str, Any]]:
    desc = "Add a tool node that calls one callable."
    if variant == "table":
        desc += "\n" + _REF_TABLE
    return [tool("add_tool_node", desc, ["node_id", "callable"],
                 {"node_id": {"type": "string"},
                  "callable": {"type": "string", "description": "callable ref"},
                  "args": {"type": "object"}})]


REF_SCENARIOS: list[dict[str, Any]] = [
    {"id": "ref-function", "target_tool": "add_tool_node", "system_prompt": SYS,
     "user_prompt": "加一个 tool 节点调 function fn_send_email。", "expect": {"ref": "fn_send_email"}},
    {"id": "ref-handler", "target_tool": "add_tool_node", "system_prompt": SYS,
     "user_prompt": "加一个 tool 节点调 handler hd_db 的 query 方法。", "expect": {"ref": "hd_db.query"}},
    {"id": "ref-mcp", "target_tool": "add_tool_node", "system_prompt": SYS,
     "user_prompt": "加一个 tool 节点调 mcp 的 slack 服务器的 post 工具。", "expect": {"ref": "mcp:slack/post"}},
    {"id": "ref-agent", "target_tool": "add_tool_node", "system_prompt": SYS,
     "user_prompt": "加一个 tool 节点调 agent ag_summarize。", "expect": {"ref": "ag_summarize"}},
    {"id": "ref-handler2", "target_tool": "add_tool_node", "system_prompt": SYS,
     "user_prompt": "加一个 tool 节点调 handler hd_oauth 的 refresh_token 方法。", "expect": {"ref": "hd_oauth.refresh_token"}},
]


def validate(called: str | None, args: dict[str, Any] | None, scenario: dict[str, Any]) -> tuple[bool, list[str]]:
    if called != "add_tool_node":
        return False, [f"called {called!r} not add_tool_node"]
    if not args:
        return False, ["no args"]
    ref = args.get("callable", "")
    exp = scenario["expect"]["ref"]
    errors = []
    if not CALLABLE_RE.match(str(ref)):
        errors.append(f"ref {ref!r} fails syntax regex")
    if ref != exp:
        errors.append(f"ref {ref!r} != expected {exp!r}")
    return len(errors) == 0, errors


def main() -> int:
    variant = sys.argv[1] if len(sys.argv) > 1 else "none"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    tools = ref_tool(variant)
    all_results = []
    for scen in REF_SCENARIOS:
        print(f"\n=== {scen['id']} :: {variant} ===", flush=True)
        rs = run_forge_cell(scen, variant, tools, validate, reps=reps)
        all_results.extend(rs)
        v = sum(1 for r in rs if r.valid)
        print(f"  {v}/{len(rs)} valid", flush=True)
    save_results(all_results, f"ref_{variant}")
    print("\n" + "=" * 60)
    print(failure_digest(all_results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
