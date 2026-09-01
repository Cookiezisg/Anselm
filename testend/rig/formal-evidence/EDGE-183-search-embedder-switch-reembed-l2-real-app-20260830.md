# EDGE-183 换 embedder 重嵌 · L2

- 结论：`pass`
- 法条：`F2`（五通道事实闭合）
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-223728`
- 数据副本：`/private/tmp/anselm-data-edge183-real-20260830`

## 真实动作与结果

在真实 Go sidecar + Flutter App + managed gateway 台架上，将搜索 embedder 从
`builtin` 切换为 Ollama，并由真实 Ollama `embeddinggemma:latest` 完成重嵌。切换后的
服务端设置为 `embedder=ollama`、`model=ollama:embeddinggemma`、状态 `ready`。

切换后 SQLite 事实为：

```text
search_docs: 35
ollama:embeddinggemma vectors: 35, matching current docs: 35
embeddinggemma-300m-qat-q8_0 vectors: 1, matching current docs: 0
```

旧 builtin 行是已删除 search document 的陈旧孤儿，当前 provider 只按 workspace + 当前
model key 读取，因此没有混入新模型检索；该事实没有被掩盖为“旧行归零”。直接 REST
验证中，自然乱码 `flomptar quendel vaxori` 返回 `total=0`，而目标语义查询返回
`EDGE182 Semantic Recall Fixture`。

## 五通道回执

- `screen.mov`：60fps、`3104x1844`、`356.286667s`，包含设置切换后的真实 App 查询。
- `backend.log`：真实 sidecar journal，未发现应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- `sse.jsonl`：三路 `messages`、`entities`、`notifications` 均有连接和 durable frames；messages
  回合推进至 `seq=63`，含 search/read 工具链和最终 `message close`。
- `llm.jsonl` 与 `llm-bodies/`：managed gateway challenge/install/models 与真实聊天请求均穿过独立 wire tap；请求和响应均为成功链路。
- `frontend.log`：只有 macOS IMK 系统噪声，无 Flutter 应用级错误；收台后 backend、ssetap、llmtap、App 进程归零。

这是“切换 + 重嵌 + 当前模型隔离 + 真实 App 消费”的同一 session 证据，不以旧单测或
后台状态替代现场结果。
