# EDGE-309 · 侧幕分档时钟 · L4 fixed

## 场景

真实 macOS App 在同一既有对话中显示两个已执行触点。台架在打开对话前把两个 durable `lastAt` 校准为相差两分钟：`clean_relative_clock_b` 为当前时间前 9 分钟，`clean_relative_clock_a` 为当前时间前 11 分钟。打开 Activity 侧幕后只保存基线帧，随后不再点击、滚动、发送消息或刷新页面，等待被动分钟时钟使两条记录合并到同一时间档。

正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-190217`

## 五通道证据

- 画面：`screen.mov`，`137.806667s`；基线为 `evidence/EDGE-309-l4-formal-before.png`，结束帧为 `evidence/EDGE-309-l4-formal-after.png`。基线显示 `Just now (1)` 与 `Earlier today (1)` 两个组头；结束帧显示两条实体行仍在，组头已消失。
- 逐帧测量：`evidence/edge309-formal-1fps-diff.jsonl` 的 `f082→f083` 是分档过渡；30fps ROI 测量 `evidence/edge309-formal-30fps-diff.jsonl` 连续报告 `f0955→f0961` 六个相邻变化帧，变化包围盒从 `(2378,288)-(2934,503)` 收敛到 `(2378,284)-(2934,376)`，不是一帧替换成裸行。过渡截图位于 `evidence/edge309-formal-30fps/`。
- 后端：同一 session 的 `backend.log` 无 `WARN`、`ERROR` 或 `panic`。
- SSE：`sse.jsonl` 记录 notifications、messages、entities 三流各一次连接，静置期间无断流；收台时三流均为正常 `eof`。
- 前端：`frontend.log` 无 Flutter/Dart/布局异常；唯一平台级 `IMKCFRunLoopWakeUpReliable` 诊断不属于应用错误。
- LLM wire：`llm.jsonl` 仅记录台架启动后的受管 tap ready；本场景没有新的模型回合，故不把无关的上游调用冒充本项证据。
- `rig-check.sh`：五通道均通过；`rig-down.sh`：录屏正常 finalize，未留下台架进程。

## 判定

法条：`B1`、`B2`。

修复前的真实录屏曾在一个相邻 30fps 帧内把分组结构替换为裸行，测量为 `changedFrac=0.00529`、box=`(2378,284)-(2934,506)`；该红事实没有写绿。修复后将所有 settled tier 放进稳定的 keyed `_TiersItem`，组头通过 `AnimatedSize` 使用 `AnMotion.mid` 收起，再采用最终单档形状；组件测试还用注入时钟推进两分钟，确认组头消失且两条行仍在。

结论：**L4 PASS**。被动时间重分桶不再一帧跳变，既有内容不丢，视觉过渡有连续中间帧。
