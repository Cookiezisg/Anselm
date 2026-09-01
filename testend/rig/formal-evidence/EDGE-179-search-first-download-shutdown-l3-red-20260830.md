# EDGE-179｜首用下载途中关停｜L3 红证据（2026-08-30）

## 判定

`L3 失败`，依据 `CODEX.md` 的 `A4`：长等待或后台不可用必须在产品界面给出可理解、可恢复的反馈，且前端错误面不能持续失控。此证据不把“没有反馈”降级为 `na`。

## 真实场景

- 真实 rig session：`/private/tmp/anselm-rig-formal-20260801-5/sessions/20260830-213111`
- 真实 Flutter App 启动并完成 onboarding，创建 workspace `ws_bf0f1c3a0d2d0fc7`
- 通过真实 API 建立唯一 fixture 文档，仅用于触发首用 builtin embedder 下载
- 真实 `/api/v1/search/settings` 返回 `engine.status=downloading`，模型为 `embeddinggemma-300m-qat-q8_0`
- 真实 backend 收到 SIGTERM，日志显示 installer `context canceled`、随后回落 lexical provider

## 五通道证据

1. **Frame**：`screen.mov` 可读，3108×1848，60fps；关停前后抽取的 150 帧均仍是空白 Chat。没有断连横幅、错误页、重试入口或状态变化。
2. **Backend journal**：记录 SIGTERM、有序关停、下载 context cancellation 与 lexical fallback。
3. **SSE tap**：三条 stream 均已连接，断开后记录连接生命周期。
4. **Frontend console**：sidecar 退出后累计 `76` 行 `Connection refused`，覆盖 messages/entities/notifications 三条 SSE；没有全局状态收敛。
5. **LLM wire**：本场景未发送聊天请求，`llm.jsonl` 与录制 manifest 均存在，证明通道已接入而非静默缺失。

## 时序与问题

`edge179-l3-shutdown-timing.txt` 的原始时间戳为：

```text
shutdown_requested_at=2026-08-30T13:32:56.858511000Z
backend_exited_at=2026-08-30T13:32:56.897578000Z
```

两者相差约 39ms；同文件的 `elapsed_poll=2s` 是把已退出进程按 zombie 观察到的保守轮询值，不作为 backend 关停耗时结论。

故障不是后端未关停，而是前端在后端已不可用后仍维持正常 Chat 外壳，同时三条 SSE 无限重连并持续把连接错误刷进 Terminal。用户既看不到真实状态，也没有恢复动作。

## 后续

保留本红证据，先修复外接后端的持续健康监督；修复后用真实 App 重跑同一场景，以新的 session 做显式 revalidation。L4/L5 不因 L3 红证据代填。
