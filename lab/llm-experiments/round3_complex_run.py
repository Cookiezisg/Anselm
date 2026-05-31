"""Run the 300 HARD/COMPLEX scenarios (the intricate end) single-shot forge.
Surfaces → tools: create_workflow & cel_when → workflow_tools; create_agent → agent_tools;
create_function → function_tools; create_handler → handler_tool. Captures the artifact (ops/code)
→ /tmp/r3cxres/<surface>.json. Forge = create (no act-on-existing contamination). temp=default.
  python3 round3_complex_run.py [only]
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
import wave1_gen as w
from wave1_gen import SYSTEM, parse_args

SCEN = Path("/tmp/r3complex"); RES = Path("/tmp/r3cxres"); RES.mkdir(exist_ok=True)
TOOLS = {
    "create_workflow": cat.workflow_tools("V3-full-teaching"),
    "cel_when": cat.workflow_tools("V3-full-teaching"),
    "create_agent": cat.agent_tools("V3-full"),
    "create_function": cat.function_tools("V3-antipattern"),
    "create_handler": w.handler_tool(),
}
EXPECTED = {"create_workflow": "create_workflow", "cel_when": "create_workflow", "create_agent": "create_agent",
            "create_function": "create_function", "create_handler": "create_handler"}


def run(only=None, workers=24):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    budget = {"v": False}
    for surf in TOOLS:
        if only and only not in surf:
            continue
        f = SCEN / f"{surf}.json"
        if not f.exists():
            print(f"!! {surf}: no scenarios"); continue
        scens = json.loads(f.read_text())
        tools = TOOLS[surf]
        exp = EXPECTED[surf]

        def work(s):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}]
                res = ds.chat_complete(messages=msgs, tools=tools, scenario=f"r3cx_{surf}", variant="complex",
                                       temperature=None, max_tokens=16000, disable_thinking=False)
                tcs = res.effective_tool_calls
                tc = [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs]
                code = ""
                for c in tc:
                    if c["name"] == exp and isinstance(c["args"], dict) and c["args"].get("code"):
                        code = c["args"]["code"]
                return {"id": s["id"], "user": s["user"], "intent": s.get("intent", ""), "rubric": s.get("rubric", []),
                        "code_test": s.get("code_test"), "expected_tool": exp,
                        "called": [c["name"] for c in tc], "tool_calls": tc, "code": code}
            except ds.BudgetExhausted:
                budget["v"] = True
                return None
            except Exception as e:
                return {"id": s.get("id"), "error": f"{type(e).__name__}: {e}"}

        results = []
        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            for fut in cf.as_completed([ex.submit(work, s) for s in scens]):
                r = fut.result()
                if r:
                    results.append(r)
        results.sort(key=lambda x: x.get("id", ""))
        (RES / f"{surf}.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
        called_exp = sum(1 for r in results if exp in r.get("called", []))
        print(f"== {surf}: {len(results)} ran, called-{exp} {called_exp}/{len(results)} | ¥{ds.cumulative_cost_rmb():.2f}", flush=True)
        if budget["v"]:
            print("*** BUDGET EXHAUSTED ***"); break
    print(f"R3 COMPLEX RUN done; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(only=sys.argv[1] if len(sys.argv) > 1 else None)
