# Relation — 跨实体关系图（relgraph 数据底座）

**Phase**：Phase 5 增量（V1.2 后端阶段，前端启动前的最后补块）
**状态**：📐 设计期（2026-05-19 brainstorm 通过，等开工）
**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../service-contract-documents/api-design.md`](../service-contract-documents/api-design.md) — 3 端点索引
- [`../service-contract-documents/database-design.md`](../service-contract-documents/database-design.md) — `relations` 表 + 3 张 version 表加列
- [`../service-contract-documents/error-codes.md`](../service-contract-documents/error-codes.md) — 4 sentinel
- [`./function.md`](./function.md) [`./handler.md`](./handler.md) [`./workflow.md`](./workflow.md) — `forged_in_conversation_id` 字段写入方
- [`./document.md`](./document.md) — wikilink 解析与 `document_links_entity` 边
- [`./conversation.md`](./conversation.md) — `conversation_forged_entity` / `_edited_entity` 边触发源
- [`./catalog.md`](./catalog.md) — relgraph 节点 label 复用 catalog 聚合

---

## 1. 一句话

**跨实体边的 live-derived 存储**：每个跨 domain 的引用（workflow 用 function、doc 引 doc、对话 forge trinity 实体）派生为一条边写进 `relations` 表，source 域状态变就立刻 sync。前端 `洞察` tab 全图 + 各实体详情页"谁用我 / 我用谁"全部从本表读。**只读对外**，无用户造边端点，无 reconcile，无 SSE 广播。

---

## 2. 端到端推演（设计原则 #5）

### 2.1 LLM forge 出新 function

```
User 在对话 cv_a 让 LLM 创建一个 csv 处理函数
  → LLM tool_use: create_forge { kind: "function", name: "parse_csv", ... }
  → app/tool/forge/create.go → functionapp.Service.Create
      → 落 function fn_x + version fnv_1 (status=accepted, forged_in_conversation_id=cv_a)
      → Service.Create 末尾调：
          relationapp.Service.SyncIncoming(
              ctx, "function", "fn_x",
              kindScope=["conversation_forged_entity"],
              edges=[{from: cv_a → fn_x, kind: forged_entity, attrs: {versionId: fnv_1}}]
          )
      → relations 表 INSERT 1 行
  → 工具返回 → LLM 看到结果
```

### 2.2 用户在新对话里 edit_forge 改这个 function

```
对话 cv_b，LLM 调 edit_forge → fn_x 出 v2 (pending, forged_in_conversation_id=cv_b)
  → User UI 点 Accept → functionapp.Service.AcceptPending
      → fnv_2.status flip accepted
      → fn_x.ActiveVersionID = fnv_2.ID（指针翻向新 version）
      → AcceptPending 末尾调：
          relationapp.Service.SyncIncoming(
              ctx, "function", "fn_x",
              kindScope=["conversation_edited_entity"],
              edges=[{from: cv_b → fn_x, kind: edited_entity, attrs: {versionId: fnv_2, versionNumber: 2}}]
          )
        // editor=cv_b ≠ origin=cv_a → 写 edited 边
      → relations 表 INSERT 1 行
```

**Revert 路径同理**：用户在 UI 上 Revert 到老 version → `Service.Revert` 内部也调 `SetActiveVersion` 翻指针，hook 触发 SyncIncoming 重写 edited 边指向那个老 version 的 editor。若那个老 version 是 v1（origin）→ edited 边 suppress（merged into forged）。

### 2.3 用户在 workflow 里挂这个 function

```
User 在 workflow editor 创建新 workflow，graph 含 function 节点引用 fn_x → 提交
  → workflowapp.Service.Create(graph)
      → 落 wf_y + wfv_1 (status=accepted, ActiveVersionID=wfv_1)
      → Create 末尾调：
          relationapp.Service.SyncOutgoing(
              ctx, "workflow", "wf_y",
              kindScope=workflowKinds (5 种 uses_*),
              edges=computeWorkflowOutEdges(wfv_1.GraphParsed)
                = [{wf_y → fn_x, kind: workflow_uses_function, attrs:{nodeIds:["n_1"]}}]
          )
        // 如果 Create 由 LLM 触发，再调 SyncIncoming(workflow, wf_y, [forged], ...) 写 forged 边
      → relations 表 INSERT 1+ 行

