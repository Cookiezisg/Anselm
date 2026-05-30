"""Round-2 B (single-shot complex): the genuinely-hard surfaces.
- LARGE workflows (12+ nodes, multi-case/loop/approval) with the when: design
- COMPLEX CEL when-guards (time-window / multi-field / 5-way)
- COMPLEX stateful handlers + polling (sliding-window limiter / conn pool / multi-source dedup)
n=30 each. Output: /tmp/r2c/<id>.json
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args, structural, handler_tool
from wave10_when import WHEN_TOOL

OUT = Path("/tmp/r2c"); OUT.mkdir(exist_ok=True)
WF = cat.workflow_tools("V3-full-teaching")
FN = cat.function_tools("V5-combined")
HD = handler_tool()

SCEN = [
    # ---- LARGE workflows (12+ nodes) ----
    {"id": "bigwf_ecommerce", "surface": "create_workflow", "mode": "ARTIFACT", "tools": WF,
     "user": ("建一个完整的电商订单处理 workflow:webhook 收到订单 → fn_validate_order 校验 → fn_check_inventory 查库存;"
              "库存不足 → fn_reorder 补货并等待(approval 人工确认补货)→ 回到查库存;库存足 → fn_charge_payment 扣款;"
              "支付被风控标记(payload.fraud_flag)→ 人工审批,拒绝则 fn_cancel_order;通过或无风控 → fn_fulfill 出库 → "
              "fn_ship 发货 → fn_notify_customer;发货失败重试最多 3 次,仍失败 → fn_alert_ops。最后 fn_update_crm 更新记录。"),
     "intent": "~14-node pipeline: validate→inventory(low→reorder+approval→loop)→payment(fraud→approval→cancel)→fulfill→ship(retry3)→notify→crm.",
     "rubric": ["webhook trigger", "validate → check_inventory in order", "low-inventory → reorder + approval → loops back to check_inventory", "payment step; fraud_flag → approval → reject:cancel", "fulfill → ship → notify chain", "ship-fail retry bounded at 3 → alert_ops", "crm update at end", "all case/approval route via per-branch when guards, no dangling", "≥12 nodes, coherent + runnable, data flows", "no fictional structure / no contradictions"]},
    {"id": "bigwf_support", "surface": "create_workflow", "mode": "ARTIFACT", "tools": WF,
     "user": ("建客服工单 workflow:webhook 进工单 → ag_classify 分 urgent/high/normal/low + 类别;urgent → fn_page_oncall + 人工审批是否升级;"
              "high → fn_assign_senior;normal → fn_assign_team;low → fn_autorespond;所有非 low 的最后都 fn_log_sla;"
              "如果 ag_classify 置信度低(payload.confidence<0.6)→ 人工复核分类再路由。"),
     "intent": "~12-node: classify→confidence-gate(low→human review→reroute)→4-way priority→各 path→sla log.",
     "rubric": ["webhook trigger", "ag_classify agent", "confidence<0.6 gate → human review → re-route", "4-way priority routing (urgent/high/normal/low) via when guards", "urgent → page + approval", "high→senior, normal→team, low→autorespond", "non-low paths → log_sla", "when guards correct + ordered, no dangling", "≥10 nodes coherent runnable"]},
    {"id": "bigwf_etl", "surface": "create_workflow", "mode": "ARTIFACT", "tools": WF,
     "user": ("建数据 ETL workflow:每小时 cron → fn_extract 抽数 → fn_validate 校验;校验失败 → fn_quarantine 隔离 + 通知;"
              "校验通过 → fn_transform 转换;转换出错重试最多 2 次,仍失败 → 死信 fn_deadletter;成功 → fn_load 入库;"
              "入库后 → fn_refresh_cache + fn_notify_done。"),
     "intent": "~11-node: cron→extract→validate(fail→quarantine+notify)→transform(retry2→deadletter)→load→cache+notify.",
     "rubric": ["cron hourly trigger", "extract → validate in order", "validate-fail → quarantine + notify", "transform with retry bounded 2 → deadletter", "load after transform success", "load → cache refresh + notify_done", "case via when guards, retry emit+bound, no dangling", "≥10 nodes coherent runnable, data flows"]},
    # ---- COMPLEX CEL when-guards ----
    {"id": "celw_timewindow", "surface": "cel_when", "mode": "ARTIFACT", "tools": WHEN_TOOL,
     "user": ("在 wf_x 的 case 'hours' 上:工作时间(payload.dow 在 1-5 且 payload.hour 在 9-18)走 fast(to=f),否则走 queue(to=q)。"),
     "intent": "when fast: dow in 1..5 && hour>=9 && hour<18; queue default.",
     "rubric": ["fast when correctly encodes weekday (dow 1-5) AND business hours (9-18)", "queue default (when true)", "boundary handling sane (>=9, <18 or <=18 consistent)", "null-safe", "no key-match (each branch a when)"]},
    {"id": "celw_multifield", "surface": "cel_when", "mode": "ARTIFACT", "tools": WHEN_TOOL,
     "user": ("在 wf_x 的 case 'risk' 上:金额>1000 且地区在 [US,EU] 且不在黑名单(payload.blacklisted 为 false)→ review(to=r);否则 auto(to=a)。"),
     "intent": "when review: amount>1000 && region in [US,EU] && !blacklisted; auto default.",
     "rubric": ["review when = amount>1000 AND region in [US,EU] AND not blacklisted", "uses a list-membership check for region (in [\"US\",\"EU\"])", "boolean blacklisted handled (==false or !)", "auto default", "null-safe, no key-match"]},
    {"id": "celw_5way", "surface": "cel_when", "mode": "ARTIFACT", "tools": WHEN_TOOL,
     "user": ("在 wf_x 的 case 'tier' 上 5 路按 payload.score 分:>=90 s_plus(to=sp),>=75 s(to=s),>=50 a(to=a),>=25 b(to=b),否则 c(to=c)。"),
     "intent": "5-way ordered when guards on score thresholds, first-true-wins.",
     "rubric": ["5 branches with when guards >=90/>=75/>=50/>=25/default", "ORDER correct so 95→s_plus not lower (first-true-wins ordering)", "all 5 targets sp/s/a/b/c", "thresholds correct + descending", "no key-match"]},
    # ---- COMPLEX handlers / polling (CODE) ----
    {"id": "hd_sliding", "surface": "create_handler", "mode": "CODE", "tools": HD,
     "user": "写个 handler 做滑动窗口限流:allow(now) 返回是否放行,限制是每 window 秒内最多 max_calls 次(滑动窗口,非固定窗口)。",
     "intent": "sliding-window rate limiter: keep timestamps in window, allow if count<max. bare-names.",
     "rubric": ["class keeps a deque/list of recent call timestamps", "allow(now) evicts timestamps older than now-window, then allows if remaining < max_calls (and records now)", "SLIDING not fixed-window", "bare-named params (now), init (window, max_calls)", "schemas match", "valid Python; burst then window-slide behavior correct"],
     "code_test": {"expected_behavior": "window=10,max=2. allow(0)=T allow(1)=T allow(2)=F (2 in window). allow(11)=T (the now=0 call slid out, window now [1,11]→ only t=1 counts... actually at now=11 window is (1,11]: t=1 evicted? t=1 is at boundary; t=2 in window → count=1<2 → T).", "test_inputs": ["window=10,max_calls=2; allow(0),allow(1),allow(2),allow(11),allow(12)"], "mocks_hint": "pass now explicitly; pure (collections.deque ok)."}},
    {"id": "hd_connpool", "surface": "create_handler", "mode": "CODE", "tools": HD,
     "user": "写个 handler 做连接池:acquire() 拿一个连接(没空闲且没到上限就新建,到上限返回 None),release(conn) 归还。上限 max_size。",
     "intent": "connection pool: acquire (reuse idle / create if under max / None if maxed), release. bare-names.",
     "rubric": ["holds idle + in-use sets/lists + a max_size", "acquire reuses an idle conn, else creates if total<max_size, else returns None", "release returns a conn to idle", "bare-named params; init max_size (+ a conn factory or stub)", "schemas match", "valid Python; acquire to max → None, release → reusable"],
     "code_test": {"expected_behavior": "max_size=2. a=acquire()(ok), b=acquire()(ok), c=acquire()(None, maxed). release(a). d=acquire()(ok, reused).", "test_inputs": ["max_size=2; acquire x3 then release one then acquire"], "mocks_hint": "stub the connection factory (e.g. returns an int/object); pure."}},
    {"id": "fp_multisource", "surface": "create_function", "mode": "CODE", "tools": FN,
     "user": "写个 polling 函数,同时轮询两个来源(A、B)的新消息,合并、按 id 去重,返回新消息;cursor 要能跨重启(序列化两个源各自的进度)。",
     "intent": "polling: poll 2 sources, merge, dedup by id, only-new, restart-safe cursor (serialize both sources' progress).",
     "rubric": ["kind polling + interval", "poll(last_cursor)->{events,next_cursor}", "polls BOTH sources, merges", "dedups by id (no duplicate ids in events)", "cursor encodes BOTH sources' progress (a dict/tuple) so it's restart-safe", "only-new since cursor; no re-emit across polls", "valid Python; runs against mocked 2-source feeds"],
     "code_test": {"expected_behavior": "Mock source A and B. poll(None) returns merged new (deduped by id) + cursor encoding both. Second poll(cursor) no-new → []. Add to A → only that. Same id in A and B → appears once.", "test_inputs": ["poll(None), poll(cursor), add to A, dup id in both"], "mocks_hint": "stub two fetch functions returning controllable lists with {id, ts}; mutate between polls."}},
]


def run(reps=30, workers=24):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {}
    for s in SCEN:
        r = {k: s[k] for k in ("id", "surface", "mode", "intent", "rubric", "user")}
        if "code_test" in s:
            r["code_test"] = s["code_test"]
        r["reps"] = []
        recs[s["id"]] = r
    jobs = [(s, i) for s in SCEN for i in range(reps)]
    budget = {"v": False}

    def work(job):
        s, i = job
        if budget["v"]:
            return (s["id"], None)
        try:
            res = ds.chat_complete(messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}],
                                   tools=s["tools"], scenario=f"r2c_{s['id']}", variant="complex",
                                   temperature=None, max_tokens=16000, disable_thinking=False)
            tcs = res.effective_tool_calls
            return (s["id"], {"rep": i, "content": res.content,
                              "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
                              "structural": structural(s["surface"] if s["surface"] in ("create_workflow", "create_function", "create_handler") else "x", tcs),
                              "cost_rmb": round(res.cost_entry.cost_rmb, 6)})
        except ds.BudgetExhausted as e:
            budget["v"] = True
            return (s["id"], {"rep": i, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (s["id"], {"rep": i, "error": f"{type(e).__name__}: {e}"})

    done = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for fut in cf.as_completed([ex.submit(work, j) for j in jobs]):
            sid, rep = fut.result()
            if rep:
                recs[sid]["reps"].append(rep)
            done += 1
            if done % 20 == 0:
                print(f"... {done}/{len(jobs)}; ¥{ds.cumulative_cost_rmb():.2f}", flush=True)
    for sid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{sid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        called = sum(1 for x in rec["reps"] if x.get("structural", {}).get("called"))
        print(f"{sid:18s} {rec['surface']:16s} reps={len(rec['reps'])} called={called}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")
    print(f"ROUND2-COMPLEX GEN DONE; n={reps}; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 30)
