# Industry Research Notes — LLM Tool Design SOTA

**Date**: 2026-05-29
**Source coverage**: 5 parallel subagent surveys (Anthropic / OpenAI / DeepSeek / IDE agents+LangChain / Academic+Runtimes)
**Goal**: 沉淀 5-10 Forgify-specific 可测假设 → Phase 2 实验设计

---

## 🚨 关键 DeepSeek V4-flash 实测发现(改变实验预算)

| 项目 | 实测值 | 影响 |
|---|---|---|
| **Pricing(uncached)** | $0.14/1M input / $0.28/1M output | ¥1/M input,¥2/M output |
| **Pricing(cached input)** | $0.0028/1M(**50× cheaper**) | ¥0.02/M cached input |
| **Context window** | 1M tokens | 完全够用 |
| **Max output** | 384K tokens | 完全够用 |
| **Max tools/request** | 128 | 即使全 89 工具齐发也够 |
| **OpenAI-compatible** | ✅ | tools[] + tool_choice 直接用 |
| **Cache 自动开** | ✅ 默认 | 65-70% 命中率 typical |
| **典型单跑成本** | **¥0.03-0.07** | 远低于估算 ¥0.16 |
| **¥200 budget 实际能跑** | **3000-6000 runs** | 远超 spec 估的 770+300 |

