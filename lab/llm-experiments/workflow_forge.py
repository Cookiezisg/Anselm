"""Workflow 编排 forging — the crown jewel surface.

Scenarios from easy (linear) to hard (full pipeline + loop-back) to trap (old node names).
Validator checks NEW-design correctness: 5 node types, callable refs, case structure,
trigger presence, loop-back edges.

Usage:
    python3 workflow_forge.py V1-generic --reps 20
    python3 workflow_forge.py V2-enum-types --reps 20
    python3 workflow_forge.py V3-full-teaching --reps 20
"""

from __future__ import annotations

import sys
from typing import Any

from catalog_v2 import validate_workflow_ops, workflow_tools, CALLABLE_RE
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = """You are an AI engineer for Forgify, a local-first AI workflow platform.
Workflows are graphs of nodes connected by edges. You build them by calling create_workflow with an ops array."""


WORKFLOW_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "wf-linear",
        "target_tool": "create_workflow",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个 workflow:手动触发,然后用 agent ag_summarize 总结,最后用 tool 调 function fn_save 保存结果。"
        ),
        "expect": {"node_types": {"trigger", "agent", "tool"}, "min_nodes": 3, "callables": ["fn_save"], "agent_refs": ["ag_summarize"]},
    },
    {
        "id": "wf-branch",
        "target_tool": "create_workflow",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个邮件分类 workflow:手动触发 → agent ag_classifier 分类(输出 invoice / inquiry / spam)→ "
            "case 节点按分类路由:invoice 走 tool 调 fn_invoice,inquiry 走 agent ag_reply,spam 直接结束。"
        ),
        "expect": {"node_types": {"trigger", "agent", "case"}, "needs_case": True, "min_nodes": 4},
    },
    {
        "id": "wf-loop",
        "target_tool": "create_workflow",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个带重试的 workflow:触发 → agent ag_solve 尝试解题 → case 判断 payload.confidence;"
            "如果低于 0.8,回到 ag_solve 重新试(把 attempt 计数 +1),否则用 tool 调 fn_publish 发布。"
        ),
        "expect": {"node_types": {"trigger", "agent", "case"}, "needs_case": True, "needs_loopback": True},
    },
    {
        "id": "wf-full",
        "target_tool": "create_workflow",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个每天早上9点的邮件简报 workflow:cron 定时触发 → tool 调 mcp:gmail/list 拉取邮件 → "
            "agent ag_summarize 总结 → case 判断有没有内容(payload.count > 0):有内容则走 approval 节点让用户确认,"
            "用户确认后用 tool 调 mcp:slack/post 发送;没内容直接结束。"
        ),
        "expect": {"node_types": {"trigger", "tool", "agent", "case", "approval"}, "needs_case": True, "callables": ["mcp:gmail/list", "mcp:slack/post"]},
    },
    {
        "id": "wf-callable-mix",
        "target_tool": "create_workflow",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个 workflow 串起 4 种 callable:手动触发 → tool 调 function fn_fetch → "
            "tool 调 handler hd_db 的 query 方法 → tool 调 agent ag_analyze → tool 调 mcp 的 slack/post。"
        ),
        "expect": {"node_types": {"trigger", "tool"}, "callables": ["fn_fetch", "hd_db.query", "ag_analyze", "mcp:slack/post"]},
    },
    {
        "id": "wf-trap-old-nodes",
        "target_tool": "create_workflow",
        "system_prompt": SYS,
        "user_prompt": (
            "造一个 workflow:触发后跑 function fn_x 处理数据,然后根据结果是否大于 100 分两路走,"
            "大于的话调 fn_high,否则调 fn_low。"
        ),
        # TRAP: user says "function" + "根据结果分两路" — old design had `function`/`condition` nodes.
        # NEW design: function → tool node (callable=fn_x); branching → case node. LLM must NOT emit
        # node type "function" or "condition".
        "expect": {"node_types": {"trigger", "tool", "case"}, "needs_case": True, "forbid_node_types": {"function", "condition", "llm"}},
    },
]


