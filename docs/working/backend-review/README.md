---
id: WRK-001
type: working
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
expires: 2026-09-11
landed-into: ""
audience: [human, ai]
---

# backend-review —— 全后端系统级 Code Review（2026-06-11）

## 目标

五维审查使系统达到**长期稳定维护标准**：① 产品正确性（业务语义=产品预期）② 工程正确性（无逻辑 bug/并发/竞态/泄漏）③ 代码质量 ④ 架构一致性 ⑤ 可维护性。

与刚收口的 docswriter（按域的设计评审+文档落定）互补：docswriter 答"设计讲不讲得通"，本轮答"实现扛不扛得住"——并发热点、资源生命周期、产品边界场景、错误路径。

## 规则

- 分支 `backend-review`；小问题顺手修、大问题有明确正确解法也修、**产品级决策留档 [DECISIONS-PENDING.md](DECISIONS-PENDING.md) 等用户裁决**。
- 每条 finding 先亲自验证再定性（docswriter F-4 方法论）。
- 修复随轮提交；`make verify` + `-race` 全绿才算轮收口。

## 波次

| 轮 | 范围 | 状态 |
|---|---|---|
| R1 | 并发与竞态亲审（队列/broker/池/bus/调度器/锁） | ← 进行中 |
| R2 | 产品正确性对照（业务边界场景） | ⬜ |
| R3 | 错误路径+边界面扫（subagent+亲验） | ⬜ |
| R4 | 架构一致性+死代码 | ⬜ |
| R5 | 收尾：-race 全测+留档+报告 | ⬜ |

## 文件

- [findings.md](findings.md) —— 全部发现（编号 CR-N：维度/严重度/验证过程/处置）
- [DECISIONS-PENDING.md](DECISIONS-PENDING.md) —— 等用户回来裁决的产品级问题
- REPORT.md —— 终报（收尾时写）
