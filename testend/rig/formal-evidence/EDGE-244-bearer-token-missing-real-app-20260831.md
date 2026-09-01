# EDGE-244 bearer token 缺失：真实 App L2

- 正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-173413`；App、backend、ssetap、llmtap、API proxy 和窗口录屏均由同一 manifest 归属。
- backend 使用仅限本 session 的 bearer；API proxy 只在 `/api/v1/health` 注入该 token，并对其它 App 请求移除 `Authorization`。健康检查可达，而真实 App 的 workspace 请求确实走缺失 bearer 的负例。
- 真实 App 通过 Computer Use 显示认证专用错误态：标题 `Restart the local engine`，提示引擎拒绝 Anselm authentication token，要求重启 backend 后 retry；旧的 `Couldn't set up the workspace` 泛化文案不再出现。错误页没有清除 workspace，也没有进入 onboarding。
- 同一 session 的 backend journal 记录真实 `GET /api/v1/workspaces` HTTP `401`，响应错误码为 `UNAUTH_BAD_TOKEN`；代理 journal 记录对应转发，`/health` 仍为 `200`。
- 测试数据库随后经真实 REST 创建一个 workspace，仅用于让独立 SSE witness 完成三流接线；该操作不经过 App、不改变产品状态代码。ssetap 记录 `messages`、`entities`、`notifications` 三条连接。
- `rig-check.sh` 与 `rig-down.sh` 均通过；backend 无未解释 WARN/ERROR/panic，frontend console 无 Flutter/Dart/RenderFlex/unhandled/assertion，llmtap 已就绪且 managed key wiring 通过，窗口录屏可由 ffprobe 校验。该负例在 workspace 列表请求阶段结束，因此没有 LLM 请求，这是场景边界而非缺失观测。

## Verdict

- L1 已由既有 transport contract 证据覆盖。
- L2 `pass`：认证故障由真实 App 触发并按产品语义呈现，HTTP、backend、SSE witness、frontend console、LLM tap/布线和窗口录屏均绑定同一正式 session。
- L3-L5 保持开放：本场景没有独立的持续操作、复杂视觉 craft 或入口发现性主张；不以错误页的静态观察替代这些等级。
