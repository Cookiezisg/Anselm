---
id: WRK-027
type: working
status: archived
owner: @weilin
created: 2026-06-18
reviewed: 2026-07-28
review-due: 2026-10-26
audience: [human, ai]
landed-into: docs/working/backend-evolution/HISTORY.md
---

# Iteration Loop —— 下一步 / 任务索引（一行一条）

> **本表 = 「下一步做什么」的薄索引。** 早期静态探针清单（T1–T5 手搓任务）已被 [`README.md`](README.md) 的 **EXPLORE 引擎**取代——探针现按 novelty × value 动态生成、Workflow 并发扇出，不再维护固定 task 列。存量 backlog 已于 0621 清账+攻坚全部关闭（唯 F101 HIGH·watch 待活体 pprof），「清存量」不再是去向。

## A · 高频复活 + 多模态贯通（当前进行中，2026-07-28 起）

默认真模型路径 = **Anselm API / `anselm-auto`**。先全量静态门禁作基线；再按 [`ARCHIVE.md`](ARCHIVE.md) §0 的 A–E 组跑旧高频绿格 `reprobe` 与当前 frontier：对话/模型主链 → 知识与驻地 → agent/tool/durable → 多模态值流 → 恢复与资源卫生。每条主轨迹 6–9 轮、查完整 ground truth；多模态是全部适用轨迹的乘子，不是单独一格。确认 finding 立即按 8 拍 EXPLOIT，不积压。

## B · 续 loop（本战役后默认）—— 探新方向

按 [`README.md`](README.md) 的 8 拍跑：看 [`ARCHIVE.md`](ARCHIVE.md) frontier → 想/挑新探针（novelty × value）→ Workflow 扇出多轮 probe → 后端 ground-truth 判 → 有就都修 → 记 [`LOG.md`](LOG.md) 一行 → commit。**唯一停止信号 = 当前 Anselm 主验收路由额度耗尽**（NEVER-DONE 不变式）。

## 回归套件（硬记忆 —— 探针永不回碰）

`testend/golden/selfiter_*_test.go`：多轮里用户侧消息脚本化（固定）、agent 侧真模型；结构性 finding 优先转零 token 断言。跑法 `make -C backend testend`（llmmock、零 token）/ `make -C backend evals`（`EVALS=1`、真模型金标）。