后续用户编辑 graph：Edit → AcceptPending → ActiveVersionID flip 新 version → hook 触发重 sync
```

### 2.4 用户在 doc 里写 [[fn_x]] 引用这个 function

```
User 在 doc 编辑器（前端有 @ picker，自动注入 [[fn_x]]）保存
  → POST/PATCH /api/v1/documents/doc_z
  → documentapp.Service.Update
      → 写 doc body 到 documents 表
      → 末尾调 wikilinkpkg.Parse(body) → [ParsedRef{kind:function, id:fn_x, count:1}]
      → relationapp.Service.SyncOutgoing(
            ctx, "document", "doc_z",
            kindScope=["document_links_entity"],
            edges=[{doc_z → fn_x, kind: document_links_entity, attrs:{count:1}}]
        )
      → relations 表 INSERT 1 行
```

### 2.5 软删 conversation cv_a

```
User 软删 cv_a → conversationapp.Service.Delete
  → conversations.deleted_at = now (软删)
  → 末尾调 relationapp.Service.PurgeEntity(ctx, "conversation", "cv_a")
      → DELETE FROM relations WHERE user_id=? AND ((from_kind="conversation" AND from_id="cv_a") OR (to_kind="conversation" AND to_id="cv_a"))
  → cv_a → fn_x 的 forged_entity 边消失
  → fn_x 在 relgraph 上还在，但没有"creator"了
  → cv_b → fn_x 的 edited_entity 边不动
```

### 2.6 前端打开洞察 tab 全图

```
relgraph.jsx 挂载 → GET /api/v1/relgraph
  → relationapp.Service.GetRelgraph
      → SELECT * FROM relations WHERE user_id=?
      → 拉 6 类全量实体（function/handler/workflow/document/skill/mcp）
      → 收集 edges 端点中的 conversation ID set
      → conversationapp.GetBatch(那些 conv ID)
      → 组装 nodes（kind/id/label/sub）+ edges
  → 200 envelope { data: { nodes:[...], edges:[...] } }
  → 前端力导向布局画图
```

---

## 3. 设计原则

按 brainstorm 阶段确认的 6 条核心原则：

1. **Derived 数据，不是用户造的** —— 无 POST/PATCH/DELETE 端点；用户不能直接造边或删边。
2. **Live derivation** —— source 域状态变 → 立刻 sync 边。无定时任务、无 reconcile 端点、无 polling。
3. **prod-only** —— trinity 实体只看 accepted version；workflow 只看 `active_version_id` 指向的 graph；pending / rejected 不入图。
4. **实体级节点** —— function/handler/workflow 永远 1 个 graph 节点（不分版本）；版本号是 attrs 元数据。
5. **Cascade hard-delete** —— 实体软删时所有出/入边硬删（无 tombstone）。
6. **不广播** —— 边变更不走 notifications SSE，前端打开 relgraph 时主动 GET 拉。

---

## 4. Domain model

### 4.1 Relation entity

```go
// internal/domain/relation/relation.go

type Relation struct {
    ID         string         `gorm:"primaryKey;type:text" json:"id"`              // rel_<16hex>
    UserID     string         `gorm:"index;not null;type:text" json:"userId"`

    FromKind   string         `gorm:"not null;type:text;index:idx_rel_fwd,priority:2" json:"fromKind"`
    FromID     string         `gorm:"not null;type:text;index:idx_rel_fwd,priority:3" json:"fromId"`
    ToKind     string         `gorm:"not null;type:text;index:idx_rel_rev,priority:2" json:"toKind"`
    ToID       string         `gorm:"not null;type:text;index:idx_rel_rev,priority:3" json:"toId"`

    Kind       string         `gorm:"not null;type:text;check:kind IN ('conversation_forged_entity','conversation_edited_entity','workflow_uses_function','workflow_uses_handler','workflow_uses_mcp','workflow_uses_skill','workflow_uses_document','document_links_entity')" json:"kind"`

    Attrs       string         `gorm:"not null;type:text;default:'{}'" json:"-"`
    AttrsParsed map[string]any `gorm:"-" json:"attrs,omitempty"`

    CreatedAt   time.Time      `json:"createdAt"`
    UpdatedAt   time.Time      `json:"updatedAt"`
    // 注意：NO deleted_at。live-derived，硬删边
}

