# Document — Notion-style 树状文档库

**Phase**：Phase 5（V1.2 后端阶段最后一块愿景核心）
**状态**：📐 设计期（等用户过审 → 开工）
**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../final-sweep.md`](../final-sweep.md) §14 — 5 子项实施清单 + 2026-05-16 设计改向史（弃 RAG / 弃 flat-with-sections）
- [`../service-contract-documents/api-design.md`](../service-contract-documents/api-design.md) — 7 端点索引
- [`../service-contract-documents/database-design.md`](../service-contract-documents/database-design.md) — `documents` 表
- [`../service-contract-documents/error-codes.md`](../service-contract-documents/error-codes.md) — 4 sentinel
- [`./catalog.md`](./catalog.md) — 第 4 source 接入
- [`./workflow.md`](./workflow.md) — LLM 节点 `AttachedDocumentIds` 字段
- [`./chat.md`](./chat.md) — Conversation `AttachedDocumentIDs` 字段
- [`./permissions.md`](./permissions.md) — `delete_document` tool `destructive=true` 走 ask 路径

---

## 1. 一句话

**Notion-style 树状文档库**：单表 `Document` 自引用形成层级（项目 → 子项目 → 文档 → 子文档），全 markdown 内容，AI 经 7 个 system tool 读 + 组织（search / list / read / create / edit / move / delete）。挂在 workflow LLM 节点或 conversation 上作为持久知识 context。**无 RAG / 无 chunking / 无向量库**——详 final-sweep §14 设计改向。

---

## 2. 端到端推演（设计原则 #5）

### 2.1 用户主动建文档

```
User 在 testend 侧边栏点根级 [+]
  → POST /api/v1/documents { name: "Project Alpha", parentId: null }
  → documentapp.Service.Create
      → validate（name 非空 / parent 存在或 nil / content ≤ 1 MB / 同父下 name 不冲突）
      → documentdomain.Repository.Insert（含 sizeBytes 计算）
      → Service.recomputePath（root → "/Project Alpha"）
      → notifications.Publish("document", { action: "created", id, parentId })
  → 201 envelope { data: { id, path: "/Project Alpha", ... } }
  → testend 侧边栏插入新节点；catalog 收 invalidate hook → 下次 polling 重生成 summary
```

### 2.2 AI 帮组织文档

```
LLM 看到 catalog summary 里几篇 doc 散在 root，决定整理
  → tool_use: create_document({ name: "Notes", description: "All my notes" })
      → doc_001 created at root
  → tool_use: move_document({ id: "doc_xyz", parentId: "doc_001" })
      → Service.Move
          → validate IsAncestor（防成环）
          → Update parent_id + position
          → RecomputePathSubtree（级联整子树 path 字段）
          → notifications.Publish("document", { action: "moved", id, parentId })
  → 每次 tool call 触发 notification → testend 侧边栏实时刷新树
```

### 2.3 工作流挂文档

```
Workflow llm 节点 config: { prompt: "总结要点", attachedDocumentIds: ["doc_xyz"] }
  → scheduler 跑节点
  → dispatch_llm.go 跑前：
      → documentapp.GetBatch(ctx, ["doc_xyz"]) → 拿 content + path
      → 拼 prefix = "<documents>\n<document path=\"/Project Alpha/API spec\">\n{content}\n</document>\n</documents>\n\n"
      → fullPrompt = prefix + cfg.Prompt
      → 调 LLM
  → 输出回流下游节点
```

### 2.4 对话挂文档

```
User 在 testend 对话视图右侧"挂载文档"折叠面板勾选 "API spec"
  → PATCH /api/v1/conversations/{id} { attachedDocumentIds: ["doc_xyz"] }
  → 下一条 message 发送时：
      → runner.buildSystemPrompt 看到 conv.AttachedDocumentIDs 非空
      → documentapp.GetBatch(ctx, [...ids]) 拿全 content
      → 拼 system prompt（静态段 cache-friendly）：
        [STATIC]
          - Base prompt
          - Tool defs（含 7 个 document tool）
          - Catalog summary（含 documents source）
          - Pinned memories
          - Memory index
          ─── Attached documents ─── ← 新
          <documents>
            <document path="/Project Alpha/API spec">{full content}</document>
          </documents>
        [DYNAMIC]
          - locale / now / task budget
        [CONV OVERRIDE]
          - conversation.SystemPrompt
