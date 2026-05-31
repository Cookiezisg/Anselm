# LLM Prompt Forging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is an **iterative forging research** plan, not code-feature TDD — each task is a forging loop where iteration content is emergent (determined by reading real-LLM failure traces), so steps lock the *scenarios / initial variant / validator / convergence bar / doc format*, and the per-iteration fix is decided at runtime.

**Goal:** Forge every LLM-facing surface of post-revamp Forgify to 🟢 (one-shot-correct + token-efficient) via trace-driven iteration on real DeepSeek V4-flash, round-robin until DeepSeek reports insufficient balance, delivering definitive copy-paste descriptions (doc 14) + data/iteration-logs (doc 13).

**Architecture:** Real-DeepSeek-as-oracle loop. Per surface: write description/schema variant → run N≥20 complex scenarios → programmatic validator + read failure traces → root-cause → iterate (prefer tool-call change; design change only if tool-call can't, with confidence, minimized) → converge to 🟢 → log. Round-robin across surfaces until balance exhausted.

**Tech Stack:** Python 3.9 + httpx, DeepSeek V4-flash (OpenAI-compat), programmatic validators (ops/CEL/ref), JSONL traces, budget ledger.

**Spec:** `docs/superpowers/specs/2026-05-29-llm-prompt-forging-plan.md`

---

## Coverage scope (locked)

**Forge everything LLM-facing in post-revamp system** = NEW (agent entity / 5-node workflow / CEL / polling / lifecycle / diagnosis) **+ surviving OLD** (handler forging bare-names / function env-fix / document·mcp·skill·memory tools / system prompt / catalog / utility scenarios / subagent / error envelope). **Exclude only revamp-killed** (old 14-node / 10-op workflow surface / condition·loop·variable·parallel·wait·http·llm nodes / function·handler·mcp·skill as standalone workflow nodes).

## Stop signal (locked)

DeepSeek API returns HTTP 402 / "Insufficient Balance" → `BudgetExhausted`. NOT a self-imposed ¥cap. `deepseek_client.py` cap disabled, 402 caught.

## Convergence bar per surface

- Complex surface (workflow编排/agent/CEL): one-shot ≥ 90%
- Simple surface (search/get/delete): one-shot ≥ 98%
- Token: track; prefer the cheaper variant when accuracy within 3pp
- Ceiling = 2 consecutive iterations < +3pp → escalate to design recommendation (minimized, confidence-gated)

## doc 14 per-surface block format (locked)

```
### <tool>  [🟢 X% · Yk tok · N轮 · lazy组: <group> · 依赖: <tools>]
#### 就这么写 Description(): <full copy-paste text>
#### 就这么写 Parameters(): <full JSON schema>
#### 为什么(逐轮 Δ): v1 desc→% (失败模式); v2 改→% (消灭X); ... vN→% 收敛
#### 别这么写(top 3 致命反例): ❌... ❌... ❌...
#### 残留 / 已知限制: ...
```

---

## File Structure

**Already built (Phase done):**
- Create: `research/llm-experiments/deepseek_client.py` — API client, ledger, 402-stop, content-leak fallback ✅
- Create: `research/llm-experiments/catalog_v2.py` — NEW-design tool defs (workflow/agent/function variants) + validators (`validate_workflow_ops` / `validate_cel` / `validate_callable_ref`) ✅
- Create: `research/llm-experiments/forge_runner.py` — test oracle: `run_forge_cell` + `failure_digest` + `save_results` ✅
- Create: `research/llm-experiments/workflow_forge.py` — crown-jewel scenarios + validator + variants ✅

**To build (one per surface):**
- Create: `research/llm-experiments/agent_forge.py` — agent forging scenarios + validator
- Create: `research/llm-experiments/cel_forge.py` — CEL case-expression scenarios + validator
- Create: `research/llm-experiments/ref_forge.py` — callable-ref scenarios + validator
- Create: `research/llm-experiments/fnhd_forge.py` — function(polling/kind) + handler(bare-names) forging
- Create: `research/llm-experiments/tool_sweep.py` — all ~89 tools description baseline + targeted iteration
- Create: `research/llm-experiments/artifact_forge.py` — catalog / lazy / error-envelope / forge-teaching / chainPatterns
- Create: `research/llm-experiments/utility_forge.py` — auto-title / rerank×4 / compaction / env-fix / web-summary / subagent
- Create: `research/llm-experiments/composite_forge.py` — end-to-end complex scenarios
- Create: `research/llm-experiments/forge_state.json` — round-robin progress + per-surface current verdict/variant

**Outputs (in-place, no 15/16):**
- Modify: `documents/version-1.2/working/workflow-revamp/13-llm-research-report.md` — full rewrite: data + per-round iteration logs + design before/after
- Modify: `documents/version-1.2/working/workflow-revamp/14-llm-research-playbook.md` — full rewrite: death-conclusion blocks per surface + §0 scorecard + §6 design recs + §7 roadmap

---

## Task 1: Workflow 编排 forging (crown jewel) 🔴

**Files:**
- Use: `research/llm-experiments/workflow_forge.py` (scenarios + validator + V1/V2/V3 variants exist)
- Modify: same file to add forged variants V4+ as iteration demands
- Output: doc 14 §1.1-1.2 (create_workflow / edit_workflow), doc 13 §workflow

**Scenarios (locked, 6):** wf-linear / wf-branch / wf-loop / wf-full / wf-callable-mix / wf-trap-old-nodes (see workflow_forge.py).

**Validator (locked):** `validate()` in workflow_forge.py — node types ∈ 5, callable refs regex, case has expression, loop-back detection, forbid old node types, required refs present.

- [ ] **Step 1: Baseline V1-generic** — `DEEPSEEK_API_KEY=… python3 workflow_forge.py V1-generic 20`. Record overall % + per-scenario + failure digest. (DONE: 0/120 — failures: type-key not op-key, React-flow `data`, camelCase addNode, old node types function/condition.)
- [ ] **Step 2: Run V2-enum-types + V3-full-teaching** — `python3 workflow_forge.py V2-enum-types 20` then `V3-full-teaching 20`. Record digests.
- [ ] **Step 3: Read digests, root-cause** — for each remaining failure class, write the cause (which scenario, what malformed output). Identify the highest-impact fix.
- [ ] **Step 4: Iterate** — add V4 (and beyond) to `workflow_forge.py` targeting the top failure class (e.g., if CEL still wrong → strengthen CEL teaching; if loop-back wrong → add loop example; if ref wrong → add ref table). Re-run N=20. Compare to prior. Record Δ.
- [ ] **Step 5: Repeat Step 4** until 🟢 (≥90% across all 6 scenarios, hard ones included) OR ceiling (2× <+3pp).
- [ ] **Step 6: If ceiling** — try ONE design-change variant (workflow_split_tools: add_workflow_node / connect_workflow_nodes / set_case_branches). Run N=20. If it clears 🟢, record as design recommendation with the comparison.
- [ ] **Step 7: Converge N=40** on the winning variant for a stable number.
- [ ] **Step 8: Write doc 14 §1.1/§1.2** in the locked block format (full Description + Parameters + per-round Δ + top-3 anti-examples + lazy group `workflow-edit` + deps `accept_pending_workflow` + residual). Write doc 13 workflow section (full iteration log).

---

## Task 2: Agent forging

**Files:**
- Create: `research/llm-experiments/agent_forge.py` (mirror workflow_forge.py structure; use `catalog_v2.agent_tools(variant)` V1-generic/V2-enum/V3-full)
- Output: doc 14 §1.3 (create_agent/edit_agent), doc 13 §agent

**Scenarios (locked, 5):**
1. `ag-classify` — "造一个 agent ag,分类邮件成 invoice/inquiry/spam,输出 enum" → expect set_prompt + set_output_schema(enum) + values
2. `ag-tools` — "造一个 agent 总结网页,挂 function fn_fetch 和 mcp:gmail/list" → expect set_tools with valid callable refs only
3. `ag-knowledge` — "造一个客服 agent,挂 skill 'support-tone' + 3 个知识文档 doc_a/doc_b/doc_c" → expect set_skill + set_knowledge
4. `ag-full` — prompt + skill + knowledge + tools + outputSchema + model 全配
5. `ag-trap-platform-tools` — "造一个 agent 能读文件、上网搜、记笔记" → TRAP: agent CANNOT mount platform tools (fs/web/memory). LLM should refuse/redirect to forging functions, NOT put "filesystem"/"web_search"/"memory" in tools.

**Validator:** called == create_agent; ops have valid op keys; set_output_schema kind ∈ {enum,json_schema,free_text}; set_tools entries all match CALLABLE_RE (fn_/hd_.method/mcp:/ag_) — reject platform tool names; set_skill ≤ 1.

- [ ] **Step 1:** Build agent_forge.py with scenarios + validator above.
- [ ] **Step 2:** Run V1-generic / V2-enum / V3-full N=20. Digests.
- [ ] **Step 3:** Root-cause + iterate (esp. trap: does LLM keep platform tools out?).
- [ ] **Step 4:** Loop to 🟢. Converge N=40.
- [ ] **Step 5:** Write doc 14 §1.3 + doc 13 §agent.

---

## Task 3: CEL case-expression forging

**Files:**
- Create: `research/llm-experiments/cel_forge.py` (uses `catalog_v2.validate_cel`)
- Output: doc 14 §4 CEL teaching + doc 13 §CEL

**Scenarios (locked, 6):** Given a routing requirement in NL, produce a `set_case_branches`-style call (expression + branches):
1. `cel-simple` — "按 payload.category 路由到 invoice/inquiry/spam/_default"
2. `cel-numeric` — "payload.score ≥ 0.8 走 high,否则 low"
3. `cel-nullsafe` — "只有 payload.user 存在且 payload.user.email 非空且长度>5 才走 valid,否则 reject" → expect has() guards
4. `cel-loop` — "payload.attempt > 5 或 confidence ≥ 0.9 走 done,否则回 retry 并 attempt+1" → expect emit attempt+1
5. `cel-contains` — "tags 含 'urgent' 走 escalate"
6. `cel-trap-compute` — "判断邮件正文情感是否积极" → TRAP: case 不能做分析/计算;LLM 应说"这要上游 agent 先分类",不该硬塞情感分析进 CEL

**Validator:** `validate_cel` (no side-effects, balanced parens, references payload/ctx) + scenario-specific (cel-nullsafe must contain `has(`; cel-loop emit must contain attempt; cel-trap should NOT produce a compute-laden expression — flag if expression > N tokens or contains non-CEL).

- [ ] **Step 1:** Build cel_forge.py.
- [ ] **Step 2-4:** Run baseline (no teaching) → iterate CEL teaching (null-safety table, has() examples, "case 是看牌发牌员不是分析师" boundary) to 🟢. Converge N=40.
- [ ] **Step 5:** Write doc 14 §4 CEL + doc 13 §CEL.

---

## Task 4: Callable ref forging

**Files:**
- Create: `research/llm-experiments/ref_forge.py` (uses `catalog_v2.validate_callable_ref`)
- Output: doc 14 §4 callable-ref teaching + doc 13 §ref

**Scenarios (locked, 5):** tool node config given NL:
1. `ref-function` — "调 function fn_send_email" → `fn_send_email`
2. `ref-handler` — "调 handler hd_db 的 query 方法" → `hd_db.query`
3. `ref-mcp` — "调 mcp 的 slack post 工具" → `mcp:slack/post`
4. `ref-agent` — "调 agent ag_summarize" → `ag_summarize`
5. `ref-mixed` — one workflow needing all four

**Validator:** every produced callable ref matches CALLABLE_RE; correct kind per scenario.

- [ ] **Step 1:** Build ref_forge.py.
- [ ] **Step 2-4:** baseline → iterate ref-syntax table to 🟢. Converge N=40.
- [ ] **Step 5:** Write doc 14 §4 ref + doc 13 §ref.

---

## Task 5: Function (polling/kind) + Handler (bare-names) forging — surviving old

**Files:**
- Create: `research/llm-experiments/fnhd_forge.py` (uses `catalog_v2.function_tools`; add handler tool defs mirroring real backend bare-names contract)
- Output: doc 14 §1.4 create_function / §1.5 create_handler + edits, doc 13 §fn/hd

**Function scenarios (locked, 5):** add (normal) / time (normal) / polling-gmail (kind=polling+interval) / polling-cursor (kind=polling, MUST produce last_cursor/next_cursor) / trap-webhook (normal not handler).
**Handler scenarios (locked, 4):** oauth-cache (stateful) / db-query (bare-names body: `self.db.run(sql)` not `args["sql"]`) / counter (state persist) / trap-stateless (should be function not handler).

**Validator:** function — kind correct, polling has interval + code mentions last_cursor & next_cursor; handler — body uses bare names (flag `args[` / `init_args[` dict access), init_args_schema present.

- [ ] **Step 1:** Build fnhd_forge.py (function variants exist in catalog_v2; add handler variants V1-terse/V3-antipattern/V5-bareNames-examples).
- [ ] **Step 2-4:** baseline → iterate (polling cursor example; handler bare-names contract + example) to 🟢. Converge N=40.
- [ ] **Step 5:** Write doc 14 §1.4/§1.5 + doc 13 §fn/hd.

---

## Task 6: All-tool description sweep (~89)

**Files:**
- Create: `research/llm-experiments/tool_sweep.py` — every tool (Quadrinity CRUD + lifecycle + runtime + diagnosis + mcp/skill/document/memory), one canonical "user wants X" scenario each, V5-combined (antipattern+example) description.
- Output: doc 14 §1-3 remaining tools + §0 scorecard, doc 13 per-tool table

- [ ] **Step 1:** Build tool_sweep.py with one canonical scenario per tool + a generic "did LLM call THIS tool with required args" validator.
- [ ] **Step 2:** Run N=15/tool baseline (V5-combined description). Record per-tool %.
- [ ] **Step 3:** For each tool < 🟢, read trace, iterate description targeting its failure. Re-run.
- [ ] **Step 4:** Converge N=30 on tools that needed iteration.
- [ ] **Step 5:** Write each tool's doc 14 block + the §0 scorecard rows.

---

## Task 7: Non-tool artifacts forging

**Files:**
- Create: `research/llm-experiments/artifact_forge.py`
- Output: doc 14 §4 + doc 13 §artifacts

**Artifacts (locked):** (a) catalog rendering → does LLM pick correct entity ref from the menu; (b) lazy grouping + activate_tools (re-confirm V4 no-Resident-search with NEW agent tools, 11 groups); (c) error envelope (prose vs sentinel+next_step → multi-turn recovery rate); (d) chainPatternsSection (multi-step plan); (e) the 4 forge-teaching blocks feed into Tasks 1-5 (cross-ref, no separate run).

- [ ] **Step 1:** Build artifact_forge.py with a sub-runner per artifact (each has its own scenario set + metric).
- [ ] **Step 2-4:** baseline → iterate each to 🟢. error-envelope needs multi-turn (use chain_runner pattern with reasoning_content passthrough).
- [ ] **Step 5:** Write doc 14 §4 artifacts + doc 13 §artifacts.

---

## Task 8: Utility scenarios forging — surviving old

**Files:**
- Create: `research/llm-experiments/utility_forge.py`
- Output: doc 14 §5 + doc 13 §utility

**Scenarios (locked):** auto-title / rerank (function·handler·skill·mcp, 4 variants of rank-prompt) / compaction / env-fix (deps error → JSON {deps}) / web-summary. Each: 5-6 inputs, judge output quality (programmatic where possible: title ≤ N chars; rerank valid JSON id-array; env-fix valid JSON; compaction ≤ token cap).

- [ ] **Step 1:** Build utility_forge.py.
- [ ] **Step 2-4:** baseline → iterate each prompt to 🟢. Converge.
- [ ] **Step 5:** Write doc 14 §5 + doc 13 §utility.

---

## Task 9: Composite complex scenarios (end-to-end confidence)

**Files:**
- Create: `research/llm-experiments/composite_forge.py` (multi-turn, uses chain_runner)
- Output: doc 14 §0 verdicts confirmation + doc 13 §composite

**Scenarios (locked, 3):** full workflow编排 (cron→gmail→classify→case→approval→reply→retry-loop); multi-entity forge chain (create_agent + 2 functions + wire workflow + activate); diagnosis chain (query_events→trace→dead-letter→replay).

- [ ] **Step 1:** Build composite_forge.py with the forged (winning) descriptions from Tasks 1-8 loaded together.
- [ ] **Step 2:** Run N=15 each multi-turn. Measure end-to-end completion (all required tool calls in valid sequence).
- [ ] **Step 3:** Read traces; if a composite fails, trace which single-surface description is the weak link → iterate that surface.
- [ ] **Step 4:** Re-run. Converge.
- [ ] **Step 5:** Confirm §0 scorecard verdicts hold under composite load. Write doc 13 §composite.

---

## Task 10: Round-robin loop until balance exhausted

- [ ] **Step 1:** After Round 1 (Tasks 1-9 once), read `forge_state.json` — list surfaces not yet 🟢.
- [ ] **Step 2:** For each non-🟢 surface, new-hypothesis iterate (don't repeat failed v's — try a structurally different angle). Re-run.
- [ ] **Step 3:** For 🟢 surfaces, run a stability re-check (N=40) and a token-reduction attempt (can a shorter description hold the %?).
- [ ] **Step 4:** Update doc 13/14 after each surface change.
- [ ] **Step 5:** Loop Steps 1-4. Terminate when all 🟢 OR `BudgetExhausted` (DeepSeek 402). On terminate, write final §0 scorecard + §6 design recommendations + §7 roadmap.

---

## Continuous discipline (every task)

- [ ] After each surface converges: update `forge_state.json` (surface → verdict/variant/%/token), append doc 13 iteration log, write/refresh doc 14 block.
- [ ] Check `budget.json` cumulative after each task (visibility only; not a stop).
- [ ] On `BudgetExhausted`: stop cleanly, ensure doc 13/14 reflect all converged surfaces, note which surfaces were mid-forge.

---

## Execution discipline notes

- No sandbox (no real venv install) — validate ops/CEL/refs/args structurally + semantically; I read nuanced traces.
- One-shot metric only (first tool call). Multi-turn only for error-envelope recovery + composite scenarios.
- Prefer tool-call iteration; design change only when tool-call ceilings AND confident, minimized, with before/after.
- Parallel reps (ThreadPoolExecutor=6) per cell; file-locked ledger for concurrent safety.
