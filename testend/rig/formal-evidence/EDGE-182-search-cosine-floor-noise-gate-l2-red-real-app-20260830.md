# EDGE-182 cosineFloor 噪声闸：L2 真实 App 红场

- 结论：`fail`，已 stop-and-fix；本格不得进入 L3-L5。
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-221606`。
- 数据副本：`/private/tmp/anselm-data-edge182-real-20260830`。

## 复现

在真实 Go sidecar、真实 Flutter App、真实 `EmbeddingGemma-300m`、managed gateway、三路 SSE witness、LLM tap 和 60fps Computer Use 录屏组成的同一 session 中，使用真实 workspace 的统一搜索接口查询自然乱码 `flomptar quendel vaxori`。词法无命中，但 `/api/v1/search` 返回了 `3` 个不相关实体，最高响应 score=`0.953125`。

直接读取同一 workspace 的真实向量 BLOB，并向正在运行的真实 embedder 取 query 向量，raw cosine 排序为 `0.721914`、`0.704642`、`0.701619`、`0.642252`……。因此当前 `cosineFloor=0.55` 没有挡住真实模型的高基线噪声；既有人工向量 focused tests 不能代表这条真实模型分布。

同一 session 的 identifier-shaped 查询 `zzqvulon_76` 返回空，说明 identifier 早期守卫有效，但不能抵消自然乱码路径的红场。真实 App 聊天工具路径最终显示无文档结果，是模型额外限制为 `document` 的调用行为；底层统一 search REST 的错误召回仍是产品缺陷，不能被上层自我过滤掩盖。

## 五通道

- backend journal：搜索请求、真实 embedder ready 和收台均可追溯；无应用级 WARN/ERROR。
- SSE：同一 session 的 `messages`、`notifications`、`entities` witness 已连接并记录真实聊天/实体事件。
- LLM wire：managed challenge/chat 请求与响应落在 `llm.jsonl` 及 body/response 文件中。
- frontend：`frontend.log` 未出现 Flutter/Dart/RenderFlex/Unhandled 红线；App 仍可用，但这不是底层搜索正确的证据。
- Computer Use/录屏：真实 App 的自然乱码聊天路径和正常 Composer 画面已封存于 `screen.mov`，不把“App 没显示 REST 错误结果”误算为搜索通过。

判定依据：`CODEX F2`。真实搜索返回无关实体，故 L2 失败；下一步是修改 semantic-only 召回闸并以全新 session 复验，不能修改阈值来掩盖红场。