```

### 2.5 跨 domain 依赖

| 上游 | 下游 | 调用 |
|---|---|---|
| `chat/runner` | `documentapp.Service` | `GetBatch(ids)` 拼 `<documents>` 段 |
| `workflow/dispatcher/dispatch_llm` | `documentapp.Service` | 同上 |
| `workflow/validate` | `documentapp.Service` | `GetBatch(ids)` 校验 attached docs 全存在 |
| `catalog/Service` | `documentapp.AsCatalogSource()` | 注入 4 source 之一 |
| `documentapp.Service` | `notifications.Bridge` | Create/Edit/Move/Delete publish |

---

## 3. 设计原则

| 原则 | 落地 |
|---|---|
| **抄 Notion 数据模型** | 单 Document = 一个 page，page 之间靠 ParentID 形成树，全 markdown |
| **AI 能组织不止读** | 7 system tool 含 create / move / delete，让 AI 真能帮用户整理文档库 |
| **不引向量库** | LLM 排序 + catalog 套路（同 forge / skill / mcp）；详 final-sweep §14 |
| **挂在 LLM 节点 / 对话上** | 不新增 workflow 节点类型；用现有 llm 节点 config 字段 + Conversation 字段，cache-friendly |
| **Path 冗余字段** | 每次 Save 回填 path（如 `/Projects/2026/Q1`），catalog / UI 无需 N 层 JOIN |
| **递归软删** | 删父 → 子树全部 deleted_at 标；展现层 query 已经过滤；Restore 不在 V1 |
| **拒绝成环** | Move 校验：parent 不能是 self 也不能是 self 的后裔（DFS 检查） |
| **destructive delete** | `delete_document` tool 自动标 destructive=true → §3 permissions ask 路径 |
| **1 MB 单文档上限** | 超过应该拆子文档；硬上限避免巨型 doc 撑爆 prompt cache |

---

## 4. Domain model

```go
package document

type Document struct {
    ID          string     `gorm:"primaryKey"`              // doc_<16hex>
    UserID      string     `gorm:"index;not null"`          // 多租户预留（V1 = local-user）
    ParentID    *string    `gorm:"index"`                   // 自引用；nil = root
    Name        string     `gorm:"not null"`                // 标题
    Description string     // 一行摘要给 catalog / LLM 看
    Content     string     `gorm:"type:text"`               // markdown body
    Tags        []string   `gorm:"serializer:json"`         // 用户标
    Position    int        // 同级排序（拖拽改）
    Path        string     `gorm:"index"`                   // 冗余：/Projects/2026/Q1
    SizeBytes   int64
    CreatedAt   time.Time
    UpdatedAt   time.Time
    DeletedAt   *time.Time `gorm:"index"`
}

// Repository
type Repository interface {
    Insert(ctx context.Context, d *Document) error
    Get(ctx context.Context, id string) (*Document, error)
    GetBatch(ctx context.Context, ids []string) ([]*Document, error)
    ListByParent(ctx context.Context, userID string, parentID *string) ([]*Document, error)
    ListAll(ctx context.Context, userID string) ([]*Document, error)              // 整树拉给 testend / catalog
    Search(ctx context.Context, userID string, query string) ([]*Document, error) // V1 LIKE name + description
    Update(ctx context.Context, d *Document) error
    SoftDeleteSubtree(ctx context.Context, id string) error                       // 事务递归
    IsAncestor(ctx context.Context, candidateAncestorID, descendantID string) (bool, error)
    CountDescendants(ctx context.Context, id string) (int64, error)               // 删确认用
    UpdatePathSubtree(ctx context.Context, root *Document) error                  // Move 后级联
}

// Sentinels
var (
    ErrDocumentNotFound = errors.New("document not found")
    ErrInvalidParent    = errors.New("invalid parent (cycle or self)")
    ErrNameConflict     = errors.New("document name already exists under same parent")
    ErrContentTooLarge  = errors.New("document content exceeds 1 MB")
)

// Constants
const MaxContentBytes = 1 << 20 // 1 MB
```

---

## 5. DB schema + 索引

```sql
CREATE TABLE documents (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  parent_id     TEXT,
  name          TEXT NOT NULL,
  description   TEXT NOT NULL DEFAULT '',
  content       TEXT NOT NULL DEFAULT '',
  tags          TEXT NOT NULL DEFAULT '[]',  -- JSON array
  position      INTEGER NOT NULL DEFAULT 0,
  path          TEXT NOT NULL,
  size_bytes    INTEGER NOT NULL,
  created_at    DATETIME NOT NULL,
  updated_at    DATETIME NOT NULL,
  deleted_at    DATETIME
);

-- GORM tag 自动建：
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_parent_id ON documents(parent_id);
CREATE INDEX idx_documents_path ON documents(path);
CREATE INDEX idx_documents_deleted_at ON documents(deleted_at);

