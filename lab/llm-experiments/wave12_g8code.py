"""Wave-12: validate G8's CODE half — does DeepSeek FIX buggy code given a concrete test result?

The unified test-before-accept principle (G8) claims forge code bugs are recovered by run/call test
+ feedback + fix. Validated for workflow (capability_check recovery); here we test it for CODE directly
on the known-~40%-buggy token-bucket handler. Python orchestrates: forge → RUN → feed back wrong-output
→ DeepSeek fixes → RUN again. Measures convergence-to-correct within the loop.

Output: /tmp/w12/result.json
"""
from __future__ import annotations
import json, os, sys, re, inspect
from pathlib import Path
import catalog_v2 as cat
import deepseek_client as ds
from wave1_gen import SYSTEM, handler_tool, parse_args

OUT = Path("/tmp/w12"); OUT.mkdir(exist_ok=True)
HD = handler_tool()
USER = ("写个 handler 做令牌桶限流:allow(now) 返回是否放行(bool),每秒补充 rate 个令牌,桶容量 capacity,"
        "桶初始装满。init 参数 rate、capacity。")
EXPECT = [True, True, False, True]  # rate=1 cap=2: allow(0,0,0,2)


def run_code(code: str):
    """Instantiate the handler class (rate=1,cap=2) and run allow(0,0,0,2). Return (seq, err)."""
    ns = {}
    try:
        exec(code, ns)
    except Exception as e:
        return None, f"SyntaxError/exec: {e}"
    # find the class that has an allow-like method
    classes = [v for v in ns.values() if inspect.isclass(v) and any('allow' in m.lower() for m in dir(v))]
    if not classes:
        return None, "no class with an allow method"
    C = classes[-1]
    for args in [dict(rate=1, capacity=2), (1, 2)]:
        try:
            inst = C(**args) if isinstance(args, dict) else C(*args)
            break
        except Exception:
            inst = None
    if inst is None:
        return None, "could not instantiate with rate=1,capacity=2"
    meth = [m for m in dir(inst) if 'allow' in m.lower() and not m.startswith('_')]
    if not meth:
        return None, "no public allow method"
    f = getattr(inst, meth[0])
    seq = []
    for now in [0, 0, 0, 2]:
        try:
            seq.append(bool(f(now)))
        except Exception as e:
            return None, f"allow({now}) raised: {e}"
    return seq, None


def episode(rep: int, max_turns=3):
    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": USER}]
    trace = []
    for turn in range(max_turns):
        res = ds.chat_complete(messages=msgs, tools=HD, scenario=f"w12_rep{rep}", variant="g8code",
                               max_tokens=8000, disable_thinking=False)
        tcs = res.effective_tool_calls
        if not tcs:
            trace.append({"turn": turn, "no_call": True, "content": (res.content or '')[:200]})
            break
        args = parse_args(tcs[0])
        code = args.get("code", "")
        seq, err = run_code(code)
        ok = (err is None and seq == EXPECT)
        trace.append({"turn": turn, "ran": seq, "err": err, "ok": ok})
        if ok:
            return {"rep": rep, "converged_turn": turn, "turns": turn + 1, "trace": trace}
        # feed back the real test result (this is the G8 mechanism: test → actionable error)
        reasoning = (res.raw_response.get("choices", [{}])[0].get("message", {}) or {}).get("reasoning_content")
        am = {"role": "assistant", "content": res.content or None}
        if reasoning:
            am["reasoning_content"] = reasoning
        if res.tool_calls:
            am["tool_calls"] = res.tool_calls
        msgs.append(am)
        detail = (f"call_handler test FAILED. allow(now=0),allow(0),allow(0),allow(2) returned {seq}, "
                  f"expected {EXPECT}. " if err is None else f"call_handler test FAILED to run: {err}. ")
        fb = {"role": "tool", "tool_call_id": tcs[0].get("id", "?"),
              "content": json.dumps({"error": {"code": "TEST_FAILED", "message": detail,
                  "next_step": "Fix the code: bucket must START FULL (tokens=capacity), refill min(capacity, tokens+rate*elapsed) based on elapsed time since last call, consume 1 if available. Re-submit with create_handler."}}, ensure_ascii=False)}
        msgs.append(fb)
    return {"rep": rep, "converged_turn": None, "turns": len(trace), "trace": trace}


def run(reps=8, workers=8):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    results = []
    budget = {"v": False}
    def work(rep):
        if budget["v"]:
            return None
        try:
            return episode(rep)
        except ds.BudgetExhausted:
            budget["v"] = True; return {"rep": rep, "budget_exhausted": True}
        except Exception as e:
            return {"rep": rep, "error": f"{type(e).__name__}: {e}"}
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for fut in cf.as_completed([ex.submit(work, r) for r in range(reps)]):
            r = fut.result()
            if r:
                results.append(r)
    results.sort(key=lambda x: x.get("rep", 0))
    (OUT / "result.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
    # analysis
    first_ok = sum(1 for r in results if r.get("converged_turn") == 0)
    ever_ok = sum(1 for r in results if r.get("converged_turn") is not None)
    n = len([r for r in results if "converged_turn" in r])
    print(f"first-try correct: {first_ok}/{n}")
    print(f"converged after test-feedback fix loop: {ever_ok}/{n}  <-- G8 code-recovery rate")
    for r in results:
        if "trace" in r:
            print(f"  rep{r['rep']}: turns={r['turns']} converged_turn={r.get('converged_turn')} seq_path={[t.get('ran') for t in r['trace']]}")
    print(f"cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 8)
