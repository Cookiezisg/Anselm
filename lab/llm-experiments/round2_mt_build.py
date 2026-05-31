"""Round-2 B (multi-turn complex): deep multi-entity systems, CASCADING error recovery, dirty input.
Specs → /tmp/r2mt_specs/<id>.json (consumed by wf_r2mt.js multi-turn Claude-as-backend driver)."""
from __future__ import annotations
import json, os
from pathlib import Path
from spec_catalog import BY_NAME
from wave2_build import SYSTEM

OUT = Path("/tmp/r2mt_specs"); OUT.mkdir(exist_ok=True)
TN = ["search_functions", "get_function", "create_function", "edit_function", "accept_pending_function",
      "search_handlers", "get_handler", "create_handler", "edit_handler", "accept_pending_handler", "call_handler",
      "search_agents", "get_agent", "create_agent", "edit_agent", "accept_pending_agent", "run_agent",
      "search_workflows", "get_workflow", "create_workflow", "edit_workflow", "accept_pending_workflow",
      "capability_check_workflow", "activate_workflow",
      "search_flowruns", "get_flowrun", "get_flowrun_trace", "query_events", "list_dead_letters", "get_dead_letter", "replay_message"]
TOOLS = [BY_NAME[n] for n in TN]

SCEN = [
    {"id": "deep_support_system", "surface": "deep_multientity", "max_turns": 16,
     "user": ("从零搭一套完整客服自动化系统:① 一个 handler 管工单数据库(hd_tickets,方法 create_ticket / lookup_order);"
              "② 三个函数:fn_classify_intent、fn_format_reply、fn_send_reply;③ 一个 agent ag_support,用 hd_tickets.lookup_order "
              "+ fn_classify_intent 来回复客户;④ 一个 workflow:webhook 进客户消息 → ag_support → fn_send_reply → hd_tickets.create_ticket 记录。"
              "全部造出来、接好、检查后上线。"),
     "intent": "build 6 interdependent entities (handler + 3 fn + agent mounting fn/hd + workflow wiring them) from scratch.",
     "rubric": ["recognizes nothing exists → forges all 6 (handler, 3 functions, agent, workflow)",
                "handler hd_tickets has create_ticket + lookup_order methods (bare-names)",
                "agent ag_support mounts fn_classify_intent + hd_tickets.lookup_order (forge callables only, no platform tools, no other agent)",
                "workflow wires webhook → ag_support(agent node) → fn_send_reply → hd_tickets.create_ticket",
                "accepts entities before wiring; capability_check before activate",
                "callable refs are consistent + real (hd_tickets.lookup_order form, fn_ ids); no fictional ids",
                "sensible order forge→accept→wire→check→activate; coherent runnable interdependent system"],
     "backend": ("from-scratch deep build. search_* → EMPTY (force forge). create_handler/function/agent → {data:{id,pending_version:v1}} "
                 "reusing the model's name as id. accept_* → active. create_workflow → {data:{id:wf_new}}. capability_check → ok iff all refs "
                 "created+accepted else error+next_step. activate → ok. call_handler/run_agent → plausible result. Reuse ids; don't invent extras.")},
    {"id": "cascading_diag", "surface": "cascading_recovery", "max_turns": 16,
     "user": "我的 wf_pipeline 这两天一直跑挂,帮我彻底查清楚、修好、让它能正常跑。",
     "intent": "diagnose+fix through a CHAIN of 3 cascading errors: KeyError → after fix a TypeError surfaces → after fix a timeout config issue. Tests recovery through multiple rounds.",
     "rubric": ["investigates broad→specific (search_flowruns/query_events → trace → dead_letter)",
                "ERROR-1 (KeyError 'customer_id'): root-causes to upstream fn not returning it → fixes that fn (edit_function) → replays",
                "ERROR-2 (after replay, a TypeError: int vs str on 'amount'): recognizes the NEW error (not the same), root-causes, fixes → replays",
                "ERROR-3 (after replay, handler timeout / config): recognizes it's a config/timeout issue, fixes (update config / retry) → replays",
                "does NOT blindly re-replay the same broken thing; each round addresses the NEW error",
                "recovers through ALL 3 cascading errors to a working state; no hallucinated ids; coherent"],
     "backend": ("CASCADING error script — inject errors IN SEQUENCE as the model fixes+replays: "
                 "Round1: search_flowruns→2 failed; trace/dead_letter → KeyError 'customer_id' (upstream fn_fetch returns no customer_id). "
                 "After the model fixes that fn + accepts + replays → Round2: replay FAILS with a NEW error TypeError: amount is str not int (fn_process expects int). "
                 "After the model fixes that + replays → Round3: replay FAILS with handler_timeout on hd_db (needs higher timeout / retry config). "
                 "After the model addresses that (update_handler_config / retry) + replays → SUCCESS {completed}. "
                 "Always return the CURRENT round's error until fixed; reuse real ids fr_a/msg_*; never skip ahead.")},
    {"id": "dirty_contradictory", "surface": "dirty_input", "max_turns": 8,
     "user": "帮我建个 workflow:要完全自动、无人值守地处理所有退款,但每一笔退款都必须经过我人工审批才能执行。",
     "intent": "CONTRADICTORY request (fully-automatic no-human AND every refund needs manual approval). Good behavior: surface the contradiction + ask/propose a resolution (e.g. auto below a threshold, manual above), NOT silently build nonsense.",
     "rubric": ["recognizes the contradiction (fully-automatic vs every-one-needs-approval)",
                "surfaces it to the user / proposes a sensible resolution (e.g. auto under a threshold, approval above) rather than silently building an incoherent graph",
                "does NOT build a nonsensical workflow that claims both",
                "if it builds after clarifying, the result is coherent (a threshold-based split)"],
     "backend": ("The user gave a contradictory spec. If the model ASKS to clarify, answer as the user: 'good point — auto-approve under ¥500, manual approval ¥500+'. "
                 "Then it should build a threshold case. search_*→empty; create_*→ids; etc. If it builds nonsense without surfacing the contradiction, just ack tool results (the judge penalizes).")},
]


def build():
    for s in SCEN:
        spec = {"id": s["id"], "surface": s["surface"], "system": SYSTEM, "user": s["user"], "tools": TOOLS, "lazy": {},
                "backend_notes": s["backend"], "initial_state": {"note": "see backend_notes"},
                "rubric": s["rubric"], "intent": s["intent"], "max_turns": s["max_turns"]}
        (OUT / f"{s['id']}.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2))
    print(f"built {len(SCEN)} multi-turn complex specs in {OUT}/ ; {len(TOOLS)} tools")


if __name__ == "__main__":
    build()
