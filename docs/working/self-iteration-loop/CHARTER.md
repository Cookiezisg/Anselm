---
id: WRK-022
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# 自迭代 Loop —— 项目章程（CHARTER）

> 长期项目的**治理契约**：使命、已定取舍、不可让步红线、人在环掌舵点、成败判据。
> 分期路线见 [`PLAN.md`](PLAN.md)；支撑事实与代码锚点见 [`FINDINGS.md`](FINDINGS.md)；导航与活状态见 [`README.md`](README.md)。
> **本项目是 `working` 类（90 天落地上限）**——永久结论落 ADR `decisions/0006-*` 与 `references/`，本文件只活在「在研」期（落地协议见 GOVERNANCE §9）。

## 1. 使命

建一个 **loop**：AI（Claude Code）持续诊断与改进 Anselm 后端的 **agent 质量**，人掌舵门控。覆盖四维度——**产品 bug / harness 工程 / tool-call 设计 / 描述与 prompt 设计**。

**为什么是 loop 而非一次性**：「好不好」依赖真实失败语料，而失败语料随产品演化持续产生（新 tool、新旅程、模型升级都改变什么 prompt 措辞有效）。一次性优化必过拟合到当时的失败分布。loop 的价值在 **「失败 → 永久 eval case → 防回归」飞轮**，**不在跑得勤**。

## 2. 已定取舍（committed posture，2026-06-18）

作者决策：**上全套 rigor（真·自迭代）**，按「两个并行 team」投入算力。含义——**不走轻量人驱动捷径**：物理隔离 grader、母体逃逸面封死、judge 校准、人晨审门控全部要做。算力不是约束，**正确性与防自欺是约束**。

## 3. 四维度不是平级（信号确定性决定能否交 AI）

详表见 [`FINDINGS.md §1`](FINDINGS.md)。一句话：**产品 bug 与 harness 只能 AI 诊断、人改**；**tool-call 是唯一有确定性回归信号的可自改窄缝**；**描述/prompt 维度最薄、排最后、且开它前先问值不值**。

## 4. 四条不可让步红线

1. **AI 只改外提后的文案数据文件，绝不 `edit` `.go`** ——前提：文案先外提成数据文件（[`PLAN.md` Phase 0](PLAN.md)），否则这条是空话（裂缝一，见 FINDINGS §2）。
2. **grader 对 agent 物理不可见**（METR 实证 30.4%→0.7%）——前提：CI 隔离拓扑先建（今天为零，裂缝二）。
3. **PR-as-proposal，永不自动 merge**；approval `timeoutBehavior` 严禁 `approve`。
4. **无 case 的修复 = 未完成的修复** ——镜像 CLAUDE.md 设计原则 #9 的文档同步铁律。

## 5. 三个物理约束（设计边界，已核实，详见 FINDINGS §2）

- **可改面是 `.go` 字面量** → 必先把 tool `Description()`（散 61 文件）+ 5 处 section 常量外提成数据文件，红线 #1 才从声明变成可断言。
- **grader 隔离今天为零**（无 `.github/`、无 CI、无 AST guard）→ Phase 0 必建，红队验收前 AI 不开任何写权限。
- **AI 自带 `bash`/filesystem 工具** → 自改节点必须**物理剥离这些工具 + OS sandbox + egress deny**，否则 worktree 隔离对手握 bash 的进程是纸糊的。

## 6. 防作弊是架构问题不是提示问题

METR：「请勿 reward hack」提示近零效；**物理隔离把作弊率 30.4%→0.7%（>43×）**。完整作弊向量 → 缓解表见 [`FINDINGS.md §3`](FINDINGS.md)。核心：门禁做成 **agent 物理够不到、且 grader 对 agent 不可见**的硬约束；二阶 transcript 审计只作高亮、不替代人审。

## 7. 人在环掌舵点（用户有主观能动性，人是掌舵者不是橡皮图章）

| 掌舵点 | 机制 | 防 fatigue |
|---|---|---|
| **PR 晨审（主闸）** | 永不自动 merge；填「我检查了 X」结构化 checklist 才能 merge | 每日人审 PR 硬上限，超了 cron 停产排队（背压） |
| **approval 否决 + 理由** | `scheduler/advance.go` NodeParked 等人 yes/no+reason；reason 回流 eval_cases 当负样本 | `timeoutBehavior` 严禁 approve（机械断言守） |
| **eval_cases 策展** | 哪条成永久 case、标 held-out、expectedOutcome 对吗——**前置把关**（D1 不可删=放错永久污染） | 判分字段 AI 物理够不到（表级写权限剥离） |
| **judge rubric 引入/改动** | judge=契约，r≥0.80 人标校准；rubric 改动重新校准 | 不复用旧校准集 |
| **grader 侧改动** | CODEOWNERS 强制额外人审 | 与日常晨审者不同人/不同时段 |
| **scope 决策** | 每拍改哪个维度由人/cron 写死，AI 不自选、不能影响 scope 输入 | — |

## 8. 成功判据（分期）

- **第 1 周**：两张确定性事实表（裸奔域地图 + danger 软作弊数字），零耐久状态、零 AI 写。
- **第 1 月**：三层判官接缝 + eval 表（带生命周期态）+ golden 统计层（Wilson + pass^k）就位。
- **第 3 月**：tool-call 维度首批「AI 提案 / 人处置」PR，人审通过率与真正落地改进数可量。
- **终态**：整条 loop 建成真 Anselm durable workflow（cron Trigger → Workflow 跑 testend/evals → judge Agent 评分 → Approval park）——`idx_frn_once` 记忆化保证贵 judge 节点 replay 不重判，durable 引擎杀手锏自证，loop 兼做产品 demo。

## 9. 叫停 / 收紧信号（任一触发 → 收紧或关停对应维度，详见 PLAN §8）

红队作弊 PR 未被隔离外 CI 拦 → **关停 AI 写权限** · 某维度边际收益连续 N 拍跌破阈 → **永久休眠该维度** · proxy↔真 gap 超阈 → 早停 · danger-false-safe 率单调上升 → 收紧 · 人审通过率≈93% 且 checklist 草填 → fatigue 已发生 · **grader 金标自检失败 → 立即停 loop**（裁判静默失真比不跑更糟）· 月度 token 触硬熔断 → 全局刹车。

## 10. 明确不做（out of scope）

- 产品 bug 维度的 **AI 自动改 `.go`**（AI 只产 finding，人改 + 同提交补 scenario 锁回归）。
- 为窄缝**预先承诺重投入而不验信号**（先用零 AI 确定性手段证明值得）。
- `drainInteractions` 泄进生产 loop（评测专用；生产 loop 套用 = 人在环门自动放行）。

## 11. 安全地板（与 loop 正交，永不破）

`make verify`（gofmt + vet + build + 单测 + `cmd/docs`）红即 revert，不可越。AI 改文案触动契约时**同提交**改 `references/backend/{api,events}.md` + `domains/<域>.md`（CLAUDE.md 同步触发表）。

## 12. 落地去向（landing targets，本 working 项目的归宿）

- **核心架构决策与约束** → ADR `decisions/0006-self-iteration-loop.md`（**待本 CHARTER 评审后落**；ADR 不可变，故不抢跑）。
- **各阶段建成的基础设施** → `references/`：testend 观测缝进 `references/testend/overview.md`；eval 表 schema 进 `references/backend/database.md` + 新域文档；loop workflow 进 `references/backend/foundation/`。
- 本项目落地即 frontmatter 填 `landed-into` 指向上述，`git mv` 本目录入 `archive/`。
