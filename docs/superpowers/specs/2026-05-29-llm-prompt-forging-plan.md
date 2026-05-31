# LLM Prompt Forging — Research Plan v2

**Date**: 2026-05-29
**Supersedes**: `2026-05-29-llm-tool-design-research-design.md`(那份是 benchmark-and-pick 思路,本份改为**迭代淬炼**)
**Mandate**: 对 Forgify workflow-revamp 新设计的**所有 LLM-facing 表面**,迭代淬炼 prompt/schema/描述,**把每一个都推到 🟢"放心"标准**(一次答对 + token 经济)。Prompt 撬不动时,反推**设计修改建议**,改完继续淬炼到 🟢。
**Model**: DeepSeek V4-flash only. **停止信号 = DeepSeek API 返回余额不足/请充值**(HTTP 402 / "Insufficient Balance")。**不是**我自设的 ¥cap —— ledger 只 TRACK 花费不 STOP。已用 ¥2.25。
**覆盖范围**: **新设计后系统里所有还活着的 LLM-facing 东西** = 新增的(agent entity / 5-node workflow / CEL / polling / 生命周期 / 诊断)**+ revamp 后存活的老东西**(handler 锻造 / function env-fix / document·mcp·skill·memory 工具 / 系统 prompt / catalog / utility 场景 / subagent / error envelope)。**只排除 revamp 明确砍掉的**(老 14-node / 10-op workflow / condition·loop·variable·parallel·wait·http·llm 节点 / function·handler·mcp·skill 作为独立 workflow 节点)。
**运行模式**: **轮询淬炼** —— 所有 surface 过一轮后,回头继续推还没到 🟢 的,一圈一圈循环,直到全 🟢 或 DeepSeek 提示充值。
**Output**: 重写 `13-llm-research-report.md`(完整数据 + 迭代日志)+ `14-llm-research-playbook.md`(**每个 tool / artifact 的死结论:就照这个写,完整文本可直接抄,零"类推"**)。不开 15/16。

---

## 0. 为什么旧 report(doc 13)不够

| 旧 report 问题 | 新 report 怎么 fix |
|---|---|
| 按 4 个抽象决策组织 | 按**每个具体 tool / artifact** 组织 + 一张总 scorecard |
| 只测 ~5 个工具,其余类推 | **全 ~89 工具 + 8 类非工具 artifact 逐个测** |
| 报 mediocre 数字就完了(schema 53%、chain 0% cell)| **迭代淬炼到收敛**:每个低分 surface 我读 trace → root-cause → 改 → 再测,直到上不去为止 |
| 无 before/after 设计对比 | **现设计 vs 淬炼后设计**,逐维 before→after |
| token 没系统化 | **每个 artifact 的 token 成本**进总表 |
| 测泛型/老 surface | **全部按 workflow-revamp 新设计**(5 node / CEL / callable ref / agent entity / polling) |
| 像跑分报告 | **像工程交付**:每个 surface 一个置信度 verdict + 必要时设计修改建议 |

---

## 1. 测什么 —— 全 LLM-facing 表面清单(新设计)

### A. Forge 实体工具(Quadrinity 核心,~43)

| 实体 | 工具 | 重点淬炼 |
|---|---|---|
| function(11)| search/get/get_versions/create/edit/accept/revert/delete/run/search_executions/get_execution | **create(kind=polling + cursor)/ edit(ops)** 🔴 |
| handler(12)| + update_config / call | **create(bare-names body contract)/ edit(ops)** 🔴 |
| agent(11,全新)| search/get/get_versions/create/edit/accept/revert/delete/run/search_executions/get_execution | **create/edit(prompt/skill/knowledge/tools/outputSchema/model)** 🔴 |
| workflow(9)| search/get/get_versions/create/edit/accept/revert/delete/capability_check | **create/edit(5-node 图 + CEL + callable ref + 回边)** 🔴🔴🔴 皇冠 |

