# EDGE-331 · 限额面板载入失败 · stop-and-fix 红场

## 结论

本轮真实 App 验收**冻结为红，不计账本、不推进批次**。代理向真实 sidecar 注入一次
`GET /api/v1/limits/schema` 的 503 后，Settings → Advanced limits 正确进入可重试错误态，
但主面直接显示了后端返回的内部诊断文本 `acceptance rig injected a transient failure`。
这违反产品法条：错误主面必须使用本地化产品文案，稳定 wire code 只能通过 tooltip 提供给
需要排查的人，后端/网关诊断不能成为用户界面文案。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024219`
- workspace：`ws_90d0563afe6f7ceb`
- data：`/private/tmp/anselm-data-edge331-20260828-r1`
- 注入：`GET /api/v1/limits/schema` 首次响应 503，后续请求恢复
- 红帧：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024219/limits-failure-red.jpg`

## 五通道观察

- **画面**：错误标题和 Retry 入口存在，但内部注入文本直接可见；这是阻断性产品文案缺陷。
- **后端**：sidecar 与代理归属正确，注入响应按预期为 503，未见额外 panic。
- **SSE**：三路 witness 已连接，错误回合有正常 durable close 观察面。
- **前端 console**：未发现 Flutter/Dart/layout 红线；问题是错误态投影规则本身。
- **LLM wire**：本场景不调用模型；managed challenge/install/models 均完成 200。

## Stop-and-fix

根因是 `LimitsPanel` 直接信任 `ApiException.message`，而 N1 的 message 可以承载调试或网关
诊断。修复为整面载入失败固定使用本地化 `settings.limits.errorHint`，只把稳定 code 放进
tooltip；同时增加 fixture widget 回归，验证内部 message 不可见、tooltip 保留 code、Retry
后能恢复配置。修复后必须用同一代理注入再次启动真实 App，确认主面只显示人话并完成重试恢复，
再写 EDGE-331 的 L2 judge。

当前批次保持 `17/50`，本证据不是通过记录。
