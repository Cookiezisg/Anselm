# EDGE-299 · 真实 App 通知中心探针（不放行）

- 日期：2026-08-30
- session：`/private/tmp/anselm-rig-codex-20260830/sessions/20260830-084544`
- 结论：**不放行 `EDGE-299` 的任何新账本格**。

## 做了什么

- conductor 启动完整五通道台架并通过 `rig-check`。
- 真实 macOS App 进入 Chat，再打开 Notifications；稳定态观察到真实工作区已有 9 条通知。
- `screen.mov` 时长 `74.595s`，三条 SSE 均连接并正常收台；backend `158` 行、frontend `3` 行，错误扫描无命中。

## 为什么不能判绿

`EDGE-299` 的构造条件是短时间灌入 **5000 条**通知，并证明顶带只投影 current、最多两条 cue，widget 数不随积压增长。本 session 只观察了已有 9 条真实通知，没有完成 5000 条真实后端通知灌入，也没有形成该压力条件下的五通道证据。因此自动单测和 demo 构造仍只能支持已有 L1 结论，不能替代本项 L2-L5。

自动证据仍为 `testend/rig/formal-evidence/EDGE-299-notice-backlog-20260826.md`；本记录只保留真实 App 探针边界，不写入 `COVERAGE.md` 绿格。
