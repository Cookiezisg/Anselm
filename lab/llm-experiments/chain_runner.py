"""Multi-turn chain runner: simulates tool results to drive multi-step chains.

Differs from runner.run_single by looping turns:
  user -> LLM -> tool_call(s) -> canned tool result -> LLM -> tool_call(s) -> ...
until LLM stops calling tools, hits max_turns, or returns content with no calls.

Mock tool results are defined per-scenario in `mock_tool_results` field.
"""

from __future__ import annotations

import copy
import json
import time
from dataclasses import dataclass, field
from typing import Any

from deepseek_client import BudgetExhausted, chat_complete


# -- Canned tool results per scenario --

DEFAULT_CANNED_RESULTS: dict[str, Any] = {
    "search_flowruns": {"data": [{"id": "fr_001", "status": "failed", "trigger": "cron", "duration_ms": 3200}, {"id": "fr_002", "status": "failed", "trigger": "cron", "duration_ms": 1800}], "nextCursor": None},
    "get_flowrun": {"data": {"id": "fr_001", "status": "failed", "trigger_node": "cron_morning", "failed_node": "tool_node_3", "error": "handler_crash"}},
    "get_flowrun_trace": {"data": {"messages": [{"id": "msg_001", "node": "trigger", "ts": "T0"}, {"id": "msg_002", "node": "fn_collect", "ts": "T1"}, {"id": "msg_003", "node": "tool_node_3", "ts": "T2", "error": "OOM"}]}},
    "query_events": {"data": [{"type": "handler_crash", "workflow_id": "wf_orders", "ts": "T2", "stack": "MemoryError"}, {"type": "dead_letter_created", "ts": "T2", "message_id": "msg_003"}]},
    "list_dead_letters": {"data": [{"message_id": "msg_003", "node": "tool_node_3", "reason": "OOM", "payload": {"order_id": "ord_42"}}]},
    "get_dead_letter": {"data": {"message_id": "msg_003", "payload": {"order_id": "ord_42"}, "ctx": {"flowrun_id": "fr_001"}, "error": "MemoryError", "stack": "..."}},
    "replay_message": {"data": {"message_id": "msg_003", "replayed_at": "T3", "new_flowrun_id": "fr_replay_001"}},
    "get_workflow": {"data": {"id": "wf_report", "name": "Daily Report", "active": False, "graph": {"nodes": [{"id": "manual_trigger", "type": "trigger"}], "edges": []}}},
    "create_function": {"data": {"id": "fn_new001", "pending_version": "v1"}},
    "edit_function": {"data": {"id": "fn_new001", "pending_version": "v2"}},
    "edit_workflow": {"data": {"id": "wf_report", "pending_version": "v3"}},
    "accept_pending_function": {"data": {"id": "fn_new001", "active_version": "v1"}},
    "accept_pending_workflow": {"data": {"id": "wf_report", "active_version": "v3"}},
    "activate_workflow": {"data": {"id": "wf_report", "active": True}},
    "search_functions": {"data": [], "nextCursor": None},  # no preexisting
    "search_workflows": {"data": [{"id": "wf_report", "name": "Daily Report", "active": False}], "nextCursor": None},
    "search_handlers": {"data": [], "nextCursor": None},
    "search_agents": {"data": [{"id": "ag_classifier01", "name": "Classifier"}], "nextCursor": None},
    "search_skills": {"data": [], "nextCursor": None},
    "search_documents": {"data": [], "nextCursor": None},
    "search_mcp_tools": {"data": [], "nextCursor": None},
    "get_function": {"data": {"id": "fn_xyz", "active_version": {"kind": "normal", "code": "def f(): pass"}}},
    "get_handler": {"data": {"id": "hd_oauth01", "methods": ["refresh"], "init_schema": {}}},
    "get_agent": {"data": {"id": "ag_classifier01", "prompt": "You are a classifier."}},
    "call_handler": {"data": {"result": "ok", "execution_time_ms": 42}},
    "run_function": {"data": {"result": 7, "execution_time_ms": 5}},
    "run_agent": {"data": {"result": "classified", "tokens_used": 152}},
    "activate_tools": {"data": {"category_activated": "ok"}},
}


def canned_result(tool_name: str, args: dict[str, Any] | None = None) -> str:
    """Return canned tool result. For search_*, ECHO the requested id/query so the
    LLM finds what it's looking for (real search would; a fixed mismatch makes the
    LLM loop searching forever — a harness artifact, not an LLM failure)."""
    args = args or {}
    if tool_name in ("search_skills",):
        q = str(args.get("query") or "")
        return json.dumps({"data": [{"name": q or "some-skill", "description": "matched skill"}]}, ensure_ascii=False)
    if tool_name in ("list_mcp_servers", "search_mcp_tools"):
        # surface a server/tool matching the query so call_mcp_tool can proceed
        q = str(args.get("query") or "").lower()
        srv = "slack" if "slack" in q else ("gmail" if ("gmail" in q or "邮件" in q) else "github")
        return json.dumps({"data": [{"server": srv, "tools": ["post", "list", "read"], "healthy": True}]}, ensure_ascii=False)
    if tool_name == "read_memory":
        return json.dumps({"data": [{"name": "old_api_key_note", "content": "remembered item matching the query"}]}, ensure_ascii=False)
    if tool_name.startswith("search_") or tool_name == "list_documents":
        # echo an id/entity matching the query so the chain can proceed
        q = str(args.get("query") or args.get("workflow_id") or args.get("path") or "")
        import re as _re
        m = _re.search(r"\b((fn|hd|ag|wf|fr|msg|doc)_[a-z0-9_]+)\b", q)
        eid = m.group(1) if m else (q if q.startswith(("fn_", "hd_", "ag_", "wf_", "doc_")) else "wf_match01")
        return json.dumps({"data": [{"id": eid, "name": eid, "active": False}], "nextCursor": None}, ensure_ascii=False)
    base = DEFAULT_CANNED_RESULTS.get(tool_name, {"data": {"ok": True}})
    return json.dumps(base, ensure_ascii=False)


