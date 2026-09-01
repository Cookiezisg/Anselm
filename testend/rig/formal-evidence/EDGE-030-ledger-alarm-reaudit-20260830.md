# EDGE-030 账本与告警独立复审

日期：2026-08-30

## 复审对象

- 账本裁决：`EDGE|生成中再 Send|L2|pass|F1`
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-124531`
- session 证据：`sessions/20260830-124531/evidence/EDGE-030-real-app-20260830.md`
- 当前覆盖行：`✓✓~~~`。本次只推进 L2，L3 的动作到首帧时延、L4 的队列控件几何/对比度、L5 的洁净态可发现性仍未判定。

## 告警事实

- `gap-too-fast`：本次写账后由尾窗间隔中位数低于 25 秒触发。零秒间隔来自完成一次真实 App 观察、五通道交叉核对后单条裁决的进程级写入，不代表观察耗时为零。
- `discovery-collapse`：尾部 50 条裁决的 `fail` 占比为 `0.0%`，低于 5% 地板。这是统计上的“可能停止发现”信号，不是“产品已经没有缺陷”的结论。

## 独立复核

1. 重新核对 `anchors.py check`：冻结锚点 `10/10`，锚点 hash 未改变；`alarms.py` 的窗口、阈值和算法未改变。
2. 重新核对正式 session 的 `manifest.json`、封口 `screen.mov`、`backend.log`、`frontend.log`、`sse.jsonl` 和 `llm.jsonl`。`rig-check` 已通过 D1 归属、App 窗口、录屏、三路 SSE 和 llmtap wiring；`rig-down` 后无残留进程。
3. 重新核对产品语义：直接 HTTP POST 在生成中返回 `409 STREAM_IN_PROGRESS` 且不产生第二个 LLM 回合；Composer 的 Enter 显示进入 FIFO 队列。清册原先把两个入口压成“不排队”，已在写账前同步为准确契约，没有把产品标准放宽。
4. 重新核对判定边界：本次只用 `judge.py` 写入 `L2 pass`，证据文件位于同一 session 的 `evidence/` 目录；L3-L5 未因本次现场记录而被顺带放行。

## 处置

两项告警仅按本复审记录串行 `ack`。不修改 `WINDOW`、`MIN_GAP_MEDIAN_S`、`BURST_RATIO`、`DISCOVERY_FLOOR`，不修改 CODEX、锚点集、顺序 gate 或历史 journal。ack 后必须重新运行 `alarms.py check` 并要求 clean；后续出现新 journal 水位时，检测器仍会重新评估。
