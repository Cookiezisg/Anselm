# EDGE-246 | DNS rebinding 防护 | 真实 App 五级现场

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-20/sessions/20260831-184415`
- App: conductor 直接启动的 macOS Anselm，PID `43042`，窗口 `11664`
- backend: conductor 启动，PID `42503`，监听 `127.0.0.1:8749`
- App proxy: conductor 启动，PID `42545`，监听 `127.0.0.1:8797`
- real managed gateway: llmtap 透明接线到 `https://api.anselm.website`；challenge/install/models 均为 `200`
- recording: `screen.mov`, `3104x1844`, `60fps`, `62.178333s`

## Controlled perturbation

`appproxy` 仅对第一次真实 App 的 `GET /api/v1/conversations` 请求，将出站
`Host` 改为 `evil.example.com`；TCP/HTTP 连接目标仍是 conductor 自己持有的真实
backend。一次性预算耗尽后，同一路径透明转发，不持续污染后续请求。

证据：`appproxy.jsonl` 有且仅有一条
`event=host_rewritten,host=evil.example.com`；随后真实 backend journal 记录同一路径
`status=403,bytes=107`，后续重试记录 `status=200,bytes=28`。403 响应的业务错误码是
`FORBIDDEN_BAD_HOST`，由 backend 的真实 `RequireLoopbackHost` 中间件产生，不是代理注入的
响应。

## Product observation

Computer Use 读取真实 App：第一次列表加载失败时，界面显示稳定的
`Couldn't load conversations`、`The local engine didn't return the conversation list.` 和
`Try again`，没有显示内部 HTTP 状态、Host、路由或堆栈。主 Chat 面仍可用，错误没有扩散成
空白页或启动失败页。点击一次 `Try again` 后，AX 树恢复 `演示对话` 和 `Recents 1`，没有
额外的重复错误请求。

窗口逐帧证据来自同一 `screen.mov`：错误态在 `frame-0020`、`frame-0025`、`frame-0045`
保持几何稳定；恢复前后为 `frame-0274`→`frame-0275`，列表从错误态切换为真实列表，随后
稳定到录屏尾帧。`measure latency -dir /private/tmp/edge246-frames-window2-20260831 -fps 10
-action 29 -threshold 0.0005` 返回 `feedbackFrame=30, latencyMs=100.0, changedFrac=0.00341,
box=(170,281)-(727,1102)`。该变化只发生在用户 Retry 之后，非自主跳变。

## Five channels

- channel 1: `rig-check` 通过；Anselm 窗口绑定录屏无外部遮挡，录屏已由 `rig-down` 封口。
- channel 2: backend journal 证明非 loopback Host 的真实 403，以及后续规范 Host 的 200；无未解释 panic/error。
- channel 3: ssetap 独立连接 `messages/entities/notifications` 三流；本旅程没有聊天回合，故没有伪造 durable message 帧。
- channel 4: frontend journal 无 `Unhandled exception`、`FlutterError`、`Dart Error/Exception`、`RenderFlex`、`Lost connection` 或 `ApiException`；最终 AX 树可见 Chat、Recents、演示对话和演示工作台。
- channel 5: llmtap 在线并记录真实 managed gateway 的 challenge/install/models；本旅程没有触发 LLM completion，故不把“在线”冒充模型调用。

## Laws and verdict

- L1 `E1`: existing middleware and real HTTP contract prove the always-on loopback allowlist; focused regression covers `127.0.0.1`, `::1`, `localhost` and rejected non-loopback hosts.
- L2 `F2`: this sealed real App session cross-checks the injected request, backend 403, frontend recovery, independent SSE connections and live LLM wire.
- L3 `A4`: Retry is the only user-triggered visible transition; measured first feedback is `100.0ms`, with no autonomous layout jump or retry storm.
- L4 `C4`: stable error and recovered states have consistent sidebar/main-shell geometry; no white flash, clipped copy, or exposed diagnostic text.
- L5 `G1`: a user without transport knowledge can identify the failure and the single actionable `Try again` affordance; recovery is directly discoverable.

## Reproduction and closure

```bash
RIG_HOME=/private/tmp/anselm-rig-formal-20260831-20 \
RIG_APP_PROXY=1 \
RIG_APP_PROXY_PATH=/api/v1/conversations \
RIG_APP_PROXY_REWRITE_HOST_PATH=/api/v1/conversations \
RIG_APP_PROXY_REWRITE_HOST=evil.example.com \
RIG_APP_PROXY_REWRITE_HOST_COUNT=1 \
testend/rig/rig-up.sh
```

The proxy rewrite is test-rig-only and defaults off. Shared transparent proxy invariants remain
covered by `testend/harness/proxycore` race tests; the focused appproxy test proves the rewrite
budget is finite and the canonical upstream Host resumes after the single perturbation.