@dataclass
class ChainTurnRecord:
    turn_idx: int
    assistant_message: dict[str, Any]
    tool_results_sent: list[dict[str, Any]]
    cost_rmb: float
    cache_hit_tokens: int
    cache_miss_tokens: int
    output_tok: int


@dataclass
class ChainRunRecord:
    rep_idx: int
    scenario_id: str
    variant_id: str
    user_prompt: str
    turns: list[ChainTurnRecord]
    final_assistant_content: str
    total_cost_rmb: float
    total_turns: int
    total_tool_calls: int
    finished_naturally: bool  # ended without max_turns
    completed: bool  # judged by scenario.completion_check
    notes: str = ""
    ts: float = field(default_factory=time.time)

    def to_dict(self) -> dict[str, Any]:
        d = self.__dict__.copy()
        d["turns"] = [t.__dict__ for t in self.turns]
        return d


def run_chain(
    composed_scenario: dict[str, Any],
    variant: dict[str, Any],
    rep_idx: int = 0,
    max_turns: int = 6,
    disable_thinking: bool = False,
) -> ChainRunRecord:
    """Run a scenario as multi-turn chain with canned tool results."""
    messages: list[dict[str, Any]] = []
    if composed_scenario.get("system_prompt"):
        messages.append({"role": "system", "content": composed_scenario["system_prompt"]})
    messages.append({"role": "user", "content": composed_scenario["user_prompt"]})

    tools = composed_scenario.get("tools", [])
    turns: list[ChainTurnRecord] = []
    total_cost = 0.0
    total_calls = 0
    finished_naturally = False
    final_content = ""

    for turn_idx in range(max_turns):
        result = chat_complete(
            messages=messages,
            tools=tools if tools else None,
            scenario=composed_scenario["id"],
            variant=variant["id"],
            tool_choice="auto",
            max_tokens=2048,
            disable_thinking=disable_thinking,
        )
        total_cost += result.cost_entry.cost_rmb
        calls = result.effective_tool_calls
        total_calls += len(calls)

        # DeepSeek V4-flash with thinking mode requires reasoning_content to be
        # passed back in subsequent assistant messages.
        choice_msg = result.raw_response["choices"][0]["message"]
        reasoning = choice_msg.get("reasoning_content")
        assistant_msg: dict[str, Any] = {
            "role": "assistant",
            "content": result.content or None,
        }
        if reasoning:
            assistant_msg["reasoning_content"] = reasoning
        if result.tool_calls:
            assistant_msg["tool_calls"] = result.tool_calls

        if not calls:
            # LLM done
            finished_naturally = True
            final_content = result.content
            turns.append(
                ChainTurnRecord(
                    turn_idx=turn_idx,
                    assistant_message=assistant_msg,
                    tool_results_sent=[],
                    cost_rmb=result.cost_entry.cost_rmb,
                    cache_hit_tokens=result.cost_entry.input_tok_cached,
                    cache_miss_tokens=result.cost_entry.input_tok_uncached,
                    output_tok=result.cost_entry.output_tok,
                )
            )
            break

        messages.append(assistant_msg)

        # Generate canned tool results
        tool_results = []
        for c in calls:
            fn = c.get("function") or c
            fn_name = fn.get("name") if isinstance(fn, dict) else None
            _a = fn.get("arguments") if isinstance(fn, dict) else None
            if isinstance(_a, str):
                try:
                    _a = json.loads(_a)
                except Exception:
                    _a = {}
            result_json = canned_result(fn_name, _a if isinstance(_a, dict) else {})
            tr = {
                "role": "tool",
                "tool_call_id": c.get("id", "?"),
                "content": result_json,
            }
            messages.append(tr)
            tool_results.append({"name": fn_name, "result": result_json[:200]})

        turns.append(
            ChainTurnRecord(
                turn_idx=turn_idx,
                assistant_message=assistant_msg,
                tool_results_sent=tool_results,
                cost_rmb=result.cost_entry.cost_rmb,
                cache_hit_tokens=result.cost_entry.input_tok_cached,
                cache_miss_tokens=result.cost_entry.input_tok_uncached,
                output_tok=result.cost_entry.output_tok,
            )
        )

    # Judge completion: did LLM call the "required tools" at any point?
    required_tools = set(composed_scenario.get("expected", {}).get("required_tools", []))
    called_tools = set()
    for t in turns:
        for c in t.assistant_message.get("tool_calls", []) or []:
            fn = c.get("function") or c
            n = fn.get("name") if isinstance(fn, dict) else None
            if n:
                called_tools.add(n)
    completed = required_tools.issubset(called_tools) if required_tools else finished_naturally

    return ChainRunRecord(
        rep_idx=rep_idx,
        scenario_id=composed_scenario["id"],
        variant_id=variant["id"],
        user_prompt=composed_scenario["user_prompt"],
        turns=turns,
        final_assistant_content=final_content,
        total_cost_rmb=total_cost,
        total_turns=len(turns),
        total_tool_calls=total_calls,
        finished_naturally=finished_naturally,
        completed=completed,
    )
