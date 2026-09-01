# EDGE-298 · 未读徽标绝不据帧 +1：真实 App L3

## 判定范围

本证据只判定 CODEX `B2`（零跳变律）：同一真实 App 场景中，通知中心因持久通知与广播回声更新时，已有内容不能发生非用户触发的重复重排，过渡必须一次完成并稳定。它不把本场没有记录动作起点的事实扩大为可量化的首帧延迟结论。

## 现场与动态测量

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051`
- 录屏=`screen.mov`，`2784x1808`，`60fps`，时长 `90.176667s`，由 `ffprobe.log` 验证可读。
- 通知中心展开发生在录屏约 `56.0s` 至 `56.2s`；此前铃铛已有一个红色未读点，之后通知行完整出现。
- 为避免编码噪声影响判读，从原录屏抽取 `55.0s` 起 `4s` 的 `30fps` 低分辨率审计窗口到 `/private/tmp/edge298-l3small`，使用 `testend/cmd/measure diff`，ROI 为左侧通知区域 `0,0,195,452`，像素阈值 `0.01`。
- 变化仅集中在一次展开窗口：
  - `frame-0032 → frame-0033`: `changedFrac=0.01310`, `box=(42,69)-(184,403)`
  - `frame-0035 → frame-0036`: `changedFrac=0.04250`, `box=(42,86)-(186,405)`
  - `frame-0036 → frame-0037`: `changedFrac=0.04337`, `box=(42,86)-(182,280)`
  从 `frame-0037` 到窗口结束没有超过阈值的后续变化。变化包围盒始终位于通知面板本身，未出现面板外既有内容被二次推动、回弹或反复绘制。

## 五通道交叉核对

- **Channel 1 / Computer Use + 录屏**：`EDGE-298-unread-badge.jpeg` 与同一录屏窗口显示通知面板只展开一次；通知行先出现、随后稳定，没有重复第二条未读提示、遮挡、裁切或 loading 残留。
- **Channel 2 / backend journal**：同场 `backend.log` 中 mark-all-read、create、update、pin 均成功，无应用级 WARN/ERROR/panic。
- **Channel 3 / SSE tap**：`sse.jsonl` 记录 `memory.created`、持久 `memory.updated` 与 pin 的 Broadcast 分流，durable seq 单调无 gap；广播没有造成新的 unread 计数。
- **Channel 4 / frontend 错误面**：`frontend.log` 与 `rig-check` 未发现 Flutter、Dart、RenderFlex、Unhandled 应用红线；前端稳定尾帧保持可见。
- **Channel 5 / LLM wire**：本场不调用 LLM；`llmtap.log` 中 challenge/install/models 为正常 `200`，没有把后台通知操作冒充模型执行。

## 结论

真实 App 的一次通知更新在视口内完成单次展开，随后稳定；测量窗口没有非用户重复位移。因此 L3=`B2` 通过。动作帧未被本场单独记录，故不声称 `A1` 或任何具体毫秒延迟；L4/L5 仍分别等待独立视觉工艺与可发现性判定。