### B. Workflow 生命周期(3)
activate_workflow / deactivate_workflow / trigger_workflow(triggerNodeId)

### C. 运行时 + 诊断(10)
search_flowruns / get_flowrun / get_flowrun_trace / get_flowrun_nodes / cancel_flowrun / query_events / list_dead_letters / get_dead_letter / replay_message / clear_dead_letters

### D. 资产工具(18)
mcp(5)/ skill(3)/ document(7)/ memory(3)

### E. 非工具 LLM artifact(8 类,**这些跟 tool 同等重要**)

| Artifact | 测什么 |
|---|---|
| **Catalog 渲染** | 系统 prompt 里的 asset 菜单格式 → LLM 能否据此选对 entity 引用 |
| **系统 prompt 段**(identity/how_to_work/tools/capabilities) | 段落结构 / 顺序 / 长度对一次答对率的影响 |
| **Lazy 分组 + activate_tools** | 11 组 + 组名 + activate 描述(V4 search-in-lazy)|
| **Error envelope** | sentinel + next_step vs prose → 错后一次恢复率 |
| **Forge 教学段**(每实体 create/edit)| function/handler/agent/workflow 各自的教学 prompt |
| **CEL 教学**(case 节点)| null-safety / has() / 嵌套 → LLM 产 valid CEL |
| **Callable ref 教学**(tool 节点)| fn_xxx / hd_xxx.method / mcp:server/tool / ag_xxx 产对率 |
| **chainPatternsSection** | 多步任务 plan-first 模板 |

### F. Utility LLM 场景(10,现存 chat infra)
auto-title / 4 个 rerank(function/handler/skill/mcp)/ compaction / env-fix / web-summary / 3 个 subagent system prompt

### G. 复合复杂场景(真试金石 —— 不是单工具,是端到端)

| 场景 | 复杂度 |
|---|---|
| **完整 workflow 编排**:cron → 拉 Gmail → agent 分类(outputSchema=enum)→ case 路由(发票/询价/垃圾)→ 发票走 approval → 询价 agent 回复 → 失败回边重试(attempt+1)| 🔴🔴🔴 |
| **多实体锻造链**:create_agent + 2 个 function + 接进 workflow + activate | 🔴🔴 |
| **诊断链**:query_events → get_flowrun_trace → get_dead_letter → replay_message | 🔴🔴 |

---

## 2. 怎么测 —— 迭代淬炼方法论(非 benchmark-and-pick)

### 2.1 核心循环(每个 surface)

```
1. 写 v1 描述/schema/prompt(我的最佳判断 + 行业 SOTA)
2. 设计该 surface 的复杂场景集(easy → hard → trap)
3. 真 DeepSeek 跑 N=20+ reps
4. 程序性 validator 自动判(ops 结构 / CEL sanity / ref regex / args 正确)
5. 我亲自读失败 trace —— 不只看 %, 而是"为什么错":
     幻觉 node type?CEL 写错?ref 语法?ops 漏字段?误解结构?
6. Root-cause → 形成假设"它错因为 X"
7. 针对 X 改 v2(可能改描述,可能改 schema,可能加 example)
8. 再跑,对比 v1:一次答对率↑?token↑↓?消灭了哪个失败模式?
9. 重复到收敛:
     - 一次答对率 ≥ 🟢 目标(复杂 surface 90%+,简单 98%+)→ 该 surface 本轮收工,进轮询队列等下一圈复查
     - 或 撞天花板(连续 2 次迭代无提升)→ 升级到设计建议 → 改设计 → 继续淬炼到 🟢
     - **不存在"到 v2 就停"**。没到 🟢 就一直推。
```

### 2.0 轮询淬炼(整体运行模式)

```
Round 1: 所有 surface 各淬炼一遍(每个推到当轮能到的最高)
Round 2: 回头看哪些还没 🟢 → 继续深挖(新假设 / 新 example / schema 重构 / 设计改)
Round 3: 再回头 ...
...
终止 = 全部 🟢  或  DeepSeek API 返回余额不足(HTTP 402 / Insufficient Balance)
```

