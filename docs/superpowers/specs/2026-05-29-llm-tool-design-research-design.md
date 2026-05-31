# LLM Tool Design Research — Design Spec

**Date**: 2026-05-29
**Owner**: 单人(用户 + Claude Code agent)
**Status**: Approved (待用户最终确认)
**Related**: `documents/version-1.2/working/workflow-revamp/` doc 10-12

---

## 1. Goal

验证 [workflow-revamp doc 12](../../version-1.2/working/workflow-revamp/12-deep-dive-findings.md) 拍的 4 个 LLM-facing 设计决策,在 Forgify 上的实际 token cost vs 任务成功率表现:

1. **Lazy 分组**:11 组(doc 12 提议) vs 6 组 vs 18 组
2. **Tool description 风格**:terse vs verbose vs antipattern vs few-shot
3. **Schema 关键设计**:enum vs string / required 策略 / 错误消息格式
4. **Multi-step chain prompts**:polling cursor 模板 / edit_workflow ops 拆分 / 多步诊断 chain

**非目标**:不研究 cross-model 兼容 / 不研究学术 baseline / 不做 LLM agent 完整 playbook。**单一模型 DeepSeek V4-flash**,因为 Forgify 本地默认就是这个模型。

---

## 2. Constraints

| 项 | 值 |
|---|---|
| **模型** | **仅 deepseek-v4-flash**(API key 已就绪) |
| **Budget** | **¥200 RMB**,硬 cap ¥180 自动停 |
| **Judge** | **Claude Code(我)亲自判** + 程序性 auto-check(90%)+ 我抽 review(10%) |
| **Output** | 2 docs cross-linked:`13-llm-research-report.md`(数据)+ `14-llm-research-playbook.md`(直接抄) |
| **自治** | 用户不打扰,3 种情况 stop:(a) 单 cell 实测 cost > 估算 3x(¥0.50/run+),(b) 至少 2 个 priority 的 winner 跟 doc 12 推荐反向(说明 doc 12 拍错),(c) 最终 doc 完成 |
| **Time** | ~8 天 |

---

## 3. Architecture

### 3.1 Phase 1 — 行业调研(1.5 天 / ¥0)

5 个并行 general-purpose subagent,各抓一类 source:

| Subagent | Sources | 重点抓 |
|---|---|---|
| S1 | Anthropic 全集(claude.com/news, docs.anthropic.com, agents.md, Skills 文档) | tool use guide / Skills / "Building effective agents" / system prompt 模板 |
| S2 | OpenAI(function calling, Assistants API, strict mode 文档) | desc 长度 / required 策略 / strict mode 利弊 |
| S3 | **DeepSeek 官方**(关键 — 我们就用它) | tool calling 能力实测 / prompt 工程建议 / 跟 Anthropic 异同 |
| S4 | Cursor + Windsurf + Aider + LangChain/LangGraph | IDE agent 工具粒度 / lazy 模式 / tool indexing |
| S5 | 学术(ReAct/Toolformer/Reflexion)+ Cognition/Replit blog | abstract + 结论 only |

**输出**:`research/llm-experiments/industry-notes.md`(中间产物,内部用,最终沉淀进 doc 13 §1)。

**Phase 1 完成判据**:产 5-10 条 **Forgify-specific 可测假设**。每条假设必须满足:
- (a) 落到 4 决策之一
- (b) 能写成 A/B 形式(有 baseline + 1+ variant)
- (c) Forgify 上下文具体(不是抽象 paper 结论)

**少于 5 条时**:5 个 subagent 漏抓某个 priority → 我手动补 web search 该 priority 的 source 找补。
**多于 10 条时**:按"假设跟 4 决策直接相关性"排序,只跑 top-10。

示例假设(初步预想,正式由调研产):
- H1: Tool description >200 字时首试对率反降(基于 OpenAI 推荐)
- H2: Lazy 组数 sweet spot 在 8-12(基于 Anthropic Skills 划分模式)
- H3: 复杂 ops 用 discriminated union 比 free string 首试对率 +20%
- H4: 多步任务前置 "plan-then-execute" 模板比 raw ReAct 步数 -30%

### 3.2 Phase 2 — 实验基建(1.5 天 / ¥0)

**技术栈**:Python(脚本最快)+ httpx + jsonl trace。

**目录结构**:

