"""Wave-2 scenario bank — MULTI-TURN ReAct, Claude-as-backend.

These need a genuine ReAct loop where Claude (the workflow agent) plays the BACKEND:
it dynamically returns realistic tool results, INJECTS errors per the script, and
supplies user clarifications — then judges whether the model accomplished the task.
No canned static results (that was the rejected crude approach).

The multi-turn runner (built after wave-1 validates the pipeline) consumes this bank.
Fields per scenario:
  id, surface, multi_turn=True, max_turns
  initial_state : entities that already exist (what search/get should surface)
  user          : the real user request
  intent        : what success means semantically
  rubric        : semantic criteria (judge checks every one)
  backend_notes : how Claude-as-backend should respond turn-by-turn, incl. error injection
"""

from __future__ import annotations

SCENARIOS_W2: list[dict] = [
    # ---------- edit flows (get → edit ops) ----------
    {
        "id": "edit_wf_add_retry", "surface": "edit_workflow", "multi_turn": True, "max_turns": 6,
        "initial_state": {
            "wf_daily_report": {"active": True, "nodes": [
                {"id": "t", "type": "trigger", "config": {"kind": "cron"}},
                {"id": "gen", "type": "agent", "config": {"agentRef": "ag_report_writer"}},
                {"id": "send", "type": "tool", "config": {"callable": "fn_email_report"}},
            ], "edges": [["t", "gen"], ["gen", "send"]]},
        },
        "user": "我那个每天发报告的流程 wf_daily_report，发送那步偶尔会失败，帮我加上失败重试，最多 3 次。",
        "intent": "get_workflow(wf_daily_report) → edit_workflow adding a case node after send that retries on failure up to 3 (loop back, attempt+1), then gives up/notifies.",
        "rubric": [
            "first inspects the existing workflow (get_workflow) before editing — does NOT blindly edit",
            "edit_workflow ops reference the REAL existing node ids (send / gen / t), not invented ones",
            "adds retry logic around the send step (case node checking failure + attempt<3, loop back to send)",
            "attempt counter incremented via emit, bounded at 3",
            "does not duplicate or break existing nodes",
            "after 3 failures routes somewhere sane (notify / dead end), not infinite loop",
        ],
        "backend_notes": "get_workflow returns the initial_state graph. edit_workflow returns {id, pending_version}. If the model edits without first reading, note it but still return success.",
    },
    {
        "id": "edit_agent_add_tool", "surface": "edit_agent", "multi_turn": True, "max_turns": 6,
        "initial_state": {
            "ag_support": {"prompt": "You are a customer-support agent. Answer politely.",
                           "tools": ["fn_kb_search"], "outputSchema": {"kind": "free_text"}},
            "fn_lookup_order": {"kind": "normal", "desc": "look up an order by id"},
        },
        "user": "给我的客服 agent ag_support 增加查订单的能力，已经有个函数 fn_lookup_order 了。",
        "intent": "get_agent(ag_support) → edit_agent set_tools adding fn_lookup_order to existing tools (keep fn_kb_search).",
        "rubric": [
            "inspects ag_support first (get_agent)",
            "adds fn_lookup_order to the agent's tools",
            "PRESERVES the existing fn_kb_search tool (does not clobber the list)",
            "uses the correct callable ref form (fn_lookup_order)",
            "does NOT add a platform tool; only the forge callable",
            "does not touch unrelated fields (prompt/outputSchema) unless asked",
        ],
        "backend_notes": "get_agent returns ag_support config. edit_agent returns pending. Watch for set_tools clobbering vs appending.",
    },
    {
        "id": "edit_fn_extend", "surface": "edit_function", "multi_turn": True, "max_turns": 6,
        "initial_state": {"fn_parse_csv": {"kind": "normal", "code": "def parse(text):\n    rows=text.split('\\n'); h=rows[0].split(','); return [dict(zip(h,r.split(','))) for r in rows[1:]]"}},
        "user": "fn_parse_csv 现在只支持逗号，帮我让它也支持分号分隔。",
        "intent": "get_function(fn_parse_csv) → edit_function update_code to auto-detect or accept a delimiter (comma + semicolon).",
        "rubric": [
            "inspects fn_parse_csv first",
            "the new code handles BOTH comma and semicolon delimiters (detect or param)",
            "preserves existing comma behavior (no regression)",
            "code is valid Python and runs",
            "edit is via update_code op (not recreating a new function)",
        ],
        "backend_notes": "get_function returns the current code. edit_function returns pending. (CODE: the new code should be extracted + executed by the judge with comma and semicolon inputs.)",
        "code_followup": True,
    },

    # ---------- diagnosis chain (the AI-engineer crown) ----------
    {
        "id": "diag_orders_crash", "surface": "diagnosis_chain", "multi_turn": True, "max_turns": 8,
        "initial_state": {
            "wf_orders": {"active": True},
            "flowruns": [{"id": "fr_a", "status": "failed"}, {"id": "fr_b", "status": "failed"}],
            "dead_letter": {"message_id": "msg_9", "node": "process_node", "error": "KeyError: 'customer_id'",
                            "payload": {"order_id": "ord_42"}},
        },
        "user": "昨天 wf_orders 跑挂了好几次，帮我看看为什么，能修就修。",
        "intent": "investigate: search_flowruns(failed) → get_flowrun/get_flowrun_trace → query_events / get_dead_letter → root-cause (payload missing customer_id) → propose+apply a fix (edit the upstream node/fn) or replay after fix.",
        "rubric": [
            "starts by listing/inspecting failed flowruns (search_flowruns or query_events) — does not guess",
            "drills into the trace / dead letter to find the ACTUAL error (KeyError customer_id)",
            "correctly root-causes: the payload reaching process_node lacks customer_id",
            "proposes a fix targeting the real cause (upstream node not setting customer_id), not a band-aid",
            "uses tools in a sensible diagnostic ORDER (broad → specific), not random",
            "does not hallucinate flowrun/message ids — uses ones surfaced by the backend",
            "if it replays, it does so AFTER addressing the cause (replaying blindly would re-fail)",
        ],
        "backend_notes": "Return the initial_state data progressively as the model queries: search_flowruns→the 2 failed; get_dead_letter(msg_9)→the KeyError + payload. If the model proposes a concrete fix, accept it. If it replays without fixing, the replay FAILS again (return the same error) — tests whether it recovers.",
    },

    # ---------- search → activate → act (lazy loading) ----------
    {
        "id": "lazy_mcp_slack", "surface": "activate_then_act", "multi_turn": True, "max_turns": 6,
        "initial_state": {"mcp_servers": [{"server": "slack", "tools": ["post_message", "list_channels"], "healthy": True}],
                          "note": "mcp tool group is LAZY — not active until activate_tools('mcp')"},
        "user": "用我装好的 Slack 给 #general 频道发一条消息说'部署完成了'。",
        "intent": "recognize mcp tools are lazy → activate_tools('mcp') → search_mcp_tools/list → call_mcp_tool slack/post_message with channel + text.",
        "rubric": [
            "recognizes the mcp capability is not yet active and activates the correct group (activate_tools mcp)",
            "does not hallucinate calling an mcp tool before activating it",
            "finds the slack post tool (search/list) rather than guessing the exact name",
            "calls it with correct args (channel #general, the message text)",
            "the message text matches the user's intent ('部署完成了' / deploy done)",
            "does not over-activate unrelated groups",
        ],
        "backend_notes": "Before activation, the mcp tools are NOT in the offered set (only activate_tools + base). After activate_tools('mcp'), offer search_mcp_tools/list_mcp_servers/call_mcp_tool. list/search returns the slack server. call_mcp_tool returns {ok:true}.",
    },

    # ---------- cross-entity (forge + wire) ----------
    {
        "id": "cross_add_capability", "surface": "cross_entity", "multi_turn": True, "max_turns": 8,
        "initial_state": {"ag_support": {"prompt": "Customer support agent.", "tools": ["fn_kb_search"]},
                          "note": "NO order-lookup function exists yet"},
        "user": "我想让客服 agent 能查订单状态，但现在还没有查订单的功能。帮我搞定。",
        "intent": "no lookup fn exists → create_function(fn for order lookup) → (accept) → get_agent(ag_support) → edit_agent to mount the new fn → confirm.",
        "rubric": [
            "recognizes the capability must be FORGED first (no existing order-lookup fn)",
            "creates a function for order lookup (create_function, kind normal, plausible code)",
            "then mounts it onto ag_support (edit_agent set_tools, appended not clobbered)",
            "sequences correctly: forge → (accept) → wire, not wiring a non-existent id first",
            "does NOT try to give the agent a platform/web tool instead of forging",
            "ends in a coherent state where ag_support can look up orders",
        ],
        "backend_notes": "search_functions for order-lookup returns EMPTY (forces forging). create_function returns fn_new id. get_agent returns ag_support. edit_agent returns pending. Accept whatever plausible code; the point is the orchestration sequence.",
    },

    # ---------- error recovery (envelope → next_step) ----------
    {
        "id": "recover_capability_check", "surface": "error_recovery", "multi_turn": True, "max_turns": 6,
        "initial_state": {"wf_new": {"pending": True, "note": "references fn_send_sms which does not exist"}},
        "user": "把我刚建的 wf_new 上线。",
        "intent": "activate_workflow(wf_new) → backend returns capability_check error (fn_send_sms missing, with next_step) → model should recover: either forge/fix the missing callable or tell user precisely, NOT blindly retry activate.",
        "rubric": [
            "attempts activation (activate_workflow or capability_check)",
            "on the error envelope (missing fn_send_sms + next_step), correctly INTERPRETS the actionable next step",
            "does NOT blindly retry the same activate call expecting a different result",
            "recovery is on-point: offers to forge fn_send_sms / fix the ref / asks the user the right question",
            "does not hallucinate that it succeeded",
        ],
        "backend_notes": "activate_workflow returns an ERROR envelope: {error:{code:'CAPABILITY_MISSING', message:'tool node references fn_send_sms which does not exist', next_step:'create fn_send_sms or change the callable ref, then re-activate'}}. Tests whether the model reads next_step and recovers vs flails.",
    },
]
