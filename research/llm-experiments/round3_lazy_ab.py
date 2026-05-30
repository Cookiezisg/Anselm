"""Lazy-group activation A/B: does the DOMAIN-based 6-group split (current Forgify: function/handler/
workflow/mcp/document/skill — create+edit+run+all in ONE domain group) activate as accurately as the
finer 11-group edit/use split? The user prefers domain-6 (simpler).
Per scenario: offer RESIDENT(7 search) + activate_tools(scheme cats); multi-turn (search-first via
resident → activate). Record which category the model activates; check vs expected for each scheme.
Reads /tmp/r3lazy/scenarios.json [{user, domain6, group11}]. temp=default. Output /tmp/r3lazy/result.json
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import experiments as e
import deepseek_client as ds
from wave1_gen import parse_args

OUT = Path("/tmp/r3lazy"); OUT.mkdir(exist_ok=True)
SYS = e.SYSTEM_PROMPT_LAZY if hasattr(e, "SYSTEM_PROMPT_LAZY") else (
    "You are Forgify's automation engineer. Most tools live in categories — call "
    "`activate_tools(category=<name>)` to load the right category for the task, then call the tool. "
    "search_* tools are always available to find existing entities by id first.")
SCHEMES = {"6-domain": e.GROUPS_6, "11-edituse": e.GROUPS_11}


def _synth_search():
    return json.dumps({"data": [{"id": "fn_a1b2c3d4e5f60718", "name": "matching_entity", "summary": "the entity"}]})


def run(workers=20):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    scens = json.loads((OUT / "scenarios.json").read_text())
    if isinstance(scens, dict):
        scens = scens.get("scenarios", [])
    budget = {"v": False}
    out = {}
    for scheme, groups in SCHEMES.items():
        tools = e.build_lazy_offering(groups)
        expkey = "domain6" if scheme == "6-domain" else "group11"

        def work(s):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": SYS}, {"role": "user", "content": s["user"]}]
                activated = []
                for turn in range(1, 4):
                    res = ds.chat_complete(messages=msgs, tools=tools, scenario=f"lazy_{scheme}", variant=scheme,
                                           temperature=None, max_tokens=6000, disable_thinking=False)
                    tcs = res.effective_tool_calls
                    names = [(t.get("function") or t).get("name") for t in tcs]
                    for t in tcs:
                        nm = (t.get("function") or t).get("name")
                        if nm == "activate_tools":
                            a = parse_args(t)
                            if isinstance(a, dict) and a.get("category"):
                                activated.append(a["category"])
                    # stop once activated, or no recon to continue
                    if activated or not tcs or not all(n.startswith("search_") for n in names):
                        break
                    asst = {"role": "assistant", "content": res.content or "", "tool_calls": tcs}
                    rc = (res.raw_response.get("choices") or [{}])[0].get("message", {}).get("reasoning_content")
                    if rc:
                        asst["reasoning_content"] = rc
                    msgs = msgs + [asst]
                    for t in tcs:
                        msgs.append({"role": "tool", "tool_call_id": t.get("id") or "c", "content": _synth_search()})
                exp = s.get(expkey)
                return {"id": s.get("id"), "expected": exp, "activated": activated,
                        "correct": exp in activated, "any_activate": bool(activated)}
            except ds.BudgetExhausted:
                budget["v"] = True
                return None
            except Exception as ex:
                return {"id": s.get("id"), "error": f"{type(ex).__name__}: {ex}"}

        recs = []
        with cf.ThreadPoolExecutor(max_workers=workers) as ex2:
            for fut in cf.as_completed([ex2.submit(work, s) for s in scens]):
                r = fut.result()
                if r:
                    recs.append(r)
        out[scheme] = recs
        att = [r for r in recs if "correct" in r]
        n = len(att)
        correct = sum(1 for r in att if r["correct"])
        anyact = sum(1 for r in att if r["any_activate"])
        print(f"[{scheme}] n={n} activate-right-group {correct}/{n}={100*correct/n if n else 0:.0f}% | "
              f"did-activate-at-all {anyact}/{n}={100*anyact/n if n else 0:.0f}% | ¥{ds.cumulative_cost_rmb():.2f}", flush=True)
        if budget["v"]:
            break
    (OUT / "result.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
    print(f"LAZY A/B done; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run()