func (Relation) TableName() string { return "relations" }
```

### 4.2 8 种边类型（闭枚举）

| # | kind | from → to | 写入时机 | 删除时机 |
|---|---|---|---|---|
| 1 | `conversation_forged_entity` | Conv → Trinity | `create_forge` 工具落 v1 且 auto-accept 后 | trinity 软删 / conversation 软删 |
| 2 | `conversation_edited_entity` | Conv → Trinity | trinity.ActiveVersionID 指向的 version 由 edit_forge 工具产生；若 editor==origin 则 suppress | ActiveVersionID 切换时重写 / 删；任一端软删 |
| 3 | `workflow_uses_function` | Workflow → Function | workflow.active_version_id 切换后从 graph nodes 重算 | active version 不再引用 / 任一端软删 |
| 4 | `workflow_uses_handler` | Workflow → Handler | 同上 | 同上 |
| 5 | `workflow_uses_mcp` | Workflow → McpServer | 同上 | 同上 |
| 6 | `workflow_uses_skill` | Workflow → Skill | 同上 | 同上 |
| 7 | `workflow_uses_document` | Workflow → Document | 同上（llm/agent 节点 attached_documents） | 同上 |
| 8 | `document_links_entity` | Document → entity（doc/fn/hd/wf/cv，5 种 prefix-ID 实体） | document Create/Update body 后 wikilink 解析 | wikilink 消失 / 任一端软删 |

### 4.3 attrs JSON shape（按 kind）

| kind | attrs |
|---|---|
| `conversation_forged_entity` | `{}` |
| `conversation_edited_entity` | `{"versionId": "fnv_abc", "versionNumber": 5}` |
| `workflow_uses_function` | `{"nodeIds": ["n_1", "n_5"], "pinnedVersionId": "fnv_xyz"}`（pinnedVersionId 可缺省=floating） |
| `workflow_uses_handler` | 同上 |
| `workflow_uses_mcp` | `{"nodeIds": ["n_3"], "serverName": "postgres"}` |
| `workflow_uses_skill` | `{"nodeIds": ["n_3"], "skillName": "csv_parse"}` |
| `workflow_uses_document` | `{"nodeIds": ["n_3"], "includeSubtree": true}` |
| `document_links_entity` | `{"count": 3}` |

`nodeIds` 是 list —— 同 workflow 中多个 node 引用同一实体时聚合。

### 4.4 不变量

- 每对 `(from_kind, from_id, to_kind, to_id, kind)` 至多 1 条边（DB UNIQUE 约束）
- 同一 trinity 实体最多 1 条 `conversation_forged_entity` 入边
- 同一 trinity 实体最多 1 条 `conversation_edited_entity` 入边（且 from ≠ #1 的 from）
- 禁止自环：from 和 to 不能是同一实体（DB trigger 防）
- relgraph 上 function/handler/workflow 永远 1 个节点

### 4.5 关键决策（brainstorm 阶段争议过的）

| 决策 | 选了什么 | 理由 |
|---|---|---|
| 存储模型 | eager diff-sync per source domain | 单用户本地无延迟需求，eager 直观；不走 catalog 那种 polling |
| Doc-to-doc 引用 | Markdown wikilinks 自动抽取（`[[id]]`） | 零字段、零 UI 操作；rename 不破链（按 ID） |
| Memory 入图 | **不入** | Memory 是 system prompt 上下文，非用户实体 |
| Conversation→Document（attached_documents） | **不入图** | 同 memory，ephemeral 上下文 |
| Conversation mentions（message 提及） | **不入图** | 信噪比低；用 skill_executions/mcp_calls 查"使用历史" |
| Flowrun→Workflow（instance_of） | **不入图** | flowrun 是执行记录，不是图实体；走 `/flowruns?workflowId=` |
| 手工 UI 编辑（PATCH meta / editor 拖图） | **不入图** | edited 边只追 LLM via edit_forge 工具；手工不写边、不更新边 |
| 多版本并行 deployed | **不支持** | backend 现有 `active_version_id` 单指针够用 |
| `workflow.enabled=false` | **保留边** | enabled 控调度器自动触发，不代表"非 prod" |
| Sync 失败策略 | propagate，同事务 | 本地 SQLite 单用户场景 sync 失败 = 真 bug，loud fail |
| Pending forge 入图 | **不入** | relgraph 是 prod 关系图；v1 auto-accept 例外 |
| Skill / MCP wikilink | **不支持** | name-based 主键不符合 wikilink 正则；通过 workflow_uses_* 入图 |
| SSE 广播 | **不广播** | 前端打开时主动拉即可 |
| relgraph 上限 | **无上限** | 单用户数据量天然有界 |

---

## 5. DB schema + 索引

### 5.1 `relations` 表（新建）

按 §S15 ID `rel_<16hex>`；按 §D1 软删——**例外不加 deleted_at**（live-derived 硬删，无审计需求）；按 §D2 标准 created_at/updated_at；按 §D3 CHECK 约束在 GORM tag 表达。

### 5.2 索引（4 个，全部 GORM tag 不走 schema_extras）

| 索引名 | 字段顺序 | 用途 |
|---|---|---|
| `uq_rel` (UNIQUE) | (user_id, from_kind, from_id, to_kind, to_id, kind) | 幂等写入；防重复 |
| `idx_rel_fwd` | (user_id, from_kind, from_id) | "我引用了谁"查询 |
| `idx_rel_rev` | (user_id, to_kind, to_id) | "谁引用了我"（relgraph 主要查询） |
| `idx_rel_user_kind` | (user_id, kind) | 按边类型扫（debug） |

### 5.3 自环禁止 trigger（schema_extras.go）

```sql
-- backend/internal/infra/db/schema_extras.go，idempotent
CREATE TRIGGER IF NOT EXISTS trg_relations_no_self_loop
  BEFORE INSERT ON relations
  WHEN NEW.from_kind = NEW.to_kind AND NEW.from_id = NEW.to_id