-- schema_extras（per §D7，partial UNIQUE 走 schema_extras）：
CREATE UNIQUE INDEX IF NOT EXISTS uniq_documents_parent_name
  ON documents(user_id, parent_id, name)
  WHERE deleted_at IS NULL;
```

**约束说明**：
- `parent_id` 没声明 FK（per §D4，V1 暂不在 GORM 声明 foreignKey）；环检测 + 删除递归在 app 层 Service 强制
- `UNIQUE(user_id, parent_id, name) WHERE deleted_at IS NULL`：同父下同名拒绝；软删的不算冲突
- `path` 索引：catalog generator + testend 树视图 query 按 path 排序时用
- `content` 用 `TEXT` 类型，SQLite 中等同 BLOB——modernc 默认 UTF-8 处理

---

## 6. System tools（7 个）

每个 tool 实现 §S18 完整 Tool 接口 9 方法（Identity 3 + 静态元数据 3 + 钩子 2 + Execute 1）+ permissionsgate `toolLevels` 静态登记。

文件布局（per §S12 例外 tool 嵌套子包）：

```
internal/app/tool/document/
├── document.go      ← DocumentTools() 工厂 + 共享 helper
├── search.go        ← SearchDocuments
├── list.go          ← ListDocuments
├── read.go          ← ReadDocument
├── create.go        ← CreateDocument
├── edit.go          ← EditDocument
├── move.go          ← MoveDocument
└── delete.go        ← DeleteDocument
```

### 6.1 `search_documents`（ReadOnly）

LLM-ranked 模式，抄 search_forge 套路：

```json
{
  "type": "object",
  "properties": {
    "query": { "type": "string", "description": "Search query (matches name/description/tags)" },
    "limit": { "type": "integer", "default": 10, "maximum": 50 }
  },
  "required": ["query"]
}
```

实现：Service 把全部 docs 的 `{id, name, description, path, tags}` 发给 LLM，让它排序选 top N。返回：

```json
{
  "documents": [
    { "id": "doc_xyz", "name": "API spec", "description": "...", "path": "/Projects/Alpha/API spec", "childCount": 3 }
  ]
}
```

### 6.2 `list_documents`（ReadOnly）

列指定层（不传 = root），无 LLM 排序，纯按 position ASC：

```json
{
  "type": "object",
  "properties": {
    "parentId": { "type": ["string", "null"], "description": "Parent doc ID; null/omit = root level" }
  }
}
```

返回同 search 但纯 SQL 拉。

### 6.3 `read_document`（ReadOnly）

```json
{ "type": "object", "properties": { "id": { "type": "string" } }, "required": ["id"] }
```

返回：

```json
{
  "id": "doc_xyz",
  "name": "API spec",
  "path": "/Projects/Alpha/API spec",
  "description": "...",
  "content": "# API spec\n\n...",
  "tags": ["api", "spec"],
  "childCount": 0
}
```

### 6.4 `create_document`（WorkspaceWrite）

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "parentId": { "type": ["string", "null"] },
    "content": { "type": "string", "default": "" },
    "description": { "type": "string", "default": "" },
    "tags": { "type": "array", "items": { "type": "string" } }
  },
  "required": ["name"]
}
```

validate：同 parent 下 name 不冲突；content ≤ 1 MB；parent 存在或 nil。返回新 doc 全字段。

### 6.5 `edit_document`（WorkspaceWrite）

```json
{
  "type": "object",
  "properties": {
    "id": { "type": "string" },
    "name": { "type": "string" },
    "content": { "type": "string" },
    "description": { "type": "string" },
    "tags": { "type": "array", "items": { "type": "string" } }
  },
  "required": ["id"]
}
```

**非全量 replace** — 只 update 提供的字段。改 name 触发 path 重算 + 子树 path 级联。

### 6.6 `move_document`（WorkspaceWrite）

```json
{
  "type": "object",
  "properties": {
    "id": { "type": "string" },
    "parentId": { "type": ["string", "null"], "description": "null = move to root" },
    "position": { "type": "integer", "minimum": 0 }
  },
  "required": ["id"]
}
```

实现：validate 成环 → Update parent_id + position → RecomputePathSubtree。position 不传则放在新 parent 最末。

### 6.7 `delete_document`（WorkspaceWrite, destructive=true）

```json
{ "type": "object", "properties": { "id": { "type": "string" } }, "required": ["id"] }
```

**destructive=true** 让 §3 permissions 自动走 ask 路径——LLM 调时强制问用户。返回：