每轮结束更新 doc 13 数据 + doc 14 死结论。budget.json 只 track 花费;**停止信号是 DeepSeek 自己说充值,不是我估的数**。目标是把预算花在把每个东西锤到放心上,不是省着花。

### 2.2 两个硬指标(同等)

- **One-shot 正确率**:第一个 tool call 就产出 valid + 语义对的输出。**不认多轮兜底**(生产环境一次对 = 省 token + 不烦用户)。
- **Token 成本**:描述 + schema 的 token 数。淬炼时盯住"准确率/token"性价比,不是无脑堆长描述。

### 2.3 程序性 validator(无 sandbox,省钱聚焦 tool-call 质量)

- `validate_workflow_ops`:node type ∈ 5 种 / callable ref regex / case 有 expression / 有 trigger
- `validate_cel`:无副作用构造 / 括号平衡 / 引用 payload|ctx
- `validate_callable_ref`:fn_/hd_.method/mcp:/ag_ regex
- `validate_agent_ops`:挂载字段合法 / tools 只含 forge callable
- args 正确性:期望字段 + enum 值

90% 程序判 + 我抽 nuanced trace 人工复核。

### 2.4 复杂场景设计(试金石)

不用 toy。用真实业务复杂度(见 §1.G)。每个复合场景**逐步加难**:线性 → 分支 → 回边 loop → 全功能。淬炼必须扛住 hard 档,不是只过 easy。

### 2.5 何时升级到"改设计"

连续 2 次 prompt 迭代无提升 + 失败模式是结构性的(例:LLM 永远搞不清 5-node ops 的嵌套)→ **停止 prompt 淬炼,产出设计修改建议**(带证据:"v1-v3 都卡 60%,失败全是 X,建议设计改成 Y")。**尽量少改设计**(你的要求),只在 prompt 真撬不动时提。

### 2.6 收敛标准 + N

- 探索阶段 N=15-20(看趋势 + root-cause)
- 收敛验证 N=30-50(确认最终版稳定)
- 简单工具(search/get/delete)可能 1 轮就 98%+,不强迫迭代
- 复杂工具(edit_workflow/create_agent/CEL)预期 3-6 轮迭代

---

## 3. 结论长什么样 —— 最终 report mockup(示例数字,非真实)

### 3.1 总 scorecard(开篇,一眼看全设计就绪度)

**目标:这张表里每一行的"淬炼后 verdict"都是 🟢**。🟡/🔴 只在 prompt + 设计改都撬不动时保留,且必须诚实写清天花板在哪、为什么。

| 维度 | 现/naive 设计 一次对率 | 淬炼后 一次对率 | token(淬炼后)| 置信 verdict | 需改设计? |
|---|---|---|---|---|---|
| workflow 编排(复杂图)| 例 32% | 例 88% | 例 1.4k | 🟡 可上线但需 fallback | ⚠️ 建议 ops 分拆 |
| agent forging | 例 55% | 例 94% | 例 0.9k | 🟢 放心 | 否 |
| function polling+cursor | 例 60% | 例 97% | 例 0.7k | 🟢 放心 | 否 |
| CEL case 表达式 | 例 40% | 例 85% | 例 0.5k | 🟡 中等 | ⚠️ 建议加 validator 回环 |
| callable ref | 例 70% | 例 99% | 例 0.3k | 🟢 放心 | 否 |
| catalog 选 entity | 例 ... | 例 ... | 例 ... | ... | ... |
| lazy 分组 activation | 例 8% | 例 90% | 例 ... | 🟢 | search 移 lazy(已定)|
| error 恢复 | 例 ... | 例 ... | ... | ... | ... |
| (其余 surface...) | | | | | |

### 3.2 设计 vs 设计 before/after(逐 surface)

