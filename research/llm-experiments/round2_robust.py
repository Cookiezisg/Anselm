"""Round-2 robustness: re-run a curated set of validated scenarios across ALL surfaces at
n=50, temperature=DEFAULT (API default ≈ production realistic), for statistically firm numbers + CIs.

Pulls the best/representative scenarios from waves 1/9/10/11 (no re-declaration drift).
Output: /tmp/r2/<id>.json  (consumed by wf_judge_r2.js)
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args, structural, SCENARIOS as W1
from wave9_gen import SCEN as W9
from wave10_when import SCEN as W10, WHEN_TOOL
from wave11_freshwf import SCEN as W11

OUT = Path("/tmp/r2"); OUT.mkdir(exist_ok=True)
WF = cat.workflow_tools("V3-full-teaching")

W1b = {s["id"]: s for s in W1}; W9b = {s["id"]: s for s in W9}
W10b = {s["id"]: s for s in W10}; W11b = {s["id"]: s for s in W11}


def norm(s, tools, surface, mode):
    d = {"id": s["id"], "surface": surface, "mode": mode, "tools": tools,
         "user": s["user"], "intent": s["intent"], "rubric": s["rubric"]}
    if "code_test" in s:
        d["code_test"] = s["code_test"]
    return d


CURATED = []
for sid in ["wf_order_fulfill", "wf_content_mod", "wf_lead_scoring", "wf_backup_retry", "wf_expense_approval"]:
    CURATED.append(norm(W11b[sid], WF, "create_workflow", "ARTIFACT"))
for sid in ["wf_clear_triage", "wf_branch_signup"]:
    CURATED.append(norm(W1b[sid], WF, "create_workflow", "ARTIFACT"))
for sid in ["ag_router", "ag_extract_invoice", "ag_trap_pdf"]:
    CURATED.append(W9b[sid])
for sid in ["fn_dedup", "fn_validate_email", "fp_status_poll"]:
    CURATED.append(W9b[sid])
CURATED.append(W1b["fn_workdays"])
CURATED.append(W9b["hd_ratelimit"])
for sid in ["hd_oauth", "hd_cache_ttl"]:
    CURATED.append(W1b[sid])
for sid in ["when_compound", "when_nullguard", "when_3way"]:
    CURATED.append(norm(W10b[sid], WHEN_TOOL, "cel_when", "ARTIFACT"))


def run(reps=50, workers=24):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {}
    for s in CURATED:
        r = {k: s[k] for k in ("id", "surface", "mode", "intent", "rubric", "user")}
        if "code_test" in s:
            r["code_test"] = s["code_test"]
        r["reps"] = []
        recs[s["id"]] = r
    jobs = [(s, i) for s in CURATED for i in range(reps)]
    budget = {"v": False}

    def work(job):
        s, i = job
        if budget["v"]:
            return (s["id"], None)
        try:
            res = ds.chat_complete(messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}],
                                   tools=s["tools"], scenario=f"r2_{s['id']}", variant="robust",
                                   temperature=None, max_tokens=16000, disable_thinking=False)  # temp=None → API default
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
            if done % 25 == 0:
                print(f"... {done}/{len(jobs)}; ¥{ds.cumulative_cost_rmb():.2f}", flush=True)

    for sid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{sid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        called = sum(1 for x in rec["reps"] if x.get("structural", {}).get("called"))
        errs = sum(1 for x in rec["reps"] if x.get("error"))
        print(f"{sid:20s} {rec['surface']:16s} reps={len(rec['reps'])} called={called} err={errs}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")
    print(f"ROUND2-ROBUST GEN DONE; n/scenario={reps}; cumulative ¥{ds.cumulative_cost_rmb():.2f}; {len(CURATED)} scenarios")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 50)
