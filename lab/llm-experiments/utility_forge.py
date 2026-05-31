"""Utility LLM scenarios — surviving-old chat infra prompts.

auto-title / rerank / compaction / env-fix / web-summary. These are NON-tool-call
LLM uses (the model returns text/JSON, not a tool call). Validators are programmatic
(title length, JSON validity, id-array correctness).

Usage: python3 utility_forge.py 15
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from deepseek_client import chat_complete
from forge_runner import RESULTS_DIR

MAXW = 6

# Each entry: (id, system_prompt, user_prompt, validator_fn)
# Validators take the raw content string -> (ok, reason)


def v_title(content):
    t = content.strip().strip('"').strip()
    if not t:
        return False, "empty"
    if len(t) > 40:
        return False, f"too long ({len(t)} chars)"
    if "\n" in t:
        return False, "multi-line"
    return True, ""


def v_json_idarray(content):
    s = content.strip()
    # strip markdown fences
    if s.startswith("```"):
        s = s.strip("`")
        s = s[s.find("\n")+1:] if "\n" in s else s
        s = s.replace("json", "", 1).strip("`\n ")
    try:
        arr = json.loads(s)
    except Exception as e:
        return False, f"not JSON: {e} | {s[:80]}"
    if not isinstance(arr, list):
        return False, "not a list"
    if not all(isinstance(x, str) for x in arr):
        return False, "non-string ids"
    return True, ""


def v_json_deps(content):
    s = content.strip()
    if s.startswith("```"):
        s = s.strip("`"); s = s[s.find("\n")+1:] if "\n" in s else s; s = s.replace("json","",1).strip("`\n ")
    try:
        obj = json.loads(s)
    except Exception as e:
        return False, f"not JSON: {e} | {s[:80]}"
    if not isinstance(obj, dict) or "deps" not in obj:
        return False, "missing deps key"
    if not isinstance(obj["deps"], list):
        return False, "deps not a list"
    return True, ""


def v_summary_cap(cap):
    def f(content):
        n = len(content)
        if n == 0:
            return False, "empty"
        if n > cap:
            return False, f"over cap ({n} chars > {cap})"
        return True, ""
    return f


SCEN = [
    ("title-1", "You generate a concise conversation title. Output ONLY the title, max 6 words, no quotes, no punctuation at end.",
     "User asked how to set up a cron-triggered workflow that emails a daily report.", v_title),
    ("title-2", "You generate a concise conversation title. Output ONLY the title, max 6 words, no quotes.",
     "User is debugging why their polling function keeps double-firing on GitHub comments.", v_title),
    ("title-3", "Output ONLY a concise title (≤6 words), nothing else.",
     "用户想把一个 handler 的 OAuth token 缓存逻辑改成自动刷新。", v_title),
    ("rerank-1", "Rank the candidates by relevance to the query. Output ONLY a JSON array of candidate ids, most relevant first. No prose.",
     'Query: "send email". Candidates: [{"id":"fn_send_email","desc":"Send transactional email"},{"id":"fn_parse_csv","desc":"Parse CSV"},{"id":"fn_email_validate","desc":"Validate email address"}]', v_json_idarray),
    ("rerank-2", "Rank candidates by relevance. Output ONLY a JSON array of ids (most relevant first).",
     'Query: "数据库查询". Candidates: [{"id":"hd_db","desc":"SQL database handler"},{"id":"fn_format_date","desc":"format date"},{"id":"hd_cache","desc":"Redis cache"}]', v_json_idarray),
    ("envfix-1", "A pip install failed. Output ONLY a JSON object {\"deps\": [list of corrected package specs]}. No prose.",
     "Error: No matching distribution found for beautifulsoup. The code imports bs4 and requests.", v_json_deps),
    ("envfix-2", "Output ONLY JSON {\"deps\": [...]} with the packages needed. No prose.",
     "ModuleNotFoundError: No module named 'PIL'. Code does `from PIL import Image` and `import numpy`.", v_json_deps),
    ("compact-1", "Summarize the conversation below into <= 400 chars, preserving key decisions and open questions.",
     "User and assistant discussed: building a workflow with cron trigger, then adding a polling function for Gmail, then debating whether to use a handler for OAuth state, decided yes, then hit a rate limit issue with the Gmail API and discussed exponential backoff, then talked about adding an approval node before sending summaries. Open: whether to cache tokens in SQLite or memory." * 2, v_summary_cap(450)),
    ("websum-1", "Summarize the web page content below in <= 300 chars, plain text.",
     "Article: A new study shows that intermittent fasting may improve metabolic health markers in adults over 40. The randomized trial of 200 participants found reductions in fasting glucose and improvements in insulin sensitivity over 12 weeks. Researchers caution the effects varied by individual and more long-term data is needed." * 3, v_summary_cap(350)),
]


def run_scen(sid, sysp, userp, validator, reps):
    def _one(i):
        try:
            r = chat_complete(messages=[{"role": "system", "content": sysp}, {"role": "user", "content": userp}],
                              scenario=sid, variant="util", max_tokens=1500, disable_thinking=True)
            ok, reason = validator(r.content or "")
            return {"ok": ok, "reason": reason, "content": (r.content or "")[:100]}
        except Exception as e:
            return {"ok": False, "reason": f"EXC {e}", "content": ""}
    rows = []
    with ThreadPoolExecutor(max_workers=MAXW) as ex:
        for f in as_completed([ex.submit(_one, i) for i in range(reps)]):
            rows.append(f.result())
    return rows


def main():
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    summary = {}
    for sid, sysp, userp, validator in SCEN:
        rows = run_scen(sid, sysp, userp, validator, reps)
        ok = sum(1 for r in rows if r["ok"])
        summary[sid] = (ok, len(rows))
        flag = "" if ok >= reps * 0.9 else "  <-- LOW"
        bad = next((r for r in rows if not r["ok"]), None)
        print(f"{sid:12s} {ok}/{reps}{flag}" + (f"  e.g. {bad['reason']} | {bad['content'][:60]!r}" if bad else ""), flush=True)
    (RESULTS_DIR / "utility_summary.json").write_text(json.dumps(summary, indent=2))
    tot = (sum(v for v, _ in summary.values()), sum(n for _, n in summary.values()))
    print(f"\nUTILITY: {tot[0]}/{tot[1]} ({tot[0]*100//tot[1]}%)")


if __name__ == "__main__":
    main()
