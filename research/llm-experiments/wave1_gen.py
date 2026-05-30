"""Wave-1 generation: single-decision crown-jewel forge surfaces.

Burns DeepSeek (the budget-constrained resource) in a tight batch loop. For each
scenario × rep: one real assembled-prompt call → capture tool_calls/content +
structural check + cost → write a trajectory JSON for the Claude judge Workflow.

Single-decision surfaces (create_workflow / create_agent / create_function /
create_handler / CEL) are faithfully one turn — no backend needed — so Python
generation is exact AND maximizes scenarios-per-yuan. Multi-turn chains (edit /
diagnosis / search→activate) come in later waves with Claude-as-backend.

Output: /tmp/w1/<scenario_id>.json  — {id, surface, mode, intent, rubric, user,
         reps:[{rep, content, reasoning, tool_calls, structural, cost_rmb}], code_test?}
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import catalog_v2 as cat
import deepseek_client as ds

try:
    from json_repair import repair_json  # recover brace-undercount malformed args (FINDING G1)
except Exception:
    repair_json = None

OUT = Path("/tmp/w1")
OUT.mkdir(exist_ok=True)

# Realistic assembled chat system prompt (role + injected-field convention).
SYSTEM = """You are Forgify's chat agent — the user's personal AI automation engineer.
You forge automation entities and orchestrate them. Capabilities come ONLY from forge entities
(functions / handlers / agents) — there is no platform escape hatch (no built-in web/file/email).
If the user needs an external capability, you FORGE a function for it.

