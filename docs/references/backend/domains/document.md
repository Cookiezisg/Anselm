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

HTTP PATCH 是部分更新：省略字段保持原值，description 去首尾空格，content 与 tags 分别按正文和
字符串数组全量替换。空 patch 或所有提供字段都已等值时返回当前实体，但不写盘、不刷新 `updatedAt`、
不重建搜索/Relation 索引，也不发送 `document.updated`；重复 autosave 因而不会伪造一次修改。

Move 支持：

- `parentId = nil` 移到根；
- `position = nil` 追加到目标 sibling 尾部；
- 显式 `position` 必须是目标 sibling 列表的插入下标 `0..N`（含末位），负数或超过 `N` 返回 `DOCUMENT_INVALID_POSITION`；托管 provider 若发出严格十进制整数字符串（如 `"0"`）也窄兼容，浮点、布尔、数组与任意字符串拒绝；
- 若目标父级和解析后的插入位置都与当前相同，移动是成功 no-op：保留 `updatedAt`，不写盘、不发 `document.moved`；
- 拒绝移到自身或自身后裔；这种循环拒绝是该精确文档/父节点组合的终局结果，本回合不得原样重试；
- 把目标 sibling 重排为连续 position；跨父移动同时压缩旧父剩余 sibling 的 position，不留下空洞；
- 级联重写整棵子树的物化 path。

Duplicate 深拷整棵子树，为每个节点铸新 ID 并重映射 parent/path；新根名称按 Create
规则去重。复制逐节点执行，不宣称跨整棵树原子。

Delete 软删整棵子树，并在删除前枚举所有后裔 ID 清理 Relation 边。墓碑保留，可由用户恢复；
因此 `delete_document` 的工具层静态危险下限是 `cautious`（不可被模型自报 `safe` 降低，但不需要
不可逆操作的人闸）。
正常 List/Get/Search 不返回已删节点。

`delete_document` 对已不存在或已删除的 opaque ID 返回 completed 但带明确 not-found 句子的软失败，
不改变任何文档或墓碑状态；调用方不得把该句子渲染成成功删除。

## 3. 内容与挂载

正文写入后解析 wikilink，并以 diff-sync 重建该文档的 link 出边。Document 自身不
解析引用目标的内容，也不把名称当身份。

Conversation 挂载按发送时的 Attachment/Document ID 快照解析。已删或缺失文档会在
prompt 内渲染显式 missing 标记，不静默生成空 grounding；Agent knowledge 的缺失策略
更严格，见 [`agent.md`](agent.md)。

Tree metadata 投影用 `hasContent ≡ sizeBytes > 0`，允许侧栏判断空页而不拉取正文。

## 4. 发现与 AI 操作

统一 Search 引擎索引名称、描述、tags 和 Markdown 正文，并提供 heading-aware snippet。
`search_documents` 只接受文档库 `query`（不是文件系统 Grep 的 `path/pattern`），返回
`id/name/path/description/tags/snippet` 以及 `total/nextCursor`；内容索引命中会从 durable
Document 行补齐路径和元数据。该出口只接受有词法证据的文档行，不把纯语义相似项冒充关键词
命中；RAG/综搜的混合召回不改变本工具语义。`nextCursor` 只在结果被截断时出现；缺席即表示结果完整，不能重复同一 query。
一旦返回匹配文档的 opaque ID，下一步必须直接逐字使用该 ID；若有 `nextCursor`，才把它和原 query 一起原样传回可继续
翻页；Document 自带的 DB LIKE Search 只查名称/描述，作为统一索引不可用时的回退（回退路径
不提供 cursor 续页）。

为兼容托管 provider 偶尔误发的 filesystem-shaped `path/pattern` 参数，工具边界仅在这两个键出现时做确定性恢复：
非空 `pattern`（否则 `path`）只作为文档库 query，两者都空则返回一页有界文档列表；它从不读取文件系统。没有
`query` 且也没有这两个兼容键时仍以 `DOCUMENT_QUERY_REQUIRED` 拒绝。

用户明确给出最大结果数时，模型必须在**首次**调用就传 `limit`，禁止先用默认上限探测后
再重复同一查询；这样避免额外等待和活动轨迹噪声。

`search_documents.limit` 的标准线缆形状是整数。为兼容托管 provider 偶尔多包一层的确定性错误，工具边界也接受严格十进制整数字符串（如 `"5"`）；浮点数、数组、布尔值和任意字符串拒绝，不做猜测或四舍五入。

`list_documents` 是已知父节点下的直接子节点枚举，不是关键词检索。它按 sibling `position`
稳定 cursor 分页：默认每页 50、最大 200，返回本页 `count`、同一父节点下的 `total`、`hasMore`
与 `complete`；有下一页时还返回不透明 `nextCursor`，必须逐字复制到下一次调用的 `cursor`。
游标绑定铸造它的 `parentId`（根级为空）；若把另一个父节点的游标带来，服务端返回
`INVALID_REQUEST`，绝不静默跳过当前父节点的前几行。
`complete=true` 才能称为完整枚举，不能从本页 `count` 或某个全局上限推断。HTTP 的
同一回合已经返回过相同 `parentId/cursor/limit` 的枚举不得重复调用；需要不同视图时再显式改变边界或过滤。
`GET /documents` 使用同一 `?parentId&cursor&limit` 契约；`GET /documents/tree` 是单独的 metadata
树投影，不是这个工具的分页出口。

LLM 工具覆盖 create/read/list/search/edit/move/delete。`create_document` 的 `name`、`description`、`content`、`tags`
在**每一次调用**都必填，包括首次调用；`name` 必须是用户要求的原始标题，后三者没有用户值时也必须显式传空
字符串或空数组。用户同时给出 description、tags 或 content 时，必须和标题逐字放在同一个 canonical create call 中；自然语言中的“with body X”明确映射为 `content=X`，标题不得复制进正文；
禁止 name-only placeholder、先 create 再 edit/rename/delete 修复、不同参数重复创建同一文档。参数校验失败不算创建
成功，模型不得静默用猜测的 name 重试同一个创建意图；同父同名是同一业务身份。
`read_document` 的 `id` 必须逐字使用
`search_documents` 或 `list_documents` 返回的 opaque `doc_` ID；文档 name/path 不是身份，不能拿来
直接读取。工具把可修复的 domain 错误转为
软失败文本，允许模型修正参数。HTTP 还提供 iterate，以当前文档为目标启动 AI 编辑。
`edit_document` 的一次用户编辑意图必须由一个 canonical call 完成，不能把 name、description、content、tags 拆成多次调用；`content` 与 `tags` 是全量替换，其中 `tags` 的标准线缆形状是 JSON 字符串数组，不能传逗号拼接或任意字符串。为兼容少数 provider 的多包一层错误，`create_document` 与 `edit_document` 的工具边界额外接受“字符串内容本身仍是合法 JSON 字符串数组”的形状，绝不猜测或拆分任意字符串。

## 5. 契约

CRUD、tree、move、duplicate、iterate 端点见 [`api.md`](../api.md)；`documents` 表见
[`database.md`](../database.md)；`DOCUMENT_*` 错误见
[`error-codes.md`](../error-codes.md)。变更通过 `document.*` 通知投影。

Relation 负责当前 wikilink/挂载拓扑，Search 负责可再生内容索引；Document 行和正文
仍是 durable truth。