BEGIN
  SELECT RAISE(ABORT, 'relations: self-loop forbidden');
END;
```

### 5.4 Trinity version 表加列

```go
// function_versions / handler_versions / workflow_versions 各加：
ForgedInConversationID *string `gorm:"index;type:text" json:"forgedInConversationId,omitempty"`
```

- nullable text（HTTP 手工 create/edit 时为 NULL —— 不写 conv 相关边）
- LLM via `create_forge` / `edit_forge` 工具触发时填入当前 conversation ID
- 是 #1 #2 边的"作者签名"字段

**联动**：`function.md` / `handler.md` / `workflow.md` 各加 5.1 节字段说明；`database-design.md` 表行更新。

---

## 6. Domain port + Service 层

### 6.1 Service interface（`internal/domain/relation/relation.go`）

```go
type SyncEdge struct {
    ToKind string
    ToID   string
    Kind   string
    Attrs  map[string]any
}

type Service interface {
    // 把 (from_kind, from_id) 在 kindScope 范围内的所有出向边整组替换。
    // Diff & sync 幂等：插新、删旧、attrs 变了 update。
    SyncOutgoing(ctx context.Context, fromKind, fromID string,
                 kindScope []string, edges []SyncEdge) error

    // 把 (to_kind, to_id) 在 kindScope 范围内的所有入向边整组替换。
    // 用于 #1 #2 "每个 trinity 至多 1 个 forged + 1 个 edited" 场景。
    SyncIncoming(ctx context.Context, toKind, toID string,
                 kindScope []string, edges []SyncEdge) error

    // 实体被删时调用：硬删所有 from_id=id 或 to_id=id 的边。
    PurgeEntity(ctx context.Context, kind, id string) error

    // 读路径
    ListOutgoing(ctx context.Context, fromKind, fromID string) ([]*Relation, error)
    ListIncoming(ctx context.Context, toKind, toID string) ([]*Relation, error)
    Neighborhood(ctx context.Context, kind, id string, depth int) ([]*Relation, error)

    // relgraph 全图快照（无分页无上限）
    GetRelgraph(ctx context.Context) (*Snapshot, error)
}

type Snapshot struct {
    Nodes []GraphNode `json:"nodes"`
    Edges []*Relation `json:"edges"`
}

type GraphNode struct {
    Kind  string `json:"kind"`
    ID    string `json:"id"`
    Label string `json:"label"`
    Sub   string `json:"sub,omitempty"`
}
```

### 6.2 错误策略

所有 relations 操作（sync + purge）**和调用方同事务**，失败 propagate。无 best-effort、无 reconcile endpoint、无 SSE 通知。本地 SQLite 单用户场景失败 = 真 bug，loud fail。

### 6.3 Repository ports（消费其他 domain，只读）

relations 域需要 7 个 read-port 用于组装 relgraph 节点：

```go
type functionReader interface { ListAll(ctx, userID) ([]FuncMeta, error) }
type handlerReader interface  { ListAll(ctx, userID) ([]HandlerMeta, error) }
type workflowReader interface { ListAll(ctx, userID) ([]WfMeta, error) }
type documentReader interface { ListAll(ctx, userID) ([]DocMeta, error) }
type skillReader interface    { ListAll(ctx, userID) ([]SkillMeta, error) }
type mcpReader interface      { ListAll(ctx, userID) ([]McpMeta, error) }
type conversationReader interface { GetBatch(ctx, userID, ids) ([]ConvMeta, error) }
```

每个 reader 在对应 domain 加一个**轻量 meta 视图**（只 id/name + sub，不返完整 entity）。

**ConvMeta label 取值规则**（简化）：

```go
type ConvMeta struct {
    ID        string
    Title     string  // 用户起的标题；常为空
    Summary   string  // conversation 自动 summarize 字段（可能为空）
    UpdatedAt time.Time
}

