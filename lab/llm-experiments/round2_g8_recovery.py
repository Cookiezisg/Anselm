"""Round-2 G8 re-validation at TEMP=DEFAULT: does create→test→error-feedback→fix recover the
weak token-bucket handler surface (R2 robustness 62%) at production temperature?
Each episode: ds create_handler → g8_test (mock-clock oracle, subprocess-isolated) → if BUG,
feed G7 error envelope → ds fix → g8_test again. Measures first-draft vs post-recovery correctness.
n=20, temp=default. Output: /tmp/g8/recovery.json"""
from __future__ import annotations
import json, os, subprocess, sys
from pathlib import Path
import deepseek_client as ds
from g8_spec import CREATE_HANDLER, USER
from wave1_gen import SYSTEM

G8 = Path("/tmp/g8"); G8.mkdir(exist_ok=True)
HERE = Path(__file__).parent


def _parse(args):
    if isinstance(args, dict):
        return args
    try:
        return json.loads(args, strict=False)
    except Exception:
        try:
            from json_repair import repair_json
            return json.loads(repair_json(args))
        except Exception:
            return None


def _test(code: str, tag: str):
    p = G8 / f"{tag}.py"; p.write_text(code)
    r = subprocess.run([sys.executable, str(HERE / "g8_test.py"), str(p)], capture_output=True, text=True, cwd=str(HERE))
    try:
        return json.loads(r.stdout.strip().splitlines()[-1])
    except Exception:
        return {"verdict": "HARNESS_CANT_RUN", "detail": f"oracle crash: {r.stderr[:200]}"}


MAX_ROUNDS = 3  # how many test→feedback→fix iterations to try


def episode(i: int):
    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": USER}]
    res = ds.chat_complete(messages=msgs, tools=[CREATE_HANDLER], scenario=f"g8_create_{i}", variant="g8recover",
                           temperature=None, max_tokens=16000, disable_thinking=False)
    tcs = res.effective_tool_calls
    if not tcs:
        return {"rep": i, "attempted": False, "note": "nocall"}
    args = _parse(tcs[0].get("function", {}).get("arguments"))
    if not args or "code" not in args:
        return {"rep": i, "attempted": True, "verdicts": ["NO_CODE_FIELD"]}
    v = _test(args["code"], f"r{i}_d0")
    verdicts = [v["verdict"]]
    rec = {"rep": i, "attempted": True, "verdicts": verdicts, "first_detail": v["detail"]}
    if v["verdict"] != "BUG":
        return rec  # CORRECT (done) or HARNESS_CANT_RUN (exclude)
    # ---- G8 recovery loop: feed the failing test as a G7 envelope, ask to fix, re-test, repeat ----
    rnd = 0
    while v["verdict"] == "BUG" and rnd < MAX_ROUNDS:
        rnd += 1
        tc_id = tcs[0].get("id") or "call_0"
        msgs = msgs + [
            {"role": "assistant", "content": "", "tool_calls": tcs},
            {"role": "tool", "tool_call_id": tc_id, "content": json.dumps({"error": {
                "code": "HANDLER_TEST_FAILED", "message": v["detail"],
                "next_step": "fix the token-bucket refill logic and resubmit create_handler with corrected code"}}, ensure_ascii=False)},
            {"role": "user", "content": "试跑失败(见上)。修正令牌桶逻辑后重新提交 create_handler。"}]
        r = ds.chat_complete(messages=msgs, tools=[CREATE_HANDLER], scenario=f"g8_fix{rnd}_{i}", variant="g8recover",
                             temperature=None, max_tokens=16000, disable_thinking=False)
        tcs = r.effective_tool_calls
        if not tcs:
            verdicts.append("NOCALL_ON_FIX"); break
        a = _parse(tcs[0].get("function", {}).get("arguments"))
        if not a or "code" not in a:
            verdicts.append("NO_CODE_ON_FIX"); break
        v = _test(a["code"], f"r{i}_d{rnd}")
        verdicts.append(v["verdict"])
    rec["verdicts"] = verdicts
    return rec


def run(reps=20, workers=12):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = []
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for fut in cf.as_completed([ex.submit(episode, i) for i in range(reps)]):
            try:
                recs.append(fut.result())
            except ds.BudgetExhausted:
                print("*** BUDGET EXHAUSTED ***"); break
            except Exception as e:
                recs.append({"error": f"{type(e).__name__}: {e}"})
    recs.sort(key=lambda x: x.get("rep", 99))
    (G8 / "recovery.json").write_text(json.dumps(recs, ensure_ascii=False, indent=2))
    att = [r for r in recs if r.get("attempted") and (r.get("verdicts") or [""])[0] in ("CORRECT", "BUG")]
    n = len(att)

    def correct_by_round(r, k):
        # correct if a CORRECT verdict appears at index <= k (0=first draft, 1=after 1 fix, ...)
        return "CORRECT" in (r.get("verdicts") or [])[:k + 1]

    curve = [sum(1 for r in att if correct_by_round(r, k)) for k in range(MAX_ROUNDS + 1)]
    cant = sum(1 for r in recs if (r.get("verdicts") or [""])[0] == "HARNESS_CANT_RUN")
    nocall = sum(1 for r in recs if not r.get("attempted"))
    print(f"\n=== G8 RECOVERY CURVE @ temp=default (n={n} testable; {cant} harness-cant-run, {nocall} nocall) ===")
    labels = ["first-draft (0 fix)"] + [f"after {k} fix-round{'s' if k > 1 else ''}" for k in range(1, MAX_ROUNDS + 1)]
    for k, lab in enumerate(labels):
        print(f"  {lab:22s}: {curve[k]}/{n} = {100*curve[k]/n if n else 0:.0f}%")
    print(f"cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 20)
