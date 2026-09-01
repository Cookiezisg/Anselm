# EDGE-181 整批 embed upsert 全失败：L2 真实 App 数据真相

- 结论：`pass`。
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-220606`。
- 数据副本：`/private/tmp/anselm-data-edge181-real-20260830`，没有改动开发数据目录。

## 真实故障路径

1. 在独立 SQLite 副本的真实 `search_embeddings` 表上安装受控 `BEFORE INSERT` trigger，令实际 `UpsertEmbedding` 返回 `SQLITE_CONSTRAINT_TRIGGER`。这是真实 store 写入失败注入，用来确定性模拟“磁盘满/表不可写”这条错误分支；本证据不把它表述为物理磁盘已满。
2. 启动真实 Go sidecar、真实 Flutter App、三路独立 SSE witness、managed gateway LLM tap 和 60fps Computer Use 录屏。真实 embedder `llama-server` PID=`63222` 进入 ready。
3. 首轮 backfill 对缺失向量 `sd_249418760d538144` 真实写表失败；backend journal 同时记录 `upsert failed` 与 `batch fully failed to persist; aborting backfill round, next kick retries`。
4. 通过真实文档 PATCH 触发一次独立 entity kick。第二轮仅新增两条失败尝试，累计 `upsert failed=3`、`batch abort=2`；随后观察窗口内计数保持不变，证明没有把失败批次立即热循环重跑。
5. 同一 session 的真实搜索仍返回 `EDGE181` 文档，并返回 `<mark>EDGE181</mark>` 高亮；词法搜索没有因向量表不可写而被伪装成成功或整体打断。

## 五通道交叉证据

- backend：`backend.log` 行 20/21 与 160-162 记录两轮真实失败、明确 abort 和 next-kick 语义；健康探测持续 `200`。
- SSE：`sse.jsonl` 连接 `messages`、`notifications`、`entities` 三流，并记录真实 document update durable frame。
- LLM wire：`llm.jsonl` 记录 managed gateway readiness；本场背景索引与 REST 搜索没有聊天模型请求，不将 readiness 冒充业务调用。
- frontend：`frontend.log` 只有 App 启动和 Dart VM service，无 Flutter/Dart/RenderFlex/Unhandled/overflow 红线。
- Computer Use/录屏：同一 manifest 的 `screen.mov` 记录 App 持续保持可用 Chat 空态；稳定帧在 `frames-edge181/normal-001.png` 至 `normal-025.png`。

判定依据：`CODEX F2`。真实 store 写失败、worker abort、下一次独立 kick、词法检索结果和五通道日志相互一致。
