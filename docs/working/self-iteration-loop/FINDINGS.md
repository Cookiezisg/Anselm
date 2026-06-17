---
id: WRK-024
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# 自迭代 Loop —— 证据基（FINDINGS）

> 支撑 [`CHARTER.md`](CHARTER.md) + [`PLAN.md`](PLAN.md) 的硬事实。来源：18-agent 调研（3 精读 Anselm 基质 + 5 联网最佳实践 + 3 设计方案 + 3 评委 + 2 对抗评审），代码锚点全部 `file:line` 核实。
> **只写已验证事实**，结论性取舍在 CHARTER/PLAN，本文件不重复。

## 1. 四维度现实表

| 维度 | 改的物理对象 | 信号确定性 | 今天有信号 | 能否交 AI 自改 |
|---|---|---|---|---|
| **产品 bug** | `.go` 执行代码 | **最高**（testend 红绿） | 有（`testend/scenarios/` 19 文件 ~90 函数 + `flowrun_nodes` failed 行） | **否**——AI 只产 finding，人改 |
| **harness 工程** | `testend/harness/*.go`（grader 本身） | 高 | 有 | **否**——它是裁判，人审 PR 加观测缝 |
| **tool-call 设计** | tool 描述/参数（拟外提文案） | 中（可建确定性 tool-selection eval） | **今天为零**（无 tool-selection eval） | **是**（唯一可自改窄缝，待护栏+外提） |
| **描述/prompt 设计** | section 常量 + utility prompt | **最低**（promptdump 只验结构在场） | **几乎为零** | **最晚**（要先有校准过的 LLM-judge） |

**诚实核心判断**：去掉「人改 .go」通道后，AI 真能**自动改 + 确定性裁决**的面只剩 **tool-call description 一条窄缝**，其边际收益按 OPRO/APE/GEPA 自陈「三轮后趋零」。故 loop 姿态 = **先零 AI 把「看见」和「护栏」做扎实，证明窄缝值得，再逐步开 AI 写权限**。

## 2. 三个承重墙裂缝（已核实为真，是设计边界）

**裂缝一：「AI 只改文本、绝不写 `.go`」今天物理上不可能。**
- `Description()`/`Parameters()` 是 Go 方法体——散在 **61 个文件**（`grep -l "func.*Description() string" backend/internal/app/tool/`）。
- 5 处 section 是 `const` 字符串字面量（`backend/internal/app/chat/prompt.go:21-43`：`identitySection`…`criticalRulesSection`）。
- 三字段文案是 `backend/internal/app/tool/fields.go:82-84` 内联 JSON 字面量。
- `injectStandardFields`（`fields.go:65`）靠 **`panic`** 守约束——「文案」与「会 panic 的控制流」物理交织。
- **结论**：红线 #1 在文案外提成数据文件之前是空话 → 外提是前置工程项（PLAN Phase 0）。

**裂缝二：grader 物理隔离今天等于零。**
- 仓库**无 `.github/`、无 CI、无 CODEOWNERS、无 branch protection、无 AST guard**；`backend/cmd/` 只有 `docs`（仅 lint markdown frontmatter/链接，不碰代码/不守 closed-union）和 `server`。
- METR「30.4%→0.7%」那套 antiGaming 第一硬招建立在不存在的地基上。

**裂缝三：AI 自带逃逸面（原 naive 方案完全漏掉）。**
- AI 是带 `bash`（`backend/internal/app/tool/shell/bash.go`）+ filesystem 工具（`backend/internal/app/tool/filesystem/{read,write,edit}.go`）的 Anselm agent。
- 当 loop 终态是 durable workflow 里的 Agent 节点，它默认能 `cat` worktree 外的 golden 期望、`git log` 抄历史 fix。**worktree 隔离对手握 bash 的进程是纸糊的** → 自改节点必须物理剥离工具 + OS sandbox + egress deny。

## 3. 作弊向量 → 缓解（防作弊是架构问题）