// relgraph 节点 label / sub 映射：
//   label = Title if Title != "" else (Summary[:30] if Summary != "" else "(未命名对话)")
//   sub   = humanizeTime(UpdatedAt)  // "2 天前"
```

**不去查 messages 表抽取 first message snippet**——避免 relations reader 与 messages domain 耦合，复杂度降一档。

---

## 7. Source-domain Sync Hooks（18 个）

**核心抽象**：trinity（function/handler/workflow）三个 entity 表都有 `ActiveVersionID` 字段——"latest / prod / current" 永远是这个指针指的那个 version。**任何动这个指针的地方都触发 relations sync**。三种方法都动它：`Create`（初始置位）/ `AcceptPending`（flip 到新 accepted）/ `Revert`（flip 到老 accepted）。

| # | 文件 | 函数 | Hook 触发的边 |
|---|---|---|---|
| **workflow（4）** | | | |
| 1 | `app/workflow/workflow.go` | `Service.Create` | `SyncIncoming(workflow, id, [forged], ...)` + `SyncOutgoing(workflow, id, [5种 uses], computeEdges(v1.GraphParsed))` |
| 2 | `app/workflow/workflow.go` | `Service.AcceptPending` | `SyncIncoming(workflow, id, [edited], ...)` + `SyncOutgoing(workflow, id, [5种 uses], computeEdges(newActiveVID.GraphParsed))` |
| 3 | `app/workflow/workflow.go` | `Service.Revert` | 同 #2（指针指向老 version，重算 outgoing） |
| 4 | `app/workflow/workflow.go` | `Service.Delete` | `PurgeEntity("workflow", id)` |
| **function（4）** | | | |
| 5 | `app/function/function.go` | `Service.Create` | `SyncIncoming(function, id, [forged], ...)`（无 outgoing——function 无 graph） |
| 6 | `app/function/function.go` | `Service.AcceptPending` | `SyncIncoming(function, id, [edited], ...)` |
| 7 | `app/function/function.go` | `Service.Revert` | 同 #6（重写 edited 指向 target version 的 editor） |
| 8 | `app/function/function.go` | `Service.Delete` | `PurgeEntity("function", id)` |
| **handler（4）** | | | |
| 9 | `app/handler/handler.go` | `Service.Create` | 镜像 #5 |
| 10 | `app/handler/handler.go` | `Service.AcceptPending` | 镜像 #6 |
| 11 | `app/handler/handler.go` | `Service.Revert` | 镜像 #7 |
| 12 | `app/handler/handler.go` | `Service.Delete` | 镜像 #8 |
| **document（3）** | | | |
| 13 | `app/document/document.go` | `Service.Create` | parse body wikilinks → `SyncOutgoing(document, id, [doc_links], ...)` |
| 14 | `app/document/document.go` | `Service.Update` | 同 #13（body dirty check 后才 sync） |
| 15 | `app/document/document.go` | `Service.SoftDeleteSubtree` | 对 root + 所有 descendants 逐个 `PurgeEntity("document", x)` 同事务 |
| **其他（3）** | | | |
| 16 | `app/conversation/conversation.go` | `Service.Delete` | `PurgeEntity("conversation", id)` |
| 17 | `app/mcp/mcp.go` | `Service.DeleteServer` | `PurgeEntity("mcp", name)` |
| 18 | `app/skill/skill.go` | `Service.Delete` | `PurgeEntity("skill", name)` |

**edited 边的 editor 取值**：`SyncIncoming` 调用方读 trinity.ActiveVersionID 指向的 version 行的 `forged_in_conversation_id`，如果与 origin version（version_number=1）的 `forged_in_conversation_id` 相等 → 传 empty edges（suppress）；否则写。

### 7.1 Tool 改动：`forged_in_conversation_id` 注入

`app/tool/forge/create.go` 和 `app/tool/forge/edit.go` 通过新加的 `reqctxpkg.SetConversationID` / `GetConversationID` 把当前 conversation ID 经 ctx 透传到 functionapp/handlerapp/workflowapp 写 version 时填入。chat 流程已有这层 ctx，仅 propagate 即可。

---

## 8. Wikilink 解析器

### 8.1 接口（新工具包 `internal/pkg/wikilink/wikilink.go`）

```go
type ParsedRef struct {
    Kind  string  // function / handler / workflow / document / conversation
    ID    string  // 完整 ID（含 prefix）
    Count int     // body 中出现次数
}