```json
{ "id": "doc_xyz", "deletedCount": 4 }
```

`deletedCount` 含子树多少个一起软删了。

---

## 7. HTTP API

| Method | Path | 用途 | 状态码 |
|---|---|---|---|
| GET | `/api/v1/documents?parentId=` | 列指定层（不传 = root），轻字段不含 content | 200 |
| GET | `/api/v1/documents/tree` | 整树 metadata（含 path，不含 content）；前端侧边栏一次拉满 | 200 |
| POST | `/api/v1/documents` | 创建 | 201 |
| GET | `/api/v1/documents/{id}` | 详情含 content | 200 / 404 |
| PATCH | `/api/v1/documents/{id}` | 改 name / description / content / tags | 200 / 404 / 422 |
| DELETE | `/api/v1/documents/{id}` | 软删（递归） | 204 / 404 |
| POST | `/api/v1/documents/{id}:move` | 改 parentId + position | 200 / 404 / 422 |

路由实现：handler `Register` 用 `strings.Cut(":")` 拆 `{idAction}` mux（同 apikey / function / handler 套路）。

errmap 4 sentinel 登记到 `transport/httpapi/response/errmap.go::errTable`（per §S17）：

| Sentinel | HTTP | code |
|---|---|---|
| `ErrDocumentNotFound` | 404 | `DOCUMENT_NOT_FOUND` |
| `ErrInvalidParent` | 422 | `DOCUMENT_INVALID_PARENT` |
| `ErrNameConflict` | 409 | `DOCUMENT_NAME_CONFLICT` |
| `ErrContentTooLarge` | 422 | `DOCUMENT_CONTENT_TOO_LARGE` |

---

## 8. Catalog 接入

`documentapp.AsCatalogSource()` 返回 `catalogdomain.CatalogSource` 接口实现：

```go
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
    return &catalogSource{svc: s}
}

func (cs *catalogSource) Name() string                  { return "documents" }
func (cs *catalogSource) Granularity() catalogdomain.Granularity { return catalogdomain.PerItem }
func (cs *catalogSource) List(ctx context.Context) ([]catalogdomain.Item, error) {
    docs, err := cs.svc.ListAll(ctx)
    if err != nil { return nil, err }
    items := make([]catalogdomain.Item, len(docs))
    for i, d := range docs {
        items[i] = catalogdomain.Item{
            ID:          d.ID,
            Name:        d.Name,
            Description: d.Description,
            Tags:        d.Tags,
            Path:        d.Path, // catalog 看 path 决定 group
        }
    }
    return items, nil
}
```

Generator LLM 看到 documents source 后生成 catalog summary：

```markdown
## Documents

可用文档：
- /Projects/Alpha — Alpha 项目根目录
- /Projects/Alpha/API-spec — Alpha 项目 API 接口规范
- /Projects/Alpha/architecture — 架构图与说明
- /Projects/Beta — Beta 项目根
- /Notes/daily/2026-05-15 — 5/15 日报
- /Notes/daily/2026-05-16 — 5/16 日报
...（共 12 篇）

调 `search_documents(query=...)` 或 `list_documents(parentId=...)` 进一步浏览；用 `read_document(id)` 看正文。
```

超阈值（>50 docs）progressive disclosure：

```markdown
## Documents

可用文档（共 87 篇，按 path 分组）：
- /Projects（23 篇）
- /Notes/daily（45 篇）
- /API-Reference（11 篇）
- /Misc（8 篇）

调 `list_documents(parentId='...')` 查指定层；`search_documents(query='...')` 全局搜。
```

Refresh 触发：`documentapp` 在 Create / Edit / Move / Delete 后 `notifications.Publish("document", {action})`，catalog Service 收到 → invalidate cache → 下一次 polling cycle 重新 generate（已有 1s polling 路径，加 invalidate hook）。

---

## 9. Workflow 接入（两种节点 — `llm` 挂知识库 + `agent` 干活）

Workflow 跟 document 的接触面有**两种 LLM 节点**，分别覆盖"读 doc 当上下文"和"用 doc tools 操作 doc"两个独立场景：

| 节点 | 比喻 | LLM call 数 | tool 访问 | 典型用途 |
|---|---|---|---|---|
| **`llm`**（现有，扩展）| LLM + 挂知识库 | 1 次（确定）| 无 | 总结 / 改写 / 翻译 / 给附带 doc 的内容做单次回答 |
| **`agent`**（**新增 14th 节点类型**）| 派个 agent 干活 | 1-N 次（取决于 tool 调用次数）| 全套 system tools（含 7 个 document tool + filesystem + bash + web + MCP + skill + ...）| 多步任务："读 doc X、研究 GitHub issue、把发现写到 doc Y" |

