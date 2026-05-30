"""Wave-11: FRESH diverse workflow scenarios with the `when:` case design — anti-overfit confirmation.
Confirms create_workflow ~80%+ generalizes BROADLY (not just the 4 wave-1 scenarios iterated 4x).
Reuses wave1_gen machinery. Output: /tmp/w11/<id>.json
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args, structural

OUT = Path("/tmp/w11"); OUT.mkdir(exist_ok=True)
TOOLS = cat.workflow_tools("V3-full-teaching")

SCEN = [
    {"id": "wf_order_fulfill",
     "user": "建 workflow:webhook 收到订单(payload 有 sku),先调 fn_check_inventory 查库存;有货走 fn_ship 发货,缺货走 fn_backorder 并通知 fn_notify_customer。",
     "intent": "webhook → fn_check_inventory → case in-stock?(when) → ship / backorder+notify.",
     "rubric": ["webhook trigger", "fn_check_inventory called FIRST (data produced before routing)", "case routes on stock status via per-branch when guards", "in-stock branch → fn_ship", "out-of-stock branch → fn_backorder (and notify)", "no dangling/null branch", "case routes via branches not redundant connect", "runnable end-to-end"]},
    {"id": "wf_content_mod",
     "user": "建 workflow:每 10 分钟拉新帖子(fn_poll_posts),ag_moderate 分类成 ok/flag/ban;ok 调 fn_publish;flag 走人工审批,通过则 fn_publish 否则 fn_remove;ban 直接 fn_remove 并 fn_log。",
     "intent": "cron → fn_poll_posts → ag_moderate → case ok/flag/ban → ok:publish; flag:approval→publish/remove; ban:remove+log.",
     "rubric": ["cron trigger ~10min", "fn_poll_posts fetch step FIRST (not empty payload to agent)", "ag_moderate agent node", "case routes ok/flag/ban (per-branch when on category)", "ok → fn_publish", "flag → approval node → approved:fn_publish / rejected:fn_remove", "ban → fn_remove then fn_log", "no dangling branches", "runnable"]},
    {"id": "wf_lead_scoring",
     "user": "建 workflow:webhook 收到线索,ag_score 打分(0-100),分数 >=70 调 fn_assign_sales 分配销售,否则调 fn_nurture 发培育邮件。",
     "intent": "webhook → ag_score → case score>=70 (when) → assign_sales / nurture.",
     "rubric": ["webhook trigger", "ag_score agent produces a score", "case routes via per-branch when (score>=70)", ">=70 branch → fn_assign_sales", "else branch → fn_nurture", "when guard uses >= 70 correctly + null-safe", "no dangling", "branches not redundant connect"]},
    {"id": "wf_backup_retry",
     "user": "建 workflow:每天凌晨调 fn_run_backup 备份,失败就重试,最多重试 2 次,2 次都失败调 fn_alert_oncall。",
     "intent": "cron → fn_run_backup → case fail&attempt<2 (when) loop back +1 / after 2 → alert.",
     "rubric": ["cron trigger", "fn_run_backup tool node", "case checks failure + attempt via per-branch when", "retry branch loops BACK to fn_run_backup with emit attempt+1 (null-safe default)", "bound = 2 retries (attempt<2)", "after exhausted → fn_alert_oncall", "loop terminates (no infinite)", "no dangling"]},
    {"id": "wf_expense_approval",
     "user": "建 workflow:manual 触发报销(payload 有 amount),金额 >5000 走 VP 审批(approval),>1000 走经理审批(approval),否则自动通过 fn_auto_approve。审批通过都调 fn_reimburse,拒绝调 fn_notify_reject。",
     "intent": "manual → case 3-level (>5000 VP / >1000 manager / else auto) via when guards, ordered; approvals → reimburse/reject.",
     "rubric": ["manual trigger with payloadSchema(amount)", "case routes 3 ways by amount via per-branch when, ORDERED (>5000 before >1000 before else)", ">5000 → VP approval node; >1000 → manager approval node; else → fn_auto_approve", "approval approved branches → fn_reimburse", "approval rejected → fn_notify_reject", "no dangling branches / approval timeouts not left dangling", "thresholds correct (>5000, >1000) + ordered so 6000 hits VP not manager"]},
]


def run(reps=10, workers=14):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists(): os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {s["id"]: {**{k: s[k] for k in ("id", "intent", "rubric", "user")}, "surface": "create_workflow", "mode": "ARTIFACT", "reps": []} for s in SCEN}
    jobs = [(s, i) for s in SCEN for i in range(reps)]
    budget = {"v": False}
    def work(job):
        s, i = job
        if budget["v"]: return (s["id"], None)
        try:
            res = ds.chat_complete(messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}],
                                   tools=TOOLS, scenario=f"w11_{s['id']}", variant="freshwf", max_tokens=16000, disable_thinking=False)
            tcs = res.effective_tool_calls
            return (s["id"], {"rep": i, "content": res.content,
                              "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
                              "structural": structural("create_workflow", tcs), "cost_rmb": round(res.cost_entry.cost_rmb, 6)})
        except ds.BudgetExhausted as e:
            budget["v"] = True; return (s["id"], {"rep": i, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (s["id"], {"rep": i, "error": f"{type(e).__name__}: {e}"})
    done = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for fut in cf.as_completed([ex.submit(work, j) for j in jobs]):
            sid, rep = fut.result()
            if rep: recs[sid]["reps"].append(rep)
            done += 1
            if done % 10 == 0: print(f"... {done}/{len(jobs)}; ¥{ds.cumulative_cost_rmb():.2f}", flush=True)
    for sid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{sid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        called = sum(1 for x in rec["reps"] if x.get("structural", {}).get("called"))
        print(f"{sid:20s} reps={len(rec['reps'])} called={called}")
    if budget["v"]: print("*** BUDGET EXHAUSTED ***")
    print(f"WAVE-11 GEN DONE; ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 10)
