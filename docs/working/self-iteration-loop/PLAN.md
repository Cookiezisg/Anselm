---
id: WRK-023
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# 自迭代 Loop —— 分期计划（PLAN）

> 诚实分期。每期：**交付 / 信号 / 落地去向 / 退出判据**。前置依赖严格。
> 治理契约见 [`CHARTER.md`](CHARTER.md)；事实依据与代码锚点见 [`FINDINGS.md`](FINDINGS.md)。

## 0. 依赖序（硬）

```
Phase 0（地基，AI 写权限零）──┐
                             ├─► Month 1（表+判官）─► Month 2（半自动诊断，AI 入场不写码）─► Month 3（PR 闭环，仅 tool-call）─► Week 11+（描述/prompt，先问值不值）
Week 1（零 AI 确定性切片，可与 Phase 0 并行）─┘
```

**铁律**：Phase 0 的红队验收门未过（一条故意改 golden 期望的作弊 PR 被隔离外 CI 物理拦下）之前，**AI 不开任何写权限（哪怕只读文案）**。

## 1. 核心 loop（7 拍）—— 终态形态

```
拍0 触发    一次只 scope 一个维度的一个 finding（禁「改进整个库」）
拍1 失败采集 确定性 Function：扫 failed flowruns + agent_executions + go test FAIL → 永久 eval_cases 行
拍2 基线快照 跑 make testend（零 token）抓 promptdump 全文 + golden pass^k/Wilson 区间 → eval_baseline（AI 永远看不到的对照组）
拍3 诊断    Agent 真模型，读失败的自然语言 trace（promptdump 序列 + FlowRun.Error），只产 finding，绝不写代码
拍4 执行    Claude Code headless，grader 不可见 worktree，只改【外提后的文案数据文件】，shell/fs 工具物理剥离
拍5 验证    ① make verify 地板（红即 revert）② testend per-case delta ③ promptdump 全文 diff ④ golden k 次 pass^k + Wilson 区间
拍6 人闸    approval 节点 park 等人，timeoutBehavior 严禁 approve，人审带结构化 checklist
拍7 收敛    接受→更新 baseline；回退→rollback；每维度收益曲线监控
```

## 2. Phase 0 — 前置地基（独立项目，AI 写权限零）

会腐化的长期负债，**必须显式独立**，与「本地优先桌面 app、不做 SaaS」形态正交——**先问清值不值**（CHARTER §2 已答「值得」）再投入：

- [ ] `.github/workflows` 多 job 隔离拓扑（grader job 跑在 agent worktree 之外、容器里缺席判分逻辑/期望值/llmmock 脚本）。
- [ ] main branch protection（require PR + status checks + 禁 force-push + admin 不可绕）。
- [ ] CODEOWNERS 守 `testend/`、`testend/golden/`、`cmd/docs`、closed-union、`.github`。
- [ ] AST guard（守 closed-union：4 frame 动词 / 6 block 型 / 5 图节点 kind / 4 trigger 源 + S15 ID + S20 errorspkg）。
- [ ] OS sandbox（Seatbelt/bubblewrap）+ egress deny 的 headless 运行壳；自改节点 toolset 物理剥离 `shell`/`filesystem`。
- [ ] **文案外提重构**（一次性、零 AI、纯人工）：5 处 section 常量（`chat/prompt.go:21-43`）+ 61 个 tool `Description()` → `//go:embed` 数据文件；`fields.go` 的 `panic` 守约束保持在 `.go`。
- **验收门** = 一条故意作弊 PR（改 golden 期望让自己过）被隔离外 CI **物理拦下**的可回归证据。此证据存在前，AI 写权限零。
- **落地去向**：隔离拓扑/AST guard 进 `references/`；文案外提是代码改动，同提交更 `references/backend/domains/chat.md` 等。

## 3. 🟢 Week 1 — 最小切片（零 AI、零反噬、当周出真信号）

**只做两件确定性、不依赖任何新表/CI/AI 的事**：

1. **coverage-honesty meta-test**：让 testend 对任一 Quadrinity 域零 scenario 报 `null` 非隐式 100%，接进 `make verify`。立刻产「哪些域在裸奔」的真实地图。纯加 Go 测试，永不反噬。
2. **danger-false-safe 观测探针**：因 `fields.go:124` 已确认缺失/非法默认 safe，在 testend 加纯确定性断言统计「多少工具调用本应 dangerous 却落 safe」，把最危险的内建 gaming 面变成可见数字。

- **明确第 1 周不做**：不建 `eval_cases`/`eval_baseline` 耐久表（D1 不可删，早期 schema/语料错误 = 永久污染）；不搭 CI（属 Phase 0）；不碰红队 PR（隔离没建则无对象）。
- **交付**：两张确定性事实表（裸奔的域 + danger 软作弊面），零耐久状态，AI 写权限零。
- **退出判据**：信号被证明「值得」（裸奔地图非空 / danger 软作弊面可观）→ 才进 Month 1。

## 4. Month 1 — 表 + 三层判官接缝（仍无 AI 自改）