```
## workflow 编排
现设计(老 14-node 10-op / 或 naive 新设计 v1):
  一次对 32% | token 1.1k | 失败模式:幻觉 node type 40% / CEL 错 25% / ref 错 20% / 漏 trigger 15%
淬炼后(v5):
  一次对 88% | token 1.4k | 残留失败:超 6 节点的回边 loop 偶尔连错(12%)
关键改动:
  - 加 5-node enum + 每 node type 一行 config 模板 (+0.2k token, 一次对 +30pp)
  - 加 1 个完整 example (+0.1k token, +15pp)
  - CEL null-safety 内联 (+0.05k, CEL 错 25%→6%)
设计建议:⚠️ 6+ 节点回边场景建议 ops 分拆成 add_node/connect/set_case_branches(实测分拆 v 一次对 92%,但多 2 步)
```

(每个 surface 一段:before / after / 关键改动逐条带 Δ / 设计建议)

### 3.2b 死结论 —— 每个 tool 的描述就这么写(playbook 核心,doc 14)

**这是你最终要的东西**:不是"建议参考",是"**照抄**"。每个 tool / artifact 一节,格式锁定(含 3 个确认调整):

```
### create_workflow  [🟢 92% · 1.4k tok · 5 轮 · lazy组: workflow-edit · 依赖: accept_pending_workflow]
                       └─ 标题行含:verdict / 一次对% / token / 迭代轮数 / 【调整1】lazy组 + 依赖工具

#### 就这么写 Description()(直接贴 backend/internal/app/tool/workflow/create.go):
  [完整可抄文本,含 5-node enum + CEL 教学 + ref 语法 + 1 完整 example]

#### 就这么写 Parameters():
  [完整 JSON schema]

#### 为什么这么写(【调整2】逐轮 Δ,不只最终):
  v1 泛型 ops              → 0%   失败:type-key / React-flow data / 老节点 function+condition
  v2 +op-key 强调 +enum    → X%   消灭 type-key + camelCase
  v3 +5-node enum +禁老节点 → X%   消灭 function/condition(trap 场景 baseline 100% 踩)
  v4 +callable ref 语法表   → X%   消灭 function_id/agent_id 乱填
  v5 +CEL 内联 +1 example  → 92%  消灭 case 结构错 → 收敛

#### 别这么写(【调整3】top 3 最致命反例):
  ❌ 泛型 ops → 0%(LLM 退回 React-flow data 字段)
  ❌ 不列 5 node → 用老 function/condition 节点
  ❌ 不写 ref 语法 → 填 function_id 而非 callable

#### 残留 / 已知限制:
  6+ 节点回边 loop 偶尔连错 X%(已到天花板 / 或:见 §6 设计建议)
```

**3 个确认调整已纳入**:① 标题行加 lazy组 + 依赖工具;② 为什么 = 逐轮 Δ;③ 反例 = top 3 致命。
每个 tool / artifact 都这一节。零含糊,零类推。

### 3.3 Per-tool scorecard(89 行大表,你要的"每个 tool call")

| Tool | 复杂度 | baseline 一次对 | 淬炼后 一次对 | 迭代轮 | token | 残留失败模式 | 最终描述 |
|---|---|---|---|---|---|---|---|
| create_workflow | 5 | 32% | 88% | 5 | 1.4k | 6+节点回边 | [§playbook] |
| edit_workflow | 5 | 28% | 86% | 5 | 1.4k | 同上 | [§] |
| create_agent | 3 | 55% | 94% | 4 | 0.9k | knowledge 多挂时漏 | [§] |
| create_function(polling)| 3 | 60% | 97% | 3 | 0.7k | — | [§] |
| edit_function | 4 | 40% | 90% | 3 | 0.6k | — | [§] |
| search_functions | 2 | 95% | 99% | 1 | 0.2k | — | [§] |
| ...(全 89 行)| | | | | | | |

### 3.4 Per-artifact scorecard(非工具 LLM 输入)

