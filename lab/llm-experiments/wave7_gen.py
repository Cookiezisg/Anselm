"""Wave-7: create_workflow DIFFICULTY GRADIENT — map WHERE the 55% comes from.

Hypothesis: simple/linear workflows are fine; only complex multi-branch (multiple case nodes /
loops / many terminal paths) hit the case-routing weakness. If true, the G8 heavy check/fix is only
needed for complex graphs — a more actionable conclusion than a flat "workflow 55%".

Reuses wave1_gen machinery (SYSTEM, parse_args, structural). Output: /tmp/w7/<id>.json
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args, structural

OUT = Path("/tmp/w7"); OUT.mkdir(exist_ok=True)
TOOLS = cat.workflow_tools("V3-full-teaching")

# ordered simplest → most complex
SCEN = [
    {"id": "g1_linear", "complexity": "1-linear",
     "user": "建个 workflow:手动触发,先调 fn_fetch_data 拉数据,再调 fn_save_report 存报告。就这两步,顺序执行。",
     "intent": "trigger(manual) → tool fn_fetch_data → tool fn_save_report. linear, no case.",
     "rubric": ["trigger present (manual)", "tool node fn_fetch_data", "tool node fn_save_report", "edges connect them in order t→fetch→save", "NO unnecessary case nodes", "no dangling targets", "runnable linear flow"]},
    {"id": "g2_one_case", "complexity": "2-one-case",
     "user": "建个 workflow:webhook 触发(payload 有 amount),如果 amount>1000 走 fn_manual_review,否则走 fn_auto_approve。",
     "intent": "webhook → case on amount>1000 → manual_review / auto_approve. one case, 2 branches.",
     "rubric": ["webhook trigger", "one case node with CEL on amount>1000", "branch1 → fn_manual_review", "branch2 → fn_auto_approve", "branches via branches not redundant connect", "no dangling/null targets", "CEL uses > 1000 correctly"]},
    {"id": "g3_two_case", "complexity": "3-two-case",
     "user": ("建个 workflow:cron 触发,调 ag_triage 分类成 urgent/normal/spam;urgent 再调 fn_check_vip 看是不是 VIP,"
              "VIP 走 fn_page_oncall,非 VIP 走 fn_create_ticket;normal 走 fn_create_ticket;spam 直接丢弃。"),
     "intent": "cron → agent triage → case1(urgent/normal/spam) → urgent→case2(vip?) → page_oncall/create_ticket; normal→create_ticket; spam→drop.",
     "rubric": ["cron trigger", "agent ag_triage", "case1 routes urgent/normal/spam", "urgent → second case checking VIP", "case2 VIP → fn_page_oncall, non-VIP → fn_create_ticket", "normal → fn_create_ticket", "spam → terminal/drop (no dangling null)", "no redundant connect edges on case nodes", "both cases route via branches"]},
    {"id": "g4_loop", "complexity": "4-loop",
     "user": "建个 workflow:手动触发,调 fn_sync_data,失败就重试,最多 5 次,5 次都失败调 fn_alert 通知。",
     "intent": "tool fn_sync_data → case checks failure+attempt<5 → loop back (attempt+1) / after 5 → fn_alert.",
     "rubric": ["tool fn_sync_data", "case checks failure + attempt", "retry branch loops back to fn_sync_data", "attempt incremented via emit, bounded at 5", "after 5 → fn_alert", "loop terminates (not infinite)", "CEL null-safe on attempt"]},
    {"id": "g5_approval_timeout", "complexity": "5-approval",
     "user": ("建个 workflow:webhook 触发的退款请求,先 ag_assess 评估,然后人工审批;审批通过调 fn_process_refund;"
              "拒绝调 fn_notify_reject;如果 24 小时没人审批,默认拒绝走 fn_notify_reject。"),
     "intent": "webhook → agent assess → approval(timeout 24h → reject) → approved→process_refund / rejected→notify_reject; timeout→notify_reject.",
     "rubric": ["webhook trigger", "agent ag_assess", "approval node with prompt", "approved → fn_process_refund", "rejected → fn_notify_reject", "timeout behavior set (24h → reject path)", "timeout routes to notify_reject (not dangling)", "approval routes via branches"]},
    {"id": "g6_complex", "complexity": "6-complex",
     "user": ("建个 workflow:cron 每小时拉 fn_poll_orders 的新订单,ag_classify 分类成 normal/suspicious/invalid;"
              "normal 调 fn_fulfill;suspicious 走人工审批,通过则 fn_fulfill 否则 fn_flag;invalid 调 fn_reject 并 fn_log。"),
     "intent": "cron → poll → classify → case(normal/suspicious/invalid) → normal:fulfill; suspicious:approval→fulfill/flag; invalid:reject+log. complex multi-branch + approval + multi-step.",
     "rubric": ["cron trigger", "fetch step fn_poll_orders (data flows, not empty)", "agent classify", "case routes normal/suspicious/invalid", "normal → fn_fulfill", "suspicious → approval → approved:fn_fulfill / rejected:fn_flag", "invalid → fn_reject then fn_log", "no dangling/null targets anywhere", "case+approval route via branches not redundant connect", "fully runnable"]},
]


def run(reps=12, workers=14):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {s["id"]: {**{k: s[k] for k in ("id", "complexity", "intent", "rubric", "user")}, "surface": "create_workflow", "mode": "ARTIFACT", "reps": []} for s in SCEN}
    jobs = [(s, r) for s in SCEN for r in range(reps)]
    budget = {"v": False}

    def work(job):
        s, r = job
        if budget["v"]:
            return (s["id"], None)
        try:
            res = ds.chat_complete(
                messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}],
                tools=TOOLS, scenario=f"w7_{s['id']}", variant="grad", max_tokens=16000, disable_thinking=False,
            )
            tcs = res.effective_tool_calls
            return (s["id"], {"rep": r, "content": res.content,
                              "reasoning": (res.raw_response.get("choices", [{}])[0].get("message", {}) or {}).get("reasoning_content", ""),
                              "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
                              "structural": structural("create_workflow", tcs), "cost_rmb": round(res.cost_entry.cost_rmb, 6)})
        except ds.BudgetExhausted as e:
            budget["v"] = True
            return (s["id"], {"rep": r, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (s["id"], {"rep": r, "error": f"{type(e).__name__}: {e}"})

    done = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for fut in cf.as_completed([ex.submit(work, j) for j in jobs]):
            sid, rep = fut.result()
            if rep:
                recs[sid]["reps"].append(rep)
            done += 1
            if done % 12 == 0:
                print(f"... {done}/{len(jobs)}; ¥{ds.cumulative_cost_rmb():.2f}", flush=True)

    for sid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{sid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        called = sum(1 for x in rec["reps"] if x.get("structural", {}).get("called"))
        print(f"{sid:20s} {rec['complexity']:14s} reps={len(rec['reps'])} called={called}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")
    print(f"WAVE-7 GEN DONE; ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 12)
