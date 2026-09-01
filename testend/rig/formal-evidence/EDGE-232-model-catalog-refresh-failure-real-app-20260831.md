# EDGE-232 模型目录运行时刷新失败：真实 App 五通道证据

## 结论

本格验证通过。真实 App 启动后约 30 秒，模型目录后台刷新被 acceptance rig
定向到关闭的 `http://127.0.0.1:9/api.json`，只产生可解释的 warning；既有
vendored/last-good 目录没有被清空，Models & keys 页面仍显示 managed model、六个
scenario default，随后真实聊天仍返回精确的 `EDGE232CHATOK`。

这不是断网或全局代理伪造：`ANSELM_RIG_MODEL_CATALOG_URL` 只覆盖 models.dev 的
后台 fetch，真实 managed gateway 仍为 `https://api.anselm.website`，device-proof
仍由 llmtap 透明转发并记录。

## Session

- formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-134318-edge232`
- isolated data: `/private/tmp/anselm-data-edge232-20260831`
- app: real direct macOS App, PID `83068`, window-owned recording
- backend: conductor-owned PID `82622`, port `:8826`
- catalog fault: `ANSELM_RIG_MODEL_CATALOG_URL=http://127.0.0.1:9/api.json`
- real upstream: `https://api.anselm.website`
- recording: `screen.mov`, H.264, `3104x1844`, `60fps`, `147.233333s`

## Product path

1. 真实 App 走首次 onboarding，创建 workspace `EDGE232 Catalog Probe`。
2. App 进入完整 Chat shell；在后台刷新窗口到达后，backend journal 记录：
   `llm: model catalog refresh failed (previous catalog kept)`，错误为 loopback
   端口拒绝连接。
3. Computer Use 打开 Settings → Models & keys。页面仍显示 `Anselm Free · Auto
   multimodal`、managed key、`0 / 1B` quota、六个 scenario 默认模型和可操作的
   `Refresh model list`，没有空目录、错误骨架或不可解释的崩溃态。
4. 回到 Chat，真实输入 `Reply with exactly EDGE232_CHAT_OK`。App 通过真实
   managed gateway 完成两次 streaming completion，最终 UI 显示 `EDGE232CHATOK`，
   composer 恢复可用。

## 五通道对账

- **帧**：连续 `screen.mov`，封口帧为 `evidence/frames/edge232-final.png`；聊天
  settled 后回答只出现一次，composer 可用，无 clipping、overlap、白屏或输入跳变。
- **后端**：`backend.log` 有且仅有本格预期的 catalog refresh warning；无 panic、
  FATAL、应用级 ERROR 或未解释 WARN。健康探针持续 `200`。
- **SSE**：`ssetap` 独立连接 notifications、messages、entities 各一次并 clean EOF；
  messages durable seq `1..8`，notifications durable seq `1..2`，ephemeral delta
  没有进入 durable 序列。
- **前端**：`frontend.log` 无 `FlutterError`、`DartError`、`RenderFlex`、Unhandled、
  Exception、ERROR 或 FATAL；仅未增长的 macOS IMK host diagnostic。
- **LLM 线缆**：`llmtap` 启动事件、真实 managed challenge/install/models/quota 和
  两次 `/v1/chat/completions` 全为 `200`；请求体与响应体均落盘，没有把 catalog
  失败伪装成 gateway 失败。

## 代码与自动验证

`catalogRefreshURL()` 默认仍返回生产 `models.dev` URL，仅在显式设置
`ANSELM_RIG_MODEL_CATALOG_URL` 时替换后台刷新地址；失败路径保留当前 catalog。
新增 `TestCatalogRefresh_RigURLOverrideIsScopedToRefresh`，与既有
`TestCatalogRefresh_FailSilent` 一起通过：

```text
(cd backend && mise exec -- go test ./internal/infra/llm \
  -run 'TestCatalogRefresh_(FailSilent|RigURLOverrideIsScopedToRefresh)' \
  -count=1 -race -v)
PASS
```

`gofmt`、`bash -n testend/rig/rig-up.sh`、`rig-check.sh` 和 `rig-down.sh` 均通过。

## 判定边界

L1 既有 focused evidence 已证明失败保留旧目录；本 session 新增真实 App 的 L2
证据，引用法典 `E7`。L3 通过 `A4`：后台失败不阻塞 App，模型页面与聊天在等待窗口后
仍可操作；L4/L5 对本项没有独立视觉成品或独立入口，模型选择器本身的视觉 craft
与可发现性由既有 catalog surface 覆盖，按明确适用性边界记 `na`，不是缺证据 waiver。