Design first, then make the decisive tool call with the COMPLETE arguments (don't call a tool with
half the work). Reference existing entities by id. Every tool call must include `summary`
(one sentence: what you're doing and why)."""

# ---- handler tool (not in catalog_v2; defined here with teaching) ----
_HANDLER_TEACHING = """A handler is a forge entity = a STATEFUL Python class (holds connections / cache / tokens).
BODY CONTRACT — BARE NAMES (critical):
  - __init__ receives its init params as BARE NAMED args (NOT a dict): def __init__(self, client_id, base_url): ...
  - each method receives its args as BARE NAMED args too: def refresh(self, force): ...
  - init_schema / methods_schema declare those exact param names + types.
Example:
  create_handler(name="oauth", code='''
class OAuth:
    def __init__(self, client_id, client_secret):
        self.client_id = client_id; self.client_secret = client_secret
        self._token = None; self._exp = 0
    def token(self, now):
        if self._token is None or now >= self._exp:
            self._token = self._fetch(); self._exp = now + 3600
        return self._token
''', init_schema={"client_id":"string","client_secret":"string"}, methods_schema={"token":{"now":"number"}})
"""


def handler_tool() -> list[dict]:
    return [cat.tool(
        "create_handler",
        "Create a stateful handler (a forge entity = Python class).\n\n" + _HANDLER_TEACHING,
        ["name", "code", "init_schema", "methods_schema"],
        {"name": {"type": "string"},
         "code": {"type": "string"},
         "init_schema": {"type": "object", "description": "init param names -> type"},
         "methods_schema": {"type": "object", "description": "method name -> {arg: type}"}},
    )]


def cel_tool() -> list[dict]:
    # focused CEL test: a set_case_branches tool (from catalog split tools)
    return [cat.workflow_split_tools()[2]]


# ============================================================
# Scenario bank — each: id, surface, mode, tools, user, intent, rubric, code_test?
# ============================================================
SCENARIOS: list[dict] = [
    # ---------- create_workflow (ARTIFACT) ----------
    {
        "id": "wf_clear_triage", "surface": "create_workflow", "mode": "ARTIFACT",
        "tools": cat.workflow_tools("V3-full-teaching"),
        "user": ("每天早上 9 点，拉取我未读的邮件，用 AI 把每封分类成 invoice / inquiry / spam；"
                 "invoice 交给 fn_process_invoice 处理，其余的发给我人工审批。已有 ag_email_classifier 可分类。"),
        "intent": "cron@9 → fetch unread emails → classify each → invoice routes to fn_process_invoice, rest to approval.",
        "rubric": [
            "trigger is cron at 9am",
            "THE FETCH STEP EXISTS: there is an actual mechanism to fetch unread emails (a tool node calling a fetch callable, OR explicitly flagged as missing) — NOT silently assumed",
            "agent node uses ag_email_classifier",
            "a case node routes on the classification (invoice vs rest)",
            "invoice branch reaches a tool node with callable fn_process_invoice",
            "the rest reach an approval node",
            "no dangling/null branch targets",
            "case routing uses branches (not redundant connect edges duplicating the branch targets)",
            "the graph is actually runnable: classifier receives real email data, not an empty payload",
        ],
    },
    {
        "id": "wf_vague_daily", "surface": "create_workflow", "mode": "ARTIFACT",
        "tools": cat.workflow_tools("V3-full-teaching"),
        "user": "帮我搞个自动化：把我每天的待办事项整理成一份日报，每天傍晚发到我邮箱。",
        "intent": "cron (evening) → gather todos → summarize into a report → email it. Vague: model must infer steps + that fetching todos & emailing need forge callables.",
        "rubric": [
            "trigger is cron in the evening",
            "there is a step to gather/read the todos (a callable, not assumed)",
            "there is a summarize step (agent or function)",
            "there is a send-email step via a callable (fn/hd/mcp), NOT a bare platform 'email'",
            "graph is connected end to end, runnable",
            "model did not invent a platform email/web tool out of thin air",
        ],
    },
    {
        "id": "wf_retry_loop", "surface": "create_workflow", "mode": "ARTIFACT",
        "tools": cat.workflow_tools("V3-full-teaching"),
        "user": "调用一个不太稳定的接口 fn_call_flaky_api，如果失败就重试，最多重试 3 次，3 次都失败就发通知给我。",
        "intent": "tool node calls fn_call_flaky_api → case checks success/attempt → on failure loop back (attempt+1) up to 3 → after 3 fail, notify.",
        "rubric": [
            "a tool node calls fn_call_flaky_api",
            "a case node checks failure/attempt count",
            "on failure-and-attempt<3: a branch loops BACK to the call node (cyclic) to retry",
            "the loop increments an attempt counter via branch emit (attempt+1), not platform state",
            "after 3 attempts: routes to a notify step",
            "the loop terminates (does not loop forever) — bound is exactly 3 retries",
            "CEL conditions are correct (e.g. attempt < 3, null-safe)",
        ],
    },
    {
        "id": "wf_branch_signup", "surface": "create_workflow", "mode": "ARTIFACT",
        "tools": cat.workflow_tools("V3-full-teaching"),
        "user": ("新用户注册后（webhook 触发，payload 里有 email 字段），发一封欢迎邮件 fn_send_welcome；"
                 "如果是企业邮箱（不是 gmail/qq/163 这种），额外通知销售 fn_notify_sales。"),
        "intent": "webhook → send welcome (always) → case on email domain → if corporate, also notify sales.",
        "rubric": [
            "trigger is webhook with payload schema containing email",
            "welcome email step (fn_send_welcome) runs for ALL users",
            "a case node decides corporate vs personal email by domain",
            "corporate branch reaches fn_notify_sales",
            "personal branch does NOT notify sales (ends or no-op)",
            "the CEL domain check is plausible (inspects the email domain, null-safe)",
            "ordering correct: welcome happens regardless; sales-notify only for corporate",
        ],
    },

    # ---------- create_agent (ARTIFACT) ----------
    {
        "id": "ag_enum_sentiment", "surface": "create_agent", "mode": "ARTIFACT",
        "tools": cat.agent_tools("V3-full"),
        "user": "做一个 agent，把客户评论分类成 正面 / 负面 / 中性 三类。",
        "intent": "agent: prompt classifies a review into positive/negative/neutral; outputSchema=enum with those 3 values.",
        "rubric": [
            "prompt instructs classification of a customer review",
            "outputSchema kind is enum",
            "enum values are exactly the three classes (positive/negative/neutral or 正面/负面/中性)",
            "prompt is a single block (not split system/user)",
            "tools list is empty or only forge callables — NO platform tools",
            "prompt references the input via {{ payload.* }} appropriately",
        ],
    },
    {
        "id": "ag_json_extract", "surface": "create_agent", "mode": "ARTIFACT",
        "tools": cat.agent_tools("V3-full"),
        "user": "做一个 agent，读一段产品描述，提取出 价格(price)、SKU、库存数量(stock) 三个字段。",
        "intent": "agent: extract price/SKU/stock from product description text; outputSchema=json_schema with those 3 fields + types.",
        "rubric": [
            "prompt instructs extraction of the three fields from product description",
            "outputSchema kind is json_schema",
            "json_schema has exactly price, SKU, stock with sensible types (number/string/number)",
            "prompt is one block, references input via {{ payload.* }}",
            "no platform tools mounted",
        ],
    },
    {
        "id": "ag_trap_web", "surface": "create_agent", "mode": "ARTIFACT",
        "tools": cat.agent_tools("V3-full"),
        "user": "做一个 agent，能上网查实时汇率，然后帮我把一个金额从美元换算成人民币。",
        "intent": "TRAP: agents cannot have web/platform tools. Correct behavior: forge a function for the rate lookup (or note it must be forged) and mount that fn_xxx — NOT mount a bare 'web'/'http' tool.",
        "rubric": [
            "the agent does NOT mount a platform web/http/browser tool (that is forbidden)",
            "correct handling: either tools=[a forge fn_xxx for rate lookup] OR the model explicitly says a function must be forged first",
            "the agent did not hallucinate a built-in web capability",
            "prompt describes the conversion task with {{ payload.* }} for the amount",
            "if a fn ref is mounted, it is a plausible rate-lookup callable id",
        ],
    },

    # ---------- create_function normal (CODE) ----------
    {
        "id": "fn_workdays", "surface": "create_function", "mode": "CODE",
        "tools": cat.function_tools("V5-combined"),
        "user": "写个函数，算两个日期（YYYY-MM-DD 字符串）之间的工作日天数（不含周末）。",
        "intent": "normal function computing business days between two date strings, excluding weekends.",
        "rubric": [
            "kind is normal",
            "code parses two YYYY-MM-DD strings",
            "counts weekdays only (Mon-Fri), excludes Sat/Sun",
            "boundary handling is sane (inclusive/exclusive consistent)",
            "code is syntactically valid Python and RUNS",
            "returns a correct count for the test inputs",
        ],
        "code_test": {
            "expected_behavior": "Given 2024-01-01 (Mon) and 2024-01-08 (Mon), business days between should be 5 (Jan 1-5) or 6 depending on inclusivity — judge for a sane weekday-only count, not off-by-huge. Given 2024-01-06 (Sat) and 2024-01-07 (Sun) → 0.",
            "test_inputs": ["('2024-01-01','2024-01-08')", "('2024-01-06','2024-01-07')", "('2024-03-01','2024-03-31')"],
            "mocks_hint": "no external deps; pure date math (datetime module is fine).",
        },
    },
    {
        "id": "fn_csv_parse", "surface": "create_function", "mode": "CODE",
        "tools": cat.function_tools("V5-combined"),
        "user": "写个函数，把一段 CSV 文本（第一行是表头）解析成 list of dict。",
        "intent": "normal function parsing CSV text (header row) into list[dict].",
        "rubric": [
            "kind is normal",
            "uses header row as dict keys",
            "handles multiple data rows",
            "code is valid Python and RUNS",
            "returns correct list[dict] for the test input",
            "reasonable handling of the csv module or manual split",
        ],
        "code_test": {
            "expected_behavior": "Input 'name,age\\nalice,30\\nbob,25' → [{'name':'alice','age':'30'},{'name':'bob','age':'25'}] (age may be str or int).",
            "test_inputs": ["'name,age\\nalice,30\\nbob,25'"],
            "mocks_hint": "no external deps; csv module fine.",
        },
    },

    # ---------- create_function polling (CODE — cursor) ----------
    {
        "id": "fp_rss", "surface": "create_function", "mode": "CODE",
        "tools": cat.function_tools("V5-combined"),
        "user": "写一个 polling 函数，每分钟检查一个 RSS feed 有没有新文章，有就把新文章作为事件返回。",
        "intent": "polling function: poll(last_cursor) -> {events, next_cursor}; only NEW articles since cursor; cursor advances; no dupes.",
        "rubric": [
            "kind is polling",
            "polling_interval is set (~60s)",
            "signature is poll(last_cursor) returning {events, next_cursor}",
            "only returns articles NEWER than last_cursor (no re-emitting old ones)",
            "next_cursor advances to the latest seen (and stays put when no new items)",
            "code is valid Python and RUNS against a mocked feed",
            "two consecutive polls do NOT emit the same article twice",
        ],
        "code_test": {
            "expected_behavior": "Mock the feed fetch. First poll(None) returns some events + a cursor. Second poll(that cursor) with no new items returns [] and same cursor. Add a new item, third poll returns ONLY the new one.",
            "test_inputs": ["poll(None) then poll(returned_cursor)"],
            "mocks_hint": "stub the RSS fetch (e.g. fetch_feed / feedparser.parse) to return a controllable list of items with timestamps/ids. Replace the network call with an in-memory list you mutate between polls.",
        },
    },
    {
        "id": "fp_dirwatch", "surface": "create_function", "mode": "CODE",
        "tools": cat.function_tools("V5-combined"),
        "user": "写一个 polling 函数，监控一个目录，有新文件出现就作为事件返回。",
        "intent": "polling function watching a dir for new files; cursor = seen set or latest mtime; returns only new files.",
        "rubric": [
            "kind is polling with interval",
            "poll(last_cursor) -> {events, next_cursor}",
            "detects only NEW files since last cursor",
            "cursor representation is sound (mtime or seen-set serialized)",
            "valid Python, RUNS against a mocked directory listing",
            "no duplicate emission across polls",
        ],
        "code_test": {
            "expected_behavior": "Mock os.listdir/scandir. poll(None) returns current files + cursor. With no changes, next poll returns []. Add a file → next poll returns only it.",
            "test_inputs": ["poll(None) then poll(cursor) with a new file added"],
            "mocks_hint": "stub the directory listing function to return a controllable list; mutate between polls.",
        },
    },

    # ---------- create_handler (CODE — stateful + bare-names) ----------
    {
        "id": "hd_oauth", "surface": "create_handler", "mode": "CODE",
        "tools": handler_tool(),
        "user": "写个 handler 维护一个 OAuth access token，过期了自动刷新，对外提供一个拿当前有效 token 的方法。",
        "intent": "stateful handler holding token+expiry; a method returns a valid token, refreshing when expired. bare-names body contract.",
        "rubric": [
            "it's a class with __init__ holding token + expiry state",
            "a method returns the current valid token, refreshing if expired",
            "BARE-NAMES contract obeyed: __init__ and methods take bare named params (NOT a single dict arg)",
            "init_schema + methods_schema declare matching param names",
            "valid Python; class instantiates; method callable; refresh logic correct (no refresh when valid, refresh when expired)",
            "no global state — state lives on self",
        ],
        "code_test": {
            "expected_behavior": "Instantiate with mock creds. Mock the token-fetch to return incrementing tokens. First get(now=0) fetches token A. get(now=10) (still valid) returns A WITHOUT refetch. get(now=99999) (expired) refetches → token B.",
            "test_inputs": ["instantiate, get(now=0), get(now=10), get(now=99999)"],
            "mocks_hint": "stub the network refresh method (e.g. self._fetch / requests.post) to return controllable tokens and count calls.",
        },
    },
    {
        "id": "hd_cache_ttl", "surface": "create_handler", "mode": "CODE",
        "tools": handler_tool(),
        "user": "写个 handler，做一个带 TTL 的内存缓存：set(key,value)、get(key)，过了 TTL 的项算作不存在。",
        "intent": "stateful TTL cache handler: set/get, entries expire after TTL. bare-names.",
        "rubric": [
            "class holds a dict of key -> (value, expiry)",
            "set(key, value) and get(key) methods with bare-named params",
            "get returns None/miss for expired entries",
            "TTL respected (needs a 'now' param or time source — judge how time is obtained; a passed-in now is cleanest given no platform clock guarantee)",
            "init_schema/methods_schema match param names",
            "valid Python; instantiates; set then get works; expired get misses",
        ],
        "code_test": {
            "expected_behavior": "set('k','v') at now=0 with ttl. get('k', now=1) → 'v'. get('k', now=after_ttl) → miss/None.",
            "test_inputs": ["set('k','v',now=0), get('k',now=1), get('k',now=10000)"],
            "mocks_hint": "if the handler uses time.time(), monkeypatch it; prefer if it takes an explicit now param.",
        },
    },

    # ---------- CEL (ARTIFACT — set_case_branches) ----------
    {
        "id": "cel_vip_approval", "surface": "cel_case", "mode": "ARTIFACT",
        "tools": cel_tool(),
        "user": ("在工作流 wf_billing 的 case 节点 'gate' 上配置路由：只有当金额(payload.amount)大于等于 1000 "
                 "且客户是 VIP(payload.vip 为 true)时，走人工审批分支 to=approve；否则自动通过 to=auto。"),
        "intent": "CEL: amount>=1000 && vip==true → approve, else auto.",
        "rubric": [
            "expression correctly encodes amount>=1000 AND vip true",
            ">= used (not > ) for the 1000 threshold",
            "boolean vip handled correctly (payload.vip, or payload.vip==true)",
            "branches map to approve / auto with correct targets",
            "null-safety if appropriate (has(payload.amount))",
            "no side effects / no non-CEL constructs",
        ],
    },
    {
        "id": "cel_retry_deadletter", "surface": "cel_case", "mode": "ARTIFACT",
        "tools": cel_tool(),
        "user": ("在工作流 wf_pipeline 的 case 节点 'retry_gate' 上配置重试路由：如果处理失败(payload.ok 为 false)"
                 "且已尝试次数 payload.attempt 小于 3，就回到上游节点 process 重试，并把 attempt 加一；否则进死信节点 dead。"),
        "intent": "CEL retry: !ok && attempt<3 → loop to retry_target with emit attempt+1; else → dead.",
        "rubric": [
            "expression checks failure (ok==false / !ok) AND attempt < 3",
            "the retry branch's `to` is the upstream retry_target (loop back)",
            "the retry branch emit increments attempt: attempt = (has(payload.attempt)? payload.attempt : 0) + 1",
            "the else/default branch goes to dead",
            "attempt<3 bound is correct (strictly < 3, so attempts 0,1,2 → max 3 tries)",
            "null-safe on payload.attempt",
        ],
    },
    {
        "id": "cel_nullsafe_items", "surface": "cel_case", "mode": "ARTIFACT",
        "tools": cel_tool(),
        "user": "在工作流 wf_proc 的 case 节点 'has_items' 上配置：如果 payload 里有 items 且非空，就走 process 分支(to=node_handle)处理；否则走 skip 分支(to=node_end)跳过。",
        "intent": "CEL: has(payload.items) && payload.items.size()>0 → process, else skip.",
        "rubric": [
            "uses has(payload.items) before dereferencing (null-safety)",
            "checks non-empty via size()>0 (or equivalent)",
            "process / skip branches with correct targets",
            "no side effects",
            "expression is valid CEL (not Python list truthiness)",
        ],
    },
]


def parse_args(tc: dict) -> dict:
    fn = tc.get("function") or tc
    a = fn.get("arguments") if isinstance(fn, dict) else None
    if isinstance(a, str):
        try:
            return json.loads(a, strict=False)  # tolerate control chars in strings
        except Exception:
            # FINDING G1: DeepSeek emits brace-undercount malformed JSON in ~4% of
            # complex tool args; json_repair (brace-balance) recovered 100% in testing.
            # Backend MUST run such a repair — Go encoding/json rejects these outright.
            if repair_json is not None:
                try:
                    fixed = repair_json(a, return_objects=True)
                    if isinstance(fixed, dict) and fixed:
                        fixed["__repaired__"] = True
                        return fixed
                except Exception:
                    pass
            return {"_unparseable": a}
    return a if isinstance(a, dict) else {}


def structural(surface: str, tcs: list[dict]) -> dict:
    """Cheap structural signal (an UPPER BOUND, not semantic truth)."""
    if not tcs:
        return {"called": False}
    tc = tcs[0]
    name = (tc.get("function") or tc).get("name")
    args = parse_args(tc)
    out = {"called": True, "tool": name, "first_arg_keys": sorted(args.keys())[:8]}
    if surface in ("create_workflow",):
        out["wf"] = cat.validate_workflow_ops(args.get("ops"))
    elif surface == "cel_case":
        if "expression" in args:
            out["cel"] = cat.validate_cel(args.get("expression", ""))
    elif surface == "create_function":
        out["kind"] = args.get("kind")
        out["has_code"] = bool(args.get("code"))
    elif surface == "create_handler":
        out["has_code"] = bool(args.get("code"))
        out["has_schemas"] = bool(args.get("init_schema") is not None and args.get("methods_schema") is not None)
    return out


def _one_rep(sc: dict, r: int) -> dict:
    """One (scenario, rep) DeepSeek call → rep dict. BudgetExhausted propagates."""
    res = ds.chat_complete(
        messages=[{"role": "system", "content": SYSTEM},
                  {"role": "user", "content": sc["user"]}],
        tools=sc["tools"], scenario=sc["id"], variant="w1",
        max_tokens=16000, disable_thinking=False,  # 16k: complex workflow+thinking truncated at 8k (G2)
    )
    tcs = res.effective_tool_calls
    return {
        "rep": r,
        "content": res.content,
        "reasoning": (res.raw_response.get("choices", [{}])[0].get("message", {}) or {}).get("reasoning_content", ""),
        "tool_calls": [{"name": (t.get("function") or t).get("name"), "args": parse_args(t)} for t in tcs],
        "structural": structural(sc["surface"], tcs),
        "cost_rmb": round(res.cost_entry.cost_rmb, 6),
        "leaked": bool(res.leaked_tool_calls),
        "finish_reason": res.finish_reason,
    }


def run(reps: int = 6, only: str | None = None, workers: int = 14) -> None:
    import concurrent.futures as cf
    if not os.environ.get("DEEPSEEK_API_KEY"):
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            os.environ["DEEPSEEK_API_KEY"] = kf.read_text().strip()

    scs = [sc for sc in SCENARIOS if not only or only in sc["id"]]
    by_id: dict[str, dict] = {}
    for sc in scs:
        rec = {k: sc[k] for k in ("id", "surface", "mode", "intent", "rubric", "user")}
        if "code_test" in sc:
            rec["code_test"] = sc["code_test"]
        rec["reps"] = []
        by_id[sc["id"]] = rec
    jobs = [(sc, r) for sc in scs for r in range(reps)]
    budget_hit = {"v": False}

    def work(job: tuple) -> tuple:
        sc, r = job
        if budget_hit["v"]:
            return (sc["id"], None)
        try:
            return (sc["id"], _one_rep(sc, r))
        except ds.BudgetExhausted as e:
            budget_hit["v"] = True
            return (sc["id"], {"rep": r, "budget_exhausted": True, "error": str(e)})
        except Exception as e:
            return (sc["id"], {"rep": r, "error": f"{type(e).__name__}: {e}"})

    done = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(work, j) for j in jobs]
        for fut in cf.as_completed(futs):
            sid, rep = fut.result()
            if rep is not None:
                by_id[sid]["reps"].append(rep)
            done += 1
            if done % 10 == 0:
                print(f"... {done}/{len(jobs)} calls; cumulative ¥{ds.cumulative_cost_rmb():.2f}", flush=True)

    for sid, rec in by_id.items():
        rec["reps"].sort(key=lambda x: x.get("rep", 0))
        _write(rec)
        called = sum(1 for x in rec["reps"] if x.get("structural", {}).get("called"))
        errs = sum(1 for x in rec["reps"] if x.get("error"))
        print(f"{sid:24s} surface={rec['surface']:16s} reps={len(rec['reps'])} called={called} err={errs} cost=¥{sum(x.get('cost_rmb',0) for x in rec['reps']):.4f}")
    if budget_hit["v"]:
        print("\n*** BUDGET EXHAUSTED during wave-1 gen ***")
    print(f"\nWAVE-1 GEN DONE: cumulative ¥{ds.cumulative_cost_rmb():.2f}; trajectories in {OUT}/")


def _write(rec: dict) -> None:
    (OUT / f"{rec['id']}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    only = sys.argv[2] if len(sys.argv) > 2 else None
    run(reps=reps, only=only)