// Parse 扫描 markdown body，抽取 [[<id>]] 形式的引用。
// 返回 dedup 后的 [{kind, id, count}] —— count 是 body 中出现次数。
// 用 idgenpkg 的 prefix-to-kind 映射；未知 prefix 跳过。
func Parse(body string) []ParsedRef
```

### 8.2 ID prefix → kind 映射（`pkg/idgen/prefix.go`，新文件）

```go
// 只有"实体级"的 prefix ID 进表
var KindByPrefix = map[string]string{
    "fn":  "function",
    "hd":  "handler",
    "wf":  "workflow",
    "doc": "document",
    "cv":  "conversation",
}
```

**Skill / MCP 不在表里**——以 `Name` 字段当主键（用户起名，非系统 prefix-ID），不符合 wikilink 正则 `[a-z]+_[0-9a-f]{16}`。

- ✅ `[[fn_xxx]]` `[[wf_xxx]]` `[[doc_xxx]]` `[[hd_xxx]]` `[[cv_xxx]]` —— 写入 `document_links_entity` 边
- ❌ `[[csv_parse]]`（skill）`[[postgres]]`（mcp）—— 不匹配，跳过

Skill/MCP 仍出现在 relgraph 中（通过 `workflow_uses_skill` / `workflow_uses_mcp` 边）。doc 想直引 skill/mcp 用例罕见，V1 不支持；未来如需扩，加 `[[@skill:name]]` 之类语法。

### 8.3 正则

```
\[\[([a-z]+_[0-9a-f]{16})\]\]
```

中文 / 任意字符 wikilink（如 `[[文档标题]]`）**不支持**——前端编辑器靠 `@` picker UX 注入 ID。

### 8.4 Dangling target 处理

解析出 `[[fn_abc]]` 但 function 表查不到 → 跳过，不写边。SyncOutgoing 内部 batch existence check（`WHERE id IN (...)` 一次性查），不存在的 silent drop + log debug。

---

## 9. HTTP API

3 个端点，全部只读，全部按 ctx user_id 自动过滤。

### 9.1 `GET /api/v1/relations` —— 单实体详情页查关系

**Query 参数**（全部 optional，可组合）：

| 参数 | 类型 | 含义 |
|---|---|---|
| `fromKind` | string | 起点 kind |
| `fromId` | string | 起点 ID（须与 fromKind 同传） |
| `toKind` | string | 终点 kind |
| `toId` | string | 终点 ID（须与 toKind 同传） |
| `kind` | string | 边类型 |
| `cursor` | string | 翻页游标（§N4） |
| `limit` | int | 每页（默认 200，最大 500） |

**典型查询**：

| 场景 | 查询 |
|---|---|
| function 详情页"谁在用我" | `?toKind=function&toId=fn_x` |
| workflow 详情页"我用了谁" | `?fromKind=workflow&fromId=wf_x` |
| document backlinks | `?toKind=document&toId=doc_x&kind=document_links_entity` |
| conversation 详情"forge 了什么 / edit 了什么" | `?fromKind=conversation&fromId=cv_x` |
| "A 是否引用 B" | `?fromKind=A_kind&fromId=A_id&toKind=B_kind&toId=B_id` |

**返回**（§N1 envelope）：

```json
{
  "data": [{ "id": "rel_xxx", "userId": "...", "fromKind": "workflow", "fromId": "wf_x", "toKind": "function", "toId": "fn_y", "kind": "workflow_uses_function", "attrs": {"nodeIds":["n_1","n_5"]}, "createdAt": "...", "updatedAt": "..." }],
  "nextCursor": "...",
  "hasMore": false
}
```

### 9.2 `GET /api/v1/relations/neighborhood?kind=&id=&depth=` —— 2-hop 邻域

**参数**：
- `kind`, `id`: 中心实体
- `depth`: 1 / 2 / 3 跳（默认 2，最大 3）

**返回**：邻域内所有边（同 9.1 shape）；BFS from↔to 方向交替走。

### 9.3 `GET /api/v1/relgraph` —— 洞察 tab 全图快照

**节点过滤规则**：

| 实体类型 | 进图条件 |
|---|---|
| function / handler / workflow / document / skill / mcp | 全部（含孤儿） |
| **conversation** | **仅当有边连着**（孤儿对话不入图，避免 chat 历史污染） |

**边**：全部 8 种 kind 的所有边。

**返回**：

```json
{
  "data": {
    "nodes": [{"kind": "workflow", "id": "wf_x", "label": "weekly summary", "sub": "..."}],
    "edges": [...]
  }
}
```

**无分页，无上限**。

### 9.4 不做的端点

| 不做 | 理由 |
|---|---|
| `POST/PATCH/DELETE /relations` | 用户不能直接造边 |
| `POST /relations:reconcile` | sync 同事务必成功，drift 不存在 |
| `GET /relations/{id}` | 单边详情无用例 |
| `GET /documents/{id}/backlinks` | 用 `?toKind=document&toId=X&kind=document_links_entity` |
| `GET /relations/stats` | 用量统计前端 client-side 算 |
| SSE 边流 | 前端打开图时主动 GET |

---

## 10. 错误码（4 sentinel，登记 errmap §S17）

| sentinel | HTTP | code | 触发 |
|---|---|---|---|
| `ErrInvalidEntityRef` | 400 | `INVALID_ENTITY_REF` | fromKind / toKind 不是合法 entity kind |
| `ErrInvalidKind` | 400 | `INVALID_RELATION_KIND` | kind 不在 8 种枚举里 |
| `ErrDepthOutOfRange` | 400 | `DEPTH_OUT_OF_RANGE` | neighborhood depth < 1 或 > 3 |
| `ErrIncompleteFilter` | 400 | `INCOMPLETE_FILTER` | 给了 fromKind 没给 fromId（或反之） |

注：**无 NotFound 端点**——过滤无结果返空 data + hasMore=false，不是 404。

---

## 11. 测试覆盖（§T 系列）

### 11.1 各层

| 层 | 文件 | 重点 |
|---|---|---|
| domain | `domain/relation/relation_test.go` | kind 枚举、attrs schema、equality |
| store | `infra/store/relation/store_test.go` | CRUD、diff-sync、cascade、no-self-loop trigger（§T2 in-mem SQLite） |
| app | `app/relation/service_test.go` | SyncOutgoing diff、SyncIncoming "至多 1 边"、PurgeEntity cascade |
| wikilink | `pkg/wikilink/wikilink_test.go` | regex、prefix 路由、dedup count |
| transport | `transport/httpapi/handlers/relation_test.go` | envelope、过滤组合、分页、错误码 |
| pipeline | `test/relation_pipeline_test.go` | 端到端真 SQLite 真 HTTP（§T5 强制） |

### 11.2 必覆盖 10 条边界 case（§T1 命名）

1. `TestSyncIncoming_SuppressWhenEditorEqualsOrigin` —— editor==origin 时不写 edited 边
2. `TestSetActiveVersion_RevertRewritesEditedEdge` —— revert 时 edited 边重指向
3. `TestPurgeEntity_CascadesAllDirections` —— 删 conv，所有 from=cv 和 to=cv 的边清空
4. `TestSyncOutgoing_IdempotentOnIdenticalInput` —— 同 edges 调两次，第二次 0 DB write
5. `TestNoSelfLoopTrigger_RejectsInsert` —— INSERT 自环边 trigger 拒绝
6. `TestWikilinkParser_DropsUnknownPrefix` —— `[[xyz_abc]]` 解析后丢弃
7. `TestSyncOutgoing_DropsDanglingTarget` —— 写 edge 时 target 不存在 → silent drop
8. `TestWorkflowUses_AggregatesNodeIds` —— 多 node 引用同实体 → 单边 + nodeIds=list
9. `TestNeighborhood_RespectsDepthLimit` —— depth=2 时不返 3-hop 边
10. `TestRelgraph_OmitsOrphanConversations` —— 没边的 conv 不进 nodes

### 11.3 Pipeline test（§T5 强制）

`backend/test/relation_pipeline_test.go::TestRelationPipeline_FullLifecycle` 走 §2.1 → 2.6 全链：create_forge → edit_forge → workflow accept → doc wikilink → 软删 → relgraph 验证。每次 `harness.New(t)` 全新 in-mem SQLite，幂等。

---

## 12. 实施顺序（5 个 Phase，~3.5 天，单 PR）

| Phase | 范围 | 完工标志 | 预估 |
|---|---|---|---|
| **R1** | Domain struct + Store + Schema + 3 张 version 表加 `forged_in_conversation_id` | AutoMigrate / CRUD smoke / 索引就位 | 1d |
| **R2** | App service（SyncOutgoing/Incoming/PurgeEntity/读路径） + wikilink parser + idgen prefix 表 | diff-sync 算法测试绿、wikilink unit 全绿 | 0.5d |
| **R3** | 18 个 source-domain hook + tool/forge ctx 注入 | 各 domain 现有测试 + 新加 relations assertions 全绿 | 1d |
| **R4** | 3 HTTP 端点 + handler + 4 sentinel 进 errmap | curl smoke + handler tests 绿 | 0.5d |
| **R5** | §S14 文档同步 + pipeline test | `make test-pipeline` 全绿、文档 checklist 全打勾 | 0.5d |

**单 PR 全做完**：relations 是 cohesive domain，分 PR 文档同步压力大。

---

## 13. §S14 文档同步检查表

实施时按 phase 同步，**不能积压**。

| 文件 | 改什么 | Phase |
|---|---|---|
| `service-design-documents/relation.md`（本文件） | 落地后据实更新 | R1 起持续 |
| `service-design-documents/function.md` `handler.md` `workflow.md` | + 一节 "relations integration"（hook 在哪几个 method 调）+ `forged_in_conversation_id` 字段说明 | R3 |
| `service-design-documents/document.md` `conversation.md` `mcp.md` `skill.md` | + 一节 "relations integration"（hook 列表） | R3 |
| `service-contract-documents/api-design.md` | + relations 一节，3 端点 | R4 |
| `service-contract-documents/database-design.md` | + `relations` 表行 + 3 张 version 表新列行 | R1 |
| `service-contract-documents/error-codes.md` | + 4 sentinel | R4 |
| `service-contract-documents/events-design.md` | 不动（不广播） | — |
| `progress-record.md` | `[feat]` dev log | R5 |
| `CLAUDE.md §S15` | + `rel_` → relation prefix | R1 |
| `backend-design.md` | + relation domain 加入 architecture 树 | R5 |

---

## 14. 风险 / Gotchas

| 风险 | 缓解 |
|---|---|
| AutoMigrate 在 modernc.org/sqlite 上 ALTER TABLE ADD COLUMN nullable | 已验证兼容 |
| SyncOutgoing 每条 edge 写前 verify target 存在 → N 次 SELECT | batch SELECT WHERE id IN (...) 一次性查 |
| `forged_in_conversation_id` 透传链 | 经 `reqctxpkg.SetConversationID` 走 ctx（chat 流程已有此 ctx） |
| workflow active_version_id 不变但 graph 内容变 | 不存在——version graph frozen，accept 时冻结 |
| Pipeline test 跨域 hook 时序 race | in-mem SQLite + 同步调用无并发 |
| 巨型 markdown body 解析性能 | 5MB body regex 跑 < 100ms，无优化需要 |

---

## 15. UX 备注（前端实现时务必注意）

| 项 | 备注 |
|---|---|
| **Wikilink 编辑 UX** | 后端只认 `[[<id>]]` 16-hex prefix-ID 形式。前端编辑器**必须**有 `@` picker 自动注入 ID，用户绝不应手输 ID |
| **手工 UI 编辑不入图** | edited 边只表达"AI 在某对话里改的"；手工 PATCH 不更新此边。详情页可单独显示"上次手工修改时间"，但不在 relgraph 里画 |
| **Forge merged into forged**（origin==editor） | UI 文案："created and last edited in cv_a"；不画两条边 |
| **Pinned rejected version 警告** | 是 workflow capability check 的事，不在 relations 范围；前端可根据 attrs.pinnedVersionId 状态显示警告徽章 |
| **删除被引用实体前先警告** | 用户按 "Delete function fn_x" 之前，前端应先 `GET /relations?toKind=function&toId=fn_x` 查在用方。若有 workflow 引用，弹确认框列出："这个函数还被 N 个 workflow 用，删除后这些 workflow 下次跑会失败"。同样适用于 handler / mcp / skill / document。后端 relations 不阻止删除，前端 UX 负责劝阻 |

---

## 16. 不在 V1 范围

- 多版本并行 deployed
- relations 边变更 SSE 广播
- reconcile / rebuild 兜底端点
- 用量统计聚合端点（前端 client-side 算）
- 跨用户多租户隔离逻辑（V1 单用户本地）
- 大数据量分页 / 上限（V1 无限制）
- Wikilink 链 skill/mcp（待 `[[@skill:name]]` 语法扩展）

---

## 17. 关键不变量（契约测试断言）

代码改动若动到以下任何一条都要回头看测试是否仍覆盖：

1. **8 种 kind 枚举闭合**：DB CHECK 约束 + domain 包常量 + GORM tag 三处必须一致；新加 kind 三处一起改
2. **每对 (from, to, kind) 至多 1 行**：DB UNIQUE 强制；SyncOutgoing/Incoming 内 UPSERT 必须用此 unique 做冲突解决
3. **同 trinity 实体至多 1 条 forged + 1 条 edited**：SyncIncoming 调用方必须保证此约束（service 层 validation）
4. **editor==origin suppress**：SyncIncoming 入参为 empty edges 时表达"删除入向边"——`conversation_edited_entity` kindScope 路径必须正确处理 empty
5. **自环禁止**：DB trigger 拒；service 层也加 sanity check 防 invalid input
6. **prod-only**：SyncOutgoing / SyncIncoming 给 trinity（function/handler/workflow）算边的输入必须基于 `ActiveVersionID` 指向那一 version，不能是任意 version。三个 trinity 类型在这一点上**完全对称**——`ActiveVersionID` 是 latest/prod/current 的唯一事实源
7. **Cascade 同事务**：PurgeEntity 和 source 域 soft-delete 必须同事务，失败回滚 entity 删除
8. **手工编辑不入边**：functionapp / handlerapp / workflowapp 的 UpdateMeta / PATCH 类操作**不调** SyncIncoming
9. **v1 auto-accept 写 forged 边**：trinity Create 服务必须在 v1 status flip accepted（ActiveVersionID 置位）后立即调 SyncIncoming，不能延后
10. **document_links_entity 解析时机**：document Update 必须在 body 字段确实变化时才重 sync（dirty check 防无意义写）
