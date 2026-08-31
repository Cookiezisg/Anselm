# EDGE-238 · settings 三段整体写 · 真实 App 五通道证据

## 结论

`settings.json` 的 `limits`、`network`、`retention` 三段在真实 App 的分段写入和重启后仍完整存在；修改
一段不会抹除另外两段。没有发现需要 stop-and-fix 的产品缺陷。

## 正式会话

- 首轮真实修改与聊天：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-160154`
- 重启/恢复复验：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-161135`
- 两轮均由同一 rig conductor 托管真实 App、App-owned sidecar、三路 SSE witness、LLM tap、frontend
  console 和窗口录屏；两轮 `rig-check` 通过，`rig-down` 通过，收台后没有 conductor-owned survivor。

## 真实操作与结果

1. 在 App 的 `Settings → Advanced limits` 中用真实键盘把 `agent.maxSteps` 从 `25` 改为 `26`，服务端
   `PATCH /api/v1/limits` 返回 `200`。
2. 在 App 的 `Settings → Storage & logs` 中选择 `Run history retention → 180 days`，App 显示
   `Retention updated`，服务端 `PATCH /api/v1/retention` 返回 `200`。
3. `Settings → Network` 显示直连状态：三个 proxy 字段为空、Save 在无改动时不可提交；没有为验收引入真实
   代理或改变网关路由。此后服务端读取为 `network={}`。
4. 首轮落盘后的文件真相为：`limits.agent.maxSteps=26`、`retention.runRetentionDays=180`、
   `network={}`，所有其他 limits 字段仍在。
5. 关闭首轮 App 并以新 sidecar 重启，同一 workspace 的设置页再次显示 `26` 与 `180 days`；重启后直接读
   `GET /limits`、`GET /network`、`GET /retention` 与 `settings.json`，三段均一致。
6. 首轮补发一条普通消息，经当前 managed gateway 穿过 llmtap 完成；LLM journal、三路 SSE、backend
   journal、frontend console 和录屏均为非空且归属同一 manifest。

## 五通道与异常边界

- Frame：首轮 Settings 操作、`Retention updated`、Network 直连空态和重启后的 `26`/`180 days` 均在
  Anselm 窗口录屏中可见；录屏为 H.264 `3104x1844/60fps`，首轮 `505.788333s`，重启轮 `46.773333s`。
- Backend：D1 确认 App-owned sidecar PID 与监听端口一致；HTTP PATCH/GET 全部按预期返回。日志中的一条
  `search engine ... operation not permitted` WARN 是当前 macOS sandbox runtime 无法执行时的既有 lexical
  fallback，紧邻 INFO 已明确说明 `provider unavailable, staying lexical`；本轮没有 panic、FATAL 或设置写入错误，
  该环境边界不冒充设置功能红线。
- SSE：两轮 messages/entities/notifications 均由 ssetap 连接并在收台时 clean EOF；未因设置写入伪造 durable
  状态。
- Frontend：无 `FlutterError`、Dart exception、RenderFlex、Unhandled exception 或失联红线；首次真实键盘
  提交与重启恢复均可见。
- LLM wire：首轮 challenge/install/models/quota 与普通聊天请求经过当前 llmtap；重启轮持久 managed key
  仍指向同一 tap 端口，`channel5_wiring` 通过。第二轮未把无聊天请求伪装成新 completion。

## 判定依据

- L2 `F1`：App、REST 与磁盘逐字段一致，且重启后仍一致。
- L3 `A1`：输入提交后服务端立即返回，界面回到稳定值；retention 更新有明确即时反馈，不存在静止等待。
- L4 `C4`：稳定帧中 Settings 的 section、scope badge、field、warning callout、button 圆角层级一致，无截断、
  重叠或异常跳变。
- L5 `G1`：新建 workspace 后从主壳 Settings 入口可直接找到 Advanced limits、Network、Storage & logs；
  页面标题、侧栏命名和 machine scope 说明让用户不依赖内部 API 名称即可完成目标。
