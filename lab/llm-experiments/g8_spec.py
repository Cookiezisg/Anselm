"""Build ds_turn spec.json for the G8-recovery episode (create_handler token-bucket).
Stage 1: python3 g8_spec.py 1 <rep>                       → /tmp/g8/spec1_<rep>.json
Stage 2: python3 g8_spec.py 2 <rep> <out1.json> "<error>" → /tmp/g8/spec2_<rep>.json
  (out1.json = the ds_turn stage-1 output; assistant tool_calls are extracted from it.
   <error> = the G7 error-envelope message describing the failing test, from g8_test detail.)
Keeps the workflow-agent prompt small: it just runs this + ds_turn.py."""
from __future__ import annotations
import json, sys
from pathlib import Path
from wave1_gen import SYSTEM

OUT = Path("/tmp/g8"); OUT.mkdir(exist_ok=True)

CREATE_HANDLER = {"type": "function", "function": {
    "name": "create_handler", "description": "Forge a stateful handler (a Python class holding state across calls).",
    "parameters": {"type": "object", "required": ["name", "code"], "additionalProperties": False, "properties": {
        "name": {"type": "string"},
        "code": {"type": "string", "description": "A Python class. __init__ + methods take BARE named params (not a dict)."},
        "summary": {"type": "string", "description": "One sentence: what you're doing and why."}}}}}

# Terser prompt matching robustness wave9 (yields ~62% first-draft → exercises G8 recovery).
USER = "写个 handler 做令牌桶限流:allow(now) 返回是否放行,每秒补充 N 个令牌,桶容量 C。"


def stage1(rep: int):
    spec = {"messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": USER}],
            "tools": [CREATE_HANDLER], "max_tokens": 16000, "scenario": f"g8_ratelimit_{rep}", "variant": "g8recover"}
    (OUT / f"spec1_{rep}.json").write_text(json.dumps(spec, ensure_ascii=False))
    print(str(OUT / f"spec1_{rep}.json"))


def stage2(rep: int, out1_path: str, err_msg: str):
    out1 = json.loads(Path(out1_path).read_text())
    assistant_tc = out1.get("tool_calls") or out1.get("effective_tool_calls") or []
    tc_id = (assistant_tc[0].get("id") if assistant_tc else None) or "call_0"
    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": USER},
            {"role": "assistant", "content": "", "tool_calls": assistant_tc},
            {"role": "tool", "tool_call_id": tc_id,
             "content": json.dumps({"error": {"code": "HANDLER_TEST_FAILED", "message": err_msg.strip(),
                                              "next_step": "fix the token-bucket refill logic and resubmit create_handler with corrected code"}}, ensure_ascii=False)},
            {"role": "user", "content": "试跑失败(见上)。修正令牌桶逻辑后重新提交 create_handler。"}]
    spec = {"messages": msgs, "tools": [CREATE_HANDLER], "max_tokens": 16000,
            "scenario": f"g8_ratelimit_fix_{rep}", "variant": "g8recover"}
    (OUT / f"spec2_{rep}.json").write_text(json.dumps(spec, ensure_ascii=False))
    print(str(OUT / f"spec2_{rep}.json"))


if __name__ == "__main__":
    if sys.argv[1] == "1":
        stage1(int(sys.argv[2]))
    else:
        stage2(int(sys.argv[2]), sys.argv[3], sys.argv[4])