理由两种分开（不合一）：**成本可见性**——`llm` ≈ $0.001-0.01 / 节点；`agent` ≈ $0.01-0.10+ / 节点（多 turn）。在节点类型上区分让 workflow author 拼图时一眼算钱。dispatcher 80% 共享代码（dispatch_agent.go 抄 chat runner），ROI 高。

### 9.1 共用：`AttachedDocuments` schema

两种节点都用同一 attach schema（live-resolve subtree）：

```go
// 节点 config 共用字段
type AttachedDocument struct {
    DocumentID     string `json:"documentId"`
    IncludeSubtree bool   `json:"includeSubtree,omitempty"` // default false = 只此篇
}

type LLMNodeConfig struct {
    Prompt            string              `json:"prompt"`
    Model             string              `json:"model,omitempty"`
    AttachedDocuments []AttachedDocument  `json:"attachedDocuments,omitempty"`
}

type AgentNodeConfig struct {
    Prompt            string              `json:"prompt"`
    Model             string              `json:"model,omitempty"`
    AttachedDocuments []AttachedDocument  `json:"attachedDocuments,omitempty"`
    EnabledTools      []string            `json:"enabledTools,omitempty"` // V1.1 留作 whitelist；V1 全注入
    MaxTurns          int                 `json:"maxTurns,omitempty"`     // 默认 10
}
```

**live-resolve subtree** 含义：保存的不是展开后的 ID list，而是"我要这棵树"的意图。dispatch 时 backend 现展开成最新后裔。用户之后往 `/Notes/daily/` 加新日报自动跟上，不用回头编辑 workflow。

Resolver（共用 `documentapp.ResolveAttached`）：

```go
func (s *Service) ResolveAttached(ctx context.Context, atts []AttachedDocument) ([]*Document, error) {
    seen := map[string]bool{}
    var ids []string
    for _, a := range atts {
        if a.IncludeSubtree {
            sub, err := s.repo.ListSubtreeIDs(ctx, userID, a.DocumentID)
            if err != nil { return nil, err }
            for _, id := range sub {
                if !seen[id] { seen[id] = true; ids = append(ids, id) }
            }
        } else {
            if !seen[a.DocumentID] { seen[a.DocumentID] = true; ids = append(ids, a.DocumentID) }
        }
    }
    return s.repo.GetBatch(ctx, userID, ids)
}
```

Repository 加 public method `ListSubtreeIDs(ctx, userID, rootID) ([]string, error)`——expose 已有的私有 `collectDescendantIDs`，多一个公共接口。

### 9.2 `llm` 节点（dispatch_llm.go）— **单次 + 读 doc**

```go
func (d *LLMDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
    cfg := parseLLMConfig(in.Node.Config)
    docPrefix, err := buildDocsPrefix(ctx, d.documentSvc, cfg.AttachedDocuments)
    if err != nil {
        return DispatchOutput{Error: err}
    }
    fullPrompt := docPrefix + cfg.Prompt
    out, err := d.caller.Generate(ctx, cfg.Scenario, fullPrompt, in.ExecCtx.Variables)
    // ...
}

func buildDocsPrefix(ctx context.Context, svc *documentapp.Service, atts []AttachedDocument) (string, error) {
    if len(atts) == 0 { return "", nil }
    docs, err := svc.ResolveAttached(ctx, atts)
    if err != nil { return "", err }
    var sb strings.Builder
    sb.WriteString("<documents>\n")
    for _, doc := range docs {
        fmt.Fprintf(&sb, "<document path=%q>\n%s\n</document>\n", doc.Path, doc.Content)
    }
    sb.WriteString("</documents>\n\n")
    return sb.String(), nil
}
```

**保持 single-shot 语义**——`llm` 节点跟现状一致，只是 prompt 前多了 `<documents>` 段。没 tool registry，无法 mutate doc。

### 9.3 `agent` 节点（dispatch_agent.go）— **agentic loop + 完整 tools**

