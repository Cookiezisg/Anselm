"""Deterministic token-bucket test harness — the G8-recovery verdict oracle.
  python3 g8_test.py <code.py>  → prints JSON {verdict, detail}
verdict ∈ {CORRECT, BUG, HARNESS_CANT_RUN}. Supports BOTH API styles:
  (a) allow(now) — explicit timestamp passed in (robustness wave9 style); or
  (b) allow()    — internal clock (mocked via time.monotonic/time.time).
Checks: burst to capacity C=5 all-allow; over-capacity deny; refill N=1/s after elapsed; cap at C."""
from __future__ import annotations
import inspect, json, sys, time

METHODS = ["allow", "allow_request", "try_acquire", "acquire", "is_allowed", "consume", "take", "request", "__call__"]


def _instantiate(cls):
    for kw in [dict(capacity=5, refill_rate=1.0), dict(capacity=5, rate=1.0), dict(rate=1.0, capacity=5),
               dict(capacity=5, refill_per_sec=1.0), dict(c=5, n=1.0), dict(n=1.0, c=5),
               dict(max_tokens=5, refill_rate=1.0), dict(capacity=5, fill_rate=1.0)]:
        try:
            return cls(**kw)
        except Exception:
            pass
    for args in [(1.0, 5), (5, 1.0), (5, 1), (1, 5)]:  # (rate,cap) per rubric, and (cap,rate)
        try:
            return cls(*args)
        except Exception:
            pass
    return None


def run(code_path: str):
    src = open(code_path).read()
    ns: dict = {}
    try:
        exec(src, ns)
    except Exception as e:
        return {"verdict": "HARNESS_CANT_RUN", "detail": f"exec error: {type(e).__name__}: {e}"}
    cls = next((v for v in ns.values() if isinstance(v, type) and any(hasattr(v, m) for m in METHODS)), None)
    if cls is None:
        return {"verdict": "HARNESS_CANT_RUN", "detail": "no rate-limiter class found"}
    inst = _instantiate(cls)
    if inst is None:
        return {"verdict": "HARNESS_CANT_RUN", "detail": "cannot instantiate with capacity=5, refill=1/s"}
    meth = next((m for m in METHODS if hasattr(inst, m)), None)
    call = getattr(inst, meth)
    # does the method accept an explicit `now`?
    try:
        nparams = len([p for p in inspect.signature(call).parameters.values()
                       if p.kind in (p.POSITIONAL_OR_KEYWORD, p.POSITIONAL_ONLY)])
    except (ValueError, TypeError):
        nparams = 0
    wants_now = nparams >= 1

    clk = {"t": 0.0}
    real_mono, real_time = time.monotonic, time.time

    def take():
        try:
            r = call(clk["t"]) if wants_now else call()
        except TypeError:
            r = call() if wants_now else call(clk["t"])
        return bool(r[0]) if isinstance(r, tuple) else bool(r)

    if not wants_now:
        time.monotonic = lambda: clk["t"]; time.time = lambda: clk["t"]
    try:
        clk["t"] = 0.0
        burst = [take() for _ in range(5)]
        sixth = take()
        clk["t"] = 2.0
        ref = [take() for _ in range(3)]       # expect T,T,F
        clk["t"] = 1000.0
        ncap = sum(take() for _ in range(7))    # expect exactly 5 (never exceed capacity)
    finally:
        time.monotonic, time.time = real_mono, real_time
    checks = {"burst_all_allow": all(burst), "over_capacity_deny": not sixth,
              "refill_2_then_deny": ref[:2] == [True, True] and ref[2] is False,
              "never_exceed_capacity": ncap == 5}
    ok = all(checks.values())
    fails = [k for k, v in checks.items() if not v]
    return {"verdict": "CORRECT" if ok else "BUG",
            "detail": (f"api={'allow(now)' if wants_now else 'internal-clock'} burst={burst} sixth={sixth} "
                       f"after+2s={ref} cap+1000s={ncap}/5" + ("" if ok else f" | FAILED: {fails}"))}


if __name__ == "__main__":
    print(json.dumps(run(sys.argv[1]), ensure_ascii=False))
