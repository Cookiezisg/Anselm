---
id: DOC-036
type: reference
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Search

## 1. 定位

Search 是实体内容的可重建投影，统一服务：

- HTTP omni/vertical search；
- `search_blocks` Workflow 积木发现；
- 各实体 `search_*` LLM tools；
- 内部 `Retrieve` RAG 端口。

执行日志、Call、Firing 与 Flowrun node 不进入统一索引；它们体量无界，使用各自
专用查询。

## 2. 投影与同步

各实体通过窄 `Source` 投影为 `search_docs`：

```text
workspace + entity type + entity ID + anchor + chunk
→ title/body/tags/ref hint/timestamps
```

Function、Handler、Agent、MCP、Skill、Document、Workflow、Trigger、Control、
Approval、Conversation 与 Memory 都有 source。Skill/MCP 的公开 entity key
使用 name，与 HTTP/挂载寻址一致。

业务写成功后 `Notifier.Changed` 非阻塞入队。单 worker 在 detached workspace
context 重读实体并 replace projection；Conversation 可按 message anchor 增量
更新，避免长 thread 全量重索。

Queue 满可丢 notification，但 Boot reconcile 比较 live/index stamps 并删除
孤儿，是崩溃、丢事件和 schema rebuild 的自愈机制。`:reindex` 使用 force
reconcile：重新投影所有 live entities、就地覆盖并清孤儿，不先清空整个
workspace，因此并发搜索不会经过空索引窗口。

## 3. Lexical search

物理层使用 SQLite FTS5 trigram 与 BM25，title 权重大于 body。短于 trigram
能力的 token 使用 LIKE fallback；长短混合 query 组合 MATCH 与 LIKE。

结果排序先归一基础分，再应用稳定产品提升：

```text
exact name > name prefix > body match
```

可接线积木相对内容实体有轻微 boost；tie 由 updated time 与 entity ID 稳定
打破。

融合分物化在有界窗口内。Cursor 包含 query hash 与 offset，服务端发无填充
base64url(JSON)，解码也接受等价的标准填充形式，以兼容托管模型对不透明 cursor 补齐 `=`；
不同 query 复用 cursor 仍返回 `SEARCH_CURSOR_INVALID`，不能翻到另一结果集。

HTTP `updatedAfter`/`updatedBefore` 是包含端点的 RFC3339 界，服务端先归一到 UTC；畸形时间值或
`updatedAfter` 晚于 `updatedBefore` 返回 `422 SEARCH_INVALID_WINDOW`，不会静默变成空结果或无界查询。
`includeArchived` 默认 `true`，仅接受（大小写不敏感的）`true`/`false`；其他值返回
`422 SEARCH_INVALID_INCLUDE_ARCHIVED`，不会静默回到含归档的默认范围。

Omni search 按 entity 折叠，保留最佳 chunk 与 matched chunk 数。Blocks 按
`(entity,anchor)` 折叠，使 Handler method、MCP tool 等可直接生成 ref hint。

内容命中返回有界 snippet；精确查询中的连字符/复合 token 必须在可见窗口中保持为完整证据
（例如 `ORBITAL-112-FIX4` 不能只显示 `ORBITAL`）。窗口仍有上限，绝不把全文转成搜索结果。

## 4. Semantic search

EmbeddingProvider 有两种实现：

- Builtin：Sandbox direct installer 管理 llama-server 与内置 embedding model；
- Ollama：调用配置的本机 `/api/embed`。

机器级设置为 `embedder=builtin|ollama|off`，另含 Ollama base URL/model。`GET /search/settings`
返回最近已知的 engine 状态：Builtin 会区分 `absent/downloading/ready/error`，Ollama 在首次
成功嵌入前为 `absent`，请求失败为 `error`，成功后才为 `ready`；读取设置不为获得状态而同步探测
外部 daemon，避免一个设置页面被连接超时拖住。机器级设置虽然从任意 workspace header 读取，所有
workspace 看到的是同一份值。
Provider/模型变化通过 `search_embeddings.model` 使不匹配向量自动补算，旧模型
向量不混用。多字段 PATCH 在一个事务内整体提交；写入失败不会留下半套机器设置。设置变化会
使所有已进入索引的 workspace 的向量缓存失效并逐个 kick 补算，而不是只处理发起请求的 workspace。

