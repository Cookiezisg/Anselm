"""Round-2 C (new dimensions): long-context degradation, injected fields (destructive/execution_group),
agent knowledge/skill mounting. n=30. Output: /tmp/r2n/<id>.json

(self-consistency is computed separately by analyzing the n=50 robustness reps — no new gen.)
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

OUT = Path("/tmp/r2n"); OUT.mkdir(exist_ok=True)

# ---- a LARGE fake asset catalog (~60 entities) to bloat context ----
_FN = ["fn_send_email:发送邮件给收件人", "fn_send_sms:发短信", "fn_fetch_orders:拉取订单列表", "fn_lookup_customer:按id查客户",
       "fn_calc_tax:算税", "fn_format_invoice:格式化发票HTML", "fn_parse_csv:解析CSV", "fn_validate_address:校验地址",
       "fn_charge_card:信用卡扣款", "fn_refund:退款", "fn_export_pdf:导出PDF", "fn_compress_image:压缩图片",
       "fn_translate:翻译文本", "fn_summarize_doc:总结文档", "fn_geocode:地址转坐标", "fn_currency_convert:汇率换算",
       "fn_check_inventory:查库存", "fn_reserve_stock:预留库存", "fn_notify_slack:发Slack", "fn_create_ticket:建工单"]
_HD = ["hd_db_pool:数据库连接池", "hd_oauth_token:OAuth令牌管理", "hd_redis_cache:Redis缓存", "hd_s3_client:S3客户端",
       "hd_rate_limiter:限流器", "hd_session_store:会话存储", "hd_kafka_producer:Kafka生产者", "hd_smtp_conn:SMTP连接"]
_AG = ["ag_classifier:工单分类", "ag_summarizer:文本总结", "ag_sentiment:情感分析", "ag_extractor:字段抽取",
       "ag_translator:翻译agent", "ag_router:意图路由", "ag_responder:客服回复生成", "ag_scorer:线索打分"]
_WF = ["wf_daily_report:每日报告", "wf_order_pipeline:订单处理", "wf_onboarding:新用户引导", "wf_billing:账单",
       "wf_support_triage:工单分流", "wf_backup:备份", "wf_lead_nurture:线索培育", "wf_content_moderation:内容审核"]
BIG_CATALOG = "Existing assets in this account (reference by id):\n" + "\n".join(
    f"  {e}" for e in (_FN + _HD + _AG + _WF))
LONG_HISTORY = [  # bloat the conversation
    {"role": "user", "content": "先帮我看看账户里都有些什么资产。"},
    {"role": "assistant", "content": "你的账户里有 " + str(len(_FN)) + " 个函数、" + str(len(_HD)) + " 个 handler、" + str(len(_AG)) + " 个 agent、" + str(len(_WF)) + " 个 workflow。" + BIG_CATALOG[:400] + " ...(完整见 catalog)。需要我做什么?"},
    {"role": "user", "content": "嗯先不动,我想想。"},
    {"role": "assistant", "content": "好的,随时说。"},
]

# ---- injected-field tools (summary/destructive/execution_group per §S18) ----
def injected_tools():
    inj = {"summary": {"type": "string", "description": "One sentence: what you're doing and why."},
           "destructive": {"type": "boolean", "description": "true if this operation is irreversible/destructive."},
           "execution_group": {"type": "integer", "description": "same group runs in parallel; ascending groups run serially."}}
    def t(name, desc, req, props):
        p = {**props, **inj}
        return {"type": "function", "function": {"name": name, "description": desc, "parameters": {"type": "object", "required": req, "properties": p, "additionalProperties": False}}}
    return [
        t("delete_function", "Soft-delete a function (irreversible-ish; affects referencing workflows).", ["id"], {"id": {"type": "string"}}),
        t("delete_workflow", "Soft-delete a workflow.", ["id"], {"id": {"type": "string"}}),
        t("get_function", "Read a function's code/signature.", ["id"], {"id": {"type": "string"}}),
        t("run_function", "Test-run a function with args.", ["id", "args"], {"id": {"type": "string"}, "args": {"type": "object"}}),
        t("search_functions", "Find functions by query.", ["query"], {"query": {"type": "string"}}),
    ]

INJ_NOTE = ("\n\nEvery tool call MUST include: summary (one sentence), destructive (true ONLY if irreversible like delete),"
            " execution_group (int; independent ops that can run in parallel share a group; dependent ops use ascending groups).")

SCEN = [
    # ---- long-context degradation (find the right entity among ~60) ----
    {"id": "lc_pick_email", "system": SYSTEM + "\n\n" + BIG_CATALOG, "history": LONG_HISTORY,
     "tools": [cat.tool("call_callable", "Call an existing forge callable by id with args.", ["id", "args"], {"id": {"type": "string"}, "args": {"type": "object"}})],
     "user": "现在用现有的发邮件能力给 customer@acme.com 发个'订单已发货'通知。",
     "intent": "pick fn_send_email (NOT fn_send_sms / fn_notify_slack) from the 60-entity catalog.",
     "rubric": ["calls call_callable with id=fn_send_email (the right one, not sms/slack)", "args include the recipient + message", "does NOT hallucinate a non-existent id", "not confused by the 60-entity catalog"]},
    {"id": "lc_pick_wf", "system": SYSTEM + "\n\n" + BIG_CATALOG, "history": LONG_HISTORY,
     "tools": [cat.tool("get_workflow", "Get a workflow's graph.", ["id"], {"id": {"type": "string"}}), cat.tool("search_workflows", "Find workflows.", ["query"], {"query": {"type": "string"}})],
     "user": "把那个处理订单的流程调出来看看。",
     "intent": "identify wf_order_pipeline (the order one) among 8 workflows + 60 total entities.",
     "rubric": ["targets wf_order_pipeline (the order-processing one) via get_workflow or search_workflows", "does not pick a wrong workflow (billing/backup/etc.)", "no hallucinated id"]},
    {"id": "lc_pick_handler", "system": SYSTEM + "\n\n" + BIG_CATALOG, "history": LONG_HISTORY,
     "tools": [cat.tool("get_handler", "Get a handler's def.", ["id"], {"id": {"type": "string"}}), cat.tool("search_handlers", "Find handlers.", ["query"], {"query": {"type": "string"}})],
     "user": "看下管数据库连接的那个 handler 是怎么配的。",
     "intent": "identify hd_db_pool among 8 handlers.",
     "rubric": ["targets hd_db_pool (the db connection one)", "not a wrong handler (oauth/redis/s3)", "no hallucinated id"]},
    # ---- injected fields (destructive / execution_group) ----
    {"id": "inj_destructive", "system": SYSTEM + INJ_NOTE, "history": [],
     "tools": injected_tools(),
     "user": "把 fn_old_unused 这个没用的函数直接删了(id 就是 fn_old_unused,无需先 search)。",
     "intent": "delete_function with destructive=true + summary.",
     "rubric": ["calls delete_function(fn_old_unused)", "destructive=true (it IS irreversible)", "summary present + on-point", "execution_group present (int)"]},
    {"id": "inj_parallel", "system": SYSTEM + INJ_NOTE, "history": [],
     "tools": injected_tools(),
     "user": "帮我同时试跑 fn_a、fn_b、fn_c 三个函数(id 就是这三个,互不依赖,无需先 search),各传空参数。",
     "intent": "3 run_function calls, independent → SAME execution_group (parallel), destructive=false, summaries.",
     "rubric": ["3 run_function calls (a/b/c)", "all destructive=false (test-run isn't destructive)", "independent ops share the SAME execution_group (parallel)", "summaries present"]},
    {"id": "inj_mixed", "system": SYSTEM + INJ_NOTE, "history": [],
     "tools": injected_tools(),
     "user": "用 get_function 看一下 fn_x 的代码(id 就是 fn_x,无需 search),然后基于它试跑一次。",
     "intent": "get_function then run_function — DEPENDENT → ascending execution_groups; both destructive=false.",
     "rubric": ["get_function then run_function", "dependent ops use ASCENDING execution_groups (get group < run group)", "both destructive=false", "summaries present"]},
    # ---- agent knowledge / skill mounting ----
    {"id": "km_knowledge", "system": SYSTEM, "history": [],
     "tools": cat.agent_tools("V3-full"),
     "user": "做个客服 agent,要参考我知识库里的《退款政策》和《SLA 文档》两篇文档来回答。",
     "intent": "create_agent with knowledge = [those 2 docs] mounted (set_knowledge); prompt references them.",
     "rubric": ["create_agent with a set_knowledge op mounting the 2 documents", "knowledge holds doc refs (not pasted into prompt)", "prompt references using the knowledge", "no platform tools"]},
    {"id": "km_skill", "system": SYSTEM, "history": [],
     "tools": cat.agent_tools("V3-full"),
     "user": "做个写周报的 agent,用'summarization'这个 skill 作为方法论。",
     "intent": "create_agent with set_skill='summarization' + a prompt (skill pre-activated, prompt still required).",
     "rubric": ["create_agent with set_skill = summarization", "prompt still present (skill is methodology, prompt is the task)", "no platform tools", "outputSchema sensible"]},
]


def run(reps=30, workers=24, only=None):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    scen = [s for s in SCEN if not only or only in s["id"]]
    recs = {s["id"]: {**{k: s[k] for k in ("id", "intent", "rubric", "user")}, "reps": []} for s in scen}
    jobs = [(s, i) for s in scen for i in range(reps)]
    budget = {"v": False}

    def work(job):
        s, i = job
        if budget["v"]:
            return (s["id"], None)
        try:
            msgs = [{"role": "system", "content": s["system"]}] + s.get("history", []) + [{"role": "user", "content": s["user"]}]
            res = ds.chat_complete(messages=msgs, tools=s["tools"], scenario=f"r2n_{s['id']}", variant="newdim",
                                   temperature=None, max_tokens=8000, disable_thinking=False)
            tcs = res.effective_tool_calls
            return (s["id"], {"rep": i, "content": res.content,
                              "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
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
        print(f"{sid:16s} reps={len(rec['reps'])}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")
    print(f"ROUND2-NEWDIM GEN DONE; n={reps}; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 30, only=sys.argv[2] if len(sys.argv) > 2 else None)
