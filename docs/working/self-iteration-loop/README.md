---
id: WRK-025
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# 自迭代 Loop —— 项目导航 + 活状态

> **目标**：建一个 loop，让 AI（Claude Code）持续诊断与改进 Anselm 后端 agent 质量、人掌舵门控，覆盖产品 bug / harness / tool-call / 描述与 prompt 四维度。**已定姿态：上全套 rigor（真·自迭代），按两个并行 team 投入。**

## 文档

| 文件 | 作用 |
|---|---|
| [`CHARTER.md`](CHARTER.md) | 治理契约：使命 / 已定取舍 / 四红线 / 人在环掌舵点 / 成败判据 / 叫停信号 |
| [`PLAN.md`](PLAN.md) | 分期路线：核心 7 拍 loop / Phase 0 / Week 1 / Month 1-3 / Week 11+ / 每维度子 loop |
| [`FINDINGS.md`](FINDINGS.md) | 证据基：四维度现实表 / 三裂缝 / 作弊向量→缓解 / 代码锚点 / 外部引用（含 URL） |

## 活状态板

- **当前阶段**：📋 立项（CHARTER/PLAN/FINDINGS 已落，待作者评审）。
- **下一动作**：① 作者评审本三篇 → ② 评审通过后落 ADR `decisions/0006-self-iteration-loop.md`（锁核心架构决策，ADR 不可变故不抢跑）→ ③ 起 Week 1 最小切片（coverage-honesty meta-test + danger-false-safe 探针，零 AI、零反噬）。
- **可与 Week 1 并行**：Phase 0 地基（CI 隔离 / 文案外提 / 母体逃逸封死 / 红队验收门）。

## 开放决策（待作者拍板）

| # | 决策 | 默认建议 |
|---|---|---|
| D1 | ADR 0006 现在就落，还是等 Week 1 信号验证后落？ | 评审 CHARTER 后即落（核心约束已定、ADR 是「带完整约束」的永久锚） |
| D2 | Phase 0 与 Week 1 并行起，还是先 Week 1 出信号再投 Phase 0？ | 并行——Week 1 零成本出信号，Phase 0 是长周期地基不等它 |
| D3 | 文案外提（5 section + 61 tool Description → embed 数据文件）谁来做、何时做？ | Phase 0 内、纯人工一次性重构，先于任何 AI 写权限 |

## 落地协议（GOVERNANCE §9，working 90 天上限）

本项目结论分两路落永久层后 `git mv` 入 `archive/`：核心架构决策 → ADR `decisions/0006`；建成的基础设施 → `references/`（testend 观测缝 / eval 表 schema / loop workflow）。各篇 frontmatter 落地时填 `landed-into`。
