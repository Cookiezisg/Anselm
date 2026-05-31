"""Wave-4: CONTENT + Utility surfaces (non-tool-call outputs, judged for content).

Utility prompts (auto-title / rerank / compaction / env-fix / web-summary) are direct
prompt→text/JSON outputs — the prompt text here is candidate FINAL spec §7 text. CONTENT tools
(create_document / write_memory) judged for whether the produced content does what was asked.

Output: /tmp/w4/<id>.json = {id, kind, thinking, output, rubric, expected_hint, reps:[...]}
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import deepseek_client as ds

OUT = Path("/tmp/w4"); OUT.mkdir(exist_ok=True)

# Each: id, system, user (the utility prompt + context), rubric, expected_hint, thinking
SCEN = [
    {
        "id": "auto_title", "thinking": False,
        "system": "You generate a conversation title. Output ONLY the title: ≤6 words, no quotes, no punctuation at the end, no markdown.",
        "user": "Conversation:\nUser: 帮我建个每天早上把未读邮件分类并把发票转给财务的自动化\nAssistant: 好的，我来设计这个 workflow...(建了 cron→分类 agent→case 路由→财务通知)\n\nTitle:",
        "rubric": ["≤6 words / 简短", "captures the email-triage/invoice automation topic", "no surrounding quotes", "no markdown / no trailing punctuation"],
        "expected_hint": "something like 'Email triage invoice automation' / '邮件分类发票转发流程'",
    },
    {
        "id": "rerank_fn", "thinking": False,
        "system": "You rerank candidates by relevance to the user's need. Output ONLY a JSON array of the top 3 candidate ids (most relevant first). No prose.",
        "user": "Need: 给客户发送账单提醒邮件\nCandidates:\n- fn_send_email: send an email to a recipient\n- fn_parse_csv: parse CSV text\n- fn_format_invoice: format an invoice into HTML\n- fn_calc_tax: compute tax\n- fn_send_sms: send an SMS\n- fn_lookup_customer: look up a customer by id\n\nTop 3 ids:",
        "rubric": ["valid JSON array of ids", "top-1 is fn_send_email (most relevant to sending a billing email)", "fn_lookup_customer or fn_format_invoice reasonably in top 3", "no prose / no extra text", "exactly ids from the candidate list (no hallucinated ids)"],
        "expected_hint": "fn_send_email first; then plausibly fn_format_invoice / fn_lookup_customer",
    },
    {
        "id": "rerank_skill", "thinking": False,
        "system": "Rerank skills by relevance to the task. Output ONLY a JSON array of the top 2 skill names, most relevant first.",
        "user": "Task: 把一篇长技术文档总结成要点\nSkills:\n- summarization: condense text into key points\n- code-review: review code for bugs\n- data-extraction: extract structured fields\n- translation: translate between languages\n\nTop 2:",
        "rubric": ["valid JSON array", "top-1 is summarization", "no prose", "names from the list only"],
        "expected_hint": "summarization first",
    },
    {
        "id": "compaction", "thinking": False,
        "system": "Compact this conversation to preserve context. Keep: key decisions, current task state, open questions, and any important ids. Be concise (a short structured summary). Drop chit-chat.",
        "user": "Conversation:\nUser: 建个发日报的流程\nAssistant: 建好了 wf_daily_report(cron 9点→ag_report_writer→fn_email_report），已 active。\nUser: 发送老失败\nAssistant: 查了 fr_a/fr_b，发现 fn_email_report 在 SMTP 超时。建议加重试。\nUser: 加上重试最多3次\nAssistant: (正在编辑 wf_daily_report 加 case 重试节点，还没 accept)\nUser: 等下，先确认下重试间隔\n\nCompact summary:",
        "rubric": ["preserves wf_daily_report id + that it's the daily-report workflow", "preserves the current task: adding retry (max 3) to the send step, NOT yet accepted", "preserves the open question: retry interval to confirm", "preserves the root cause: fn_email_report SMTP timeout", "concise, no chit-chat", "doesn't invent facts"],
        "expected_hint": "must keep: wf_daily_report, retry-3 in progress (pending), interval question open, SMTP timeout cause",
    },
    {
        "id": "env_fix", "thinking": False,
        "system": "A Python function failed with a missing-dependency error. Return ONLY a JSON object: {\"deps\": [pip package names to install]}. No prose.",
        "user": "Code:\nimport requests\nfrom bs4 import BeautifulSoup\nimport pandas as pd\ndef scrape(url):\n    r = requests.get(url); soup = BeautifulSoup(r.text, 'html.parser')\n    return pd.DataFrame(...)\n\nError: ModuleNotFoundError: No module named 'bs4'\n\nDeps JSON:",
        "rubric": ["valid JSON {deps:[...]}", "includes beautifulsoup4 (the pip name for bs4 — NOT 'bs4')", "includes requests and pandas (or at least beautifulsoup4)", "uses correct PIP names (beautifulsoup4 not bs4)", "no prose"],
        "expected_hint": "beautifulsoup4 (key: knows bs4→beautifulsoup4), requests, pandas",
    },
    {
        "id": "web_summary", "thinking": False,
        "system": "Summarize the web page for the user's query in 3-4 sentences. Use ONLY facts present in the page. Do not add outside information.",
        "user": "Query: deepseek v4 价格\nPage:\nDeepSeek V4 Pricing. Input tokens: $0.14 per million (cache miss), $0.028 per million (cache hit). Output tokens: $0.28 per million. Context window 128k. The flash variant disables thinking by default.\n\nSummary:",
        "rubric": ["accurate to the page (input $0.14/M miss, $0.028/M hit, output $0.28/M)", "3-4 sentences / concise", "no hallucinated facts not in the page", "addresses the price query"],
        "expected_hint": "must state the input/output prices correctly; no invented numbers",
    },
    {
        "id": "doc_create", "thinking": True,
        "system": "You are Forgify's chat agent. The user wants a knowledge document created. Produce the document content (markdown).",
        "user": "把'新员工第一周 onboarding checklist'写成一篇知识库文档，给团队用。包含账号开通、环境搭建、第一个任务、答疑渠道。",
        "rubric": ["covers the 4 requested sections (账号开通/环境搭建/第一个任务/答疑渠道)", "actually a usable checklist (actionable items), not vague", "markdown structure", "on-topic for new-employee onboarding"],
        "expected_hint": "a real checklist with the 4 sections",
    },
    {
        "id": "mem_write", "thinking": False,
        "system": "You are Forgify's chat agent. The user stated a durable preference. Produce the memory entry to save as JSON {\"name\":..., \"content\":...} capturing the fact concisely.",
        "user": "记住：我所有的报告都要用中文，PDF 格式，并且每周五下午发。",
        "rubric": ["valid JSON {name, content}", "content captures ALL three facts: 中文 + PDF + 周五下午", "name is a sensible key (e.g. report_preferences)", "concise, no extra prose outside JSON"],
        "expected_hint": "must capture all 3: Chinese, PDF, Friday afternoon",
    },
]


def run(reps=8, workers=14):
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()
    recs = {s["id"]: {**{k: s[k] for k in ("id", "rubric", "expected_hint", "thinking")}, "prompt": s["user"], "reps": []} for s in SCEN}
    jobs = [(s, r) for s in SCEN for r in range(reps)]
    budget = {"v": False}

    def work(job):
        s, r = job
        if budget["v"]:
            return (s["id"], None)
        try:
            res = ds.chat_complete(
                messages=[{"role": "system", "content": s["system"]}, {"role": "user", "content": s["user"]}],
                scenario=f"w4_{s['id']}", variant="util", max_tokens=4000, disable_thinking=not s["thinking"],
            )
            return (s["id"], {"rep": r, "output": res.content, "cost_rmb": round(res.cost_entry.cost_rmb, 6)})
        except ds.BudgetExhausted as e:
            budget["v"] = True
            return (s["id"], {"rep": r, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (s["id"], {"rep": r, "error": f"{type(e).__name__}: {e}"})

    done = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(work, j) for j in jobs]
        for fut in cf.as_completed(futs):
            sid, rep = fut.result()
            if rep:
                recs[sid]["reps"].append(rep)
            done += 1
            if done % 16 == 0:
                print(f"... {done}/{len(jobs)} calls; cumulative ¥{ds.cumulative_cost_rmb():.2f}", flush=True)

    for sid, rec in recs.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        (OUT / f"{sid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
        sample = (rec["reps"][0].get("output") or "")[:60] if rec["reps"] else ""
        print(f"{sid:14s} reps={len(rec['reps'])} sample={sample!r}")
    if budget["v"]:
        print("\n*** BUDGET EXHAUSTED ***")
    print(f"\nWAVE-4 GEN DONE: cumulative ¥{ds.cumulative_cost_rmb():.2f}; in {OUT}/")


if __name__ == "__main__":
    run(reps=int(sys.argv[1]) if len(sys.argv) > 1 else 8)
