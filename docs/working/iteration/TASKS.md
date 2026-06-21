---
id: WRK-027
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-21
review-due: 2026-09-19
audience: [human, ai]
landed-into:
---

# Iteration Loop —— 下一步 / 任务索引（一行一条）

> **本表 = 「下一步做什么」的薄索引。** 早期静态探针清单（T1–T5 手搓任务）已被 [`README.md`](README.md) 的 **EXPLORE 引擎**取代——探针现按 novelty × value 动态生成、Workflow 并发扇出，不再维护固定 task 列。下面只留两条 still-actionable 的去向 + 回归套件指针。

## A · 续 loop（默认）—— 探新方向

按 [`README.md`](README.md) 的 8 拍跑：看 [`ARCHIVE.md`](ARCHIVE.md) frontier → 想/挑新探针（novelty × value）→ Workflow 扇出多轮 probe → 后端 ground-truth 判 → 有就都修 → 记 [`LOG.md`](LOG.md) 一行 → commit。**唯一停止信号 = deepseek 额度耗尽**（NEVER-DONE 不变式）。

## B · 清存量 —— 修未结 finding

若不探新、改清账：按 [`LOG.md`](LOG.md) 顶部「未结 backlog」表逐条修，actionable 优先 **F174 → F153 → F161 → F152**，再扫 MED 群（F154/F155/F156/F162/F163）与聚合行（F168/F175）。每条的修法定位已写在其 LOG 行。

## 回归套件（硬记忆 —— 探针永不回碰）

`testend/golden/selfiter_*_test.go`：多轮里用户侧消息脚本化（固定）、agent 侧真模型；结构性 finding 优先转零 token 断言。跑法 `make testend`（llmmock、零 token）/ `make evals`（`EVALS=1`、真模型金标）。