Embedding worker 与 lexical index worker 分离，下载/推理不阻塞实体写或 FTS。
批量补算失败时停止本轮，等待下一次 kick，避免对同一缺失批次形成热循环。
Workspace vector cache 在增量写后 patch；只有 purge、schema/model 变化才整体
失效。

查询时 lexical window 与超过相关性下限的 semantic window 使用 RRF 融合；但无词法命中且形似
ID/key 的 query（含下划线、路径分隔符或数字）不接受纯向量命中。内置 embedder 对不透明
token 可能有偏高相似度基线，猜出一个实体比返回空结果更危险；有词法证据时仍可做语义补充，
普通自然语言仍保留 semantic-only recall。
Semantic provider 不可用、未 ready 或失败时原样返回 lexical 结果；降级不改变
HTTP shape。

## 5. Search blocks 与工具

`search_blocks`：

当目录超过 utility 精选预算时，第二档先用词法索引收窄候选，再交给 utility 精选；该收窄阶段刻意不混入纯语义向量邻居，避免与查询无关的积木进入 sifter 候选池。普通综搜仍可按全局搜索合同使用混合语义召回。

1. 小目录直接交 utility sifter 选；
2. 大目录先从索引取候选，再交 sifter；
3. Sifter 缺席/失败则使用索引排序。

没有可直接接线 ref 的 hit 会从 blocks 结果剔除。

该工具只覆盖能直接接进 workflow 图的六类节点：function、handler 方法、MCP tool、agent、
control、approval。Trigger 不是 workflow block，必须使用 `search_triggers`；notification 也不是
独立的 blocks kind，应搜索实际提供通知能力的 function、handler 或 MCP tool。`trigger` 和
`notification` 作为 `kinds` 值会被严格拒绝，不做静默转换。

用户询问“哪个 workflow step 可以连接/接线/放入图中”时，聊天路由应优先调用 `search_blocks`，
即使用户已经说出 function 或 handler；需要详情时再用命中返回的 `entityId` 调用对应 `get_*`。

命中后读取详情时必须把返回的 `entityId` 原样传给对应的 `get_*` 工具，不能把展示名当作
`functionId` 或 `handlerId`。可接线 ref 的精确值由相邻 blocks 结果卡承载，助手正文只保留名称、
类型和用途，避免脱敏后留下不完整的接线句。

`search_blocks` 的 `kinds` 原生形状是字符串数组、`limit` 原生形状是整数；为兼容部分托管模型，它们也接受**同一值的 JSON 字符串编码**（例如 `"[\"handler\"]"` 与 `"20"`）。服务端只在字符串能严格解回数组/精确十进制整数时接受；任意 kind 字符串、浮点、非数字字符串和数组以外的编码仍拒绝，不做猜测式转换。

每个可接线 `ref` 只返回一条命中。统一索引可能同时为同一实体保留描述、代码或方法片段；`search_blocks` 在输出边界按最终 wireable `ref` 去重，并保留排序靠前的最佳片段，避免结果卡把同一个积木显示成多个选择。

`WebSearch` 的 `limit` 公开 schema 是 integer。部分托管模型会把它编码成精确十进制字符串，执行边界可以接受这种窄兼容形状；浮点、任意文本、数组和布尔仍拒绝。WebSearch 只使用 workspace 明确选定的 search-category key，不在多个 provider 间静默轮换；未配置或 provider 失败时，tool result 必须返回可行动的配置/故障原因，不能伪造结果或重试成另一种搜索。

若用户明确指定 `kinds` 或 `limit`，工具描述要求模型在同一次调用中带上这些过滤条件；不得先做一次未过滤搜索再补做过滤搜索。这样“只找某一类积木”的用户意图不会被一个看似相同但语义更宽的中间结果污染。

实体 `search_*` tools 在 query 非空时使用同一内容引擎，并返回 count、total、
nextCursor/hasMore；引擎缺席时退回实体原生 substring 搜索。Document 额外返回
path/snippet。

`Retrieve` 返回未折叠 chunks，可按 types、TopK 与 MaxChars 限制。它是内部
端口；没有生产调用方时仍不应被文档描述成用户可达能力。

## 6. 安全与契约

- Infra search 每条 SQL 显式带 workspace predicate；
- API key、MCP config、Trigger config 等加密字段永不进入明文索引；
- FTS schema version 不匹配时 Boot 重建派生索引；
- 索引写失败不回滚业务真相。

精确 HTTP 端点见 [`api.md`](../api.md)，表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)。
