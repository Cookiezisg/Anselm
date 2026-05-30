"""Wave-10: VALIDATE the proposed `when:`-branch case-node design (don't just recommend — test it).

Key-match contract (expression value == branch key) scored 0-18% on boolean conditions (wave-9).
Hypothesis: per-branch `when: <bool CEL>` guards (no key matching) eliminate the mismatch → high.
If confirmed, the design recommendation is EMPIRICALLY validated.

Same 3 CEL tasks as wave-9, but the tool uses `when:` semantics. Output: /tmp/w10/<id>.json
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

OUT = Path("/tmp/w10"); OUT.mkdir(exist_ok=True)

WHEN_TOOL = [cat.tool(
    "set_case_branches",
    ("Configure a case node's branches. EACH branch has a `when` boolean-CEL guard; branches are "
     "evaluated TOP-TO-BOTTOM and the FIRST branch whose `when` is true wins. Add a final catch-all "
     "branch with when:\"true\" as the default. There is NO expression-value-to-key matching — you just "
     "write one boolean condition per branch (over payload/ctx, null-safe with has()).\n"
     "Example:\n"
     "  set_case_branches(id=\"wf_x\", nodeId=\"gate\", branches={\n"
     "    \"fast\":   {\"when\": \"payload.vip || payload.amount >= 5000\", \"to\": \"f\"},\n"
     "    \"normal\": {\"when\": \"true\", \"to\": \"n\"}\n"
     "  })"),
    ["id", "nodeId", "branches"],
    {"id": {"type": "string"}, "nodeId": {"type": "string"},
     "branches": {"type": "object", "description": "{<name>: {when: <bool CEL>, to: <nodeId>, emit?}}; first true wins; final when:\"true\" = default"}},
)]

SCEN = [
    {"id": "when_compound",
     "user": "在 wf_x 的 case 节点 'gate' 上配置:payload.vip 为 true 或 payload.amount >= 5000 时走 fast(to=f),否则 normal(to=n)。",
     "intent": "branch fast when vip||amount>=5000; normal default.",
     "rubric": ["fast branch when = payload.vip || payload.amount >= 5000 (correct boolean)", "normal branch is default (when true) → n", "fast → f", "ordered so fast checked before default", "null-safe if needed", "NO branch-key-vs-boolean mismatch (by design every branch has a when)"]},
    {"id": "when_nullguard",
     "user": "在 wf_x 的 case 节点 'has_user' 上:payload 有 user 且 user.email 非空走 notify(to=nt),否则 skip(to=sk)。",
     "intent": "branch notify when has(user)&&email!=''; skip default.",
     "rubric": ["notify when = has(payload.user) && payload.user.email != '' (null-safe)", "skip is default (when true) → sk", "notify → nt", "ordered notify-before-default", "null-safe has() used"]},
    {"id": "when_3way",
     "user": "在 wf_x 的 case 节点 'pri' 上:payload.score >= 80 走 high(to=h),>= 50 走 mid(to=m),否则 low(to=l)。",
     "intent": "high when score>=80; mid when score>=50; low default.",
     "rubric": ["high when = payload.score >= 80", "mid when = payload.score >= 50", "low default (when true)", "ORDER correct: high before mid before low (so 90→high not mid)", "targets h/m/l", "thresholds >= correct"]},
]


def run(reps=12, workers=14):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {s["id"]: {**{k: s[k] for k in ("id", "intent", "rubric", "user")}, "surface": "cel_when", "mode": "ARTIFACT", "reps": []} for s in SCEN}
    jobs = [(s, i) for s in SCEN for i in range(reps)]
    budget = {"v": False}

    def work(job):
        s, i = job
        if budget["v"]:
            return (s["id"], None)
        try:
            res = ds.chat_complete(messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}],
                                   tools=WHEN_TOOL, scenario=f"w10_{s['id']}", variant="when", max_tokens=6000, disable_thinking=False)
            tcs = res.effective_tool_calls
            return (s["id"], {"rep": i, "content": res.content,
                              "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
                              "called": bool(tcs), "cost_rmb": round(res.cost_entry.cost_rmb, 6)})
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
            if done % 9 == 0:
                print(f"... {done}/{len(jobs)}; ¥{ds.cumulative_cost_rmb():.2f}", flush=True)

    for sid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{sid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        called = sum(1 for x in rec["reps"] if x.get("called"))
        print(f"{sid:16s} reps={len(rec['reps'])} called={called}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")
    print(f"WAVE-10 GEN DONE; ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 12)