| Artifact | baseline 效果 | 淬炼后效果 | token | 最终版 |
|---|---|---|---|---|
| Catalog 渲染 | ... | ... | ... | [§] |
| 系统 prompt tools 段 | ... | ... | ... | [§] |
| Lazy activate_tools 描述 | ... | ... | ... | [§] |
| Error envelope | prose 恢复 30% | sentinel+next_step 恢复 78% | +0.05k | [§] |
| CEL 教学段 | ... | ... | ... | [§] |
| 各 forge 教学段 ×4 | ... | ... | ... | [§] |
| Utility:auto-title/rerank/... | ... | ... | ... | [§] |

### 3.5 迭代日志(每个复杂 surface 一份,体现"淬炼"过程)

```
### create_workflow 淬炼日志
v1 (generic ops): 32% | 读 20 trace:8 个幻觉 node type(用了 "function"/"llm" 老节点名),
                        5 个 CEL 写成 python,4 个 ref 没前缀,3 个漏 trigger
v2 (+5-node enum + config 模板): 61% | 节点类型错 0,但 CEL 仍 5/20 错,ref 仍 3/20 错
v3 (+CEL null-safety 内联 + ref 语法表): 79% | CEL 错降到 1,ref 错 0;残留:复杂回边连错
v4 (+1 完整 loop example): 86% | 回边错降一半
v5 (+emit attempt+1 模板): 88% | 收敛,残留 12% 是 6+ 节点的边连错
天花板分析:再加描述 token 边际收益 < 2pp。建议设计侧 ops 分拆(见 §3.2)
```

### 3.6 设计修改建议汇总(prompt 撬不动的)

| Surface | 问题 | 建议改动 | 证据 | 改动量 |
|---|---|---|---|---|
| 例 workflow 大图 | 6+节点回边 prompt 到 88% 封顶 | ops 分拆成 3 个 focused tool | 分拆 v 92% | 中(加 2 tool)|
| 例 CEL | 无 parser 反馈时 LLM 不知对错 | accept 时跑 CEL validator 返结构化错 → LLM 自修 | multi-turn +X% | 小(已规划)|

---

## 4. 顺序 + 预算

**预算 = 烧满 ¥197**。不是 ~¥32 收工 —— 那只是 Round 1 的量。Round 1 后**轮询回头**继续把每个 surface 往 🟢 + 更省 token 推,一圈圈直到 DeepSeek 提示充值。

| Round 1 阶段(首轮过一遍)| 内容 |
|---|---|
| 1. 皇冠:workflow 编排 | 多轮迭代 × 复杂场景 |
| 2. agent forging / function polling / CEL / callable ref | 各多轮 |
| 3. 全 89 工具 description 体检 + 低分淬炼 | |
| 4. 非工具 artifact(catalog/lazy/error/教学段)| |
| 5. Utility 场景 | |
| 6. 复合复杂场景端到端 | |
| **Round 2+** | 回头复查未达 🟢 的,新假设深挖;已 🟢 的复测稳定性 / 压 token |
| **终止** | 全 🟢 或 budget.json 逼近 ¥197 / DeepSeek 提示充值 |

时间:长时间 autonomous。我读 trace + 设计迭代是主耗时(不是 API)。预算大概率撑得比单 session 久 —— ledger + 迭代日志持久化,可跨 session 续。

---

## 5. 需你拍

1. **report 结构(§3 mockup)+ §3.2b 死结论格式 给你的信息够吗?** 缺哪列 / 想加维度?
2. **置信 verdict 三档**(🟢放心 / 🟡可上线需 fallback / 🔴别上)够吗?目标全 🟢。
3. **顺序**:先啃皇冠(workflow 编排)?还是先在一个简单 surface 把迭代淬炼 loop 跑通给你看一眼证明方法论,再上皇冠?
4. **设计修改建议**:我提你拍,还是有把握的直接连 prompt 一起淬炼了给你看对比?

拍完即开干 —— 轮询淬炼,烧满 ¥197,每个推到 🟢,中途不打扰(除非撞设计级抉择需你拍)。doc 13 数据 + doc 14 死结论持续更新。
