"""Agent forging — create_agent ops (prompt/skill/knowledge/tools/outputSchema/model).

Crown-jewel-adjacent: agent is a NEW forge entity. Key traps:
- agent CANNOT mount platform tools (fs/web/memory) — workers not bosses
- prompt is ONE block (no system/user split)
- output_schema kind ∈ {enum, json_schema, free_text}
- tools must be valid callable refs

Usage: python3 agent_forge.py V1-generic|V2-enum|V3-full 20
"""

from __future__ import annotations

import sys
from typing import Any

from catalog_v2 import CALLABLE_RE, agent_tools
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = """You are an AI engineer for Forgify. Agents are forge entities: configured LLM workers
referenced by workflows. You build them by calling create_agent with an ops array."""

VALID_OPS = {"set_meta", "set_prompt", "set_skill", "set_knowledge", "set_tools", "set_output_schema", "set_model"}
PLATFORM_TOOLS = {"filesystem", "fs", "web", "web_search", "websearch", "memory", "shell", "bash", "ask", "subagent", "read", "write", "edit"}

AGENT_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "ag-classify",
        "target_tool": "create_agent",
        "system_prompt": SYS,
        "user_prompt": "造一个 agent 把邮件分类成 invoice / inquiry / spam 三类,输出就是这三个值之一。",
        "expect": {"ops": {"set_prompt", "set_output_schema"}, "output_kind": "enum", "enum_values": {"invoice", "inquiry", "spam"}},
    },
    {
        "id": "ag-tools",
        "target_tool": "create_agent",
        "system_prompt": SYS,
        "user_prompt": "造一个 agent 总结网页内容,它需要能调 function fn_fetch_url 抓网页 和 mcp 的 gmail/list 工具。",
        "expect": {"ops": {"set_prompt", "set_tools"}, "tools_valid_refs": True},
    },
    {
        "id": "ag-knowledge",
        "target_tool": "create_agent",
        "system_prompt": SYS,
        "user_prompt": "造一个客服 agent,挂上 skill 'support-tone',再挂 3 个知识文档 doc_faq / doc_policy / doc_pricing。",
        "expect": {"ops": {"set_prompt", "set_skill", "set_knowledge"}, "single_skill": True},
    },
    {
        "id": "ag-full",
        "target_tool": "create_agent",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个发票处理 agent:prompt 说明从邮件提取发票字段;挂 skill 'invoice-extract';"
            "挂知识文档 doc_invoice_format;能调 function fn_parse_pdf 和 handler hd_erp 的 create_invoice 方法;"
            "输出结构化 JSON(amount, vendor, date);用 deepseek-v4-flash 模型。"
        ),
        "expect": {"ops": {"set_prompt", "set_skill", "set_knowledge", "set_tools", "set_output_schema"}, "tools_valid_refs": True, "single_skill": True},
    },
    {
        "id": "ag-trap-platform-tools",
        "target_tool": "create_agent",
        "system_prompt": SYS,
        "user_prompt": "造一个研究 agent,它要能读本地文件、上网搜索、还能记笔记到记忆里。",
        # TRAP: fs / web / memory are PLATFORM tools — agents (workers) can't mount them.
        # Correct behavior: forge functions for these capabilities, OR the agent refuses platform tools.
        # FAIL if set_tools contains platform tool names.
        "expect": {"ops": {"set_prompt"}, "no_platform_tools": True},
    },
]


def validate(called: str | None, args: dict[str, Any] | None, scenario: dict[str, Any]) -> tuple[bool, list[str]]:
    errors: list[str] = []
    if called != "create_agent":
        return False, [f"called {called!r} not create_agent"]
    if not args:
        return False, ["no args"]
    ops = args.get("ops")
    if not isinstance(ops, list):
        return False, ["ops not a list"]

    seen_ops: set[str] = set()
    tools_value: list = []
    skill_count = 0
    output_kind = None
    enum_values: set = set()

    for i, op in enumerate(ops):
        if not isinstance(op, dict):
            errors.append(f"op[{i}] not an object")
            continue
        opname = op.get("op") or op.get("type")  # accept both, but flag type
        if "op" not in op and "type" in op:
            errors.append(f"op[{i}] uses 'type' key not 'op'")
        if opname not in VALID_OPS:
            errors.append(f"op[{i}] unknown op {opname!r}")
            continue
        seen_ops.add(opname)
        val = op.get("value")
        if opname == "set_skill":
            skill_count += 1
        if opname == "set_tools" and isinstance(val, list):
            tools_value = val
        if opname == "set_output_schema" and isinstance(val, dict):
            output_kind = val.get("kind")
            if val.get("kind") == "enum":
                enum_values = set(val.get("values") or [])

    exp = scenario.get("expect", {})
    for needed in exp.get("ops", set()):
        if needed not in seen_ops:
            errors.append(f"missing op {needed}")

    if exp.get("output_kind") and output_kind != exp["output_kind"]:
        errors.append(f"output_schema kind {output_kind!r} != {exp['output_kind']!r}")
    if exp.get("enum_values") and not exp["enum_values"].issubset(enum_values):
        errors.append(f"enum values {enum_values} missing {exp['enum_values'] - enum_values}")

    if exp.get("tools_valid_refs"):
        for t in tools_value:
            if not isinstance(t, str) or not CALLABLE_RE.match(t):
                errors.append(f"invalid callable ref in tools: {t!r}")

    if exp.get("single_skill") and skill_count > 1:
        errors.append(f"{skill_count} set_skill ops (agent mounts exactly 1 skill)")

    if exp.get("no_platform_tools"):
        for t in tools_value:
            if isinstance(t, str) and t.lower().strip() in PLATFORM_TOOLS:
                errors.append(f"mounted PLATFORM tool {t!r} (agents are workers, can't mount fs/web/memory)")

    return len(errors) == 0, errors


def main() -> int:
    variant = sys.argv[1] if len(sys.argv) > 1 else "V1-generic"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    tools = agent_tools(variant)
    all_results = []
    for scen in AGENT_SCENARIOS:
        print(f"\n=== {scen['id']} :: {variant} ===", flush=True)
        rs = run_forge_cell(scen, variant, tools, validate, reps=reps)
        all_results.extend(rs)
        v = sum(1 for r in rs if r.valid)
        print(f"  {v}/{len(rs)} valid", flush=True)
    save_results(all_results, f"agent_{variant}")
    print("\n" + "=" * 60)
    print(failure_digest(all_results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
