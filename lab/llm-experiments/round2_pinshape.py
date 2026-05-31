"""Round-2 validated-iteration: does PINNING the per-op value shape in the schema/description
remove the model's inner-shape guessing? ag_extract_invoice splits set_output_schema inner key
~33% schema-vs-value because ops value is untyped {}. A/B: untyped vs pinned. n=30, temp=default.
Objective metric: fraction using canonical {kind, schema}. Output: /tmp/r2pin/<variant>.json"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
from collections import Counter
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

OUT = Path("/tmp/r2pin"); OUT.mkdir(exist_ok=True)

OPS_ENUM = ["set_meta", "set_prompt", "set_skill", "set_knowledge", "set_tools", "set_output_schema", "set_model"]

def create_agent_tool(pinned: bool):
    if pinned:
        ops_desc = ("Each op = {op, value}. value shape PER op: set_prompt→string; set_model→string; "
                    "set_skill→string (skill name); set_knowledge→array of doc refs (ids/names, NEVER pasted text); "
                    "set_tools→array of callable refs; set_meta→{name?,description?}; "
                    "set_output_schema→{kind: 'json_schema'|'enum'|'free_text', schema: <a JSON-Schema object>} "
                    "(the JSON Schema goes under the key `schema`, NOT `value`).")
    else:
        ops_desc = f"Each op.op ∈ {{{', '.join(OPS_ENUM)}}}."
    return {"type": "function", "function": {"name": "create_agent", "description": "Forge an agent (configured LLM worker).",
            "parameters": {"type": "object", "required": ["name", "ops"], "additionalProperties": False, "properties": {
                "name": {"type": "string"},
                "ops": {"type": "array", "description": ops_desc, "items": {"type": "object", "required": ["op"],
                        "properties": {"op": {"type": "string", "enum": OPS_ENUM}, "value": {}}}}}}}}

USER = ("做一个发票信息抽取 agent:从发票文本里抽取发票号(invoice_no)、开票日期(date)、总金额(total)三个字段,"
        "结构化 JSON 输出。")

def inner_shape(args):
    """Return ('schema'|'value'|'raw'|'none', kind) for the set_output_schema op."""
    ops = args.get("ops", []) if isinstance(args, dict) else []
    for o in ops if isinstance(ops, list) else []:
        if isinstance(o, dict) and o.get("op") == "set_output_schema":
            v = o.get("value")
            if not isinstance(v, dict):
                return ("raw", "?")
            kind = v.get("kind", "?")
            if "schema" in v:
                return ("schema", kind)
            if "value" in v:
                return ("value", kind)
            if "type" in v:  # JSON Schema inlined directly under value (no wrapper)
                return ("inline", kind)
            return ("other", kind)
    return ("none", "?")


def run(reps=30, workers=20):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    for variant in ("untyped", "pinned"):
        tool = create_agent_tool(pinned=(variant == "pinned"))
        recs = []
        budget = {"v": False}

        def work(i):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": USER}]
                res = ds.chat_complete(messages=msgs, tools=[tool], scenario=f"r2pin_{variant}", variant=variant,
                                       temperature=None, max_tokens=8000, disable_thinking=False)
                tcs = res.effective_tool_calls
                a = parse_args(tcs[0]) if tcs else {}
                return {"rep": i, "shape": inner_shape(a), "ops": [o.get("op") for o in (a.get("ops") or []) if isinstance(o, dict)]}
            except ds.BudgetExhausted as e:
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
        shapes = Counter(r["shape"][0] for r in recs if "shape" in r)
        canonical = shapes.get("schema", 0)
        n = sum(shapes.values())
        print(f"[{variant}] n={n} inner-shape={dict(shapes)} | canonical {{kind,schema}}={canonical}/{n}="
              f"{100*canonical/n if n else 0:.0f}%")
        if budget["v"]:
            print("*** BUDGET EXHAUSTED ***"); break
    print(f"PINSHAPE A/B DONE; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 30)
