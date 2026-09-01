# EDGE-244 bearer token 缺失：真实 App L3

- 正式 session=`/private/tmp/anselm-rig-formal-20260831-12/sessions/20260831-174529`，真实 App、backend、App API proxy、ssetap、llmtap、frontend console 和窗口录屏均由同一 manifest 归属。
- 代理只延迟真实 App 的 `GET /api/v1/workspaces` `2500ms`，仅对 `/api/v1/health` 注入 bearer，workspace 请求保持缺失 bearer；backend journal 对应记录 `401 UNAUTH_BAD_TOKEN`。该延迟只用于构造超过 1 秒的真实等待，不改变产品实现。
- Computer Use 与封口录屏逐帧看到 loading 阶段的 spinner 与 `Setting up your workspace...`，随后进入修复后的认证专用错误态，显示 `Restart the local engine`、明确原因和 `Retry`，不是白屏、静止空窗或 workspace 泛化错误。
- `screen.mov` 为 `60fps / 3104x1844 / 52.655s`。5fps 抽帧后的 `measure latency` 结果为 `feedbackFrame=1, latencyMs=200.0, changedFrac=0.00054`；严格 `1%` 阈值的 `measure diff` 只发现 loading→错误的一次语义切换：`frame-008→frame-009`, `changedFrac=0.04801`，之后 12 秒窗口无超过阈值的变化。
- `rig-check.sh` 在收台前通过，`rig-down.sh` 正常封口并回收全部 conductor-owned processes；backend、SSE、frontend、LLM tap journal 均可由 session 复核，未见 Flutter/Dart 应用异常。

## Verdict

- L3 `pass`，法条=`A4`：超过 1 秒的真实 workspace 请求持续显示可辨识的进行态，并在结果到达后切换到诚实、可行动的认证错误态；等待过程中未发现视觉跳变。
- L4、L5 仍开放；本证据不把进行态测量升级为视觉 craft 或可发现性结论。
