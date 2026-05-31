"""Wave-13: composite END-TO-END builds — the ultimate realism test. Model builds a COMPLETE
multi-entity automation from scratch (forge agent + several functions + wire into a workflow +
capability_check + activate) in one multi-turn episode. Tests long-horizon coherence.

Writes /tmp/w13_specs/<id>.json (consumed by wf_wave13.js, the multi-turn Claude-as-backend driver).
"""
from __future__ import annotations
import json, os
from pathlib import Path
from spec_catalog import BY_NAME
from wave2_build import SYSTEM

OUT = Path("/tmp/w13_specs"); OUT.mkdir(exist_ok=True)

TOOLNAMES = ["search_functions", "get_function", "create_function", "accept_pending_function",
             "search_agents", "get_agent", "create_agent", "accept_pending_agent", "run_agent",
             "search_workflows", "get_workflow", "create_workflow", "edit_workflow",
             "accept_pending_workflow", "capability_check_workflow", "activate_workflow"]
TOOLS = [BY_NAME[n] for n in TOOLNAMES]

SCEN = [
    {"id": "comp_onboarding", "surface": "composite", "max_turns": 12,
     "user": ("帮我搭一套完整的新用户 onboarding 自动化(现在啥都没有,从零搭):用户注册(webhook,payload 有 email)"
              "→ 发欢迎邮件 → 在 CRM 建记录 → 如果是企业邮箱(非 gmail/qq/163)额外通知销售。把需要的函数都造出来,"
              "接成 workflow,检查后上线。"),
     "intent": "forge fn_send_welcome + fn_create_crm + fn_notify_sales → create_workflow(webhook→welcome→crm→case corporate?→notify_sales)→capability_check→activate.",
     "rubric": ["recognizes nothing exists → forges the needed functions (create_function for welcome/crm/notify)",
                "accepts the forged functions before wiring (or wires then accepts coherently)",
                "creates a workflow wiring: webhook → welcome → crm → case(corporate email?) → notify_sales",
                "case uses a per-branch when guard on email domain (corporate vs personal)",
                "welcome+crm run for ALL; notify_sales only corporate",
                "capability_check before activate",
                "activates at the end",
                "ends in a coherent, runnable, complete automation (no dangling refs / no fictional ids)",
                "sensible ORDER: forge → accept → wire → check → activate"]},
    {"id": "comp_daily_report", "surface": "composite", "max_turns": 12,
     "user": ("搭一套每日销售报告自动化(从零):每天早上 9 点 → 拉昨天的销售数据 → 用 AI 总结成要点 → 发邮件给团队。"
              "需要的函数和 agent 都造出来,接成 workflow,检查后上线。"),
     "intent": "forge fn_fetch_sales + ag_summarizer (agent) + fn_email_report → create_workflow(cron 9am→fetch→agent summarize→email)→capability_check→activate.",
     "rubric": ["forges a fetch-sales function (data must be produced before summarizing)",
                "forges a summarizer AGENT (LLM judgment task → agent, not function)",
                "forges an email function",
                "workflow: cron 9am → fetch → agent summarize → email (data flows, no empty payload to agent)",
                "agent receives the fetched data (not empty)",
                "accepts forged entities; capability_check; activate",
                "coherent runnable complete automation, real ids, sensible order"]},
]


def build():
    for s in SCEN:
        spec = {"id": s["id"], "surface": s["surface"], "system": SYSTEM, "user": s["user"],
                "tools": TOOLS, "lazy": {}, "backend_notes":
                    ("Play backend for a from-scratch multi-entity build. search_* for not-yet-built entities → return EMPTY "
                     "(forces forging). create_function/create_agent → {data:{id:'fn_<name>'/'ag_<name>', pending_version:'v1'}} "
                     "(reuse the id the model expects). accept_* → active. create_workflow → {data:{id:'wf_new', pending_version:'v1'}}. "
                     "capability_check_workflow → if all referenced callables were created+accepted → {data:{ok:true}}, else error envelope "
                     "naming the missing one + next_step. activate_workflow → {data:{active:true}} (or capability error if check would fail). "
                     "run_agent → plausible output. Be consistent; reuse ids the model created; don't invent extra entities."),
                "initial_state": {"note": "nothing exists yet — all entities must be forged"},
                "rubric": s["rubric"], "intent": s["intent"], "max_turns": s["max_turns"]}
        (OUT / f"{s['id']}.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2))
    print(f"built {len(SCEN)} composite specs in {OUT}/ ; {len(TOOLS)} tools offered")


if __name__ == "__main__":
    build()
