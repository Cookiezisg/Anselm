# EDGE-299 · 5000 条真实通知压力（UI 不放行）

- 日期：2026-08-30
- session：`/private/tmp/anselm-rig-codex-20260830-edge299/sessions/20260830-084953`
- 结论：**后端与 SSE 压力条件成立；不放行 UI 的 L2-L5**。

## 已证明

- 完整五通道台架启动；后端 PID 与 `:8742` 归属一致，LLM tap 接线通过。
- 通过真实 `POST /api/v1/skills` 生命周期并发创建 `5000` 个隔离 skill，全部返回 `201`。
- 真实工作区 `unread-count=5009`（含播种基线通知），通知流记录 `5000` 个 `skill.created` durable frame。
- 录像 `screen.mov`=`77.615s`，backend=`5156` 行，frontend=`3` 行；App 正常启动日志无 Dart/Flutter/Layout 错误。

## 为什么不能判绿

在本次压力灌入期间，录制区域被 `SecurityAgent/CoreServicesUIAgent` 系统窗口覆盖；`rig-check` 明确以 external overlay 失败。因此没有合法的无遮挡逐帧证据证明真实 App 在 5000 条候场时的顶带投影、widget 数量、交互和视觉状态。压力数据链保留，但不把后端/SSE 成功冒充为产品 UI 完成；清掉系统窗口后必须重新取真实 App 五通道证据。

收台时搜索 embedder 的一条 `context canceled` 为关停阶段的信息日志，不作为本项产品错误；其余前端错误扫描无命中。
