# EDGE-184 短词 LIKE 回退 · L2

- 结论：`pass`
- 法条：`F2`（五通道事实闭合）
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-225024`
- 数据副本：`/private/tmp/anselm-data-edge184-real-20260830`

## 真实夹具与黑盒结果

在真实 workspace 中创建 `QX deployment note`（正文同时含短 token `qx` 和长 token
`forecast`），以及 `Forecast only clean note`（只含 `forecast`）。embedder 关闭，
以便本项直接观测 lexical contract，不让语义补充掩盖 token 合取。

真实 REST 结果：

```text
q=qx:             QX deployment note, snippet contains <mark>qx</mark>, total=1
q=forecast qx:    QX deployment note, snippet marks forecast, total=1
```

真实 App 从普通 Chat 入口完成两次用户目标：先请求精确两字母 token `qx` 并展示命中文本；
再请求只返回同时包含 `forecast` 与 `qx` 的文档，最终仅保留 `QX deployment note`，并
解释两个只含 `forecast` 的文档为何排除。Computer Use 观察到两条 `search_documents`
和后续 `read_document` 工具链，结果与 REST/SQLite 事实一致。

## 五通道回执

- `screen.mov`：真实 App 录屏，`60fps`、`3104x1844`、`263.588333s`，含短 token 命中、高短 token 合取和最终稳定画面。
- `backend.log`：真实 sidecar journal，无应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- `sse.jsonl`：`messages`、`entities`、`notifications` 均连接；messages durable frames 推进至 `seq=60`，包括两次搜索/读取回合。
- `llm.jsonl` 与 `llm-bodies/`：真实 managed gateway 请求穿过 LLM tap，聊天请求均为 `200`。
- `frontend.log`：仅 macOS IMK/键盘系统噪声，无 Flutter 应用级错误。

收台后 conductor 所有权内的 backend、App、ssetap、llmtap 和 recorder 均已停止。Ollama
daemon 是测试机上独立管理的外部服务，未被 rig 认领或误杀；其模型 runner 不计为
conductor 子进程泄漏。
