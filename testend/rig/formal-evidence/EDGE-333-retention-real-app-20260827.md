# EDGE-333 保留面板真实 App 复验

## 结论

真实 macOS Debug App 在设置「存储与日志」中显示服务端拥有的 `90 天` 默认值。通过真实 UI 将其改为
`30 天` 后，面板即时回显 `30 天`；随后恢复 `90 天`，顶部反馈显示「保留策略已更新」，最终 UI 与 REST
再次返回的值一致。该路径没有发现产品级 stop-and-fix 问题。

## 真实台架

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-204754`
- manifest: 真实 Debug macOS App、Go sidecar、真实 `https://api.anselm.website`、独立 `ssetap`、独立
  `llmtap`、窗口录屏由同一台架持有。
- `rig-check.sh`: UI 操作前后均通过五通道物理观察；`rig-down.sh` 正常收台，录屏
  `239.690000s / 2784x1808 / 60fps`。
- backend journal: `GET /api/v1/retention` 初始 200；修改与恢复各为 `PATCH 200` 后跟随 `GET 200`，
  未出现 panic/fatal/error/warn 应用红线。
- frontend journal: 无 Flutter/Dart/RenderFlex/Unhandled/Exception 应用红线；仅有启动信息和已知 macOS
  IMK host noise。
- SSE witness: messages、notifications、entities 三流均已独立连接；本确定性设置路径无业务 durable
  变更帧，断开由收台完成。
- LLM tap: managed wiring 通过；本设置路径没有模型 completion，不伪造 LLM 证据。
- SQLite `PRAGMA integrity_check`: `ok`；数据目录没有客户端 `settings.json`，与「全机」服务端拥有默认值
  的语义一致。

## Computer Use 观察

- 面板层级清楚：左侧「存储与日志」选中，主标题、数据目录、诊断、保留策略、数据库和附件分组稳定。
- 「全机」徽标与 `90 天` 下拉在同一行对齐，控件尺寸和间距稳定；恢复后顶部反馈明确告知结果。
- `30 天`、`90 天`、`180 天`、`永久保留` 四个选项可发现且没有隐式覆盖或不可逆动作。

## 判决边界

本证据支持设置面板的真实 UI、服务端真相和可逆回写复验；不把没有业务变化的 SSE/LLM 通道写成伪造的
业务事件证据。正式账本只引用 CODEX 中实际适用的法条，并继续由 `judge.py` 的 evidence 与 alarm gate
约束。
