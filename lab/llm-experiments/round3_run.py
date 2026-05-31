"""Stage-2 of per-tool coverage: run deepseek-v4-flash on EACH distinct generated scenario, as a
2-TURN ReAct (honest: the model's search-first recon is turn 1; the terminal action is turn 2).
Reads /tmp/r3scen/<tool>.json (≥50/tool). Offers the tool's FAMILY toolset. If turn-1 is recon-only
(search/list/get/health), a synthetic recon RESULT is fed and the model acts again (turn 2).
Captures the union of tools called across turns → /tmp/r3res/<tool>.json. Resumable + budget-aware.
  python3 round3_run.py [only_substr]
"""
from __future__ import annotations
import json, os, re, sys
from pathlib import Path
import spec_catalog as sc
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

_ID_RE = re.compile(r"\b(?:fn|hd|ag|wf|doc|mc|cv|msg)_[0-9a-zA-Z]{6,}\b")
_VER_RE = re.compile(r"(?:第|版本|version|targetVersion)[\s:=\"']*?(\d+)")


def _extract_ctx(s):
    """Pull the scenario's REAL entity id + version so synth recon echoes them (not a generic id) —
    makes act-on-existing USAGE faithfully measurable."""
    blob = (s.get("intent", "") or "") + " " + (s.get("user", "") or "")
    mid = _ID_RE.search(blob)
    mver = _VER_RE.search(blob)
    return {"id": mid.group(0) if mid else None, "version": mver.group(1) if mver else None}

SCEN = Path("/tmp/r3scen"); RES = Path("/tmp/r3res"); RES.mkdir(exist_ok=True)
TOOL_FAMILY = {}
for fam, tools in sc.FAMILIES.items():
    for t in tools:
        TOOL_FAMILY[(t.get("function") or t)["name"]] = fam

_PREFIX = {"function": "fn", "handler": "hd", "agent": "ag", "workflow": "wf", "document": "doc"}
_RECON_PREFIX = ("search_", "list_", "get_")
_RECON_EXACT = {"Read", "Glob", "Grep", "BashOutput", "read_document", "query_events", "health_check_mcp"}


def _is_recon(name):
    return name in _RECON_EXACT or any(name.startswith(p) for p in _RECON_PREFIX)


def _reasoning(res):
    """DeepSeek requires reasoning_content echoed back on multi-turn (else 400). Pull from raw."""
    try:
        return (res.raw_response.get("choices") or [{}])[0].get("message", {}).get("reasoning_content")
    except Exception:
        return None


def synth_recon_result(name, args, expected_tool, fam, turn=1, ctx=None):
    """A plausible tool RESULT that ENABLES the model's intended next (terminal) step.
    create_* expected → recon returns empty (no existing match → model creates).
    else → recon returns a plausible existing entity (→ model acts on it).
    ctx (scenario's real id/version) is echoed so act-on-existing USAGE is faithfully measurable.
    turn≥2 → append a nudge to commit (the model already has the entity; stop re-reconning)."""
    nudge = "" if turn < 2 else "  你已获得该实体的完整信息(见上),现在直接执行用户请求的操作,不要再重复查询。"
    pid = _PREFIX.get(fam, "ent")
    ctx = ctx or {}
    plausible_id = ctx.get("id") or f"{pid}_a1b2c3d4e5f60718"
    sver = int(ctx.get("version")) if (ctx.get("version") or "").isdigit() else 8
    creating = expected_tool.startswith("create_")
    # rich entity stub so the model can PROCEED to edit/accept/revert/act (not loop in recon).
    # code type-aware: handler=stateful class, function=def (so the model isn't confused by a type mismatch).
    _code = ("class RateLimiter:\n    def __init__(self, capacity, refill_rate):\n        self.capacity = capacity\n        self.tokens = capacity\n        self.refill_rate = refill_rate\n        self.last = 0.0\n    def allow(self, now):\n        self.tokens = min(self.capacity, self.tokens + (now - self.last) * self.refill_rate)\n        self.last = now\n        if self.tokens >= 1:\n            self.tokens -= 1\n            return True\n        return False"
             if fam == "handler" else
             "def calc(order, rate):\n    subtotal = sum(i['price'] * i['qty'] for i in order['items'])\n    return round(subtotal * rate, 2)")
    rich = {"id": plausible_id, "name": "the_target_entity", "status": "pending_review",
            "current_version": 7, "pending_version": 8, "kind": ("polling" if fam == "function" else None),
            "code": _code,
            "graph": {"nodes": [{"id": "t", "type": "trigger"}, {"id": "a", "type": "tool", "config": {"callable": "fn_x"}}], "edges": [["t", "a"]]},
            "config": {"capacity": 100, "refill_rate": 10}, "tools": ["fn_x", "hd_y"], "prompt": "current agent prompt here"}
    if name == "search_mcp_tools":
        payload = {"data": [{"server": "github", "tool": "create_issue", "ref": "mcp:github/create_issue",
                             "schema": {"repo": "string", "title": "string", "body": "string"}}]}
    elif name == "list_mcp_servers":
        payload = {"data": [{"name": "github", "status": "connected"}, {"name": "slack", "status": "connected"}]}
    elif name == "Read" or name == "read_document":
        payload = {"data": "alipay_timeout_seconds: 30\nother_config: keep\nfunc CreateTicket(userID string) {...}"}
    elif name in ("Glob", "Grep"):
        payload = {"data": ["config/payment.yaml", "src/handlers/ticket.go"]}
    elif name == "BashOutput":
        payload = {"data": "tests passed: 12/12"}
    elif name.endswith("_versions"):
        # include the scenario's target version (sver) as a revertable non-current + a current later one.
        payload = {"data": [{"version": sver, "current": False, "note": "known-good target"},
                            {"version": sver + 1, "current": True, "note": "the current/bad one"}]}
    elif name.startswith("search_") or name.startswith("list_"):
        payload = {"data": []} if creating else {"data": [rich]}
        if creating:
            payload["note"] = "no matching existing entity — safe to create new"
    elif name.startswith("get_"):
        payload = {"data": rich}
    elif name.startswith("health_check"):
        payload = {"data": {"server": "github", "healthy": True}}
    elif name == "query_events":
        payload = {"data": [{"event": "node_failed", "detail": "KeyError customer_id"}]}
    else:
        payload = {"data": "ok"}
    return json.dumps(payload, ensure_ascii=False) + nudge