```go
type AgentDispatcher struct {
    loopHost      app.LoopHost
    documentSvc   *documentapp.Service
    toolRegistry  []toolapp.Tool   // 全套 system tools（含 7 个 document tool）
}

func (d *AgentDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
    cfg := parseAgentConfig(in.Node.Config)
    docPrefix, _ := buildDocsPrefix(ctx, d.documentSvc, cfg.AttachedDocuments)

    // 跟 chat runner 同一套 app/loop.Run, 但入口是 workflow 节点而非用户消息
    host := &agentHost{
        prompt:    docPrefix + cfg.Prompt,
        tools:     filterTools(d.toolRegistry, cfg.EnabledTools), // V1 全注入,V1.1 加 whitelist
        maxTurns:  defaultMaxTurns(cfg.MaxTurns),
        variables: in.ExecCtx.Variables,
    }
    result, err := app.LoopRun(ctx, host)
    // ...
    return DispatchOutput{Outputs: map[string]any{
        "out":          result.FinalText,
        "toolCalls":    result.ToolCallCount,
        "turns":        result.Turns,
    }}
}
```

**关键属性**：
- 全套 system tools 注入——`agent` 节点能调 7 个 doc tool + filesystem + bash + web + MCP + skill 等所有系统工具
- multi-turn 至 `maxTurns`（默认 10）然后 hard stop
- ` filterTools(allowList=cfg.EnabledTools)`：V1 cfg.EnabledTools 留空 → 全注入；V1.1 想 scope 时 author 填白名单
- 输出 `{out, toolCalls, turns}` 给下游节点用——`toolCalls` 让作者 audit AI 是否"应该"调了工具

### 9.4 Validation

`workflow.validate.go` 加两条 capability check：

1. **`llm` 节点的 AttachedDocuments**：每个 `documentId` 必须存在；任一不存在 → 422 `WORKFLOW_DOCUMENT_NOT_FOUND`
2. **`agent` 节点同样**——同上 check + warn maxTurns > 30 提示用户

跨域错误翻译：`documentdomain.ErrNotFound` 在 workflow.validate.go 翻为 `workflowdomain.ErrDocumentNotFound`（接 `WORKFLOW_DOCUMENT_NOT_FOUND` 422）。

### 9.5 13 → 14 NodeType

新增 `agent` 进 workflow.NodeType 枚举；dispatcher 注册到 scheduler.Router；workflow.md NodeType 表加一行；schema CHECK 约束加 `'agent'`。

---

## 10. Conversation 接入

Conversation entity 加字段（schema 跟 workflow `llm` / `agent` 节点完全一致 — 复用 `AttachedDocument` struct + `documentapp.ResolveAttached`）：

```go
type Conversation struct {
    // ... 现有字段
    AttachedDocuments []AttachedDocument `gorm:"serializer:json" json:"attachedDocuments,omitempty"`
}
```

PATCH `/api/v1/conversations/{id}` 可改 `attachedDocuments`；验证每个 `documentId` 存在（任一不在 → 422 `CONVERSATION_DOCUMENT_NOT_FOUND`）。**`includeSubtree`** 让用户挂载"整个 Notebook"（项目根+所有子文档），跨对话稳定跟着文档树变化 live-resolve。

`chat/runner.buildSystemPrompt` 看到 `conv.AttachedDocuments` 非空就调 `documentapp.ResolveAttached`（live-resolve subtree）→ prepend `<documents>` 段（跟 memory pinned 同一 cache-friendly 静态层）：

```
[STATIC]
  - Base prompt
  - Tool defs（含 7 个 document tool）
  - Catalog summary（含 documents source）
  ─── Pinned memories ───
  - ...
  ─── Memory index ───
  - ...
  ─── Attached documents ─── ← 新
  <documents>
    <document path="/Projects/Alpha/API-spec">{content}</document>
    ...
  </documents>
[DYNAMIC]
  - locale / now / ...
[CONV OVERRIDE]
  - conversation.SystemPrompt
```

**为什么放静态段而非动态段**：attached docs 在对话期间稳定（用户不会每轮换），跟 pinned memories 是同一性质。prompt cache TTL 5 分钟内重复 turn 命中。

---

## 11. Path 计算 / 树操作语义

### 11.1 Path 回填

每次 Insert / Update name / Move 时，Service.recomputePath(d) 计算：

```go
func (s *Service) recomputePath(ctx context.Context, d *documentdomain.Document) error {
    if d.ParentID == nil {
        d.Path = "/" + d.Name
        return nil
    }
    parent, err := s.repo.Get(ctx, *d.ParentID)
    if err != nil {
        return err
    }
    d.Path = parent.Path + "/" + d.Name
    return nil
}
```

Move / rename 时还要级联整子树：`Repository.UpdatePathSubtree(root)`：

```go
// 实现思路（Go 层）：
// 1. 拉子树（DFS，按 parent_id 链）所有 nodes
// 2. 拓扑排序（root 在前）
// 3. for each n in topo order:
//      n.Path = parent.Path + "/" + n.Name
//      batch update
```

