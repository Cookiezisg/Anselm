"""Round 3b — lazy grouping (fresh) + 4 specific reranks + subagent prompts.

Usage: python3 r3b_forge.py lazy 15  |  rerank 15  |  subagent 15
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from deepseek_client import chat_complete
from forge_runner import RESULTS_DIR

MAXW = 6

# ============ lazy (fresh, forge framework) ============
# Reuse experiments.py groups + activate meta, thinking-off, the V4 (no-resident-search) winner.
def run_lazy(reps):
    from experiments import GROUPS_6, GROUPS_11, GROUPS_18, _activate_tool_meta, LAZY_SCENARIOS, SYSTEM_PROMPT_LAZY
    schemes = {"V1-6": GROUPS_6, "V2-11": GROUPS_11, "V3-18": GROUPS_18}
    # V4 = 11 groups, NO resident search (only activate_tools)
    print("lazy (thinking-off, fresh):", flush=True)
    for label, groups, resident in [
        ("V1-6", GROUPS_6, True), ("V2-11", GROUPS_11, True),
        ("V3-18", GROUPS_18, True), ("V4-11-noResident", GROUPS_11, False)]:
        from experiments import RESIDENT
        tools = ([] if not resident else list(RESIDENT)) + [_activate_tool_meta(list(groups.keys()))]
        ok_total = 0; n_total = 0
        for s in LAZY_SCENARIOS:
            exp = s["expected"]
            req = exp.get("alt_activations", {}).get({"V1-6": "GROUPS_6", "V2-11": "GROUPS_11", "V3-18": "GROUPS_18", "V4-11-noResident": "GROUPS_11"}[label], exp.get("required_activations", []))
            def _one(i):
                r = chat_complete(messages=[{"role": "system", "content": SYSTEM_PROMPT_LAZY}, {"role": "user", "content": s["user_prompt"]}],
                                  tools=tools, scenario=f"lazy-{label}-{s['id']}", variant=label, max_tokens=800,
                                  tool_choice="auto", disable_thinking=True)
                tc = r.raw_response["choices"][0]["message"].get("tool_calls")
                if not tc:
                    return False
                fn = tc[0]["function"]
                if fn["name"] != "activate_tools":
                    return False
                try:
                    cat = json.loads(fn["arguments"]).get("category")
                except Exception:
                    return False
                return cat in req
            rows = []
            with ThreadPoolExecutor(max_workers=MAXW) as ex:
                for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                    rows.append(f.result())
            ok_total += sum(rows); n_total += len(rows)
        print(f"  {label}: {ok_total}/{n_total} activated-correct", flush=True)


# ============ 4 specific reranks ============
def run_rerank(reps):
    SYS = "Rank candidates by relevance to the query. Output ONLY a JSON array of ids, most relevant first. No prose."
    cases = [
        ("rerank-fn", 'Query: "send a slack message". Candidates: [{"id":"fn_slack_post","d":"post to slack"},{"id":"fn_send_email","d":"email"},{"id":"fn_parse","d":"parse"}]', "fn_slack_post"),
        ("rerank-hd", 'Query: "cache oauth tokens". Candidates: [{"id":"hd_oauth","d":"oauth token cache"},{"id":"hd_db","d":"sql db"},{"id":"hd_log","d":"logging"}]', "hd_oauth"),
        ("rerank-skill", 'Query: "extract invoice fields". Candidates: [{"name":"invoice-extract","d":"pull invoice fields"},{"name":"summarize","d":"summarize"},{"name":"translate","d":"translate"}]', "invoice-extract"),
        ("rerank-mcp", 'Query: "create github issue". Candidates: [{"id":"github/create_issue","d":"open an issue"},{"id":"slack/post","d":"slack"},{"id":"gmail/send","d":"email"}]', "github/create_issue"),
    ]
    out = {}
    for cid, q, top in cases:
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": SYS}, {"role": "user", "content": q}],
                              scenario=cid, variant="rerank", max_tokens=400, disable_thinking=True)
            s = (r.content or "").strip().strip("`")
            if s.startswith("json"): s = s[4:].strip()
            try:
                arr = json.loads(s)
                return isinstance(arr, list) and len(arr) > 0 and arr[0] == top
            except Exception:
                return False
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        ok = sum(rows); out[cid] = (ok, reps)
        print(f"{cid}: {ok}/{reps} (top-1 correct + valid JSON)", flush=True)


# ============ subagent system prompts ============
def run_subagent(reps):
    # 3 subagent roles: explorer (read-only search), forger (build entity), verifier (check)
    cases = [
        ("sub-explorer", "You are a read-only EXPLORER subagent. Search and report findings. You may ONLY call search_*/get_* tools — never create/edit/delete.",
         "找出所有跟邮件相关的 function 并汇报。",
         ["search_functions"], ["create_function", "edit_function", "delete_function"]),
        ("sub-forger", "You are a FORGER subagent. Build the requested function. Call create_function then accept_pending_function.",
         "造一个 function fn_greet 返回 'hello'。",
         ["create_function"], []),
    ]
    tools = []
    from catalog_v2 import tool as _t
    for n, req in [("search_functions", ["query"]), ("get_function", ["id"]), ("create_function", ["name", "kind", "code", "description"]),
                   ("edit_function", ["id", "ops"]), ("delete_function", ["id"]), ("accept_pending_function", ["id"])]:
        tools.append(_t(n, n.replace("_", " "), req, {p: ({"type": "array"} if p == "ops" else {"type": "string"}) for p in req}))
    for cid, sysp, prompt, want, forbid in cases:
        def _one(i):
            r = chat_complete(messages=[{"role": "system", "content": sysp}, {"role": "user", "content": prompt}],
                              tools=tools, scenario=cid, variant="sub", max_tokens=800, tool_choice="auto", disable_thinking=True)
            tc = r.raw_response["choices"][0]["message"].get("tool_calls")
            if not tc:
                return False
            names = [c["function"]["name"] for c in tc]
            if any(fb in names for fb in forbid):
                return False
            return any(w in names for w in want)
        rows = []
        with ThreadPoolExecutor(max_workers=MAXW) as ex:
            for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
                rows.append(f.result())
        ok = sum(rows)
        print(f"{cid}: {ok}/{reps} (right tools, no forbidden)", flush=True)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "lazy"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 15
    {"lazy": run_lazy, "rerank": run_rerank, "subagent": run_subagent}[mode](reps)


if __name__ == "__main__":
    main()