def validate(called: str | None, args: dict[str, Any] | None, scenario: dict[str, Any]) -> tuple[bool, list[str]]:
    errors: list[str] = []
    if called != scenario["target_tool"]:
        return False, [f"called {called!r} not {scenario['target_tool']!r}"]
    if not args:
        return False, ["no args"]
    ops = args.get("ops")
    if ops is None:
        return False, ["missing ops"]

    v = validate_workflow_ops(ops)
    errors.extend(v["errors"])

    exp = scenario.get("expect", {})
    seen_types = set(v["node_types"])

    # required node types present
    for nt in exp.get("node_types", set()):
        if nt not in seen_types:
            errors.append(f"missing required node type: {nt}")

    # forbidden (old-design) node types
    for nt in exp.get("forbid_node_types", set()):
        if nt in seen_types:
            errors.append(f"used FORBIDDEN old node type: {nt} (new design has only trigger/agent/tool/case/approval)")

    # case node required
    if exp.get("needs_case") and "case" not in seen_types:
        errors.append("expected a case node for branching but none found")

    # loop-back edge required
    if exp.get("needs_loopback"):
        # heuristic: a connect/case branch whose target is an earlier-declared node id
        if not _has_loopback(ops):
            errors.append("expected a loop-back edge (case branch pointing to an upstream node) but none detected")

    # expected callable refs present (substring match against all tool node callables)
    all_refs = " ".join(v["callable_refs"]) + " " + _all_case_and_config_text(ops)
    for ref in exp.get("callables", []):
        if ref not in all_refs:
            errors.append(f"expected callable ref {ref!r} not found")

    # expected agent refs
    agent_refs_text = _all_config_text(ops)
    for ar in exp.get("agent_refs", []):
        if ar not in agent_refs_text:
            errors.append(f"expected agentRef {ar!r} not found")

    if "min_nodes" in exp:
        n_nodes = sum(1 for o in ops if isinstance(o, dict) and o.get("op") == "add_node")
        if n_nodes < exp["min_nodes"]:
            errors.append(f"only {n_nodes} nodes, expected >= {exp['min_nodes']}")

    return len(errors) == 0, errors


def _node_ids_in_order(ops: list) -> list[str]:
    ids = []
    for o in ops:
        if isinstance(o, dict) and o.get("op") == "add_node":
            nid = (o.get("node") or {}).get("id")
            if nid:
                ids.append(nid)
    return ids


def _has_loopback(ops: list) -> bool:
    """Detect a case branch / edge whose target precedes its source in declaration order."""
    order = {nid: i for i, nid in enumerate(_node_ids_in_order(ops))}
    # check case node branches
    for o in ops:
        if not isinstance(o, dict):
            continue
        node = o.get("node") or {}
        if node.get("type") == "case":
            src = node.get("id")
            branches = (node.get("config") or {}).get("branches") or {}
            for b in branches.values():
                tgt = b.get("to") if isinstance(b, dict) else None
                if tgt and src in order and tgt in order and order[tgt] <= order[src]:
                    return True
        # explicit connect with backward target
        if o.get("op") == "connect":
            frm, to = o.get("from"), o.get("to")
            if frm in order and to in order and order[to] <= order[frm]:
                return True
    return False


def _all_config_text(ops: list) -> str:
    import json as _j
    return _j.dumps(ops, ensure_ascii=False)


def _all_case_and_config_text(ops: list) -> str:
    return _all_config_text(ops)


def main() -> int:
    variant = sys.argv[1] if len(sys.argv) > 1 else "V1-generic"
    reps = int(sys.argv[2].split("=")[-1]) if len(sys.argv) > 2 and "reps" in sys.argv[2] else (
        int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    tools = workflow_tools(variant)
    all_results = []
    for scen in WORKFLOW_SCENARIOS:
        print(f"\n=== {scen['id']} :: {variant} ===", flush=True)
        rs = run_forge_cell(scen, variant, tools, validate, reps=reps)
        all_results.extend(rs)
        v = sum(1 for r in rs if r.valid)
        print(f"  {v}/{len(rs)} valid", flush=True)
    save_results(all_results, f"workflow_{variant}")
    print("\n" + "=" * 60)
    print(failure_digest(all_results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
