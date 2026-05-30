"""Regression guard for the new satisfiability-check rule: does it OVER-flag NORMAL
(non-contradictory) requests? The ruled system prompt must still BUILD normal workflows,
NOT refuse/over-clarify. Critical: the threshold case (the RESOLVED form of the contradiction)
must build, not be mis-flagged. n=15/scenario, temp=default. Output: /tmp/r2contra/regression.json"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM
from round2_contradiction_ab import RULE, WF_TOOLS

OUT = Path("/tmp/r2contra"); OUT.mkdir(exist_ok=True)

NORMAL = [
    {"id": "daily_report", "user": "建个每天早上9点把昨天的订单汇总成报告发邮件给我的 workflow。"},
    {"id": "onboarding", "user": "新用户注册后立即发欢迎邮件,3天后再发一封使用技巧邮件。"},
    {"id": "threshold_approval",  # the RESOLVED form — must NOT be mis-flagged as contradictory
     "user": "退款请求进来:金额≥1000 的要我人工审批,低于1000的自动处理。"},
    {"id": "support_triage", "user": "工单进来先用 AI 分类,高优先级的转人工队列,普通的自动回复。"},
]


def run(reps=15, workers=16):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    out = {}
    for arm, sysp in (("baseline", SYSTEM), ("ruled", SYSTEM + RULE)):
        recs = {s["id"]: [] for s in NORMAL}
        jobs = [(s, i) for s in NORMAL for i in range(reps)]
        budget = {"v": False}

        def work(job):
            s, i = job
            if budget["v"]:
                return (s["id"], None)
            try:
                msgs = [{"role": "system", "content": sysp}, {"role": "user", "content": s["user"]}]
                res = ds.chat_complete(messages=msgs, tools=WF_TOOLS, scenario=f"r2reg_{arm}_{s['id']}", variant=arm,
                                       temperature=None, max_tokens=16000, disable_thinking=False)
                tcs = res.effective_tool_calls
                built = any((t.get("function") or t).get("name") == "create_workflow" for t in tcs)
                return (s["id"], {"rep": i, "built": built, "content_head": (res.content or "")[:140]})
            except ds.BudgetExhausted:
                budget["v"] = True
                return (s["id"], None)
            except Exception as e:
                return (s["id"], {"rep": i, "error": f"{type(e).__name__}: {e}"})

        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            for fut in cf.as_completed([ex.submit(work, j) for j in jobs]):
                sid, r = fut.result()
                if r:
                    recs[sid].append(r)
        out[arm] = recs
    (OUT / "regression.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
    print("=== REGRESSION: baseline vs ruled on NORMAL requests (built%; gap = rule's added caution) ===")
    for sid in (s["id"] for s in NORMAL):
        line = f"  {sid:18s}: "
        for arm in ("baseline", "ruled"):
            rs = out[arm][sid]; n = len([r for r in rs if "built" in r]); b = sum(1 for r in rs if r.get("built"))
            line += f"{arm} {b}/{n}={100*b/n if n else 0:.0f}%  "
        print(line)
    print(f"cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 15)
