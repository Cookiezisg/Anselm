"""Wave-3 USAGE selection sweep: offer the FULL 91-tool set, check the model picks the right tool.

This is the hardest selection condition (max disambiguation pressure) + the 11%-leak / wrong-family
concern. Many tasks are DISAMBIGUATION TRAPS (Read vs read_document; write_memory vs create_document;
forge-a-function vs mount-Bash/WebFetch on a worker). Burns DeepSeek with a large (cached) prompt.

Output: /tmp/w3/<task_id>.json — {id, task, intended, acceptable, trap, reps:[{rep, picked, args, hit}]}
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import deepseek_client as ds
from spec_catalog import ALL_TOOLS

try:
    from json_repair import repair_json
except Exception:
    repair_json = None

OUT = Path("/tmp/w3"); OUT.mkdir(exist_ok=True)

SYSTEM = """You are Forgify's chat agent — the user's AI automation engineer. You have a LARGE toolset.
For each request, pick the SINGLE most appropriate tool and call it. Disambiguate carefully:
- Forgify entities (functions/handlers/agents/workflows/documents) are managed by their OWN tools
  (get_function / read_document / ...), NOT the local-file tools (Read/Write are for the user's own disk files).
- A workflow/agent is a worker: to give it an external capability (web/db/shell/email), you FORGE a function —
  you never hand a worker the platform Bash/WebFetch.
- A capability needing LLM JUDGMENT (classify / 分类 / 抽取 / 路由 / 总结 / 打分) → create_agent (an LLM worker);
  deterministic logic → create_function. "做个分类器/打分器" = create_agent, NOT a function.
- Save to the KNOWLEDGE BASE / 存到知识库 / 团队文档 → create_document (a Forgify document), NOT local-file
  tools (Glob/Write/Read are for the user's own disk files only).
- Long-term cross-conversation facts → memory; this-conversation steps → todos.
Every tool call includes `summary`."""

# id, task, intended (best tool), acceptable (also-correct), trap note, family
TASKS = [
    # ---- version / lifecycle (under-tested) ----
    ("undo_fn", "把 fn_parse_csv 回退到上一个版本，上次的改动搞坏了。", "revert_function", [], "revert vs edit", "function"),
    ("versions_fn", "fn_send_email 都有哪些历史版本？我想看看。", "get_function_versions", [], "", "function"),
    ("deactivate_wf", "先把 wf_daily_report 下线，我要改东西。", "deactivate_workflow", [], "deactivate vs delete", "lifecycle"),
    ("delete_ag", "把那个没用的 ag_old_classifier 删了。", "delete_agent", [], "delete vs deactivate", "agent"),
    ("precheck_wf", "wf_orders 能直接上线吗？先帮我检查下引用的东西全不全。", "capability_check_workflow", [], "precheck vs activate", "workflow"),
    ("accept_fn", "刚改的 fn_x 试跑没问题了，发布成正式版吧。", "accept_pending_function", [], "", "function"),
    # ---- runtime / diagnosis (under-tested) ----
    ("cancel_run", "fr_88 这个跑了半天卡住了，取消掉。", "cancel_flowrun", [], "", "runtime"),
    ("node_state", "wf_orders 最新这次跑到哪一步了，每个节点啥状态？", "get_flowrun_nodes", ["get_flowrun_trace"], "", "runtime"),
    ("clear_dl", "wf_orders 的死信我都处理完了，批量清掉。", "clear_dead_letters", [], "", "diagnosis"),
    ("why_failed", "wf_orders 老是失败，帮我查查为啥。", "search_flowruns", ["query_events", "list_dead_letters"], "investigate-first", "diagnosis"),
    # ---- mcp (under-tested) ----
    ("install_mcp", "我想接 Notion，但好像还没装，帮我装上。", "install_mcp_from_registry", [], "install vs search", "mcp"),
    ("mcp_health", "slack 那个 mcp 连不上了吧？检查下。", "health_check_mcp", [], "", "mcp"),
    # ---- skill ----
    ("find_skill", "有没有现成的'写周报'方法论可以用？", "search_skills", [], "", "skill"),
    ("use_skill", "把 summarization 这个 skill 用起来。", "activate_skill", [], "", "skill"),
    # ---- document vs memory vs file (THE disambiguation traps) ----
    ("read_localfile", "读一下我电脑上 ~/Desktop/notes.md 这个文件。", "Read", [], "TRAP: local file → Read, NOT read_document", "base"),
    ("read_kb", "看下我知识库里那篇《报销流程》文档写了啥。", "read_document", [], "TRAP: KB doc → read_document, NOT Read", "document"),
    ("save_knowledge", "把这套《新人入职 checklist》存到知识库，以后给 agent 用。", "create_document", [], "TRAP: shareable knowledge → document", "document"),
    ("remember_pref", "记住我以后所有报告都要中文、PDF 格式。", "write_memory", [], "TRAP: durable preference → memory, NOT document", "memory"),
    ("recall", "我之前让你记的那个 API key 命名规则是啥来着？", "read_memory", [], "", "memory"),
    # ---- forge-vs-platform traps (worker capability) ----
    ("wf_needs_web", "我要做个 workflow 每天抓某网页的价格，给 workflow 加上抓网页的能力。", "create_function", ["search_functions"], "TRAP: worker web cap → forge fn, NOT WebFetch", "function"),
    ("wf_needs_shell", "workflow 里要跑一段 shell 脚本清理临时文件，怎么加？", "create_function", ["create_handler", "search_functions"], "TRAP: worker shell → forge fn, NOT Bash", "function"),
    ("boss_web", "帮我查下今天美元对人民币汇率。", "WebSearch", ["WebFetch"], "boss research → web ok", "base"),
    # ---- forge CRUD selection (entity-type disambiguation) ----
    ("find_fn", "找一下有没有发邮件的函数。", "search_functions", [], "fn not doc", "function"),
    ("find_wf", "我那个发日报的流程叫啥来着，搜一下。", "search_workflows", [], "", "workflow"),
    ("stateful_thing", "我要个东西维护数据库连接池，反复用。", "create_handler", ["search_handlers"], "stateful → handler not function", "handler"),
    ("make_classifier", "做个把工单分高/中/低优先级的分类器。", "create_agent", [], "classifier → agent", "agent"),
    ("inspect_handler", "看下 hd_db_pool 这个 handler 有哪些方法、怎么初始化。", "get_handler", [], "", "handler"),
    ("test_agent", "ag_support 改完了，拿条样例输入试跑看看效果。", "run_agent", [], "run not get", "agent"),
    ("history_calls", "hd_oauth 最近都被调用过几次？", "search_handler_calls", [], "", "handler"),
    # ---- workflow ops via edit (not create) ----
    ("add_step", "给 wf_daily_report 在发送前加一步人工审批。", "get_workflow", ["edit_workflow"], "read-before-edit", "workflow"),
    ("trigger_now", "手动触发一下 wf_report 的 manual 入口，payload 给今天日期。", "trigger_workflow", [], "", "lifecycle"),
    # ---- meta / lazy ----
    ("slack_msg", "用 Slack 给 #general 发个'上线完成'。", "activate_tools", ["search_mcp_tools", "list_mcp_servers"], "lazy: activate mcp first", "base"),
    ("multistep_plan", "帮我把'建分类agent→建3个函数→接进workflow→上线'这一串做了。", "TodoCreate", ["search_agents", "create_agent"], "multi-step → plan/todo ok or start", "base"),
    # ---- ambiguous-but-answerable ----
    ("doc_edit", "知识库里《报销流程》那篇，把额度从 500 改成 1000。", "read_document", ["edit_document", "search_documents"], "read/search then edit", "document"),
]


def parse_args(tc):
    fn = tc.get("function") or tc
    a = fn.get("arguments") if isinstance(fn, dict) else None
    if isinstance(a, str):
        try:
            return json.loads(a, strict=False)
        except Exception:
            if repair_json:
                try:
                    r = repair_json(a, return_objects=True)
                    if isinstance(r, dict):
                        return r
                except Exception:
                    pass
            return {"_unparseable": a[:300]}
    return a if isinstance(a, dict) else {}


def _one(task, rep):
    tid, msg, intended, acceptable, trap, fam = task
    res = ds.chat_complete(
        messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": msg}],
        tools=ALL_TOOLS, scenario=f"w3_{tid}", variant="sweep",
        max_tokens=4000, disable_thinking=False,
    )
    tcs = res.effective_tool_calls
    picked = (tcs[0].get("function") or tcs[0]).get("name") if tcs else None
    args = parse_args(tcs[0]) if tcs else {}
    ok = picked in ([intended] + acceptable)
    return {"rep": rep, "picked": picked, "args": args, "hit": ok, "leaked": bool(res.leaked_tool_calls), "cost_rmb": round(res.cost_entry.cost_rmb, 6)}


def run(reps=5, workers=14, only=None):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    tasks = [t for t in TASKS if not only or only in t[0]]
    recs = {t[0]: {"id": t[0], "task": t[1], "intended": t[2], "acceptable": t[3], "trap": t[4], "family": t[5], "reps": []} for t in tasks}
    jobs = [(t, r) for t in tasks for r in range(reps)]
    budget = {"v": False}

    def work(job):
        t, r = job
        if budget["v"]:
            return (t[0], None)
        try:
            return (t[0], _one(t, r))
        except ds.BudgetExhausted as e:
            budget["v"] = True
            return (t[0], {"rep": r, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (t[0], {"rep": r, "error": f"{type(e).__name__}: {e}"})

    done = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(work, j) for j in jobs]
        for fut in cf.as_completed(futs):
            tid, rep = fut.result()
            if rep:
                recs[tid]["reps"].append(rep)
            done += 1
            if done % 20 == 0:
                print(f"... {done}/{len(jobs)} calls; cumulative ¥{ds.cumulative_cost_rmb():.2f}", flush=True)

    hits = tot = 0
    for tid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{tid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        h = sum(1 for x in rec["reps"] if x.get("hit"))
        n = sum(1 for x in rec["reps"] if "hit" in x)
        hits += h; tot += n
        flag = "" if (n and h == n) else ("  <-- MISS" if n else "")
        print(f"{tid:18s} {rec['family']:10s} intended={rec['intended']:26s} hit={h}/{n}{flag}")
    if budget["v"]:
        print("\n*** BUDGET EXHAUSTED ***")
    print(f"\nWAVE-3 SWEEP: structural selection hit {hits}/{tot} = {100*hits/max(1,tot):.1f}%; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 5)