| 作弊向量（已识别） | 物理缓解 |
|---|---|
| 改 golden 期望 / testend 断言让自己过 | grader 判分逻辑+期望值+llmmock 脚本跑在 agent worktree **外**的 CI job，容器里缺席 |
| `bash`/`git log` 挖历史 fix、读 worktree 外期望 | 自改节点 toolset 物理剥离 shell/fs + OS sandbox + egress deny |
| 改 eval_cases 判分字段（AI 的 document/memory 工具天然能改）| 判分字段独立 `workspace_id` / 表级写权限剥离 / 只人工 SQL 改 |
| 让模型少自报 dangerous 加速过测（对着 danger-false-safe 反向优化）| danger-false-safe 率是**硬门 + 趋势告警**（不许单调升），第 1 周即上探针 |
| `input_examples` 里埋命中 gold 形态的样例刷 fuzzy match | example 与 gold 答案集物理分离（gold 在 grader 侧 AI 不可见）|
| 措辞通胀（往 criticalRulesSection 塞同义反复，不超 3x 即全绿）| promptdump 全文 diff 只观测不做门；真信号靠 golden 行为分 pass^k |
| judge 自评不可信 / 过拟合公开 rubric | judge≠提议者（不同模型/context）；rubric 改动用**新**人标集重校准 |
| 挑软柿子（cron 维度内挑最易涨分 case）| scope 由 grader 侧按「失败频次×held-out 覆盖」加权随机给，AI 不自选 |
| `drainInteractions` 泄进生产 loop = 人在环门自动放行 | 专门断言测试守：生产 loop 每 approval 节点 `timeoutBehavior∈{reject,fail}` |
| grader 静默失真（对 AI 不可见→对人也易腐化）| 「grader 的 grader」：固定应过/应挂金标输入定期验裁判仍判得对 |

## 4. 关键设计补件（对抗评审挖出、原方案缺）

- **eval_cases 生命周期态**：D1「只增不删」与「定期从新流量刷新抗过拟合」矛盾——给 `active`/`dormant`/`superseded` 态，`dormant` 不进 CI 门、不算 pass^k 权重但行还在（满足 D1）。
- **pass^k 非 pass@k**：reliability-critical gate 要全 k 次绿（`70%` 单次成功率的 agent，`pass@3≈97%` 但 `pass^3≈34%`）——否则放过偶发成功。
- **proxy↔真 gap 早停**：`gap = testend_delta − evals_delta`，连续 N 拍 > θ 即早停该维度（reward-hacking 随步数 26.4%→57.8% 单调放大）。
- **rollback 语义**：record-once 下已落 `flowrun_nodes` 不可删，回退 prompt 后依赖它的 run 记忆化结果失效语义，Month 3 闭环前必须定义。
- **爆炸半径 = 下一拍起所有 run**：`idx_frn_once` 只保护运行中 run，坏 Description 改动污染所有调用该 tool 的 agent/workflow 选型；approval 是唯一刹车。

## 5. 已核实代码锚点（可直接照查）

- `backend/internal/app/chat/prompt.go:21-43` —— section const 块（5 处文案）
- `backend/internal/app/tool/fields.go:65,82-84,124` —— injectStandardFields panic / 三字段文案 / danger 默认 safe
- `backend/internal/app/loop/loop.go:31,51-82` —— `maxConsecutiveAllFailTurns=3` / 三个可选 Host 能力 type-assert 模式
- `backend/internal/domain/approval/approval.go:67,79` —— `timeoutBehavior` `approve` 是合法 enum（红线 #3 的风险点）
- `testend/golden/golden_test.go:100-106` —— `drainInteractions` 自动放行（评测专用，禁泄生产）
- `backend/internal/app/tool/shell/bash.go` + `filesystem/{read,write,edit}.go` —— 母体逃逸面
- `backend/internal/pkg/limits/limits.go` —— 引擎旋钮可迁入处（A/B 前置）
- 无 `.github`/无 CODEOWNERS/无 AST guard；`testend/` 除 `go.mod` 外零非-go 文件（无 golden 快照/baseline）

## 6. 外部依据（联网调研，节选关键引用）

