# EDGE-179 L2: 首用 embedder 下载中关停

- **Session:** `/private/tmp/anselm-rig-formal-20260801-4/sessions/20260830-212132`
- **Workspace:** `ws_84288309a2cb71dd`
- **Fixture:** `doc_c479a38c954e2504` (`EDGE-179 download fixture`)
- **Verdict:** PASS for L2 five-channel shutdown truth
- **Law:** `F2` (five-channel data truth)

## 实际动作

本格针对的是首次使用 builtin embedder 时的关停安全性。台架启动真实 Anselm
桌面 App、真实 Go sidecar、独立 SSE witness、LLM wire tap 和 60 fps 录屏；为
触发首次下载，通过 workspace-scoped API 建立 fixture 文档，随后观察到：

```text
GET /api/v1/search/settings
200 {"data":{"embedder":"builtin","engine":{"status":"downloading","model":"embeddinggemma-300m-qat-q8_0"}}}
```

在 `engine.status=downloading` 的真实窗口内向 backend PID `57289` 发送
`SIGTERM`。关停计时为 `2026-08-30T13:22:52.902583000Z` 至
`2026-08-30T13:22:53.020663000Z`，约 `118ms`；不是等待下载自然结束。

## 结果交叉核对

1. **Backend journal:** `backend.log` 记录 installer 收到 `context canceled`，随后
   `search embed: provider unavailable, staying lexical`，再记录 `sandbox shutdown:
   all handles killed`；没有 panic 或 fatal。说明 Close 取消了下载上下文，未阻塞
   数据库和 sidecar 关停。
2. **SSE witness:** `sse.jsonl` 中 `messages`、`entities`、`notifications` 三条流
   均有 connect 记录，且关停时各自正常收口；没有把缺少业务变更误报为业务成功。
3. **Frontend console:** `frontend.log` 仅有正常 Flutter 启动行和 Dart VM service
   行，没有 `FlutterError`、`DartError`、`RenderFlex`、`Unhandled` 或应用异常。
4. **LLM wire:** `llm.jsonl` 记录真实 managed gateway 的 challenge/install/models
   握手均为 HTTP 200，证明本 session 使用了真实网关链路；关停发生在 embedder
   下载阶段，没有伪造一个已完成的模型调用。
5. **Frames:** `screen.mov` 已由 `rig-down.sh` 封存，`3104x1844`、`60fps`、
   `51.221667s`，Computer Use 观察到真实 App 窗口。但该轮 App 视觉仍停留在
   onboarding；下载状态由后端真实 API 与 journal 观测，不能声称界面显示了
   下载进度或关停提示。

## 严格边界

本证据只证明首用下载中的 engine Close 能在真实台架上取消 installer 并快速收口，
且五个观察通道均已存在。由于 App 没有进入可见的搜索设置/下载状态页面，L3 的
可见终态时序、L4 的视觉 craft、L5 的新用户发现性均不由本格覆盖，保持未收口。