- 建 `eval_cases`（带 `active`/`dormant`/`superseded` 生命周期态——D1 不可删 + 抗过拟合的解，见 FINDINGS §4）+ `eval_baseline`（D2 `workspace_id`、判分字段物理隔离）；写失败采集 Function。
- promptdump 升**全文快照 diff**（落 baseline 时序）；**tool-selection accuracy 确定性 eval**（fuzzy match 非 BFCL exact-match + 扰动鲁棒性）；golden 统计层（Wilson 区间 + k=3-5 次重采样 + `pass^k` + paired-difference）。
- `input_examples` 并行注入器（仿 `injectStandardFields`，强化地基设计原则 #8）。把引擎旋钮（`maxConsecutiveAllFailTurns`/`ToolResultCapKB`/`InvokeMaxTurns`）挪进 `limitspkg.Current()` 以便 A/B。
- **信号**：每次 `make testend`/`make evals` 产结构化度量（pass^k / 区间 / per-tool 计数 / token 趋势 / danger false-safe 率）落 `eval_baseline` 时序。
- **落地去向**：eval 表 schema → `references/backend/database.md`；testend 新能力 → `references/testend/overview.md`。

## 5. Month 2 — 半自动诊断助手（AI 入场、不写代码）

- 把 `:triage` 升为 loop 内核：cron/`run_failed` 触发 → 评测 Function → **review Agent**（真模型读失败语料反思诊断，GEPA 式语言反思而非标量 reward）→ approval park。**review Agent 只产 finding，人据此手动改。**
- 给 `loop.Run` 加可选 Host 能力 `TrajectoryObserver`（仿 `loop.go:51-82` 的 `ReminderProvider`/`StepRecorder` type-assert 模式），算 per-tool 调用计数/重复调用/auto-group 比例随 Result 上报，中立引擎不污染。
- 扩 `bootstrap/aispawn.go` `ExecutionRenderer` 加 `batch:failed` 伪 id 分支（聚合失败批次）。
- **信号**：每夜一份「失败语料 + 根因诊断 + 建议改法」报告 + 验证 durable workflow 能稳定承载自评编排。

## 6. Month 3 — PR-as-proposal 闭环（仅 tool-call 维度先行）

- **前提：Phase 0 全绿 + 文案外提完成 + 母体逃逸面封死。** review Agent 诊断后 Claude Code headless（`anthropics/claude-code-action@v1`，`--max-turns` + `--allowedTools` 白名单 + shell/fs 剥离）在 grader 不可见 worktree 改**外提文案数据文件**，开 PR（带诊断 + 前后 testend delta + 爆炸半径 + 新增 case）。
- **先只放 tool-call 维度**（唯一有确定性 testend 回归信号）。落 CHARTER §6 antiGaming 全套物理闸 + 二阶审计 classifier（剥 reasoning，仿 Claude Code auto mode 范式）。
- **信号**：第一批「AI 提案 / 人处置」PR，人审通过率 + 真正落地改进数。
- **rollback 语义**（缺件，本期必须定义）：record-once 下已落 `flowrun_nodes` 不可删，回退 prompt 改动后依赖它的 run 记忆化结果失效语义须先定清。

## 7. Week 11+ — 描述/prompt 维度 + dogfood 终态（先问值不值）

- **决策门**：若到此 tool-call 窄缝边际收益已趋零（OPRO/APE/GEPA 自陈三轮后趋零、20-100 样本一致优于 500），**严肃考虑不开本维度**——大概率是 judge 噪声，养 judge 校准 + golden k 次重采样的成本会与产出倒挂。
- 若开：接 golden LLM-judge（先校准 r≥0.80 + Cohen's Kappa），GEPA 式 Pareto 多旅程选择 + proxy↔真 gap 早停 + 累计轮数上限。
- **dogfood 终态**：整条 loop 建成真 Anselm durable workflow（CHARTER §8 终态）。

## 8. 每维度子 loop 速查

| 维度 | 信号源 | 度量「更好」 | AI 改哪 | 防回归 |
|---|---|---|---|---|
| 产品 bug | `testend/scenarios/`（19 文件~90 函数）红绿 + `flowrun_nodes` failed + loop.go 已分类码 | testend per-case delta 归零 + chatMsg 终态码归零 | **不改 .go**（AI 诊断，人改）| 新 scenario 永久绿门 |
| harness | `testend/harness/*.go` 观测能力够不够 | 能稳定拉真二进制+脚本驱动+捕线缆 | **一个不改**（人审 PR 加观测缝）| harness 改走人审 + 自带自测 + 「grader 的 grader」金标自检 |
| tool-call | llmmock MockToolCall 脚本 + promptdump 三字段在场(S18) + lazy 激活 | 新建 tool-selection accuracy eval（fuzzy + 扰动）+ danger false-safe 率不升 | 外提后的 tool 描述/参数、合并拆分、resident↔lazy | tool-selection eval 零门 + danger 硬门 |
| 描述/prompt | promptdump 段在场+非空+<3x（无质量分）| ①全文快照 diff ②校准过 golden LLM-judge ③A/B pairwise | 外提后 section 文案 + utility prompt（aispawn/contextmgr）| 全文 diff 只观测、真信号靠 golden 行为分（绝不让结构断言冒充质量门）|