SQLite 用 CTE 递归更新写起来复杂，先 Go 层 + 事务包裹处理。子树 N <= 几百时性能够用。

### 11.2 防成环

`Move(id, newParentID)` 校验：

1. `newParentID == id` → `ErrInvalidParent`
2. `IsAncestor(id, newParentID)` → `ErrInvalidParent`（新父是当前节点的后裔）

`IsAncestor(candidateAncestorID, descendantID)`：从 descendantID 沿 parent_id 链向上爬，撞到 candidateAncestorID 返 true，到 root 返 false。最深 N 跳。

### 11.3 软删递归

`SoftDeleteSubtree(id)`：

```sql
-- 事务包裹：
WITH RECURSIVE subtree AS (
  SELECT id FROM documents WHERE id = ? AND deleted_at IS NULL
  UNION ALL
  SELECT d.id FROM documents d JOIN subtree s ON d.parent_id = s.id
  WHERE d.deleted_at IS NULL
)
UPDATE documents SET deleted_at = ?, updated_at = ?
WHERE id IN (SELECT id FROM subtree);
```

testend 删之前先调 `CountDescendants(id)` 拿数 → confirm "X 个子节点会一起删" → 调 DELETE。

### 11.4 Position

同级 sibling 用 INTEGER position。插入到第 K 位时简单做法：renumber 全部 siblings position = 0, 1, 2, ..., N。50 个 sibling 内可接受。撞性能再换 float / gap-based positioning（V1 不做）。

---

## 12. 错误码

| Sentinel | HTTP | code | 用户语义 |
|---|---|---|---|
| `ErrDocumentNotFound` | 404 | `DOCUMENT_NOT_FOUND` | 文档不存在或已删 |
| `ErrInvalidParent` | 422 | `DOCUMENT_INVALID_PARENT` | 父级无效（成环 / 自己当自己父）|
| `ErrNameConflict` | 409 | `DOCUMENT_NAME_CONFLICT` | 同父目录下已有同名文档 |
| `ErrContentTooLarge` | 422 | `DOCUMENT_CONTENT_TOO_LARGE` | 内容超 1 MB（应拆成子文档）|

跨域包装：
- `workflow/validate` 抓 `ErrDocumentNotFound` 翻为 `WORKFLOW_DOCUMENT_NOT_FOUND`（422）
- `conversation/Service.Update` 抓 `ErrDocumentNotFound` 翻为 `CONVERSATION_DOCUMENT_NOT_FOUND`（422）

---

## 13. testend UI sketch

### 13.1 文档库主视图（`/documents` route）

左侧栏（树形）：

```
📁 Workspace
├─ 📄 Project Alpha          [+] [⋯]
│  ├─ 📄 API spec
│  ├─ 📄 Architecture
│  └─ 📄 Tasks
│     ├─ 📄 backlog
│     └─ 📄 done
├─ 📄 API Reference
└─ 📄 Daily notes
   ├─ 📄 2026-05-15
   └─ 📄 2026-05-16
```

每个 doc 行：
- 点 → 右侧打开 markdown 编辑器
- 悬停 → 显示 `[+]`（加子文档）、`[⋯]`（rename / move / delete 菜单）
- 拖拽 → 改 parent / position（实时 PATCH `:move` 端点）

右侧（编辑器）：
- 标题输入 + tags chips
- markdown 编辑器（Monaco 或 CodeMirror，参照 testend 已有的 forge 编辑器）
- 实时保存（debounce 1s 触发 PATCH content）
- 右上 description 输入框（catalog 给 LLM 看的简介）

### 13.2 对话视图侧栏（在原有对话视图右侧加）

"挂载文档" 折叠面板：
- 多选下拉，按 path 显示文档树形选项
- 勾选 / 取消 → PATCH conversation.attachedDocumentIds
- 已挂载的显示为 chip 列表，✕ 按钮快速移除

---

## 14. 实施顺序（5 个 subtask，~4 天总工程量）

