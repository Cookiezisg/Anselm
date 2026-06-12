---
id: DOC-036
type: reference
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-06-12
review-due: 2026-09-12
audience: [human, ai]
---

# search —— 统一搜索服务（BM25 + 语义混合）

> 一套索引、四个出口：人的综搜/垂搜（HTTP）、LLM 搜积木（`search_blocks`）、RAG 取数（`Retrieve`）。设计全文与裁决见 working 方案（落地后归档）；本文是代码的精确投影。

## 心智模型

- **索引 = 实体内容的纯投影**：12 类实体（conversation/function/handler/agent/mcp/skill/document/workflow/trigger/control/approval/memory）各自实现 `Source` 端口，把自己投影成 `search_docs` 行（title/body/anchor/chunk）。投影永远可重建——物理删、无软删、D1 不适用。
- **词法层**：SQLite FTS5（驱动内置）+ `trigram` 分词（中英文/代码统一子串语义）+ `bm25(title:body=4:1)`。trigram 对 <3 rune 的查询零命中（实测）→ **短词 LIKE 回退**；长短混合 token 时长 token 走 MATCH、短 token 以 LIKE 谓词叠加（隐式 AND）。
- **同步 = 写后通知 + 单 worker + 对账自愈**：实体 Service 写成功后调 `searchdomain.Notifier.Changed(type, id, anchor)`（非阻塞，队满即丢）；单 worker 在 detached ctx（S9）下重读实体并 diff 投影；boot 对账（stamps 比对 + 孤儿清理）是丢事件/崩溃/schema 重建背后的唯一自愈机制。conversation 走 `DocAt` 单 message 增量（anchor=message_id，chunk_no=块 seq——稳定键），避免长会话 O(n²) 重索。
- **排序**（§产品手感硬规则）：基底分归一到 [0,1] → exact-name +3.0 > name-prefix +1.5 > 正文命中，积木类对内容类 +0.3；tie → updated_at DESC → entity_id。测试只断言相对序。
- **分页**：融合分跨查询不稳定 → 物化 top-200 窗口，cursor = base64{queryHash, offset}；异查询 cursor 被 `SEARCH_CURSOR_INVALID` 拒绝而非切错窗口。
- **折叠**：综搜按实体折叠（最高分 chunk 胜出 + matchedChunks）；积木面板按 (entity, anchor)——每个 handler 方法 / mcp 工具本身就是结果单元。

## 代码层级

`domain/search`（类型 + `Notifier`/`EmbeddingProvider`/`Repository` 端口 + query 路由/分块纯函数 + 5 sentinel）→ `app/search`（`Service`：Search/SearchBlocks/Reindex/PurgeWorkspace + `Indexer`：队列/worker/对账；只依赖端口，不 import 实体包）→ `infra/search`（raw SQL 物理层——**D2 唯一豁免点**，见 [database.md](../database.md)）→ transport（`GET /search` + `POST /search:reindex`，见 [api.md](../api.md)）+ `app/tool/blocks`（`search_blocks`）。

四个出口：HTTP 综搜/垂搜（人）· `search_blocks`（LLM 积木面板：六类可接线单元、(entity,anchor) 粒度、ref 直填节点、无 ref 命中丢弃）· 8 个 `search_<entity>` 垂搜工具（保 schema 换引擎，`toolapp.ContentSearch`：非空 query 走内容引擎、引擎缺席/出错回退原子串路径）· `Retrieve` RAG 内部口（M3）。

## 关键不变量

1. `infra/search` 每条查询必须带显式 `workspace_id = ?` 谓词（隔离测试钉死）。
2. 密文红线：经 Encryptor 落盘的字段（api key 密文、mcp config、trigger config）**永不进投影**——索引明文落盘即泄密通道（红线测试）。
3. `fts_schema_version` 不匹配 → boot 清空全量重建——索引从不原地迁移。
4. 索引器永不阻塞业务写：Changed 非阻塞投递，溢出丢弃由对账兜底。

## 边界

- 执行日志（executions/calls/firings/flowrun_nodes）不入索——体量无界，是未来独立轴。
- `search_tools`（工具发现）独立小宇宙，不并入。
- List `?q=` 的 LIKE 名字过滤保持原样——「边打边滤」与内容检索是两种产品行为。
