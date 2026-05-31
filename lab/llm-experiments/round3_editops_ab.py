"""Edit-ops G10 fix A/B: the current edit_function/edit_handler ops are untyped (`items:{type:object}`)
→ the model guesses each op's shape (update_code with `code` vs `value` vs nested). Pin the ops shape
in the schema → does it converge? Single-shot edit (scenario gives the id), measure canonical-op-shape
consistency + which key holds the new code. n from /tmp/r3scen/edit_*.json. temp=default.
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
from collections import Counter
import spec_catalog as sc
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

OUT = Path("/tmp/r3editops"); OUT.mkdir(exist_ok=True)


def edit_tool(name, pinned):
    base = sc.BY_NAME[name].get("function", sc.BY_NAME[name])
    if not pinned:
        return {"type": "function", "function": base}
    ops_items = {"type": "object", "required": ["op"], "properties": {
        "op": {"type": "string", "enum": ["update_code", "update_kind", "update_description", "update_polling_interval"]},
        "code": {"type": "string", "description": "for update_code — the FULL new code (key is `code`, not `value`)"},
        "kind": {"type": "string", "enum": ["normal", "polling"], "description": "for update_kind"},
        "description": {"type": "string"},
        "intervalSeconds": {"type": "integer"}}}
    return {"type": "function", "function": {
        "name": name, "description": base.get("description", ""),
        "parameters": {"type": "object", "required": ["id", "ops"], "additionalProperties": False, "properties": {
            "id": {"type": "string"},
            "ops": {"type": "array", "description": "Each op = {op, <typed field>}: update_code→{op,code}; "
                    "update_kind→{op,kind}; update_description→{op,description}; update_polling_interval→{op,intervalSeconds}.",
                    "items": ops_items}}}}}


def code_shape(args):
    """How did the model express the new code in the ops? canonical = {op:update_code, code:...}."""
    ops = args.get("ops", []) if isinstance(args, dict) else []
    for o in ops if isinstance(ops, list) else []:
        if isinstance(o, dict) and o.get("op") in ("update_code", "updateCode", "update", None):
            if "code" in o:
                return "code"
            if "value" in o:
                return "value"
            if "content" in o:
                return "content"
            return "other"
    return "no-update-code-op"


def run(workers=20):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    budget = {"v": False}
    for name in ("edit_function", "edit_handler"):
        scens = json.loads(Path(f"/tmp/r3scen/{name}.json").read_text())
        for variant in ("untyped", "pinned"):
            tool = [edit_tool(name, variant == "pinned")]

            def work(s):
                if budget["v"]:
                    return None
                try:
                    # give the id + current code inline so it's a single-shot edit (isolate ops-shape).
                    u = s["user"] + "\n\n(当前代码已确认,直接提交修改。)"
                    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": u}]
                    res = ds.chat_complete(messages=msgs, tools=tool, scenario=f"editops_{name}_{variant}",
                                           variant=variant, temperature=None, max_tokens=8000, disable_thinking=False)
                    tcs = res.effective_tool_calls
                    a = parse_args(tcs[0]) if tcs else {}
                    called = bool(tcs) and (tcs[0].get("function") or tcs[0]).get("name") == name
                    return {"shape": code_shape(a) if called else "no-call", "called": called}
                except ds.BudgetExhausted:
                    budget["v"] = True
                    return None
                except Exception as ex:
                    return {"shape": f"err", "called": False}

            recs = []
            with cf.ThreadPoolExecutor(max_workers=workers) as ex:
                for fut in cf.as_completed([ex.submit(work, s) for s in scens]):
                    r = fut.result()
                    if r:
                        recs.append(r)
            sh = Counter(r["shape"] for r in recs)
            n = len(recs)
            canon = sh.get("code", 0)
            print(f"[{name}/{variant}] n={n} shapes={dict(sh)} | canonical `code` key={canon}/{n}={100*canon/n if n else 0:.0f}%", flush=True)
            if budget["v"]:
                break
        if budget["v"]:
            break
    print(f"EDIT-OPS A/B done; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run()
