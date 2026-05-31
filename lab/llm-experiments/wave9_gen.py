"""Wave-9 breadth: NEW diverse scenarios per strong surface — confirm the 90-100% rates GENERALIZE
beyond the hand-picked wave-1 scenarios (the wf generalization check proved hand-picks can mislead).

Reuses wave1_gen machinery. Output: /tmp/w9/<id>.json
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args, structural, handler_tool

OUT = Path("/tmp/w9"); OUT.mkdir(exist_ok=True)
AG = cat.agent_tools("V3-full")
FN = cat.function_tools("V5-combined")
HD = handler_tool()
CEL = [cat.workflow_split_tools()[2]]

SCEN = [
    # ---- agent (confirm 90% generalizes; incl a NEW impossible-capability trap) ----
    {"id": "ag_router", "surface": "create_agent", "mode": "ARTIFACT", "tools": AG,
     "user": "做个 agent,把支持工单路由到 billing / technical / sales 三个团队之一。",
     "intent": "agent enum-routing tickets to billing/technical/sales.",
     "rubric": ["outputSchema kind=enum", "enum values = billing/technical/sales", "prompt routes a ticket", "no platform tools", "uses {{payload.*}}"]},
    {"id": "ag_extract_invoice", "surface": "create_agent", "mode": "ARTIFACT", "tools": AG,
     "user": "做个 agent,从发票文本里提取 发票号、开票日期、总金额。",
     "intent": "agent json_schema extracting invoice_no/date/total.",
     "rubric": ["outputSchema kind=json_schema", "fields: invoice_no, date, total (sensible types)", "prompt extracts from invoice text", "no platform tools", "{{payload.*}}"]},
    {"id": "ag_trap_pdf", "surface": "create_agent", "mode": "ARTIFACT", "tools": AG,
     "user": "做个 agent,读取本地一个 PDF 合同文件,总结关键条款。",
     "intent": "TRAP: agent has no file tool — cannot read a local PDF. Correct: take the contract TEXT as payload input, OR mount a forge fn that extracts PDF text; NOT assume it can read files.",
     "rubric": ["does NOT assume the agent can read a local file/PDF itself", "correct: contract text as {{payload.*}} input OR mounts a forge fn for PDF extraction", "no platform file tool mounted", "did not hallucinate file-reading capability"]},
    # ---- function (confirm 90%; diverse algorithms) ----
    {"id": "fn_dedup", "surface": "create_function", "mode": "CODE", "tools": FN,
     "user": "写个函数,给一个 list of dict,按 'id' 字段去重,保留首次出现。",
     "intent": "normal fn dedup list[dict] by 'id', keep first.",
     "rubric": ["kind normal", "dedups by id keeping first occurrence", "valid Python RUNS", "correct output on test"],
     "code_test": {"expected_behavior": "[{'id':1,'v':'a'},{'id':2,'v':'b'},{'id':1,'v':'c'}] → [{'id':1,'v':'a'},{'id':2,'v':'b'}] (keep first id=1).", "test_inputs": ["[{'id':1,'v':'a'},{'id':2,'v':'b'},{'id':1,'v':'c'}]"], "mocks_hint": "pure; no deps."}},
    {"id": "fn_validate_email", "surface": "create_function", "mode": "CODE", "tools": FN,
     "user": "写个函数,校验一个字符串是不是合法 email,返回 True/False。",
     "intent": "normal fn validate email → bool.",
     "rubric": ["kind normal", "returns bool", "accepts a@b.com, rejects 'abc'/'a@'/'@b.com'", "valid Python RUNS", "reasonable validation"],
     "code_test": {"expected_behavior": "'alice@example.com'→True; 'abc'→False; 'a@'→False; '@b.com'→False.", "test_inputs": ["'alice@example.com'", "'abc'", "'a@'"], "mocks_hint": "pure; re module fine."}},
    {"id": "fp_status_poll", "surface": "create_function", "mode": "CODE", "tools": FN,
     "user": "写个 polling 函数,轮询一个任务状态接口,只在状态变成 'done' 时返回一个事件。",
     "intent": "polling fn: poll status endpoint; emit an event only when status transitions to done; cursor tracks last seen status; no dup.",
     "rubric": ["kind polling + interval", "poll(last_cursor)->{events,next_cursor}", "emits only on transition to done (not every poll while done)", "cursor tracks status so no duplicate done-event", "valid Python RUNS against a mocked status source"],
     "code_test": {"expected_behavior": "Mock status fn. poll(None) status=running → [] cursor=running. status→done, poll → 1 done-event, cursor=done. poll again still done → [] (no dup).", "test_inputs": ["poll(None) running, then done, then done again"], "mocks_hint": "stub the status fetch to return controllable status; mutate between polls."}},
    # ---- handler (confirm 100%; stateful) ----
    {"id": "hd_ratelimit", "surface": "create_handler", "mode": "CODE", "tools": HD,
     "user": "写个 handler 做令牌桶限流:allow(now) 返回是否放行,每秒补充 N 个令牌,桶容量 C。",
     "intent": "token-bucket rate limiter handler; allow(now) bool; refill N/s, capacity C; bare-names.",
     "rubric": ["class holds tokens + last_refill state", "allow(now) refills based on elapsed, caps at C, consumes 1 if available", "bare-named params (now), init bare (rate, capacity)", "init/methods schema match", "valid Python; burst then deplete then refill works"],
     "code_test": {"expected_behavior": "rate=1/s cap=2. allow(0)=True allow(0)=True allow(0)=False (depleted). allow(2)=True (refilled).", "test_inputs": ["init(rate=1,capacity=2); allow(0)x3 then allow(2)"], "mocks_hint": "pass now explicitly; no real clock."}},
    # ---- CEL (confirm 82%; diverse conditions) ----
    {"id": "cel_3way", "surface": "cel_case", "mode": "ARTIFACT", "tools": CEL,
     "user": "在 wf_x 的 case 节点 'pri' 上:payload.score >= 80 走 high(to=h),>=50 走 mid(to=m),否则 low(to=l)。",
     "intent": "CEL 3-way: score>=80→high, >=50→mid, else low; ternary returning key.",
     "rubric": ["expression returns one of high/mid/low matching branch keys (nested ternary)", ">=80 high, >=50 mid, else low — thresholds correct + ordered", "branches h/m/l targets", "no boolean-vs-string-key mismatch"]},
    {"id": "cel_compound", "surface": "cel_case", "mode": "ARTIFACT", "tools": CEL,
     "user": "在 wf_x 的 case 节点 'gate' 上:payload.vip 为 true 或 payload.amount >= 5000 时走 fast(to=f),否则 normal(to=n)。",
     "intent": "CEL: vip || amount>=5000 → fast, else normal.",
     "rubric": ["expression encodes vip==true OR amount>=5000", "boolean expr → keys true/false OR ternary returning fast/normal", "null-safe", "branch targets correct", "no boolean↔string-key mismatch"]},
    {"id": "cel_nullguard", "surface": "cel_case", "mode": "ARTIFACT", "tools": CEL,
     "user": "在 wf_x 的 case 节点 'has_user' 上:如果 payload 有 user 且 user.email 非空走 notify(to=nt),否则 skip(to=sk)。",
     "intent": "CEL: has(payload.user) && payload.user.email != '' → notify, else skip.",
     "rubric": ["has(payload.user) before deref (null-safe)", "checks user.email != ''", "ternary/boolean→key mapping correct", "notify/skip targets"]},
]


def run(reps=12, workers=14):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {}
    for sc in SCEN:
        r = {k: sc[k] for k in ("id", "surface", "mode", "intent", "rubric", "user")}
        if "code_test" in sc:
            r["code_test"] = sc["code_test"]
        r["reps"] = []
        recs[sc["id"]] = r
    jobs = [(sc, i) for sc in SCEN for i in range(reps)]
    budget = {"v": False}

    def work(job):
        sc, i = job
        if budget["v"]:
            return (sc["id"], None)
        try:
            res = ds.chat_complete(messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": sc["user"]}],
                                   tools=sc["tools"], scenario=f"w9_{sc['id']}", variant="breadth", max_tokens=16000, disable_thinking=False)
            tcs = res.effective_tool_calls
            return (sc["id"], {"rep": i, "content": res.content,
                               "reasoning": (res.raw_response.get("choices", [{}])[0].get("message", {}) or {}).get("reasoning_content", ""),
                               "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
                               "structural": structural(sc["surface"], tcs), "cost_rmb": round(res.cost_entry.cost_rmb, 6)})
        except ds.BudgetExhausted as e:
            budget["v"] = True
            return (sc["id"], {"rep": i, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (sc["id"], {"rep": i, "error": f"{type(e).__name__}: {e}"})

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
        print(f"{sid:20s} {rec['surface']:16s} reps={len(rec['reps'])} called={called}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")
    print(f"WAVE-9 GEN DONE; ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 12)