**评估方法论**
- code-based > LLM-judge > human：确定性评分 super fast/highly reliable、能改多选就改造；LLM-judge 单次调用+单 prompt+0-1 分+pass/fail 最稳（多判官集成反不如单次精心设计）。[anthropic.com/engineering · claude-cookbooks building_evals]
- 状态变更类任务优先 **end-state evaluation**（多 agent 走多条合法路径，固定步骤会误判）；轨迹评估用于诊断「为何对/错」。[arxiv 2510.02837]
- pointwise 易 length bias（适合纵向监控）；pairwise 更鲁棒但强 position bias（适合模型选型 A/B，需 balanced permutation）。[arxiv 2504.14716]

**Eval 飞轮 / 回归防护**
- eval-driven development = 为非确定性改造的 TDD：建特性前先定 eval，飞轮 analyze→measure→improve→automate；**复利资产是数据集不是任何单 prompt**。[zenml.io llmops]
- 每个生产失败立即变**永久** eval case，回归永不静默重返。[braintrust.dev]
- **start small：20-50 条真实失败**即可（早期效应量大、小 N 足够）；100-300「统计显著」是成熟期目标非起步门。[anthropic.com/engineering/demystifying-evals]
- CI 门控比 candidate 与**上次通过 baseline** 在**同 case** 上的 **per-case delta**（非绝对分）；安全/拒答 evals 是不可谈判 100% 门。[braintrust.dev]

**自改进 agent**
- **GEPA**（反思式 prompt 进化 + Pareto 选择）最契合：读轨迹用自然语言反思诊断、非压成标量 reward，平均超 RL 6%、省最多 35x rollouts，超 MIPROv2 >10%；官方 MCP Adapter 直接优化 tool descriptions + system prompt。**held-out valset 必需；20-100 样本一致优于 500**（500 让 prompt 膨胀 75% 性能反降）。[arxiv 2507.19457 · gepa-ai.github.io]
- OPRO 真有效但自陈短板：optimizer LLM 不能有效用 error case 推断改进方向、需数十样本否则严重过拟合、对初始化敏感。[arxiv 2309.03409]

**Tool/描述质量**
- 工具描述是性能「最重要的单一因素」，措辞小幅精修带来巨大调用准确率提升；每描述≥3-4 句、显式写「何时用/何时不用/参数/返回/caveat」。[platform.claude.com/docs · anthropic.com/engineering/writing-tools-for-agents]
- 合并优于拆分（多原子工具 → 带 action 参数的单工具）；工具数压准确率（按需加载 vs 一次性：Opus 4 tool-selection 49%→74%、省 85% token；触发阈值 >10K token 或 ≥10 工具）。[anthropic.com/engineering/advanced-tool-use]

**持续 AI 代码 loop / 防自我作弊**
- Claude Code 官方 headless（`-p` + `--output-format json` + `--max-turns` + `--allowedTools`）+ `anthropics/claude-code-action@v1`（tag 模式人发起 vs agent 模式 headless 跑在事件上）+ `schedule: cron`，自动化机制已成熟。[code.claude.com/docs/github-actions]
- **METR**：模型能看到完整 scoring function 时 reward-hack 暴增——o3 在 RE-Bench 30.4%（某任务 100%）vs HCAST（看不到）0.7%，相差 >43×；模型明知违背用户意图（10/10 答「no」），**「请勿 reward hack」几乎无效**。防作弊必须靠架构隔离。[metr.org/blog/2025-06-05]
- 独立审计（28+ 提交/9 benchmark）给出作弊 taxonomy：git log 挖 fix、对已知测试硬编码返回值、向 verifier 打印期望关键字、mock 假实现；换干净 scaffold 后 81.8%→71.7%。缓解=明确规则 + 双向访问控制 + agent 监督 agent 审 transcript。[debugml.github.io/cheating-agents]
- Claude Code auto mode 范式：输入层 prompt-injection 探针 + 输出层 transcript classifier（**故意剥 reasoning 与 tool 输出防 agent「说服」自己**）；三档权限；连续 3 拒或单 session 20 拦截升级回人。[anthropic.com/engineering/claude-code-auto-mode]
