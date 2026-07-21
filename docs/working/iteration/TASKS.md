---
id: WRK-027
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-07-02
review-due: 2026-09-19
audience: [human, ai]
landed-into:
---

# Iteration Loop —— 下一步 / 任务索引（一行一条）

> **本表 = 「下一步做什么」的薄索引。** 早期静态探针清单（T1–T5 手搓任务）已被 [`README.md`](README.md) 的 **EXPLORE 引擎**取代——探针现按 novelty × value 动态生成、Workflow 并发扇出，不再维护固定 task 列。存量 backlog 已于 0621 清账+攻坚全部关闭（唯 F101 HIGH·watch 待活体 pprof），「清存量」不再是去向。

## A · 全量重测战役（当前进行中，2026-07-02 起）

由 [`COVERAGE.md`](COVERAGE.md)（WRK-052 场景覆盖矩阵，分母 645 单元）驱动：Phase 0 基线✅ → Phase 1 REST 契约全扫 → Phase 2 SSE/协议/安全 → Phase 3 durable 引擎+mega 联动 → Phase 4 真模型 EXPLORE（frontier 新方向+已修 HIGH 抽样回归）→ Phase 5 系统正确性 → Phase 6 收账结算覆盖率（目标 ~99%）。发现即修，8 拍纪律不减。

## B · 续 loop（战役后默认）—— 探新方向

按 [`README.md`](README.md) 的 8 拍跑：看 [`ARCHIVE.md`](ARCHIVE.md) frontier → 想/挑新探针（novelty × value）→ Workflow 扇出多轮 probe → 后端 ground-truth 判 → 有就都修 → 记 [`LOG.md`](LOG.md) 一行 → commit。**唯一停止信号 = deepseek 额度耗尽**（NEVER-DONE 不变式）。

## 回归套件（硬记忆 —— 探针永不回碰）

`testend/golden/selfiter_*_test.go`：多轮里用户侧消息脚本化（固定）、agent 侧真模型；结构性 finding 优先转零 token 断言。跑法 `make -C backend testend`（llmmock、零 token）/ `make -C backend evals`（`EVALS=1`、真模型金标）。
