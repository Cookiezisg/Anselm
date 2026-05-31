"""G10 generality test on the CROWN-JEWEL tool: create_workflow trigger node.
Existing reps show the cron field name varies 6+ ways (cron/schedule/expression/cronExpr/...)
because node.config is untyped {}. A/B: untyped node:{} vs trigger config pinned in schema.
Objective metric: fraction using canonical config:{kind:"cron", cron:"<expr>"}. n=30, temp=default.
Output: /tmp/r2trig/<variant>.json"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
from collections import Counter
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

OUT = Path("/tmp/r2trig"); OUT.mkdir(exist_ok=True)
OPS_ENUM = ["add_node", "remove_node", "connect", "disconnect", "update_config"]

def create_workflow_tool(pinned):
    # pinned ∈ {"pinned", "untyped", "typed_only"}
    TYPES = "node.type ∈ {trigger, tool, agent, case, approval}."
    if pinned == "pinned":
        node_desc = ("A node = {id, type, config}. " + TYPES + " config shape PER type: "
                     "trigger→{kind:'cron'|'manual'|'webhook'|'event', cron:'<5-field cron expr>' (ONLY when kind=cron; "
                     "the cron string goes under the key `cron`, NOT schedule/expression), payloadSchema?:{...}}; "
                     "tool→{ref:'<callable ref>', args:{...}}; "
                     "agent→{ref:'ag_xxx'}; "
                     "case→{branches:{<name>:{when:'<bool CEL>', to:'<nodeId>'}}}; "
                     "approval→{prompt:'...', branches:{approved:{to},rejected:{to}}}.")
    elif pinned == "typed_only":
        # = real V3: type enum pinned, config shape NOT (isolates the config-pinning effect)
        node_desc = ("A node = {id, type, config}. " + TYPES +
                     " Set each node's config appropriately for its type (cron schedule, callable ref, branches, etc.).")
    else:  # untyped
        node_desc = "A node object with type and its config."
    return {"type": "function", "function": {"name": "create_workflow", "description": "Forge a workflow graph.",
            "parameters": {"type": "object", "required": ["name", "ops"], "additionalProperties": False, "properties": {
                "name": {"type": "string"},
                "ops": {"type": "array", "description": f"Graph ops. op ∈ {{{', '.join(OPS_ENUM)}}}.",
                        "items": {"type": "object", "required": ["op"], "properties": {
                            "op": {"type": "string", "enum": OPS_ENUM},
                            "node": {"type": "object", "description": node_desc},
                            "from": {"type": "string"}, "to": {"type": "string"},
                            "nodeId": {"type": "string"}, "config": {"type": "object"}}}}}}}}

USER = ("做一个每小时整点运行的工作流:cron 触发 → 调 fn_fetch_orders 拉订单 → 调 fn_send_report 发报告。")

def trigger_shape(args):
    ops = args.get("ops", []) if isinstance(args, dict) else []
    for o in ops if isinstance(ops, list) else []:
        if isinstance(o, dict) and o.get("op") == "add_node":
            n = o.get("node", {})
            if isinstance(n, dict) and n.get("type") == "trigger":
                cfg = n.get("config", n)
                if not isinstance(cfg, dict):
                    return ("raw", None)
                # which key holds the cron string?
                for key in ("cron", "schedule", "expression", "cronExpr", "cronExpression", "cronExpression"):
                    if key in cfg:
                        return (key, cfg.get("kind"))
                if "config" in cfg and isinstance(cfg["config"], dict):
                    return ("nested", cfg.get("kind"))
                return ("no-cron-field", cfg.get("kind"))
    return ("no-trigger", None)


def run(reps=30, workers=20):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    for variant in ("typed_only", "pinned"):
        tool = create_workflow_tool(variant)
        recs = []
        budget = {"v": False}

        def work(i):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": USER}]
                res = ds.chat_complete(messages=msgs, tools=[tool], scenario=f"r2trig_{variant}", variant=variant,
                                       temperature=None, max_tokens=8000, disable_thinking=False)
                tcs = res.effective_tool_calls
                a = parse_args(tcs[0]) if tcs else {}
                return {"rep": i, "shape": trigger_shape(a)}
            except ds.BudgetExhausted:
                budget["v"] = True
                return {"rep": i, "budget_exhausted": True}
            except Exception as e:
                return {"rep": i, "error": f"{type(e).__name__}: {e}"}

        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            for fut in cf.as_completed([ex.submit(work, i) for i in range(reps)]):
                r = fut.result()
                if r:
                    recs.append(r)
        recs.sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{variant}.json").write_text(json.dumps(recs, ensure_ascii=False, indent=2))
        keys = Counter(r["shape"][0] for r in recs if "shape" in r)
        n = sum(keys.values())
        canonical = keys.get("cron", 0)
        print(f"[{variant}] n={n} cron-field-key={dict(keys)} | canonical `cron`={canonical}/{n}="
              f"{100*canonical/n if n else 0:.0f}%")
        if budget["v"]:
            print("*** BUDGET EXHAUSTED ***"); break
    print(f"TRIGGER A/B DONE; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 30)
