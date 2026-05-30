"""Run the model-under-test over scenarios → raw traces (SPEC §3 run_model).

Single-turn by default (cheap; covers selection + first-args = both themes for most tools). Multi-turn
(config.backend='multi') adds a faithful synthetic backend for recon-then-act scenarios — the recon
result echoes the scenario's real id (the synth-id-contamination fix, R3 lesson).

Code tools (create_function/handler) with a `code_test` get REALLY EXECUTED in a subprocess — the one
hard ground truth that needs no judge.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import memory as mem
import model_client as mc

_RECON = ("search_", "list_", "get_")
_RECON_EXACT = {"Read", "Glob", "Grep", "read_document", "query_events", "health_check_mcp"}
_ID_RE = re.compile(r"\b(?:fn|hd|ag|wf|doc|mc)_[0-9a-zA-Z]{6,}\b")


def _is_recon(name: str) -> bool:
    return name in _RECON_EXACT or any(name.startswith(p) for p in _RECON)


def _wrap_tools(surfaces: dict, tool_names: list[str] | None) -> list[dict]:
    tools = surfaces["tools"]
    if tool_names:
        keep = set(tool_names)
        tools = [t for t in tools if t["name"] in keep]
    return [{"type": "function", "function": t} for t in tools]


def _synth_recon(name: str, scen: dict, expected: str) -> str:
    """A plausible recon RESULT that lets the model proceed. Echoes the scenario's real id (faithful)."""
    blob = (scen.get("intent", "") + " " + scen.get("user", ""))
    m = _ID_RE.search(blob)
    rid = m.group(0) if m else "fn_a1b2c3d4e5f60718"
    if expected.startswith("create_"):
        return json.dumps({"data": [], "note": "no matching entity — safe to create"})
    rich = {"id": rid, "name": "target_entity", "status": "pending_review",
            "current_version": 7, "code": "def calc(x):\n    return x * 2",
            "graph": {"nodes": [{"id": "t", "type": "trigger"}], "edges": []}}
    if name.startswith("get_"):
        return json.dumps({"data": rich})
    return json.dumps({"data": [rich]})


def _exec_function(code: str, code_test: dict) -> dict:
    """Real ground truth for code: run the produced function against the scenario's test in a subprocess."""
    harness = code + "\n\n" + code_test.get("harness", "")
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
            f.write(harness)
            path = f.name
        p = subprocess.run([sys.executable, path], capture_output=True, text=True, timeout=10)
        Path(path).unlink(missing_ok=True)
        if p.returncode == 0:
            return {"exec": "clean", "stdout": p.stdout[-500:]}
        return {"exec": "error", "stderr": p.stderr[-500:]}
    except subprocess.TimeoutExpired:
        return {"exec": "timeout"}
    except Exception as e:
        return {"exec": "harness_error", "err": str(e)}


def run(td: Path, scenarios: list[dict], round_dir: Path, *, tool_names: list[str] | None = None,
        config: dict | None = None) -> list[dict]:
    config = config or mem.load_json(td / "config.json", {})
    model = config.get("model_under_test", mc.DEFAULT_MODEL)
    backend = config.get("backend", "single_turn")
    sysprompt = mem.assemble_system_prompt(td)
    surfaces = mem.load_surfaces(td)
    tools = _wrap_tools(surfaces, tool_names)
    traces_dir = round_dir / "traces"
    traces_dir.mkdir(parents=True, exist_ok=True)

    out = []
    for scen in scenarios:
        msgs = [{"role": "system", "content": sysprompt}, {"role": "user", "content": scen["user"]}]
        calls, cost, content, reasoning = [], 0.0, "", ""
        maxturns = 4 if backend == "multi" else 1
        for turn in range(1, maxturns + 1):
            res = mc.chat(msgs, tools, model=model, max_tokens=12000)
            cost += res.cost_rmb
            if turn == 1:
                content, reasoning = res.content, res.reasoning
            tcs = res.effective_calls
            names = [(t.get("function") or t).get("name") for t in tcs]
            calls += [{"name": n, "args": mc.parse_args(t), "turn": turn} for n, t in zip(names, tcs)]
            expected = scen.get("expected_tool", "")
            if (expected and expected in names) or not tcs or not all(_is_recon(n) for n in names):
                break
            msgs = msgs + [{"role": "assistant", "content": res.content or "", "tool_calls": tcs}]
            for t in tcs:
                nm = (t.get("function") or t).get("name")
                msgs.append({"role": "tool", "tool_call_id": t.get("id") or f"c_{nm}",
                             "content": _synth_recon(nm, scen, expected)})

        rec = {"id": scen["id"], "user": scen.get("user", ""), "intent": scen.get("intent", ""),
               "rubric": scen.get("rubric", []), "expected_tool": scen.get("expected_tool", ""),
               "called": [c["name"] for c in calls], "tool_calls": calls,
               "content": content[:1500], "reasoning": reasoning[:800], "cost_rmb": round(cost, 6)}
        # real code execution = hard ground truth (no judge needed for this axis).
        if scen.get("code_test"):
            code = next((c["args"].get("code") for c in calls
                         if c["name"] in ("create_function", "create_handler") and isinstance(c["args"], dict) and c["args"].get("code")), None)
            if code:
                rec["exec_result"] = _exec_function(code, scen["code_test"])
        (traces_dir / f"{scen['id']}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        out.append(rec)
    return out