⚠️ **重要 bug**(GitHub issue #1244):**V4 系列有 ~11% 几率把 tool call 当 plain text 输出在 content 里**,在 40+ tools 同时挂时更严重 + **中文 prose 触发率更高**。Forgify 中文场景必踩。**experiment runner 必须实现 content-leak fallback 解析**。

⚠️ **V4-flash 比 V4-pro 在 multi-step 上差 11pp**(Terminal-Bench 56.9% vs 67.9%)。决策 #4 chain prompts 实验在 V4-flash 上做的意义重大 — 因为它确实更弱,prompt 工程的边际收益更大。

---

## 1. Anthropic 生态(Skills / Claude Code / SDK)

### 关键证据(全部 published 数据)

| 实验 | 结果 |
|---|---|
| **Lazy loading**(58 tools deferred) | 191K → 122K context(-36%);Opus 4 selection 49% → 74%(**+25pp**) |
| **Tool Use Examples**(1-5 inline) | Complex param accuracy 72% → 90%(**+18pp**) |
| **Programmatic tool calling**(代码包 3+ deps) | 43.6K → 27.3K tokens(**-37%**);knowledge retrieval +2.9pp;GIA +4.7pp |
| **response_format: concise\|detailed enum** | Slack response 206 → 72 tok(**-65%**) |

### 写法建议(skill-creator + Claude Code best practices)

- **"Pushy" 描述**抗 under-triggering:"use whenever user mentions X, even if not explicitly asked"
- **避 ALL-CAPS ALWAYS/NEVER** — 解释 why,不命令
- **Few-shot examples > 规则散文**
- **Description ~100 words**;body <500 行
- **Plan→implement→verify 循环** 显式编进 chain prompt
- **Tool 文档当新员工 onboarding** 写:歧义参数名(`user_id` 而非 `user`)、避 raw UUID/MIME、actionable 错误消息

### 与 Forgify 关系

- 89 工具 **远超** Anthropic 验证带(58-tool 5-server 实验)— lazy 是必须的
- Forgify 当前 6 lazy 组,doc 12 提议 11 — **Anthropic 数据无法直接判定 6 vs 11**,需要我们实验
- `tool_conventions` system prompt 段(Forgify §S18)架构正确 — Anthropic Slack 减 65% tokens 同思路

---

## 2. OpenAI 生态

### 关键证据

| 实验 | 结果 |
|---|---|
| **LongFuncEval**(tool catalog 8K → 120K tokens) | 7-85% accuracy drop;16-pp drop / +1K tokens |
| **DeepSeek V3 vs Qwen Plus**(29 desktop agent tasks) | **81.5% vs 96.5%**(15-pp gap);V3 平均 5-6 round vs Qwen 2 round on truncated tool output |
| **GPT-5.1 `apply_patch`**(switched from JSON-described to named function) | **-35% failure rate** |
| **Rules-first ordering**(vs burying critical instructions) | **+6% accuracy** on o3/o4-mini ripgrep tool |
| **BFCL V4**(SOTA 模型 tool calling) | GPT-5 仅 59.22%;Claude Opus 4.1 70.36% — 即使 SOTA 也挣扎 |
| **Structured Outputs strict mode** | 100% schema compliance on gpt-4o-2024-08-06 |

### 写法建议

- **<10 functions per namespace**(OpenAI 官方建议)
- **Concise action-oriented descriptions**:"Create X. Use when…"
- **Anti-pattern guard inline**:"Do NOT guess Y — ask for missing detail"
- **Rules-first, background-after**
- **`tool_choice: "auto"` > `"required"`**(模型判断好时给空间)
- **典型 5-param tool ≈ 150-250 tokens**;100 tools 上下文 = 15-25K tokens

### 与 Forgify 关系

- Forgify 89 工具 = 当前 6 组 ≈ 14 tools/组 → **边缘**(>10 ceiling 一点)
- doc 12 提议 11 组 ≈ **8 tools/组** → **sweet spot 中心**
- 18 组 ≈ 5/组 → **下限内但 activation 开销加倍**
- **DeepSeek V3 lineage 的 tool-result distrust 是 Forgify 必须设计错误消息时考虑的**

---

## 3. DeepSeek 官方 + 社区

### 关键证据(已并入🚨段)

### 写法建议(V4-flash 特定)

- **Terse `what+when` 2-sentence 描述** > verbose `what+when+how+examples`(V4 verbosity bias 烧 output)
- **Tool 数 ≤25 时 content-leak 几率显著降**(issue #1244 数据)
- **JSON mode 必须在 prompt 写字面"json"** 才不报错
- **`finish_reason="length"` 表示静默截断** — runner 必查
- **Retry + regex repair 把 JSON parse 率 78% → 97%**
- **简单 routing/extraction 关 thinking mode**(省 cost + 速度);代码/error recovery 开

### V4-flash 当 judge 不可靠

V4-flash 比 V4-pro 弱 11pp on multi-step。**做 judge 不靠谱 — 必须我(Claude Code)亲自判**,这点 spec 已对齐。

---

## 4. IDE Agents + LangChain

### 关键证据

| 实验 | 结果 |
|---|---|
| **Aider Architect+Editor chain**(o1-preview+o1-mini) | 85.0% vs 79.7% solo(**+5.3pp**) |
| Same chain(Sonnet 配对) | 80.5% vs 77.4%(**+3.1pp**) |
| Same chain(GPT-4o 配对) | 75.2% vs 71.4%(**+3.8pp**) |
| **RAG-MCP**(tool retrieval) | **43.13% vs 13.62%**(**3.2× lift**)on tool selection |
| **Anthropic `response_format` enum**(再次确认) | -65% result tokens |

### 写法建议(production 公开数据)

- **Cursor:10 tools flat, no grouping** — 工作得很好(小 N flat OK)
- **Windsurf:12 tools 语义分组**(edit vs write 分,web 跟 fs 分)
- **Aider:Architect/Editor 两阶段 chain** 一致 +3-6pp
- **LangChain:30 tools 引起混乱**,start with 3-5
- **LangGraph:ReAct 3-6 children/task = 健康**;过多用 plan-and-execute
- **Plan-and-execute pattern**:`1 × strong-model planner + N × cheap executor` 在 N>3 时胜 ReAct

### 与 Forgify 关系

- Forgify ~28 Resident **可能太多**(Anthropic 推 3-5,LangChain 推 3-5,RAG-MCP 验证收益 3.2×)
- **Aider Architect/Editor 模式直接映 Forgify chain prompts(决策 #4)**

---

## 5. 学术 + Agent Runtimes

### 关键证据

| 论文/系统 | 结果 |
|---|---|
| **ReAct**(Yao 2022) | ALFWorld +34%, WebShop +10%, reduces hallucination vs CoT |
| **Reflexion**(Shinn 2023) | HumanEval 80% → **91%**(**+11pp**) |
| **Voyager**(Wang 2023) | 3.3× more items, 15.3× faster tech-tree progress |
| **AdaPlanner**(Sun 2023) | ALFWorld +3.73%, MiniWoB++ +4.11%, **2×/600× fewer samples** |
| **Toolformer** | 训练时,不适用 Forgify |
| **OpenHands mini-SWE-agent**(bash only) | **>74% SWE-Bench Verified**(只用 bash + filesystem) |

### Cognition AI "Don't Build Multi-Agents"

- Single-threaded > multi-agent
- **Full agent traces** > 摘要传递
- 子 agent 各自决策,context 不共享 → 不可调和冲突
- 2026/03 部分回退(Devin-manage-Devins),但**单线程 writes,隔离 reads** 仍是 production 模式

### 与 Forgify 关系

- Forgify workflow 节点 **天然单线程** — 符合 Cognition 模式
- **节点间应传 full trace,不传摘要** — 决策 #4 直接 hypothesis
- **mini-SWE-agent 74% 警示**:Forgify trinity 设计可能 over-engineering(但价值在可复用 artifact,不是 raw bench)
- **Reflexion 11pp 提升 → flowrun node-fail → node-retry 中间嵌反思步可能是大赢**

---

## 🎯 Top 10 Forgify-Specific Testable Hypotheses

按 4 决策分组,每条满足 (a) 1 决策 + (b) A/B 形式 + (c) v4-flash runnable。

### Decision 1 — Lazy 分组(3 hypotheses)

**H1**(主)— 11 组 vs 6 组 activation 正确率:
- A: 6 组(现状,含 ~14 tools/组)
- B: 11 组(doc 12 提议,~8 tools/组)
- Metric:首次 `activate_tools(category)` 调对组率 / 不必要激活次数 / 总 token cost
- Anchor:Anthropic Tool Search Opus 4 +25pp;OpenAI <10 ceiling

**H2**(次)— Resident 28 → 15 收益:
- A: 28 Resident(当前)
- B: 15 Resident(只留 top-frequency search + activate_tools + 主对话基础;memory/skill 进 lazy)
- Metric:首次调对工具率 / 总 token cost
- Anchor:Anthropic 推 3-5,LangChain 推 3-5,RAG-MCP 3.2× lift

**H3**(观察)— V4-flash content-leak 随 tool 数:
- 同一 prompt,offered 25 vs 40 vs 60+ 工具
- Metric:content-leak 率(tool call 漏到 content)
- 不严格 A/B(只是要量化 leak 严重程度,影响 runner 容错设计)

### Decision 2 — Tool description 风格(3 hypotheses)

**H4**(主)— Few-shot vs 规则散文:
- A: Terse rules + JSON schema(40 字)
- B: 3 few-shot examples inline(minimal / polling / with-deps,~250 字)
- Metric:首试有效参数率,target `create_function`
- Anchor:Anthropic Tool Use Examples **72% → 90%**

**H5**(次)— Code-style vs Prose-paragraph:
- A: Prose paragraph("This function creates...")
- B: TS-like signature + 1 example + 1 edge-case + 1 error-mode
- Metric:malformed args 率 / wrong-tool calls 率
- Anchor:AdaPlanner code-style + Anthropic ACI

**H6**(次)— Terse vs Verbose(V4-flash 特定):
- A: Terse 2-sentence "what+when"
- B: Verbose "what+when+how+examples"(200 字)
- Metric:tool selection 准确率 on ambiguous queries
- Anchor:V4 verbosity bias + Macaron community 数据

### Decision 3 — Schema 设计(3 hypotheses)

**H7**(主)— 错误消息 sentinel vs prose:
- A: `"error":"NOT_FOUND","entityId":"fn_xxx"`(结构化 sentinel)
- B: "Function fn_xxx was not found, did you mean..."(prose)
- C: "kind must be 'normal' or 'polling'. Use 'polling' for fire-and-forget jobs..."(含 next-step hint)
- Metric:same-turn 错后恢复率 / rounds-to-recovery
- Anchor:DeepSeek tool-result distrust(V3 5-6 rounds vs Qwen 2)+ Anthropic actionable errors

**H8**(主)— anyOf > enum > free string for ops:
- A: ops 字段 = raw JSON
- B: ops 字段 = enum kind
- C: ops 字段 = anyOf discriminated union(DeepSeek strict mode 支持)
- Metric:首试有效参数率 / wrong-variant 率
- Anchor:OpenAI Structured Outputs 100% compliance;DeepSeek strict mode

**H9**(次)— `response_format=concise|detailed` enum:
- A: 读类 tool 单一 verbose 返回
- B: 同 tool 加 `response_format` enum,默认 concise
- Metric:result tokens 减少率 + 任务完成率(不能掉)
- Anchor:Anthropic Slack 206 → 72 tok(-65%)

### Decision 4 — Chain prompts(3 hypotheses)

**H10**(主)— Plan-then-execute vs raw ReAct:
- A: 直接 5-step task(naive prompt)
- B: 显式 plan-first prompt("先列计划再 emit tool calls")
- Metric:full-chain completion 率(5-step workflow)
- Anchor:DeepSeek V4-flash multi-step gap 11pp;LangGraph plan-and-execute 模式

**H11**(主)— Reflection step between fail/retry:
- A: 节点失败直接 retry
- B: 节点失败 → 嵌"what failed / what to try"反思块 → retry
- Metric:end-to-end success 率 on ≥3-node chains
- Anchor:Reflexion 80% → 91%(+11pp)

**H12**(主)— Full trace vs summary handoff:
- A: 节点间只传 summary
- B: 节点间传 full upstream trace(reasoning + tool_calls + observations)
- Metric:end-to-end success 率 on ambiguous tasks
- Anchor:Cognition "Don't Build Multi-Agents"

---

## 实验预算修订

由于 DeepSeek V4-flash 真实价格 **远低于 spec 估算**(单跑 ¥0.03-0.07 vs ¥0.16),¥200 budget 实际能跑 **3000-6000 runs**(估 ¥150 头吧 buffer)。

**修订 Pass 1 + 2 总量**:

| Priority | Variants | Scenarios | Pass 1 runs/cell | Pass 2 深挖 | 总 runs |
|---|---|---|---|---|---|
| 1. Lazy(H1-H3) | 3 | 12 | 20 | top × 50 | 720 + 150 |
| 2. Tool desc(H4-H6) | 4 | 8 | 20 | top × 50 | 640 + 150 |
| 3. Schema(H7-H9) | 3 | 8 | 20 | top × 50 | 480 + 150 |
| 4. Chain(H10-H12) | 3 | 6 | 20 | top × 50 | 360 + 150 |
| **小计** | — | — | — | — | **~3000 runs** |
| 预估 cost(中等 cache hit)| | | | | **~¥80-120** |

剩 ¥80+ buffer 留意外 deep dive。

---

## Next Step

Phase 2 — 实验基建。已知:
1. DeepSeek API key 已验证(模型 v4-flash 存在 + v4-pro 也在)
2. OpenAI-compatible 格式 → Python httpx 直接干
3. Content-leak fallback parser 必须写
4. Cache hit metadata 跟踪要做(影响 cost)
5. Output verbosity 控制要做(关 thinking mode for routing tasks)
