---
id: DOC-019
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Document

## 1. 定位

Document 是 workspace 内有序、可寻址的 Markdown 树。每个 `doc_` 节点持 parent、
position、物化 path、正文、描述与 tags，可被：

- Library 直接编辑；
- Chat/Workflow 显式挂载；
- Agent knowledge 引用；
- `@` mention 与 catalog 发现；
- Search 索引；
- `[[wikilink]]` 接入 Relation 图。

单篇最大 1 MB，名称最大 256 字符且不能含 `/`。Attach 永远只注入点名的单篇，
不自动拖入子树，避免一次挂载无界扩大上下文。

## 2. 树不变量

Create 对同父重名自动尝试 `name 2` 等后缀；显式 Rename 则严格返回 name conflict。
新节点的 sibling position 在同一事务中计算并插入，避免并发创建拿到相同位置。

Move 支持：

- `parentId = nil` 移到根；
- `position = nil` 追加到目标 sibling 尾部；
- 拒绝移到自身或自身后裔；
- 把目标 sibling 重排为连续 position；
- 级联重写整棵子树的物化 path。

Duplicate 深拷整棵子树，为每个节点铸新 ID 并重映射 parent/path；新根名称按 Create
规则去重。复制逐节点执行，不宣称跨整棵树原子。

Delete 软删整棵子树，并在删除前枚举所有后裔 ID 清理 Relation 边。墓碑保留；
正常 List/Get/Search 不返回已删节点。

## 3. 内容与挂载

正文写入后解析 wikilink，并以 diff-sync 重建该文档的 link 出边。Document 自身不
解析引用目标的内容，也不把名称当身份。

Conversation 挂载按发送时的 Attachment/Document ID 快照解析。已删或缺失文档会在
prompt 内渲染显式 missing 标记，不静默生成空 grounding；Agent knowledge 的缺失策略
更严格，见 [`agent.md`](agent.md)。

Tree metadata 投影用 `hasContent ≡ sizeBytes > 0`，允许侧栏判断空页而不拉取正文。

## 4. 发现与 AI 操作

统一 Search 引擎索引名称、描述和 Markdown 正文，并提供 heading-aware snippet。
Document 自带的 DB LIKE Search 只查名称/描述，作为 `search_documents` 工具在统一
索引不可用时的回退。

LLM 工具覆盖 create/read/list/search/edit/move/delete。工具把可修复的 domain 错误转为
软失败文本，允许模型修正参数。HTTP 还提供 iterate，以当前文档为目标启动 AI 编辑。

## 5. 契约

CRUD、tree、move、duplicate、iterate 端点见 [`api.md`](../api.md)；`documents` 表见
[`database.md`](../database.md)；`DOCUMENT_*` 错误见
[`error-codes.md`](../error-codes.md)。变更通过 `document.*` 通知投影。

Relation 负责当前 wikilink/挂载拓扑，Search 负责可再生内容索引；Document 行和正文
仍是 durable truth。
