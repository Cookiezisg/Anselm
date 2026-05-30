"""Isolate WHY thinking-on 'failed' — truncation vs genuine, and asking vs over-deliberation.

Test 1: workflow create, thinking-ON, max_tokens=12000 (definitely not truncated).
        Classify each: valid / truncated(finish=length) / malformed-but-complete / called-None / wrong-tool.
        → is malformed-JSON a thinking effect or just truncation (M2)?

Test 2: CEL fully-specified scenarios (branch targets given), thinking-ON single-turn.
        Compare to known thinking-OFF=100%. If ON also ~100% → earlier CEL gap was
        under-specified scenarios (asking), NOT thinking. If ON low + content=questions
        → over-deliberation (real thinking cost). Read the called-None content.

Usage: python3 diag_thinking2.py 1   |   python3 diag_thinking2.py 2
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed

from deepseek_client import chat_complete

MAXW = 6


def test1(reps=30):
    from catalog_v2 import workflow_tools, validate_workflow_ops
    from workflow_forge import WORKFLOW_SCENARIOS, SYS
    tools = workflow_tools("V2-enum-types")
    # the scenarios where malformed appeared: loop + full
    scens = [s for s in WORKFLOW_SCENARIOS if s["id"] in ("wf-loop", "wf-full", "wf-branch")]
    cls = Counter()
    examples = {}
    def _one(scen, i):
        r = chat_complete(messages=[{"role": "system", "content": scen["system_prompt"]},
                                    {"role": "user", "content": scen["user_prompt"]}],
                          tools=tools, scenario="diag1", variant="think-on",
                          max_tokens=12000, tool_choice="auto", disable_thinking=False)
        ch = r.raw_response["choices"][0]
        fr = ch["finish_reason"]
        msg = ch["message"]
        tc = msg.get("tool_calls")
        reason_chars = len(msg.get("reasoning_content") or "")
        if not tc:
            return ("called-None", fr, reason_chars, (msg.get("content") or "")[:120])
        argstr = tc[0]["function"]["arguments"]
        try:
            args = json.loads(argstr)
            v = validate_workflow_ops(args.get("ops", []))
            if v["valid"]:
                return ("valid", fr, reason_chars, "")
            return ("invalid-semantic", fr, reason_chars, str(v["errors"][:1]))
        except json.JSONDecodeError:
            if fr == "length":
                return ("truncated(length)", fr, reason_chars, argstr[-80:])
            return ("malformed-COMPLETE", fr, reason_chars, argstr[-80:])
    tasks = []
    with ThreadPoolExecutor(max_workers=MAXW) as ex:
        futs = [ex.submit(_one, s, i) for s in scens for i in range(reps)]
        for f in as_completed(futs):
            cat, fr, rc, ex_ = f.result()
            cls[cat] += 1
            if cat not in examples and cat not in ("valid",):
                examples[cat] = (fr, rc, ex_)
    print("=== Test1: workflow thinking-ON, max_tokens=12000 (no truncation possible) ===")
    tot = sum(cls.values())
    for c, n in cls.most_common():
        print(f"  {c}: {n}/{tot} ({n*100//tot}%)")
    print("  examples:")
    for c, (fr, rc, ex_) in examples.items():
        print(f"    [{c}] finish={fr} reasoning_chars={rc} tail/err={ex_!r}")
    print(f"  => malformed-COMPLETE rate (genuine thinking corruption, NOT truncation) tells us if M1 has merit")


def test2(reps=20):
    from cel_forge import cel_tool, CEL_SCENARIOS, validate, SYS
    tools = cel_tool("full")
    print("=== Test2: CEL fully-specified, thinking-ON (vs thinking-OFF=100%) ===")
    tot_ok = 0; tot = 0
    asked = 0
    for s in CEL_SCENARIOS:
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": s["system_prompt"]},
                                        {"role": "user", "content": s["user_prompt"]}],
                              tools=tools, scenario="diag2", variant="think-on",
                              max_tokens=4000, tool_choice="auto", disable_thinking=False)
            ch = r.raw_response["choices"][0]["message"]
            tc = ch.get("tool_calls")
            if not tc:
                return (False, "asked/chatted", (ch.get("content") or "")[:100])
            name = tc[0]["function"]["name"]
            try:
                args = json.loads(tc[0]["function"]["arguments"])
            except Exception:
                return (False, "malformed", "")
            ok, errs = validate(name, args, s)
            return (ok, "ok" if ok else f"invalid:{errs[:1]}", "")
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        ok = sum(1 for r in rows if r[0])
        a = sum(1 for r in rows if r[1] == "asked/chatted")
        asked += a; tot_ok += ok; tot += len(rows)
        ex_ = next((r[2] for r in rows if r[1] == "asked/chatted"), "")
        print(f"  {s['id']}: {ok}/{reps}  (asked/chatted={a})" + (f"  e.g.{ex_!r}" if ex_ else ""))
    print(f"  TOTAL thinking-ON: {tot_ok}/{tot} ({tot_ok*100//tot}%) vs thinking-OFF 100%;  total asked/chatted={asked}")


if __name__ == "__main__":
    {"1": test1, "2": test2}[sys.argv[1] if len(sys.argv) > 1 else "1"](int(sys.argv[2]) if len(sys.argv) > 2 else (30 if (len(sys.argv) < 2 or sys.argv[1] == "1") else 20))
