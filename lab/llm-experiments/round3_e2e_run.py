"""Multi-turn END-TO-END at scale: deepseek is the automation engineer building each episode FROM
SCRATCH; a generic forge-backend sim plays the backend (search→empty, create→pending id, accept→ok,
capability_check→ok, activate→ok). Captures the full trajectory → /tmp/r3e2e/results.json (judged by
wf_judge_e2e.js vs rubric). Python-driven (robust to Bash-classifier flakiness). temp=default.
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
import spec_catalog as sc
import deepseek_client as ds
from wave1_gen import SYSTEM, parse_args

E2E = Path("/tmp/r3e2e"); E2E.mkdir(exist_ok=True)
MAXTURNS = 14
FORGE_NAMES = ["search_functions", "search_handlers", "search_agents", "search_workflows", "search_documents",
               "create_function", "create_handler", "create_agent", "create_workflow", "create_document",
               "accept_pending_function", "accept_pending_handler", "accept_pending_agent", "accept_pending_workflow",
               "edit_function", "edit_handler", "edit_agent", "edit_workflow",
               "get_function", "get_handler", "get_agent", "get_workflow",
               "capability_check_workflow", "activate_workflow", "run_function", "call_handler", "run_agent"]
FORGE_TOOLS = [sc.BY_NAME[n] for n in FORGE_NAMES if n in sc.BY_NAME]
_PREFIX = {"function": "fn", "handler": "hd", "agent": "ag", "workflow": "wf", "document": "doc"}

E2E_SYS = SYSTEM + ("\n\n你是从零搭建自动化的工程师。完整流程:先 search 确认没有现成的 → forge 缺的能力"
                    "(function/handler/agent)→ accept → 用 create_workflow 把它们接成图(case 用每分支 when 守卫、"
                    "cron 后首节点先 fetch)→ capability_check_workflow → activate_workflow → 简述完成。"
                    "一步到位给完整参数,引用真实返回的 id。")


def _reasoning(res):
    try:
        return (res.raw_response.get("choices") or [{}])[0].get("message", {}).get("reasoning_content")
    except Exception:
        return None


import re as _re
_REF_RE = _re.compile(r"\b(?:fn|hd|ag)_[0-9a-zA-Z]{4,}\b")


def _wf_refs(args):
    """Extract callable refs the model put in a create_workflow's tool/agent node configs."""
    refs = set()
    ops = args.get("ops", []) if isinstance(args, dict) else []
    for o in ops if isinstance(ops, list) else []:
        if not isinstance(o, dict):
            continue
        node = o.get("node", {})
        cfg = node.get("config", {}) if isinstance(node, dict) else {}
        if isinstance(cfg, dict):
            for k in ("ref", "callable", "agentRef", "agent", "handler", "function"):
                v = cfg.get(k)
                if isinstance(v, str):
                    refs |= set(_REF_RE.findall(v))
        # also scan the whole op blob (some put refs elsewhere)
        refs |= set(_REF_RE.findall(json.dumps(o, ensure_ascii=False)))
    return refs


