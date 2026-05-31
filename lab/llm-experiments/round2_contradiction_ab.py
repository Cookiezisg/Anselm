"""Round-2 iteration: can a system-prompt rule fix the dirty_contradictory limitation (0/3)?
Contradictory request (fully-automatic unattended AND every refund needs manual approval).
A/B: baseline SYSTEM vs SYSTEM + a 'satisfiability check' rule (appended at end per G6 recency).
n=20, temp=default. Output: /tmp/r2contra/<variant>.json (judged separately)."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

OUT = Path("/tmp/r2contra"); OUT.mkdir(exist_ok=True)

USER = "帮我建个 workflow:要完全自动、无人值守地处理所有退款,但每一笔退款都必须经过我人工审批才能执行。"

# Satisfiability rule — appended at END (G6 recency), high-density, doesn't box the model in.
RULE = ("\n\n判断可满足性 —— 动手建造前,先看用户需求是否自相矛盾或无法同时满足"
        "(例:'完全自动无人值守' 与 '每一笔都要人工审批' 不可兼得)。若发现矛盾,"
        "先点明冲突、提出可行折衷(如阈值:小额自动、大额人工)请用户确认,再建。"
        "绝不静默地建一个自相矛盾的图。")

WF_TOOLS = cat.workflow_tools("V3-full-teaching")


def run(reps=20, workers=16):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    for variant, sysp in (("baseline", SYSTEM), ("ruled", SYSTEM + RULE)):
        recs = []
        budget = {"v": False}

        def work(i):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": sysp}, {"role": "user", "content": USER}]
                res = ds.chat_complete(messages=msgs, tools=WF_TOOLS, scenario=f"r2contra_{variant}", variant=variant,
                                       temperature=None, max_tokens=16000, disable_thinking=False)
                tcs = res.effective_tool_calls
                return {"rep": i, "content": res.content,
                        "called": [(t.get("function") or t).get("name") for t in tcs],
                        "built_workflow": any((t.get("function") or t).get("name") == "create_workflow" for t in tcs)}
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
        (OUT / f"{variant}.json").write_text(json.dumps(
            {"variant": variant, "user": USER, "reps": recs}, ensure_ascii=False, indent=2))
        built = sum(1 for r in recs if r.get("built_workflow"))
        print(f"[{variant}] n={len(recs)} built_workflow={built} (lower=more flagged); see judge for flagged%")
        if budget["v"]:
            print("*** BUDGET EXHAUSTED ***"); break
    print(f"CONTRADICTION A/B GEN DONE; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 20)
