"""R3-C: end-to-end ALL-FIXES re-test. Re-run the HARD complex workflow + cel_when scenarios with
the G10-COMPLIANT pinned create_workflow schema (when: branches + per-node-type config pinned) +
workflow teaching in the system prompt. Compare vs the baseline complex run (standard V3 tool).
Output /tmp/r3cres/<surface>.json (judged by wf_judge_r3cx.js pointed at r3cres). temp=default.
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args
from round3_pinned_wf import pinned_workflow_tools

SCEN = Path("/tmp/r3complex"); RES = Path("/tmp/r3cres"); RES.mkdir(exist_ok=True)
TOOLS = pinned_workflow_tools()
# workflow teaching appended (when: design is in the schema; this adds the data-flow/retry rules, G6 recency).
WF_TEACH = ("\n\n构图守则:① cron/manual 触发不带业务数据,触发后第一个节点必须先 fetch(调 fn/hd 拉数据),"
            "再给后续节点。② case 路由用每分支 when 布尔守卫(首个为真胜出,最后一条 when:'true' 兜底),"
            "不要用 add_edge 连 case 的出口。③ 重试回边必须 emit 自增计数且有界(如 (has(payload.attempt)?payload.attempt:0)<3)。"
            "④ 终止节点省略 to。⑤ 一次 create_workflow 把完整图建全。")
SYSP = SYSTEM + WF_TEACH


def run(workers=24):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    budget = {"v": False}
    for surf in ("create_workflow", "cel_when"):
        f = SCEN / f"{surf}.json"
        if not f.exists():
            continue
        scens = json.loads(f.read_text())

        def work(s):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": SYSP}, {"role": "user", "content": s["user"]}]
                res = ds.chat_complete(messages=msgs, tools=TOOLS, scenario=f"r3c_{surf}", variant="allfixes",
                                       temperature=None, max_tokens=16000, disable_thinking=False)
                tcs = res.effective_tool_calls
                tc = [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs]
                return {"id": s["id"], "user": s["user"], "intent": s.get("intent", ""), "rubric": s.get("rubric", []),
                        "expected_tool": "create_workflow", "called": [c["name"] for c in tc], "tool_calls": tc, "code": ""}
            except ds.BudgetExhausted:
                budget["v"] = True
                return None
            except Exception as e:
                return {"id": s.get("id"), "error": f"{type(e).__name__}: {e}"}

        results = []
        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            for fut in cf.as_completed([ex.submit(work, s) for s in scens]):
                r = fut.result()
                if r:
                    results.append(r)
        results.sort(key=lambda x: x.get("id", ""))
        (RES / f"{surf}.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
        print(f"== {surf} (all-fixes): {len(results)} ran | ¥{ds.cumulative_cost_rmb():.2f}", flush=True)
        if budget["v"]:
            print("*** BUDGET EXHAUSTED ***"); break
    print(f"R3-C done; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run()
