"""CEL case-expression forging — case node routing logic.

CEL is NOT in LLM mainstream training. Key traps:
- null-safety: must has() before accessing nested fields
- case is a router/dealer, NOT an analyst — can't do sentiment/compute
- loop: emit attempt+1 on retry branch

Usage: python3 cel_forge.py none|table|full 20
"""

from __future__ import annotations

import sys
from typing import Any

from catalog_v2 import tool, validate_cel
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = """You are an AI engineer for Forgify. A workflow `case` node routes messages by
evaluating a CEL (Common Expression Language) expression and emitting to a named branch.
You configure it by calling configure_case."""

_CEL_TABLE = """
CEL quick reference:
  payload.x        field access      ctx.triggerKind   metadata
  has(payload.x)   presence check    x.size()          length of string/list
  &&  ||  !        boolean           ==  !=  <  >  <=  >=   compare
  x in [a,b]       membership        "s" in x          substring/contains
Branches: each branch has {to: "<nodeId>", emit?: {<field>: <expr>}}.
"""

_CEL_FULL = _CEL_TABLE + """
NULL-SAFETY (critical — unguarded nested access errors at runtime):
  BAD :  payload.user.email.size() > 5
  GOOD:  has(payload.user) && has(payload.user.email) && payload.user.email.size() > 5

BOUNDARY: case is a dealer, not an analyst. It ROUTES on data already present.
  It CANNOT analyze/compute (no sentiment, no summarization). If routing needs
  analysis, that must be done by an upstream agent node first; case only reads its output.

LOOP: a branch `to` may point upstream. On a retry branch, emit the incremented counter:
  {to: "solve", emit: {attempt: "payload.attempt + 1"}}
"""


def cel_tool(variant: str) -> list[dict[str, Any]]:
    if variant == "none":
        desc = "Configure a case node with a CEL expression and named branches."
    elif variant == "table":
        desc = "Configure a case node (CEL routing).\n" + _CEL_TABLE
    else:  # full
        desc = "Configure a case node (CEL routing).\n" + _CEL_FULL
    return [tool(
        "configure_case",
        desc,
        ["node_id", "expression", "branches"],
        {
            "node_id": {"type": "string"},
            "expression": {"type": "string", "description": "CEL expression"},
            "branches": {"type": "object", "description": "{branchName: {to, emit?}}"},
        },
    )]


CEL_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "cel-simple",
        "target_tool": "configure_case",
        "system_prompt": SYS,
        "user_prompt": "case 节点 case1:按 payload.category 路由 —— invoice 走 node_inv,inquiry 走 node_inq,spam 走 node_spam,其他走 node_default。",
        "expect": {"references": "payload.category"},
    },
    {
        "id": "cel-numeric",
        "target_tool": "configure_case",
        "system_prompt": SYS,
        "user_prompt": "case 节点 case_score:payload.score 大于等于 0.8 走 node_high 分支,否则走 node_low。",
        "expect": {"references": "payload.score", "has_compare": True},
    },
    {
        "id": "cel-nullsafe",
        "target_tool": "configure_case",
        "system_prompt": SYS,
        "user_prompt": (
            "case 节点 case_validate:只有当 payload.user 存在、payload.user.email 存在、且 email 长度大于 5 时,"
            "才走 node_valid 分支,其他全走 node_reject。"
        ),
        "expect": {"needs_has": True},
    },
    {
        "id": "cel-loop",
        "target_tool": "configure_case",
        "system_prompt": SYS,
        "user_prompt": (
            "case 节点 case_retry:如果 payload.attempt 超过 5 次 或 payload.confidence ≥ 0.9,走 done;"
            "否则回到上游 solve 节点重试,并把 attempt 加 1。"
        ),
        "expect": {"needs_loopback_emit": True, "loop_target": "solve"},
    },
    {
        "id": "cel-contains",
        "target_tool": "configure_case",
        "system_prompt": SYS,
        "user_prompt": "case 节点 case_tag:payload.tags 里包含 'urgent' 就走 node_escalate,否则走 node_normal。",
        "expect": {"needs_contains": True},
    },
    {
        "id": "cel-trap-compute",
        "target_tool": "configure_case",
        "system_prompt": SYS,
        "user_prompt": "case 节点 case_sentiment:判断 payload.body 这封邮件的情绪是不是积极的,积极走 node_pos,否则 node_neg。",
        # TRAP: CEL cannot ANALYZE body sentiment. CORRECT behavior = route on a
        # presumed upstream field (e.g. payload.sentiment == "positive") OR refuse.
        # WRONG = trying to embed text analysis. Routing on a field IS correct.
        "expect": {"trap_no_compute": True},
    },
]


def validate(called: str | None, args: dict[str, Any] | None, scenario: dict[str, Any]) -> tuple[bool, list[str]]:
    errors: list[str] = []
    exp = scenario.get("expect", {})

    # Trap: CEL cannot analyze. CORRECT = refuse, OR route on a presumed upstream
    # field (e.g. payload.sentiment == "positive") — that's a clean field comparison,
    # not analysis. WRONG = an expression that is not valid CEL (tries to compute).
    if exp.get("trap_no_compute"):
        if called != "configure_case":
            return True, []  # refused / redirected — correct
        expr = (args or {}).get("expression", "") or ""
        v = validate_cel(expr)
        if not v["valid"]:
            return False, [f"trap: produced invalid CEL (tried to compute): {expr[:120]!r}"] + v["errors"]
        return True, []  # routes on a field — correct worker behavior

    if called != "configure_case":
        return False, [f"called {called!r} not configure_case"]
    if not args:
        return False, ["no args"]
    expr = args.get("expression", "")
    branches = args.get("branches", {})

    v = validate_cel(expr)
    errors.extend(v["errors"])

    if exp.get("references") and exp["references"] not in expr:
        errors.append(f"expression doesn't reference {exp['references']!r}: {expr[:120]!r}")
    if exp.get("has_compare") and not any(op in expr for op in [">=", ">", "<", "<=", "=="]):
        errors.append("expected a numeric comparison")
    if exp.get("needs_has") and "has(" not in expr:
        errors.append(f"missing has() null-guard (unsafe nested access): {expr[:120]!r}")
    if exp.get("needs_contains") and not any(k in expr for k in [" in ", "contains", ".exists("]):
        errors.append(f"missing membership/contains check: {expr[:120]!r}")
    if exp.get("needs_loopback_emit"):
        import json as _j
        btext = _j.dumps(branches, ensure_ascii=False)
        if exp.get("loop_target") and exp["loop_target"] not in btext:
            errors.append(f"no branch targeting upstream {exp['loop_target']!r}")
        if "attempt" not in btext:
            errors.append("retry branch missing emit attempt+1")

    return len(errors) == 0, errors


def main() -> int:
    variant = sys.argv[1] if len(sys.argv) > 1 else "none"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    tools = cel_tool(variant)
    all_results = []
    for scen in CEL_SCENARIOS:
        print(f"\n=== {scen['id']} :: {variant} ===", flush=True)
        rs = run_forge_cell(scen, variant, tools, validate, reps=reps)
        all_results.extend(rs)
        v = sum(1 for r in rs if r.valid)
        print(f"  {v}/{len(rs)} valid", flush=True)
    save_results(all_results, f"cel_{variant}")
    print("\n" + "=" * 60)
    print(failure_digest(all_results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
