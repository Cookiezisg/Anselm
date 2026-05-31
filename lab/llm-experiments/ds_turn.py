"""One DeepSeek turn, as a CLI — the primitive for Claude-as-backend real ReAct.

A Claude subagent drives a multi-turn ReAct episode by calling this repeatedly:
  1. build {messages, tools} JSON, write to a file
  2. `python3 ds_turn.py <spec.json>` → prints one assistant turn as JSON
  3. agent reads tool_calls, ACTS AS THE BACKEND (decides realistic tool results),
     appends the assistant msg + tool result msgs, loops to step 1
  4. stops when DeepSeek emits no tool_calls (final answer) or task done

This is the real-ReAct upgrade over canned-result chain_runner: the *agent* (Claude)
supplies tool results dynamically, so the loop reflects real environment behavior.

spec.json: {messages, tools?, disable_thinking?, max_tokens?, scenario?, variant?, tool_choice?}
output JSON: {ok, content, reasoning_content, tool_calls, effective_tool_calls,
              finish_reason, has_tool_call, cost_rmb, cumulative_rmb, budget_exhausted, error?}
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import deepseek_client as ds


def _ensure_key() -> None:
    if os.environ.get("DEEPSEEK_API_KEY"):
        return
    # fallback: /tmp/.ds_key (kept out of the repo; written once per machine)
    keyfile = Path("/tmp/.ds_key")
    if keyfile.exists():
        os.environ["DEEPSEEK_API_KEY"] = keyfile.read_text().strip()


def main() -> int:
    _ensure_key()
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "usage: ds_turn.py <spec.json>"}))
        return 2
    try:
        spec = json.loads(Path(sys.argv[1]).read_text())
    except Exception as e:
        print(json.dumps({"ok": False, "error": f"bad spec: {e}"}))
        return 2

    messages = spec.get("messages")
    if not isinstance(messages, list) or not messages:
        print(json.dumps({"ok": False, "error": "spec.messages must be a non-empty list"}))
        return 2

    try:
        res = ds.chat_complete(
            messages=messages,
            tools=spec.get("tools"),
            scenario=spec.get("scenario", "react"),
            variant=spec.get("variant", "default"),
            tool_choice=spec.get("tool_choice", "auto"),
            temperature=spec.get("temperature", 0.0),
            max_tokens=spec.get("max_tokens", 8000),
            disable_thinking=spec.get("disable_thinking", False),
        )
    except ds.BudgetExhausted as e:
        print(json.dumps({"ok": False, "budget_exhausted": True, "error": str(e),
                          "cumulative_rmb": ds.cumulative_cost_rmb()}))
        return 0
    except Exception as e:
        print(json.dumps({"ok": False, "error": f"{type(e).__name__}: {e}",
                          "cumulative_rmb": ds.cumulative_cost_rmb()}))
        return 1

    # reasoning_content must be echoed back in the NEXT turn's assistant msg when
    # thinking is enabled (DeepSeek 400s otherwise on multi-turn).
    msg = res.raw_response.get("choices", [{}])[0].get("message", {})
    reasoning = msg.get("reasoning_content") or ""

    out = {
        "ok": True,
        "budget_exhausted": False,
        "content": res.content,
        "reasoning_content": reasoning,
        "tool_calls": res.tool_calls,
        "effective_tool_calls": res.effective_tool_calls,
        "finish_reason": res.finish_reason,
        "has_tool_call": res.has_tool_call,
        "leaked": bool(res.leaked_tool_calls),
        "cost_rmb": round(res.cost_entry.cost_rmb, 6),
        "cumulative_rmb": round(ds.cumulative_cost_rmb(), 4),
    }
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
