# EDGE-331 · 限额面板载入失败 · 真实 App 五通道 L2

## 结论

stop-and-fix 后通过。真实 Flutter macOS App 在代理注入一次 `GET /api/v1/limits/schema` 503
时，错误面显示本地化产品文案“无法从引擎读取限额配置”，不显示后端内部诊断或 wire code；
直接点击“重试”后，限额 schema 和当前 limits 均成功加载，字段面恢复。未产生重复提交，
未留下失败活动或卡死状态。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024929`
- workspace：`ws_f4b6c3493c887b8c`
- data：`/private/tmp/anselm-data-edge331-20260828-r2`
- 录屏：`screen.mov`，时长 `59.141667s`
- 代理：`/api/v1/limits/schema` 首次 503；Retry 后转发并返回 200
- 修复后画面：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024929/limits-recovered.png`

## 产品路径

1. 启动真实 App，进入 Settings → Advanced limits。
2. 观察首次 schema 请求失败：错误标题、可重试按钮和本地化 hint 可见；后端内部文本
   `acceptance rig injected a transient failure` 与 `RIG_INJECTED_FAILURE` 均不可见。
3. 直接点击“重试”，等待请求落定；页面恢复“全机”说明、分组和 `agent/context/timeout/tools/guards`
   字段，Composer/设置导航仍可用。

## 五通道证据

- **画面**：Computer Use 读取到修复后错误态只含本地化 hint；点击 Retry 后读取到完整 schema
  字段。录屏覆盖失败态、重试和恢复。
- **后端**：backend PID `45222` 持有 `:8742`；health、schema 重试和 limits 均为 200；无
  `WARN|ERROR|panic|FATAL` 应用异常。
- **SSE**：ssetap PID `45296` 连接当前 workspace 的 messages/entities/notifications 三路，
  正常断开，无缺口。
- **前端 console**：真实 App PID `45778` 与窗口录制归属一致；无 Flutter/Dart/RenderFlex/
  RenderBox/overflow 红线。
- **LLM wire**：llmtap PID `45194` 归属 `:8788`；managed challenge/install/models 均为 200，
  本场景没有模型调用，也没有伪造成功响应。

## 收台与裁决

`rig-check` 与 `rig-down` 均通过，录屏已 finalize，收台后无 Anselm、Flutter、tap 或 recorder
残留。L2 使用 `G2`；L3-L5 沿用证据边界保持 `na`，没有把一次错误态修复冒充为性能、视觉
craft 或可发现性通过。