```
research/llm-experiments/
  ├── deepseek_client.py        # API client + cost ledger
  ├── runner.py                  # 1 scenario × 1 variant × N runs
  ├── aggregator.py              # 程序性 auto-check + 出表
  ├── scenarios/<priority>/*.yaml
  ├── variants/<priority>/*.yaml
  ├── results/<date>_<scen>_<var>.jsonl
  ├── budget.json
  ├── industry-notes.md          # Phase 1 产物
  └── README.md
```

**Scenario YAML schema**:

```yaml
id: lazy-cron-debug
priority: lazy_grouping
user_prompt: "看一下昨天 cron 失败的情况"
expected:
  activated_groups: [workflow-debug]
  forbidden_groups: [function-edit, handler-edit]
  first_tool: query_events
  args_must_include: { type: trigger_exhausted }
auto_check: programmatic   # 或 manual
notes: ""
```

**Variant YAML**:每 variant 声明覆盖哪些 prompt 片段 / schema 字段:

```yaml
id: tool-desc-V2-verbose
priority: tool_desc
target: create_function
overrides:
  tool_description: |
    Create a new Forgify function.
    ...
    Example: create_function(name="check_gmail", ...)
```

**DeepSeek client**(`deepseek_client.py`):
- 包装 chat/completions API
- 每次 call append 一行进 `budget.json`:`{ts, scen, var, in_tok, out_tok, cost_yuan}`
- 到 ¥180 硬停 raise exception
- 支持 retry(429 / 5xx 指数退避)
- 验证 DeepSeek tool calling 格式(OpenAI-compatible)