def run(only=None, workers=24):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    files = sorted(SCEN.glob("*.json"))
    if only:
        files = [f for f in files if only in f.stem]
    budget = {"v": False}
    total_done = 0
    for f in files:
        tool = f.stem
        fam = TOOL_FAMILY.get(tool)
        if not fam:
            print(f"!! {tool}: no family, skip"); continue
        tools = sc.FAMILIES[fam]
        try:
            scens = json.loads(f.read_text())
        except Exception as e:
            print(f"!! {tool}: bad scen json {e}"); continue
        if not isinstance(scens, list):
            scens = scens.get("scenarios", []) if isinstance(scens, dict) else []
        outpath = RES / f"{tool}.json"
        prior = {}
        if outpath.exists():
            try:
                prior = {r["id"]: r for r in json.loads(outpath.read_text()) if "id" in r}
            except Exception:
                prior = {}
        todo = [s for s in scens if s.get("id") and s["id"] not in prior]
        if not todo:
            print(f"== {tool}: {len(prior)} done (skip)"); continue

        MAXTURNS = 4

        def work(s):
            if budget["v"]:
                return None
            try:
                msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": s["user"]}]
                ctx = _extract_ctx(s)
                calls = []
                head = ""
                for turn in range(1, MAXTURNS + 1):
                    res = ds.chat_complete(messages=msgs, tools=tools, scenario=f"r3_{tool}_t{turn}", variant="coverage",
                                           temperature=None, max_tokens=12000, disable_thinking=False)
                    if turn == 1:
                        head = (res.content or "")[:120]
                    tcs = res.effective_tool_calls
                    names = [(t.get("function") or t).get("name") for t in tcs]
                    calls += [{"name": (t.get("function") or t).get("name"), "args": parse_args(t), "turn": turn} for t in tcs]
                    # stop: hit the expected tool, OR no call, OR a non-recon (terminal) decision was made
                    if tool in names or not tcs or not all(_is_recon(n) for n in names):
                        break
                    # else recon-only → feed synthetic results, loop
                    asst = {"role": "assistant", "content": res.content or "", "tool_calls": tcs}
                    rc = _reasoning(res)
                    if rc:
                        asst["reasoning_content"] = rc
                    msgs = msgs + [asst]
                    for t in tcs:
                        nm = (t.get("function") or t).get("name")
                        msgs.append({"role": "tool", "tool_call_id": t.get("id") or f"call_{nm}",
                                     "content": synth_recon_result(nm, parse_args(t), tool, fam, turn=turn, ctx=ctx)})
                allnames = [c["name"] for c in calls]
                return {"id": s["id"], "user": s.get("user", ""), "intent": s.get("intent", ""), "rubric": s.get("rubric", []),
                        "expected_tool": tool, "family": fam, "turns": max((c["turn"] for c in calls), default=0),
                        "called": allnames, "tool_calls": calls, "content_head": head}
            except ds.BudgetExhausted:
                budget["v"] = True
                return None
            except Exception as e:
                return {"id": s["id"], "error": f"{type(e).__name__}: {e}", "expected_tool": tool, "family": fam}

        results = list(prior.values())
        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            for fut in cf.as_completed([ex.submit(work, s) for s in todo]):
                r = fut.result()
                if r:
                    results.append(r); total_done += 1
        results.sort(key=lambda x: x.get("id", ""))
        outpath.write_text(json.dumps(results, ensure_ascii=False, indent=2))
        print(f"== {tool}: +{len(todo)} ran, {len(results)} total | ¥{ds.cumulative_cost_rmb():.2f}", flush=True)
        if budget["v"]:
            print("*** BUDGET EXHAUSTED — progress saved, rerun to resume ***"); break
    print(f"R3 RUN: +{total_done} scenarios this pass; cumulative ¥{ds.cumulative_cost_rmb():.2f}")


if __name__ == "__main__":
    run(only=sys.argv[1] if len(sys.argv) > 1 else None)
