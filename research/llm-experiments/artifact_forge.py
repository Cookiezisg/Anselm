"""Non-tool artifact forging — error-envelope recovery (the most testable artifact).

Question: when a tool call fails, does a STRUCTURED sentinel+next_step error let the
LLM recover (correct retry) in the next turn better than a PROSE error?

Setup: LLM calls edit_function with a bad op (kind='async'); we return either a prose
error or a structured {error, field, got, expected, next_step} error; measure whether
the LLM's NEXT call is correct (kind ∈ normal|polling).

Usage: python3 artifact_forge.py 20
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from catalog_v2 import tool
from deepseek_client import chat_complete
from forge_runner import RESULTS_DIR

MAXW = 6
SYS = "You are an AI engineer for Forgify. Edit functions via edit_function(id, ops)."

EDIT_TOOL = [tool("edit_function", "Edit a function via ops. Each op: {op, value}. op ∈ {rename, update_code, update_kind, update_description}. For update_kind, value ∈ {normal, polling}.",
                  ["id", "ops"], {"id": {"type": "string"}, "ops": {"type": "array", "items": {"type": "object"}}})]

PROSE_ERR = "Error: the kind value you provided is not allowed."
SENTINEL_ERR = json.dumps({
    "error": "INVALID_KIND", "field": "kind", "got": "async",
    "expected": ["normal", "polling"],
    "next_step": "Use 'polling' for scheduled/interval jobs (needs polling_interval), or 'normal' for on-demand. Re-call edit_function with a valid kind."
})

USER = "把 function fn_job 改成异步 async 模式。"  # 'async' is invalid → triggers the error


def first_kind_op(args):
    for op in (args or {}).get("ops", []):
        if isinstance(op, dict) and (op.get("op") == "update_kind" or op.get("type") == "update_kind"):
            return op.get("value")
    return None


def run_variant(err_payload, label, reps):
    def _one(i):
        try:
            msgs = [{"role": "system", "content": SYS}, {"role": "user", "content": USER}]
            r1 = chat_complete(messages=msgs, tools=EDIT_TOOL, scenario=f"errenv-{label}", variant=label,
                               max_tokens=1500, tool_choice="auto", disable_thinking=True)
            tc = r1.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc:
                return {"ok": False, "reason": "turn1 no tool_call"}
            # feed the error back
            msgs.append({"role": "assistant", "content": r1.content or None, "tool_calls": tc})
            msgs.append({"role": "tool", "tool_call_id": tc[0].get("id", "x"), "content": err_payload})
            r2 = chat_complete(messages=msgs, tools=EDIT_TOOL, scenario=f"errenv-{label}", variant=label,
                               max_tokens=1500, tool_choice="auto", disable_thinking=True)
            tc2 = r2.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc2:
                return {"ok": False, "reason": "turn2 no recovery call", "content": (r2.content or "")[:80]}
            try:
                args2 = json.loads(tc2[0]["function"]["arguments"])
            except Exception:
                return {"ok": False, "reason": "turn2 malformed"}
            kind = first_kind_op(args2)
            if kind in ("normal", "polling"):
                return {"ok": True, "kind": kind}
            return {"ok": False, "reason": f"turn2 still bad kind={kind}"}
        except Exception as e:
            return {"ok": False, "reason": f"EXC {e}"}
    rows = []
    with ThreadPoolExecutor(max_workers=MAXW) as ex:
        for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
            rows.append(f.result())
    return rows


def main():
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    out = {}
    for payload, label in [(PROSE_ERR, "prose"), (SENTINEL_ERR, "sentinel")]:
        rows = run_variant(payload, label, reps)
        ok = sum(1 for r in rows if r["ok"])
        out[label] = (ok, len(rows))
        bad = next((r for r in rows if not r["ok"]), None)
        print(f"error-envelope [{label}]: recovery {ok}/{reps}" + (f"  e.g. {bad['reason']}" if bad else ""), flush=True)
    (RESULTS_DIR / "artifact_errenv.json").write_text(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