**Aggregator**(`aggregator.py`):
- 读全部 results/*.jsonl
- 对每个(scenario, variant)计算:
  - first_tool_correct_rate(程序性检查)
  - args_correct_rate
  - hallucination_count(LLM 调用不存在的工具或参数)
  - avg_steps_to_completion
  - avg_tokens(input/output)
  - error_recovery_rate(出错后能否恢复)
- 出 CSV + Markdown 表

**Judge**:
- 程序性 auto-check 清晰指标(90%)— `aggregator.py` 自动产出
- 我亲自 review nuanced 10%(prompt 质量 / chain 流畅度 / 反例分析)
- doc 13 出表前我抽 20-30 trace 看是否 aggregator 漏判

### 3.3 Phase 3 — Pass 1 粗 sweep(1.5 天 / ~¥123)

按 priority 跑全集:

| Priority | Variants | Scenarios | Runs/cell | 总 runs |
|---|---|---|---|---|
| 1. Lazy | 3 | 10 | 10 | 300 |
| 2. Tool desc | 4 | 5 | 10 | 200 |
| 3. Schema | 3 | 5 | 10 | 150 |
| 4. Chain | 3 | 4 | 10 | 120 |
| **总** | — | — | — | **770** |

Cost 估算:平均 50k input + 8k output / run × 770 runs × DeepSeek V4-flash pricing ≈ **¥123**。

Pass 1 完成判据:每个 priority 出一个"看似胜者" + 一个"看似输者"。

**没有明显胜者时**(top 2 variant 差距 < 5%):标"无显著差异",doc 14 推荐用更省 token 的那个 variant + 备注"无强证据,日常迭代时再观察"。

### 3.4 Phase 4 — Pass 2 深挖(1.5 天 / ~¥40-48)

胜者再上 30-50 runs 拿统计显著。3-4 个深挖 cell × 30 runs ≈ 250-300 runs ≈ ¥40-48。

意外发现(Pass 1 中某个变体反胜预期)也加上 30 runs 复测。

### 3.5 Phase 5 — 写文档(2 天 / ¥0)

**`13-llm-research-report.md`** 章节:

```
1. 行业调研沉淀(5 subagent 产物综合)
   1.1-1.5 各 source 提炼
   1.6 沉淀:5-10 假设清单
2. 实验设计
   2.1 Scenario 库(全 24 个) / 2.2 Variant 矩阵 / 2.3 Metrics / 2.4 Judge 方法
3. 实验数据(每 priority 一节)
   3.x 数据表 + 胜率 + token cost + trace 样本 + 反例分析
4. 结论 + 限制 + 反例
5. 未来工作
```

**`14-llm-research-playbook.md`** 章节:

```
1. Lazy 分组最终方案
   1.1 11 组完整 tool 列表(逐组可粘 main.go)
   1.2 Resident 工具集
   1.3 activate_tools description 完整文本
   1.4 反例 + checklist
2. Tool description 模板
   2.1 模板 + 2 个填好的例子
   2.2 反例 + checklist
3. Schema 设计模式
   3.1 完整 JSON schema(enum / discriminated union)
   3.2 错误消息模板
   3.3 反例 + checklist
4. Chain prompt scaffolding
   4.1 polling cursor 模板(完整文本)
   4.2 edit_workflow ops 拆分指引(完整文本)
   4.3 多步诊断 chain(完整文本)
   4.4 CEL 写法指引
   4.5 反例 + checklist
5. Implementation roadmap(对应 Forgify 哪些文件改)
```

**两份 cross-link**:doc 14 每条结论链回 doc 13 §3 对应数据段。

---

## 4. Data Flow

```
[Phase 1]                [Phase 2]              [Phase 3-4]
5 subagents              build infra            execute runs
  → industry-notes.md     → runner / aggreg     → results/*.jsonl
  → 5-10 hypotheses       → scenarios/*.yaml    → budget.json (滚 cost)
       │                  → variants/*.yaml          │
       ↓                       ↓                     ↓
       └───────────────────────┴─────────────────────┤
                                                     │
                              [Phase 5]              │
                              我亲自看 trace
                              + 程序性 aggregator
                              + Forgify 上下文
                                ↓
                              doc 13 (报告) + doc 14 (playbook)
                              cross-linked
```

---

## 5. Error Handling

| 异常 | 应对 |
|---|---|
| DeepSeek API 429 / 5xx | 指数退避 retry(最多 3 次,初始 1s) |
| Tool calling 格式 LLM 不返 JSON | 记 hallucination,不重试,计入 aggregator |
| Budget 触 ¥180 | 硬停,raise BudgetExhausted,落 partial results |
| 单 scenario 跑超 60s | 超时 abort,记 trace 为 timeout |
| Subagent 返空 / 错 | 我手动补 source(不靠 subagent 重跑) |
| Aggregator 漏判 / 误判 | 我抽 30 trace review,触发的 priority cell 重跑 |

---

## 6. Testing / Validation

研究本身不需要单测(实验框架是 throwaway script)。但产物要验证:

| 产物 | 验证方式 |
|---|---|
| Phase 1 假设清单 | 5-10 条,每条满足 (a)(b)(c) 标准 |
| Phase 2 基建 | 跑 1 个 smoke scenario 验证 runner + aggregator 链路 |
| Phase 3-4 数据 | 我抽 20-30 trace 验证 aggregator 不漏不误 |
| Doc 13 数据表 | 每个胜者都有 N ≥ 30 支撑(Pass 1 + Pass 2) |
| Doc 14 模板 | 每个模板都有对应 doc 13 实验 cross-link |

---

## 7. Out of Scope

- Cross-model 对比(Forgify 本地就 DeepSeek)
- 学术 paper 完整综述(只抓 abstract + 结论)
- 实施 doc 14 的产物到 Forgify code(单独 task,本研究只产 playbook)
- 实验 framework 工程化(throwaway scripts,~300 行 Python 够用)
- Multi-turn 对话场景(本研究 focus 单 turn / 简单 chain,multi-turn 留未来)

---

## 8. Risks

| Risk | 缓解 |
|---|---|
| DeepSeek V4-flash 实际 tool calling 能力差,数据无意义 | Phase 2 跑 smoke scenario 验证;真不行就停下报数 |
| Budget 估算偏低(¥0.16/run 实际 ¥0.5+) | budget.json 实时 ledger,到 ¥180 硬停 |
| 单 v4-flash 数据外推到其他模型不可靠 | 显式声明 — doc 13 标 "DeepSeek V4-flash 上结论",doc 14 标 "本地默认模型适用,改 model 需复测" |
| 我 review 1000 trace 太累 / 漏判 | 程序性 auto-check 顶 90%;我只抽样 nuanced |
| 8 天估时低估 | Pass 1 结果出来后 day 5 复评进度,真延期就砍 Pass 2 范围 |

---

## 9. Decisions Log

| Date | Decision | Reason |
|---|---|---|
| 2026-05-29 | Scope: A (tight, 4 决策) | 用户拍 |
| 2026-05-29 | 迭代: B (两 pass) | 用户拍 |
| 2026-05-29 | Judge: 我 + 程序性 | 用户拍 + 不烧 deepseek + 有 Forgify 上下文 |
| 2026-05-29 | 模型: deepseek-v4-flash only | 用户拍(¥200 budget 现实) |
| 2026-05-29 | 方法论: A (调研-first hypothesis-driven) | 用户拍 |
| 2026-05-29 | 输出: 2 docs (13 report + 14 playbook) cross-linked | 用户拍 |
| 2026-05-29 | 自治: 用户不打扰,3 种 stop 条件 | 用户拍 |