def backend_sim(name, args, state):
    """Forge backend WITH G8 feedback: capability_check verifies the workflow's refs against what was
    actually created → returns missing (so the model can FIX). Assigns pending ids on create."""
    args = args if isinstance(args, dict) else {}
    if name.startswith("search_"):
        return json.dumps({"data": [], "note": "nothing exists yet — safe to create"})
    if name.startswith("create_") and name != "create_workflow":
        dom = name.split("_", 1)[1]
        pid = _PREFIX.get(dom, "ent")
        state["n"] += 1
        nid = f"{pid}_{state['n']:016x}"
        state["created"].add(nid)
        return json.dumps({"data": {"id": nid, "status": "pending_review"}})
    if name == "create_workflow":
        state["n"] += 1
        wid = f"wf_{state['n']:016x}"
        state["wf_refs"] = _wf_refs(args)         # remember what this workflow references
        state["created"].add(wid)
        return json.dumps({"data": {"id": wid, "status": "pending_review"}})
    if name.startswith("accept_pending_"):
        return json.dumps({"data": {"ok": True, "status": "active"}})
    if name.startswith("edit_workflow"):
        if args.get("ops"):
            state["wf_refs"] = _wf_refs(args) or state.get("wf_refs", set())
        return json.dumps({"data": {"ok": True, "status": "pending_review"}})
    if name.startswith("edit_"):
        return json.dumps({"data": {"ok": True, "status": "pending_review"}})
    if name == "capability_check_workflow":
        refs = state.get("wf_refs", set())
        if not refs:
            return json.dumps({"error": {"code": "NO_REFS", "message": "no tool/agent node references any forged "
                               "function/handler/agent — the workflow isn't wired to your forged pieces",
                               "next_step": "add ref to each tool node's config (e.g. config.ref='fn_...') pointing "
                               "at the ids you created, then capability_check again"}})
        missing = [r for r in refs if r not in state["created"]]
        if missing:
            return json.dumps({"error": {"code": "CAPABILITY_MISSING", "message": f"workflow references {missing} "
                               "which were never created", "next_step": "create those functions/handlers/agents (and "
                               "accept them) OR fix the refs to ids you actually created, then capability_check again"}})
        return json.dumps({"data": {"ok": True, "missing": []}})
    if name == "activate_workflow":
        return json.dumps({"data": {"ok": True, "status": "active"}})
    if name.startswith("get_"):
        return json.dumps({"data": {"id": (args or {}).get("id", "ent_x"), "status": "active", "detail": "..."}})
    if name in ("run_function", "call_handler", "run_agent"):
        return json.dumps({"data": {"result": "ok", "output": "sample"}})
    return json.dumps({"data": "ok"})


def run(workers=12):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    episodes = json.loads((E2E / "episodes.json").read_text())
    budget = {"v": False}

    def work(ep):
        if budget["v"]:
            return None
        state = {"n": 0, "created": set(), "wf_refs": set()}
        msgs = [{"role": "system", "content": E2E_SYS}, {"role": "user", "content": ep["user"]}]
        traj = []
        try:
            for turn in range(1, MAXTURNS + 1):
                res = ds.chat_complete(messages=msgs, tools=FORGE_TOOLS, scenario=f"e2e_{ep['id']}", variant="e2e",
                                       temperature=None, max_tokens=16000, disable_thinking=False)
                tcs = res.effective_tool_calls
                if not tcs:
                    traj.append({"turn": turn, "final": (res.content or "")[:400]})
                    break
                asst = {"role": "assistant", "content": res.content or "", "tool_calls": tcs}
                rc = _reasoning(res)
                if rc:
                    asst["reasoning_content"] = rc
                msgs.append(asst)
                for t in tcs:
                    nm = (t.get("function") or t).get("name")
                    a = parse_args(t)
                    traj.append({"turn": turn, "name": nm, "args": a})
                    msgs.append({"role": "tool", "tool_call_id": t.get("id") or f"c{turn}",
                                 "content": backend_sim(nm, a if isinstance(a, dict) else {}, state)})
            return {"id": ep["id"], "user": ep["user"], "intent": ep.get("intent", ""), "rubric": ep.get("rubric", []),
                    "turns_used": min(turn, MAXTURNS), "trajectory": traj}
        except ds.BudgetExhausted:
            budget["v"] = True
            return None
        except Exception as ex:
            return {"id": ep["id"], "error": f"{type(ex).__name__}: {ex}", "trajectory": traj}

    recs = []
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for fut in cf.as_completed([ex.submit(work, ep) for ep in episodes]):
            r = fut.result()
            if r:
                recs.append(r)
    recs.sort(key=lambda x: x.get("id", ""))
    (E2E / "results.json").write_text(json.dumps(recs, ensure_ascii=False, indent=2))
    print(f"E2E run: {len(recs)} episodes; cumulative ¥{ds.cumulative_cost_rmb():.2f}")
    if budget["v"]:
        print("*** BUDGET EXHAUSTED ***")


if __name__ == "__main__":
    run()
