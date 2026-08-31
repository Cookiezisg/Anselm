# EDGE-199 real App attempt: ready path, not fallback

## 结论

本次不是 `EDGE-199` 的通过证据。真实 App 确实上传并发送了 15.7 MiB 的
`edge199-large.png`，并在附件 chip 显示 `Preparing media…` 时立即发送了一次；
但两个独立附件的 durable `model-default` derivative 都在 chat 取图前已经进入
`ready`，因此没有观察到「等待约 2 秒后退回原图、后台继续追上」这一目标路径。

不写入 L2-L5 绿格，也不把 ready 路径冒充未 ready 回退。

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-082052`
- upstream: `https://api.anselm.website`
- App: PID `36396`，window `10151`
- `rig-check`：五通道均通过；`rig-down`：进程均收回，录屏 `591.636667s`
- source file: `/private/tmp/edge199-large.png`，PNG `12000x12000`，`15703629` bytes

## 现场顺序

1. 第一轮真实文件选择器上传 `edge199-large.png`，附件 chip 显示准备态；完成后发送，真实网关返回成功回答。
2. 新建对话，附件上传完成后在 chip 仍显示 `Preparing media…` 的可见窗口内立即点击 Send；真实网关仍返回成功回答。
3. 两轮均由同一真实 App、Go sidecar、三路 SSE witness、managed LLM tap、frontend console 和窗口录屏观察。

## Durable / wire evidence

SQLite `attachment_derivatives` 的两行事实：

| attachment | derivative | created (UTC) | updated (UTC) | status | proxy bytes | dimensions |
|---|---|---|---|---|---:|---|
| `att_74a5ce7cc16c43dc` | `mdr_6aaef01627aa5525` | `00:23:45.140` | `00:23:47.608` | `ready` | `1026405` | `2048x2048` |
| `att_011a90f52c6f2b31` | `mdr_42f077e50bd8049a` | `00:26:11.838` | `00:26:14.467` | `ready` | `1026405` | `2048x2048` |

The second immediate-send attempt's relevant wire order was:

- user message durable echo: `08:26:18.648+08:00`, attachment `att_011a90f52c6f2b31`
- chat request to the managed gateway: `08:26:18.674+08:00`
- assistant completed response: `08:26:47.793+08:00`
- the derivative was already `ready` at `08:26:14.467+08:00`

The LLM body recorded only the expected relative lease path
`/v1/media/leases/.../content?token=...`; no absolute URL, `data:image`, or raw image bytes
appeared in the body. SSE recorded user open/close, assistant reasoning/text blocks, and
completed message close with monotonic durable sequence numbers. Backend had no application
`WARN`/`ERROR`/panic and frontend had no Flutter/Dart exception; the only frontend log entry
was the known macOS IMK diagnostic.

## What remains open

The focused unit regression remains the only direct proof of the bounded fallback:

```text
go test ./internal/app/media -run '^TestModelDefaultImage_(ReturnsReadyArtifactOrSchedulesWork|WaitsForStartedWorker|FallsBackAfterBoundedWaitWhileWorkerCatchesUp)$'
```

To close L2-L5, a fresh real-App session must make the worker remain non-terminal while the
chat path reaches `ModelDefaultImage`; either a deterministic test-only worker-delay seam in
the rig or a naturally saturated real worker is required. Until then the row remains
`✓~~~~`.
