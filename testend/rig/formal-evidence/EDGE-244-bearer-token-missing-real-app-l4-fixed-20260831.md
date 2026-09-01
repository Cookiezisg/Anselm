# EDGE-244 bearer token 缺失：真实 App L4 修复复验

- 红证据指出的缺陷是用户面泄漏 `ApiException(UNAUTH_BAD_TOKEN, http=401)`；stop-and-fix 已移除 WorkspaceGate 对 `AnState.detail` 的传入。原始异常仍在 backend/frontend journal，不再进入产品面。
- 修复后正式 session=`/private/tmp/anselm-rig-formal-20260831-13/sessions/20260831-175540`。真实 App 仍通过同一认证负例构造：health 注入 bearer，workspace 请求缺少 bearer 并经 `2500ms` 延迟后返回真实 `401 UNAUTH_BAD_TOKEN`。
- Computer Use AX 树和稳定尾帧均只显示 `Restart the local engine`、认证原因、`Restart the backend, then retry.` 与 `Retry`；`ApiException`、`UNAUTH_BAD_TOKEN`、`invalid or missing bearer token` 均不再出现在用户面。没有文字重叠、裁切、残留 loading 或空白错误面。
- `screen.mov`=`60fps / 3104x1844 / 27.146667s`。5fps 抽帧的 `measure latency`=`feedbackFrame=1, latencyMs=200.0, changedFrac=0.00054`；严格 `1%` diff 只发现 loading→错误的一次切换 `frame-008→frame-009`, `changedFrac=0.03681`。
- `measure regions` 对按钮蓝色表面为单一 `127×56px` 连通域；仓内 `AnRadius.button=8` 与画面一致；白字/蓝底对比度 `4.31:1`，达到 CODEX D1 的 UI component `3:1` 下限。
- `rig-check.sh` 在收台前通过，`rig-down.sh` 封口并回收全部 conductor-owned processes。backend、三路 SSE、frontend console 与 managed LLM tap 均可由同 session manifest 复核；没有 Flutter/Dart 应用异常。

## Verdict

- L4 `pass`，法条=`C4`：停止推进发现的 raw exception 泄漏已修复；稳定错误态的层级、对齐、按钮几何、圆角和可读性达到视觉标准。
- L5 仍开放；本证据不把错误页的可见 Retry 当作普通用户路径 discoverability 的完整证明。
