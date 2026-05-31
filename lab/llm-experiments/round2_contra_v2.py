"""Iterate the satisfiability rule to be SHIPPABLE: the broad phrasing flags contradictions
(0→100%) but over-clarifies NORMAL requests (daily_report 100→47, onboarding 100→60).
Test a TIGHT, conditional phrasing: flag ONLY genuine contradictions; incomplete-info ≠
contradiction → build with defaults, don't over-ask. Goal: contradiction still flagged (low build)
AND normal restored (high build). n=20 contra / 15 normal, temp=default. Output /tmp/r2contra/v2.json"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import deepseek_client as ds
from wave1_gen import SYSTEM
from round2_contradiction_ab import WF_TOOLS, USER as CONTRA_USER
from round2_contra_regression import NORMAL

OUT = Path("/tmp/r2contra"); OUT.mkdir(exist_ok=True)

# TIGHT rule: scoped to genuine contradictions + explicit "incomplete-info ≠ contradiction, build with defaults".
RULE_TIGHT = ("\n\n仅当用户需求**自相矛盾、逻辑上无法同时满足**时(如'完全自动无人值守'且'每一笔都要人工审批'),"
              "才先点明冲突、提一个可行折衷(如阈值)请用户确认,再建。"
              "**需求只是信息不全(缺邮箱/数据源/格式等)不算矛盾**——按合理默认直接建,不要因此拒绝建造或反复追问。")

SCEN = ([{"id": "dirty_contradictory", "user": CONTRA_USER, "expect": "low-build (flag)"}]
        + [{**s, "expect": "high-build (normal)"} for s in NORMAL])


def run(reps_contra=20, reps_normal=15, workers=16):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    sysp = SYSTEM + RULE_TIGHT
    recs = {s["id"]: [] for s in SCEN}
    jobs = [(s, i) for s in SCEN for i in range((reps_contra if s["id"] == "dirty_contradictory" else reps_normal))]
    budget = {"v": False}

    def work(job):
        s, i = job
        if budget["v"]:
            return (s["id"], None)
        try:
            msgs = [{"role": "system", "content": sysp}, {"role": "user", "content": s["user"]}]
            res = ds.chat_complete(messages=msgs, tools=WF_TOOLS, scenario=f"r2v2_{s['id']}", variant="ruled-tight",
                                   temperature=None, max_tokens=16000, disable_thinking=False)
            tcs = res.effective_tool_calls
            built = any((t.get("function") or t).get("name") == "create_workflow" for t in tcs)
            return (s["id"], {"rep": i, "built": built, "content_head": (res.content or "")[:130]})
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
    (OUT / "v2.json").write_text(json.dumps(recs, ensure_ascii=False, indent=2))
    print("=== TIGHT rule: contradiction should stay LOW-build (flagged), normal HIGH-build (restored) ===")
    for s in SCEN:
        rs = recs[s["id"]]; n = len([r for r in rs if "built" in r]); b = sum(1 for r in rs if r.get("built"))
        print(f"  {s['id']:18s} [{s['expect']:18s}]: built {b}/{n} = {100*b/n if n else 0:.0f}%")
    print(f"cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run()