| 子任务 | 工时 | 内容 |
|---|---|---|
| **§14.1 domain + store + service + DB** | 1 天 | domain types + 4 sentinel + GORM tag schema + schema_extras partial UNIQUE + Repository impl + Service skeleton（含 recomputePath / IsAncestor / SoftDeleteSubtree）+ 单测全绿 |
| **§14.2 HTTP API + errmap** | 0.5 天 | 7 端点 handler + `{idAction}` mux dispatcher（拆 `:move`）+ errmap 4 条 + curl 冒烟全通 |
| **§14.3 7 system tools** | 1 天 | 7 个 tool 文件 + permissionsgate `toolLevels` 登记 + chat.runner ToolRegistry 注入 + 7 单测 + 1 pipeline test 端到端 |
| **§14.4 Catalog 接入** | 0.5 天 | `documentapp.AsCatalogSource()` + catalog Service register + notification → invalidate hook + generator prompt 加 path 分组指引 + 1 pipeline test |
| **§14.5a `llm` 节点 AttachedDocuments + dispatch_llm prepend** | 0.5 天 | `LLMNodeConfig.AttachedDocuments` schema + Repository.ListSubtreeIDs expose + `documentapp.ResolveAttached`(live-resolve subtree) + dispatch_llm.go buildDocsPrefix + workflow.validate capability check |
| **§14.5b NEW `agent` 节点（14th NodeType）** | 1 天 | domain.NodeType 加 `agent` + `dispatch_agent.go` 用 `app/loop.Run` + 全套 system tool registry 注入(含 7 个 document tool) + AgentNodeConfig (Prompt/AttachedDocuments/EnabledTools/MaxTurns) + scheduler.Router 注册 + 6 单测 + 1 pipeline test (workflow agent 创/编辑 doc 端到端) |
| **§14.5c Conversation.AttachedDocuments + chat prepend** | 0.5 天 | Conversation schema(同 AttachedDocument struct,跟节点共用) + PATCH 校验 + chat runner.buildSystemPrompt 调 ResolveAttached 前置 `<documents>` 段 + cross-domain CONVERSATION_DOCUMENT_NOT_FOUND |
| **§14.5d testend Notion 树 + Monaco + Conv 挂载下拉** | 1.2 天 | 侧边栏树状 UI(拖拽 reorganize + 右键 menu) + Monaco/CodeMirror markdown 编辑器 + 对话视图右侧"挂载文档"面板(subtree toggle + 子节点 preview 灰显 + token 估算) + workflow 节点 attach UI |

---

## 15. 关键不变量（契约测试断言）

| Invariant | 守卫 |
|---|---|
| 同 (user_id, parent_id) 下 name 唯一 | DB UNIQUE 约束 + 422 `ErrNameConflict` |
| ParentID 链不成环 | Service.Move validate + ErrInvalidParent |
| 软删递归：删父 = 删整子树 | `SoftDeleteSubtree` 事务保证；上游 query 必带 `deleted_at IS NULL` 过滤 |
| Path 字段一致 | 始终 = ancestors.name + "/" + self.name 拼接；recompute 在 Insert / Update name / Move 触发 |
| Content ≤ 1 MB | Service validate + 422 `ErrContentTooLarge`；超的应拆子文档 |
| Conversation.AttachedDocuments 全引用存在 | PATCH 时 ResolveAttached(check existence) 校验；任一不存在 → 422 |
| Workflow `llm` / `agent` 节点 AttachedDocuments 全引用存在 | workflow.validate.go capability check；任一不存在 → 422 |
| `AttachedDocument.IncludeSubtree` 是 live-resolve | dispatch / system prompt 拼装时即时 ListSubtreeIDs，不持久化展开后的 ID 数组 |
| `agent` 节点 MaxTurns 上限 | 默认 10；scheduler.dispatch_agent 硬截，避免 LLM loop 跑死 |
| `delete_document` tool 是 destructive | permissionsgate 标 destructive=true；§3 permissions 强制走 ask 路径 |

---

## Relations Integration（2026-05-19）

每个 doc 在 relgraph 中 1 个节点；doc body 中的 `[[<prefix>_<16hex>]]` wikilink 自动派生 `document_links_entity` 边。

| 方法 | 触发的 relation 操作 |
|---|---|
| `Service.Create` | parse body wikilinks → `SyncOutgoing(document, id, [document_links_entity], edges)` 写所有引用边 |
| `Service.Update` | body 实际变化时（dirty check）才重 sync；删除的 wikilink 触发 diff-sync 自动清理对应边 |
| `Service.Delete`（SoftDeleteSubtree） | 收集所有 descendant doc ID，对 root + descendants 逐个 `PurgeEntity("document", x)` 级联清边 |

**Wikilink 解析支持的 5 种 prefix**（per `pkg/idgen/prefix.go`）：`fn_` / `hd_` / `wf_` / `doc_` / `cv_`。skill/mcp 用 name 当主键，不在 wikilink 范围；它们经 `workflow_uses_*` 边入图。

`pkg/wikilink.Parse` 正则匹配 `[[<prefix>_<16hex>]]`；未知 prefix silent drop；同一 ID 多次出现合并 attrs.count。

详 [`./relation.md`](./relation.md) §8 + §4.2。
