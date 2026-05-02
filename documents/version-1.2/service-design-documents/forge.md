# forge domain — 详细设计文档 v3

**所属 Phase**：Phase 3
**状态**：✅ 已实现（2026-04-26 初版；2026-05-02 Phase 3 后优化轮重命名 tool→forge + Tool 接口重构 + 子包重组）
**职责**：管理用户锻造的 Python 工具全生命周期——CRUD、版本历史、pending 变更确认、测试用例、沙箱执行、导入导出；并向 ReAct Agent 提供 5 个 System Tool（search / get / create / edit / run）

**依赖**：
- `infra/db`（GORM + modernc.org/sqlite）
- `infra/sandbox`（Python subprocess 沙箱）
- `infra/llm`（create_forge / edit_forge 内部 LLM 调用 + GenerateTestCases）
- `pkg/reqctx`（userID 读取，agent-run IDs 读取）
- `domain/events`（SSE 事件推送）

**被依赖**：
- `app/tool/forge/`（5 个 system tool 实现的子包，由 app/chat 组装注入 ReAct Agent；`forgetool.ForgeTools()` 工厂返回 `[]toolapp.Tool`）
- Phase 4 workflow 节点

**Tool 接口规约**：所有 5 个 forge system tool 实现 `app/tool.Tool` 接口（10 方法全必填，详见 [`CLAUDE.md §S18`](../../../CLAUDE.md)）。

---

## 1. 核心决策

| 决策 | 选择 | 理由 |
|---|---|---|
| pending 与 version 的关系 | **合并为一张表** `forge_versions`，用 `status` 区分 | pending 和 version 形状完全一样，都是完整工具快照，无需两张表 |
| 版本快照内容 | **完整快照**：name + description + code + parameters + returnSchema + tags | 只存 code 的版本无法完整回滚，也无法看到历史状态 |
| pending 触发条件 | **所有 LLM 发起的变更**（code + 元数据）统一走 pending | 用户直接操作（HTTP PATCH / revert）立即生效，不走 pending |
| 工具搜索 | **LLM 排序**：SearchForge 把全部工具名+描述发给 LLM，LLM 返回按相关度排好的 ID + score 列表 | 比向量搜索准确（LLM 完整理解语义）；工具数量少（20-200），一次 prompt 能全放进去；无需 embedding API 或本地向量库，任何 LLM provider 都能用 |
| System Tool 位置 | `app/tool/forge/` 嵌套子包（每文件一 tool：search/get/create/edit/run.go），工厂 `ForgeTools()` 返 `[]toolapp.Tool`；组装留在 `cmd/server/main.go` | §S12 例外：tool framework meta-namespace 允许嵌套子包；Style B 命名 `SearchForge / GetForge / CreateForge / EditForge / RunForge` 显式不重叠 |
| resolveAttachments | **RunForge（System Tool）调用前完成**，不进 Service | forge Service 不感知 att_id 概念，保持纯粹 |
| GenerateTestCases | Service 方法**同步返回 `*GenerateResult`** | LLM 是非流式调用（`llm.Generate`），逐条流式推送只是化妆——直接整批返回更清晰 |
| LLM 注入 | **LLMClient 接口注入 Service** | GenerateTestCases 是 tool domain 自己的能力，不是 chat 触发的 |
| 代码生成方式 | **One-shot**，LLM 一次生成完整函数 | 工具是单函数，全量重写比 patch 更可靠 |
| 沙箱隔离 | **subprocess + 30s timeout** | 本地单用户；Docker 是过度工程 |
| AST 解析 | **Python subprocess + Google-style docstring** | 可靠提取 parameters（含 required）和 returnSchema |
| 归档 | **不做**，只有软删除 | 本地单用户，工具数量有限 |
| LLM 能否删除工具 | **不能** | 删除是破坏性操作，只走 HTTP API |
| 危险操作提示 | LLM 在 tool_call args 自报 `destructive: true` | per-call 标注比静态 IsDestructive() 精准（同一 tool 不同 args 可能不同）；UI 据此显示警示徽章；存进 ToolCallData 一等字段 + ChatToolCall SSE 字段 |
| AST dry-run | CreateForge / EditForge 在 streamCode 后调 `forgeapp.Service.ParseCode(code)` 验证，失败立刻返 LLM 重试信号 | 不进 svc.Create 的存储 I/O；干净的错误路径 |
| RunForge 输出 | 50KB 截断（`maxOutputBytes`）| 防失控 forge 撑爆 LLM context；超限替换为 notice 字符串而非裁剪 |

---

## 2. 多租户准备

- 所有表带 `user_id TEXT NOT NULL`
- Store 方法首行 `reqctx.GetUserID(ctx)`，缺失返错（接线 bug）
- Phase 3 仍硬编码 `"local-user"`

---

## 3. 领域模型

### 3.1 Forge（主实体）

```go
type Forge struct {
    ID           string         `gorm:"primaryKey;type:text"           json:"id"`
    UserID       string         `gorm:"not null;index;type:text"       json:"-"`
    Name         string         `gorm:"not null;type:text"             json:"name"`
    Description  string         `gorm:"not null;type:text;default:''"  json:"description"`
    Code         string         `gorm:"not null;type:text"             json:"code"`
    Parameters   string         `gorm:"type:text;default:'[]'"         json:"parameters"`   // JSON: [{name,type,required,description,default?}]
    ReturnSchema string         `gorm:"type:text;default:'{}'"         json:"returnSchema"` // JSON: {type,description}
    Tags         string         `gorm:"type:text;default:'[]'"         json:"tags"`          // JSON: ["tag1"]
    VersionCount int            `gorm:"not null;default:0"             json:"versionCount"`  // 当前最大 accepted version 号
    CreatedAt    time.Time      `json:"createdAt"`
    UpdatedAt    time.Time      `json:"updatedAt"`
    DeletedAt    gorm.DeletedAt `gorm:"index"                          json:"-"`

    // Pending 是当前活跃的 pending 变更（如有）。计算字段——序列化前由
    // handler/service 填充，不是 DB 列。nil 表示无 pending。
    Pending *ForgeVersion `gorm:"-" json:"pending,omitempty"`
}

func (Forge) TableName() string { return "forges" }
```

| 字段 | 说明 |
|---|---|
| `ID` | `f_<16hex>` |
| `Name` | forge 库内唯一（partial UNIQUE：`UNIQUE(user_id, name) WHERE deleted_at IS NULL`）|
| `Code` | 当前 active 代码（最新 accepted version 的代码）|
| `Parameters` | `[{"name":"x","type":"str","required":true,"description":"...","default":null}]` |
| `ReturnSchema` | `{"type":"list","description":"..."}` |
| `VersionCount` | 最新 accepted version 号，从 1 开始；create_forge 期间 stub 是 0 |
| `Pending` | **计算字段**（gorm:"-"），由 service 层 `attachPending` 在 GET / List 后填充。entity-state SSE `forge` 事件的载荷依赖此字段——edit_forge 期间 draft pending 挂在此上，前端 forge 面板从 `Forge.Pending.Code` 读流式生长的代码 |

### 3.2 ForgeVersion（版本历史 + pending 变更，合并表）

```go
type ForgeVersion struct {
    ID           string    `gorm:"primaryKey;type:text"           json:"id"`
    ForgeID      string    `gorm:"not null;index;type:text"       json:"forgeId"`
    UserID       string    `gorm:"not null;type:text"             json:"-"`
    Version      *int      `gorm:"type:integer"                   json:"version"`      // pending/rejected 时为 nil
    Status       string    `gorm:"not null;type:text"             json:"status"`       // "pending"|"accepted"|"rejected"

    // 完整 forge 快照
    Name         string    `gorm:"not null;type:text"             json:"name"`
    Description  string    `gorm:"type:text;default:''"           json:"description"`
    Code         string    `gorm:"not null;type:text"             json:"code"`
    Parameters   string    `gorm:"type:text;default:'[]'"         json:"parameters"`
    ReturnSchema string    `gorm:"type:text;default:'{}'"         json:"returnSchema"`
    Tags         string    `gorm:"type:text;default:'[]'"         json:"tags"`

    // ChangeReason 记录此版本的变更意图（Phase 5 改名 from `Message`：
    // LLM 指令 | "manual edit" | "reverted to v{N}" | "initial"）
    ChangeReason string    `gorm:"type:text;default:''"           json:"changeReason"`
    CreatedAt    time.Time `json:"createdAt"`
    UpdatedAt    time.Time `json:"updatedAt"`
}

func (ForgeVersion) TableName() string { return "forge_versions" }
```

**状态流转**：
```
pending → accepted  （用户确认）→ 分配 version 号，更新 Forge 主表
pending → rejected  （用户拒绝）→ version 保持 nil
```

**版本号分配**：accepted 时 `version = forge.VersionCount + 1`，同时 `forge.VersionCount++`

**上限**：每 forge 最多保留 `MaxAcceptedVersions=50` 条 `status='accepted'` 记录，超限硬删最旧的 accepted 版本。rejected/pending 不计入上限。

### 3.3 ForgeTestCase（测试用例定义）

```go
type ForgeTestCase struct {
    ID             string    `gorm:"primaryKey;type:text"        json:"id"`
    ForgeID        string    `gorm:"not null;index;type:text"    json:"forgeId"`
    UserID         string    `gorm:"not null;type:text"          json:"-"`
    Name           string    `gorm:"not null;type:text"          json:"name"`
    InputData      string    `gorm:"type:text;default:'{}'"      json:"inputData"`      // JSON object
    ExpectedOutput string    `gorm:"type:text;default:''"        json:"expectedOutput"` // JSON，空=不断言
    CreatedAt      time.Time `json:"createdAt"`
    UpdatedAt      time.Time `json:"updatedAt"`
}

func (ForgeTestCase) TableName() string { return "forge_test_cases" }
```

### 3.4 ForgeExecution（执行历史，Phase 5 统一表）

**Phase 5 重构**（2026-05-02）：原 `ForgeRunHistory` + `ForgeTestHistory` 两表合并为单一 `ForgeExecution`，用 `Kind` 区分 `"run"` / `"test"`。新增 chat 触发上下文 4 字段（`TriggeredBy` + `ConversationID` + `MessageID` + `ToolCallID`），让 LLM 在 chat 中调用 run_forge 后，可从 chat 消息追溯到对应执行行。

每次 `:run` / 测试用例执行 / LLM run_forge 调用都写一条。

```go
type ForgeExecution struct {
    ID           string `gorm:"primaryKey;type:text"                                            json:"id"`
    ForgeID      string `gorm:"not null;index:idx_fe_forge_created,priority:1;type:text"        json:"forgeId"`
    UserID       string `gorm:"not null;type:text"                                              json:"-"`
    ForgeVersion int    `gorm:"not null"                                                        json:"forgeVersion"`

    // Discriminator + 结果
    Kind      string `gorm:"not null;type:text"     json:"kind"`     // "run" | "test"
    Input     string `gorm:"type:text;default:'{}'" json:"input"`    // JSON
    Output    string `gorm:"type:text;default:''"   json:"output"`
    OK        bool   `gorm:"not null"               json:"ok"`
    ErrorMsg  string `gorm:"type:text;default:''"   json:"errorMsg"`
    ElapsedMs int64  `gorm:"not null;default:0"     json:"elapsedMs"`

    // test 专属字段（Kind="run" 时空）
    TestCaseID string `gorm:"type:text;default:'';index" json:"testCaseId,omitempty"`
    BatchID    string `gorm:"type:text;default:'';index" json:"batchId,omitempty"`
    Pass       *bool  `gorm:"type:integer"               json:"pass,omitempty"` // nil=无断言

    // 触发上下文
    TriggeredBy    string `gorm:"not null;type:text;default:'http'"     json:"triggeredBy"`     // "chat" | "http"
    ConversationID string `gorm:"type:text;default:'';index:idx_fe_msg" json:"conversationId,omitempty"`
    MessageID      string `gorm:"type:text;default:'';index:idx_fe_msg" json:"messageId,omitempty"`
    ToolCallID     string `gorm:"type:text;default:''"                  json:"toolCallId,omitempty"`

    CreatedAt time.Time `gorm:"index:idx_fe_forge_created,priority:2" json:"createdAt"`
}

func (ForgeExecution) TableName() string { return "forge_executions" }
```

**复合索引 2 个**：
- `idx_fe_forge_created (forge_id, created_at)` — 单 forge 历史按时间倒序检索（最常用）
- `idx_fe_msg (conversation_id, message_id)` — 一次 chat 消息触发的所有 forge 调用追溯

**保留上限**：`MaxExecutionsPerForge = 300` 条/forge（合并上限，原 100 + 200 = 300），超限硬删最旧。

### 3.6 ExecutionResult（domain 层共享类型）

定义在 `domain/tool` 避免 `infra/sandbox` 和 `app/tool` 相互依赖。

```go
type ExecutionResult struct {
    OK        bool   `json:"ok"`
    Output    any    `json:"output"`
    ErrorMsg  string `json:"errorMsg"`
    ElapsedMs int64  `json:"elapsedMs"`
}
```

---

## 4. 常量

```go
const (
    // VersionStatus values for ForgeVersion.Status.
    VersionStatusPending  = "pending"
    VersionStatusAccepted = "accepted"
    VersionStatusRejected = "rejected"

    // ExecutionKind values for ForgeExecution.Kind.
    ExecutionKindRun  = "run"  // 临时运行 / LLM 调用
    ExecutionKindTest = "test" // 测试用例

    // TriggeredBy values for ForgeExecution.TriggeredBy.
    TriggeredByChat = "chat" // LLM 在 chat 中调用
    TriggeredByHTTP = "http" // 用户直接调 HTTP

    // Retention.
    MaxAcceptedVersions   = 50  // 每 forge accepted 版本上限
    MaxExecutionsPerForge = 300 // 每 forge 执行历史上限（合并 run+test）
    SandboxTimeout        = 30 * time.Second
)
```

---

## 5. Sentinel 错误

```go
var (
    ErrNotFound         = errors.New("forge: not found")
    ErrDuplicateName    = errors.New("forge: name already exists")
    ErrVersionNotFound  = errors.New("forge: version not found")
    ErrPendingNotFound  = errors.New("forge: no pending change found")
    ErrPendingConflict  = errors.New("forge: already has a pending change")
    ErrTestCaseNotFound = errors.New("forge: test case not found")
    ErrRunFailed        = errors.New("forge: execution failed")
    ErrASTParseError    = errors.New("forge: code AST parse failed")
    ErrImportInvalid    = errors.New("forge: import data invalid")
)
```

---

## 6. Repository 接口

```go
type Repository interface {
    // Forge CRUD
    SaveForge(ctx context.Context, f *Forge) error
    GetForge(ctx context.Context, id string) (*Forge, error)
    GetForgesByIDs(ctx context.Context, ids []string) ([]*Forge, error) // LLM 排序后按 ID 批量拉完整对象
    ListForges(ctx context.Context, filter ListFilter) ([]*Forge, string, error)
    ListAllForges(ctx context.Context) ([]*Forge, error) // 供 search_forges 把全量 forge 发给 LLM 排序
    DeleteForge(ctx context.Context, id string) error

    // Versions（含 pending）
    SaveVersion(ctx context.Context, v *ForgeVersion) error
    GetVersion(ctx context.Context, forgeID string, version int) (*ForgeVersion, error)
    GetActivePending(ctx context.Context, forgeID string) (*ForgeVersion, error) // status='pending'
    ListAcceptedVersions(ctx context.Context, forgeID string) ([]*ForgeVersion, error) // status='accepted', version DESC
    UpdateVersionStatus(ctx context.Context, id, status string, version *int) error
    CountAcceptedVersions(ctx context.Context, forgeID string) (int64, error)
    DeleteOldestAcceptedVersion(ctx context.Context, forgeID string) error

    // Test cases
    SaveTestCase(ctx context.Context, tc *ForgeTestCase) error
    GetTestCase(ctx context.Context, id string) (*ForgeTestCase, error)
    ListTestCases(ctx context.Context, forgeID string) ([]*ForgeTestCase, error)
    DeleteTestCase(ctx context.Context, id string) error

    // Executions（Phase 5 统一表，9 个 history 方法 → 4 个）
    SaveExecution(ctx context.Context, e *ForgeExecution) error
    ListExecutions(ctx context.Context, filter ExecutionFilter) ([]*ForgeExecution, string, error)
    CountExecutions(ctx context.Context, forgeID string) (int64, error)
    DeleteOldestExecution(ctx context.Context, forgeID string) error
}

type ListFilter struct {
    Cursor string
    Limit  int
}

// ExecutionFilter 是 Repository.ListExecutions 接受的查询形状。所有字段可选；
// 空 filter 列出全部（按 ctx 用户过滤）。常用模式：
//   - {ForgeID, Limit:20}                        某 forge 最近 20 条执行
//   - {ForgeID, Kind:"test", BatchID:"..."}      一次 :test 批次的所有行
//   - {MessageID}                                 某 chat 消息触发的所有 forge 执行
//   - {ConversationID, Limit:100}                一个对话中所有执行
type ExecutionFilter struct {
    ForgeID        string
    Kind           string // "" | "run" | "test"
    BatchID        string
    TestCaseID     string
    ConversationID string
    MessageID      string
    ToolCallID     string
    Cursor         string // base64url(paginationpkg.Cursor); "" = first page
    Limit          int    // 0 → store default (50)
}
```

**ListExecutions 排序约定**：BatchID 指定时按 `created_at ASC`（单批次按运行顺序展示）；其他情况按 `created_at DESC`（最新在前）。Cursor 谓词随排序方向反转。

---

## 7. Store 实现要点

### 7.1 SQLite（GORM）

- Partial UNIQUE：`UNIQUE(user_id, name) WHERE deleted_at IS NULL`，在 `schema_extras.go` 追加
- `ListAcceptedVersions`：`WHERE tool_id=? AND status='accepted' ORDER BY version DESC`
- `GetActivePending`：`WHERE tool_id=? AND status='pending' LIMIT 1`
- `DeleteOldestAcceptedVersion`：硬删 `WHERE tool_id=? AND status='accepted' ORDER BY version ASC LIMIT 1`

### 7.2 工具搜索（LLM 排序）

搜索逻辑完全在 `SearchTool`（`app/agent/forge.go`）中实现，不在 Service 层，不依赖向量库。

**流程**：
1. `toolSvc.ListAllTools(ctx)` → 拿全部工具（仅 name + description，轻量）
2. 构建 prompt：列出所有工具 + query，要求 LLM 返回 `[{"id":"t_xxx","score":0.95},...]`
3. LLM 非流式调用（等完整 JSON）→ 解析 ID + score 列表，取前 limit 条
4. `repo.GetToolsByIDs(ids)` → 取完整 Tool 对象
5. 按 score 排序后返回

**为什么比向量搜索准确**：LLM 完整理解语义，能推理 "处理表格" → parse_csv；20-200 个工具一次 prompt 全放进去，不丢失信息；无需 embedding API，任何 provider 都支持。

---

## 8. Service 层（app/tool/tool.go）

### 8.1 Struct

```go
type Service struct {
    repo    tooldomain.Repository
    sandbox Sandbox
    llm     LLMClient // GenerateTestCases 使用
    log     *zap.Logger
}

type Sandbox interface {
    Run(ctx context.Context, code string, input map[string]any, timeout time.Duration) (*tooldomain.ExecutionResult, error)
}
// ExecutionResult 定义在 domain/tool/tool.go，避免 infra/sandbox ↔ app/tool 循环依赖

// LLMClient 非流式调用，等待完整 JSON 响应。
// 实现层复用 ChatModelFactory + KeyProvider，对 Service 透明。
type LLMClient interface {
    Generate(ctx context.Context, prompt string) (string, error)
}

// GenerateResult 是 GenerateTestCases 同步返回的形状。
// 要么 NotSupported=true（含 Reason），要么 TestCases 含已保存的用例。
type GenerateResult struct {
    NotSupported bool                       `json:"notSupported"`
    Reason       string                     `json:"reason,omitempty"`
    TestCases    []*tooldomain.ForgeTestCase `json:"testCases,omitempty"`
}
```

### 8.2 Input / Output 类型

```go
type CreateInput struct {
    Name        string
    Description string
    Code        string
    Tags        []string // 可为空
}

type UpdateInput struct {
    Name        *string   // nil = 不改
    Description *string
    Tags        *[]string
    Code        *string   // nil = 不改代码
}

type TestCaseInput struct {
    Name           string
    InputData      string // JSON object string
    ExpectedOutput string // JSON string，空 = 不断言
}

type TestRunResult struct {
    TestCaseID     string
    Name           string
    Input          string // 实际执行的 input JSON
    Output         string // 实际输出 JSON
    OK             bool   // sandbox 执行是否成功
    Pass           *bool  // nil=无 expected_output；true/false=断言结果
    ErrorMsg       string
    ElapsedMs      int64
}
```

### 8.3 CRUD

```go
func (s *Service) Create(ctx context.Context, in CreateInput) (*tooldomain.Tool, error)
// CreateInput: {Name, Description, Code, Tags}
// 1. parseToolCode(code) → parameters, returnSchema
// 2. repo.SaveTool（UNIQUE 冲突 → ErrDuplicateName）
// 3. repo.SaveVersion(status='accepted', version=1, message="initial")
// 4. tool.VersionCount = 1

func (s *Service) Get(ctx context.Context, id string) (*tooldomain.Tool, error)

func (s *Service) GetDetail(ctx context.Context, id string) (*ToolDetail, error)
// 供 get_forge System Tool 使用：Get + 聚合最近 test history 摘要

type ToolDetail struct {
    *tooldomain.Tool
    TestSummary TestSummary
}

type TestSummary struct {
    Total        int    // 当前测试用例总数
    LastPassRate string // 最近一次 :test 批跑的结果，格式 "3/3" | "2/3" | "" (无记录)
    LastRunAt    string // 最近一次批跑时间，ISO 8601 或 ""
}

func (s *Service) List(ctx context.Context, filter tooldomain.ListFilter) ([]*tooldomain.Tool, string, error)

func (s *Service) ListAll(ctx context.Context) ([]*tooldomain.Tool, error)
// 供 SearchTool 使用：返回当前用户全部活跃工具（无分页），仅取 name+description 即可

func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*tooldomain.Tool, error)
// UpdateInput: Name? / Description? / Tags? / Code?（用户直接操作，立即生效）
// 若 Code != nil:
//   1. 检查有无 active pending → 自动 reject
//   2. parseToolCode(newCode) → parameters, returnSchema
// 3. 更新 Tool 主表所有变更字段
// 4. tool.VersionCount++，repo.SaveVersion(status='accepted', version=VersionCount, message="manual edit")
// 5. 若 accepted count > 50 → DeleteOldestAcceptedVersion

func (s *Service) Delete(ctx context.Context, id string) error
// repo.DeleteTool（软删）
```

### 8.4 版本管理

```go
func (s *Service) ListVersions(ctx context.Context, toolID string) ([]*tooldomain.ForgeVersion, error)
// repo.ListAcceptedVersions（status='accepted', version DESC）

func (s *Service) GetVersion(ctx context.Context, toolID string, version int) (*tooldomain.ForgeVersion, error)

func (s *Service) RevertToVersion(ctx context.Context, toolID string, version int) (*tooldomain.Tool, error)
// 1. GetVersion → 拿完整快照（name/description/code/parameters/returnSchema/tags）
// 2. 检查有无 active pending → 自动 reject
// 3. 更新 Tool 主表为快照内容
// 4. tool.VersionCount++，SaveVersion(status='accepted', version=VersionCount, message="reverted to v{N}")
// 5. 若 accepted count > 50 → DeleteOldestAcceptedVersion
```

### 8.5 Pending 管理

```go
func (s *Service) GetActivePending(ctx context.Context, toolID string) (*tooldomain.ForgeVersion, error)
// repo.GetActivePending → ErrPendingNotFound if nil

func (s *Service) AcceptPending(ctx context.Context, toolID string) (*tooldomain.Tool, error)
// 1. repo.GetActivePending(toolID) → ErrPendingNotFound if none
// 2. 分配 version = tool.VersionCount + 1
// 3. 更新 Tool 主表为 pending 快照（name/description/code/parameters/returnSchema/tags）
// 4. tool.VersionCount = version
// 5. repo.UpdateVersionStatus(pv.ID, 'accepted', &version)
// 6. 若 accepted count > 50 → DeleteOldestAcceptedVersion

func (s *Service) RejectPending(ctx context.Context, toolID string) error
// repo.GetActivePending(toolID) → UpdateVersionStatus(pv.ID, 'rejected', nil)
```

### 8.6 执行

```go
func (s *Service) RunTool(ctx context.Context, toolID string, input map[string]any) (*ExecutionResult, error)
// input 已由调用方预处理（att_id 解析在 RunTool System Tool 内完成；HTTP 调用者直接传真实路径）
// 1. GetTool → code
// 2. sandbox.Run(code, input, SandboxTimeout)
// 3. 写 ForgeRunHistory（无论成功失败）
// 4. 若 count > MaxRunHistoryPerTool → DeleteOldestRunHistory
```

### 8.7 测试用例

```go
func (s *Service) CreateTestCase(ctx context.Context, toolID string, in TestCaseInput) (*tooldomain.ForgeTestCase, error)
func (s *Service) ListTestCases(ctx context.Context, toolID string) ([]*tooldomain.ForgeTestCase, error)
func (s *Service) DeleteTestCase(ctx context.Context, id string) error

func (s *Service) RunTestCase(ctx context.Context, testCaseID string, batchID string) (*TestRunResult, error)
// sandbox.Run + 若 ExpectedOutput != "" 则断言 pass/fail
// 写 ForgeTestHistory
// 若 count > MaxTestHistoryPerTool → DeleteOldestTestHistory

func (s *Service) RunAllTests(ctx context.Context, toolID string) ([]*TestRunResult, error)
// 生成 batchID → 逐条 RunTestCase(id, batchID) → 汇总返回

func (s *Service) GenerateTestCases(ctx context.Context, toolID string, count int) (*GenerateResult, error)
// 1. GetTool → code + parameters + returnSchema
// 2. llm.Generate(ctx, prompt) — 等完整 JSON
//    prompt：分析函数，若依赖外部状态输出 {"not_supported":true,"reason":"..."}
//            否则输出 {"test_cases":[{name,input,expected_output},...]}
// 3. 解析结果：
//    not_supported → return &GenerateResult{NotSupported:true, Reason:...}
//    test_cases    → 逐条 SaveTestCase 累积 → return &GenerateResult{TestCases:saved}
// 注意：追加到现有测试集
```

### 8.8 导入导出

```go
func (s *Service) Export(ctx context.Context, toolID string) ([]byte, error)
// JSON: {name, description, code, tags, testCases:[]}

func (s *Service) Import(ctx context.Context, data []byte) (*tooldomain.Tool, error)
// 解析 → Create → 若有 testCases 则 CreateTestCase
```

### 8.9 AST 解析（私有，app/tool/ast.go）

```go
type ParsedCode struct {
    FuncName   string
    Parameters []ParsedParam
    Return     ParsedReturn
    Docstring  string
}

type ParsedParam struct {
    Name        string
    Type        string
    Required    bool    // true = 无默认值
    Description string  // Google-style docstring Args: 段
    Default     *string
}

type ParsedReturn struct {
    Type        string // 返回类型注解
    Description string // Google-style docstring Returns: 段
}

// parseToolCode 启动 Python subprocess 解析代码结构。
// 要求 Google-style docstring；Description 字段解析失败时为空字符串，不报错。
func parseToolCode(code string) (*ParsedCode, error)
```

---

## 9. 文件交互（att_id 解析）

`RunTool`（System Tool，`app/agent/forge.go`）在调用 `toolSvc.RunTool` 前做 att_id 解析：

```go
// resolveAttachments 遍历 input 所有 string 值，
// 若以 "att_" 开头则查 chat_attachments 表，替换为绝对路径。
func resolveAttachments(ctx context.Context, attachRepo chatdomain.Repository, input map[string]any) (map[string]any, error)
```

HTTP 直接调用 `:run` 的用户传真实文件路径，不需要解析。

---

## 10. System Tools（`app/tool/forge/` 嵌套子包）

5 个 forge system tool 各自一个文件（Phase 3 后优化轮重组），实现 `app/tool.Tool` 接口（10 方法全必填，详见 [`CLAUDE.md §S18`](../../../CLAUDE.md)）。包别名 `forgetool`（§S13 嵌套子包规则 `<sub><parent>`）。

```
internal/app/tool/forge/
├── forge.go        ← ForgeTools() 工厂 + 共享 helpers（buildClient / streamCode / extractJSON / extractCode / resolveAttachments / prompt builders）
├── search.go       ← SearchForge struct
├── get.go          ← GetForge struct
├── create.go       ← CreateForge struct
├── edit.go         ← EditForge struct
└── run.go          ← RunForge struct
```

```go
package forge

func ForgeTools(
    svc        *forgeapp.Service,
    attachRepo chatdomain.Repository,
    picker     modeldomain.ModelPicker,
    keys       apikeydomain.KeyProvider,
    factory    *llminfra.Factory,
    bridge     eventsdomain.Bridge,
) []toolapp.Tool
// 返回 5 个 forge system tool（实现 toolapp.Tool 接口的 10 方法）
```

**统一注入 / 钩子链**（每个 forge tool 都走）：framework 自动注入 `summary` (必填) + `destructive` (可选) 字段进 Parameters；`runOneTool` 在 Execute 前跑 `ValidateInput` + `CheckPermissions`；推流时 tool 直接 `bridge.Publish(...)`，从 `pkg/reqctx` 读 convID/msgID/toolCallID。

| Tool | IsReadOnly | IsConcurrencySafe | 推 SSE | 备注 |
|---|---|---|---|---|
| SearchForge | true | true | — | LLM 排序，并发安全 |
| GetForge | true | true | — | 单条查询，并发安全 |
| CreateForge | false | false | `forge.code_streaming` + `forge.created` | 写库；AST dry-run 后再 svc.Create |
| EditForge | false | false | `forge.code_streaming` + `forge.pending_created` 或 `forge.metadata_updated` | 走 pending；元数据-only 路径推后者 |
| RunForge | false | false | — | sandbox 执行；输出 50KB 截断 |

### search_forges

```
参数：{ "query": string, "limit"?: int（默认 3，最大 5）}
返回：[{
  id, name, description,
  parameters: [{name, type, required, description, default}],
  returnSchema: {type, description},
  score: float   // LLM 给出的相关度评分 0~1（注意：原 "similarity" 在 Phase 3 改名 score——更诚实，不是向量 cosine）
}]

实现（SearchForge 内部）：
  1. svc.ListAll(ctx) → 全部 forge（name + description）
  2. llm.Generate(ctx, rankPrompt) → "[{\"id\":\"f_xxx\",\"score\":0.95},...]"
     rankPrompt：列出所有 forge + query，要求返回最相关的 limit 个 ID+score
  3. extractJSON 兼容 markdown fence 优先（` ```json ... ``` `）+ bracket fallback
  4. svc.GetForgesByIDs(ids) → 完整 Forge 对象
  5. 组装返回，score 填入

LLM 使用指引：
- score >= 0.8：高度相关，可直接 get_forge 确认后使用
- score 0.5~0.8：可能相关，建议 get_forge 读代码判断
- 返回空或全部低分：forge 库无合适工具，考虑 create_forge
```

### get_forge

```
参数：{ "forge_id": string }
返回：{
  id, name, description, code,
  parameters, returnSchema, tags, versionCount,
  testSummary: { total, lastPassRate, lastRunAt }
}
实现：svc.GetDetail(forge_id)
说明：LLM 在 search_forges 拿到候选后，对不确定的 forge 调此接口读完整代码再决定是否使用
```

### create_forge

```
参数：{ "name": string, "description": string, "instruction": string }
返回：{ "forge_id": string, "name": string, "parameters": [...] }
流程：
  1. streamCode(createPrompt + instruction) → 逐 token 推 forge.code_streaming{actionType:"create"}
  2. svc.ParseCode(code) — AST dry-run；语法错立刻返 LLM 重试（不进存储 I/O）
  3. svc.Create({name, description, code})
  4. bridge.Publish forge.created
  5. 返回 {forge_id, name, parameters}
```

### edit_forge

```
参数：{
  "forge_id": string,
  "instruction"?: string,    // 有 → LLM 生成新代码（流式）；无 → 仅改元数据
  "name"?: string,
  "description"?: string
}
// instruction 和其余字段至少提供一个

返回：{ "pending_id": string, "forge_id": string }
流程：
  1. 若有 instruction：
     a. svc.Get(forge_id) → 当前 code
     b. streamCode(editPrompt + currentCode + instruction) → 逐 token 推 forge.code_streaming{actionType:"edit"}
     c. svc.ParseCode(newCode) — AST dry-run
     d. snap.Code = newCode
  2. svc.CreatePending(forge_id, snap)
  3. 推事件（按路径选）：
     - 含 instruction → forge.pending_created
     - 仅元数据 → forge.metadata_updated（让前端区分"代码重生" vs "静默元数据"）
  4. 返回 {pending_id, forge_id}
```

### run_forge

```
参数：{ "forge_id": string, "input": object }
返回：{ "ok": bool, "output": any, "error"?: string, "elapsed_ms": int }
流程：
  1. resolveAttachments(ctx, input) — 顶层 string 字段 "att_xxx" → storage path
  2. svc.RunForge(ctx, forge_id, resolvedInput)
  3. 输出 JSON 编码后超 50KB 截断为 notice 字符串
注意：sandbox 执行失败返回 ok=false，不是 Go error
```

---

## 11. HTTP API（21 个端点，get_forge 仅为 System Tool，无对应 HTTP 端点）

| Method | Path | 用途 | 状态码 |
|---|---|---|---|
| POST | `/api/v1/forges` | 创建（直接传 code，不走 LLM）| 201 |
| GET | `/api/v1/forges` | 列表（分页；响应每个 forge 含 `pending` 字段）| 200 |
| GET | `/api/v1/forges/{id}` | 详情（响应含 `pending` 字段）| 200 |
| PATCH | `/api/v1/forges/{id}` | 更新（直接生效，任意字段）| 200 |
| DELETE | `/api/v1/forges/{id}` | 软删 | 204 |
| POST | `/api/v1/forges/{id}:run` | 执行 forge | 200 |
| POST | `/api/v1/forges/{id}:export` | 导出 JSON | 200 |
| POST | `/api/v1/forges:import` | 导入 JSON | 201 |
| GET | `/api/v1/forges/{id}/versions` | accepted 版本列表 | 200 |
| GET | `/api/v1/forges/{id}/versions/{version}` | 单版本详情（含完整快照）| 200 |
| POST | `/api/v1/forges/{id}:revert` | 回滚到指定版本 | 200 |
| GET | `/api/v1/forges/{id}/pending` | 当前 pending（无则 404）| 200/404 |
| POST | `/api/v1/forges/{id}/pending:accept` | 接受 | 200 |
| POST | `/api/v1/forges/{id}/pending:reject` | 拒绝 | 204 |
| GET | `/api/v1/forges/{id}/test-cases` | 测试用例列表 | 200 |
| POST | `/api/v1/forges/{id}/test-cases` | 创建测试用例 | 201 |
| DELETE | `/api/v1/forges/{id}/test-cases/{tcId}` | 删除测试用例 | 204 |
| POST | `/api/v1/forges/{id}/test-cases/{tcId}:run` | 运行单个测试用例 | 200 |
| POST | `/api/v1/forges/{id}:test` | 运行全部测试用例 | 200 |
| POST | `/api/v1/forges/{id}:generate-test-cases` | LLM 生成测试用例（一次性返回 JSON 批量）| 200 |
| GET | `/api/v1/forges/{id}/executions` | 执行历史（统一端点，`?kind=run\|test &batchId=&cursor=&limit=` 过滤；分页 envelope；Phase 5 替代 run-history + test-history）| 200 |

**关键说明**：
- `POST /tools` 和 `PATCH /tools/{id}` 是用户直接操作，立即生效，创建 accepted version
- `edit_forge`（System Tool）是 LLM 发起的变更，统一走 pending，用户审核后生效
- `:run` 执行失败是业务结果（200 + `ok:false`），不是 HTTP 错误

---

## 12. 错误码

| Code | HTTP | Sentinel | 场景 |
|---|---|---|---|
| `TOOL_NOT_FOUND` | 404 | `ErrNotFound` | id 查不到 |
| `TOOL_NAME_DUPLICATE` | 409 | `ErrDuplicateName` | 创建/改名撞名 |
| `TOOL_VERSION_NOT_FOUND` | 404 | `ErrVersionNotFound` | revert / get version 时版本不存在 |
| `TOOL_PENDING_NOT_FOUND` | 404 | `ErrPendingNotFound` | accept/reject 时无 pending |
| `TOOL_PENDING_CONFLICT` | 409 | `ErrPendingConflict` | edit_forge 时已有未处理 pending |
| `TOOL_TEST_CASE_NOT_FOUND` | 404 | `ErrTestCaseNotFound` | 测试用例找不到 |
| `TOOL_RUN_FAILED` | 422 | `ErrRunFailed` | sandbox 内部错误（≠ 执行失败，执行失败是 ok=false）|
| `TOOL_AST_PARSE_FAILED` | 422 | `ErrASTParseError` | 代码无法被 Python AST 解析 |
| `TOOL_IMPORT_INVALID` | 400 | `ErrImportInvalid` | 导入 JSON 格式错误 |

---

## 13. SSE 事件（Phase 6 重构 · entity-state 模型）

forge domain 现只用 **1 个 SSE 事件 `forge`**——载荷 = 完整 Forge 实体（含 `pending` 字段）的 GET 形状。详见 [`../service-contract-documents/events-design.md`](../service-contract-documents/events-design.md)。

```go
// Forge carries a full Forge snapshot, including the .Pending field when a
// pending change exists.
type Forge struct {
    *forgedomain.Forge
}

func (Forge) EventName() string { return "forge" }

// MarshalJSON 委托给嵌入的 *forgedomain.Forge——wire shape 严格 = GET /api/v1/forges/{id}。
func (e Forge) MarshalJSON() ([]byte, error) {
    if e.Forge == nil {
        return []byte("null"), nil
    }
    return json.Marshal(e.Forge)
}
```

### 触发点

| 触发场景 | 时机 |
|---|---|
| `create_forge` 进入 | 预分配 `forgeID = forgeapp.NewForgeID()`，构建 stub Forge（code 空），发首帧快照 |
| `create_forge` 流式 | LLM 每 token，更新 stub `Code` 并发快照 |
| `create_forge` 完成 | `svc.Create(ID=forgeID)` 落库后发最终快照（含 parsed parameters / version_count=1）|
| `edit_forge` 进入（含 instruction）| 预分配 `pendingID = forgeapp.NewVersionID()`，构建 draft pending 挂在 `Forge.Pending`，发首帧快照 |
| `edit_forge` 流式（含 instruction）| LLM 每 token，更新 `Pending.Code` 并发快照 |
| `edit_forge` 完成（含 instruction）| `svc.CreatePending(ID=pendingID)` 落库后发最终快照 |
| `edit_forge` 仅元数据 | 无流式；`svc.CreatePending` 落库后发一次最终快照 |
| accept_pending / reject_pending | （**TODO** Phase 6+）：HTTP handler 在状态变更后调 bridge.Publish |
| HTTP CRUD（POST/PATCH/DELETE）| **MVP 暂不广播**——单用户单窗口；多窗口同步留待后续 |

### 失败时的语义

stub / draft pending **从不落库直到 LLM 流成功 + AST 验证通过**。失败路径直接返回错误；订阅方观察到的最后一帧是错误前的部分快照，但 DB 没有对应行——前端可显示"创建/编辑失败"，并在下次 list/refresh 时清掉。

---

## 14. 端到端调用链

### 链 1：LLM 创建工具

```
用户："帮我写一个解析 CSV 的工具"
  → LLM 调 create_forge({name, description, instruction})
  → CreateTool.InvokableRun
      → llm.Stream → 推 forge.code_streaming tokens
      → toolSvc.Create → SaveTool + SaveVersion(v1, accepted)
      → 推 forge.created
      → return {tool_id, name, parameters}
```

### 链 2：LLM 编辑工具（代码 + 元数据）

```
用户："帮 parse_csv 加 delimiter 参数，顺便改个好听的名字"
  → LLM 调 edit_forge({tool_id, instruction:"add delimiter param", name:"csv_parser"})
  → EditTool.InvokableRun
      → llm.Stream(currentCode + instruction) → 推 forge.code_streaming tokens
      → 构建完整 pending 快照（name="csv_parser", 新代码, 新 parameters...）
      → repo.SaveVersion(status='pending')
      → 推 forge.pending_created
      → return {pending_id, tool_id}
```

### 链 3：用户接受 pending

```
POST /api/v1/forges/t_xxx/pending:accept
  → toolSvc.AcceptPending
      → 分配 version = VersionCount + 1
      → 更新 Tool 主表为 pending 快照（名字也改了）
      → UpdateVersionStatus → 'accepted'
      → vectorDB.Upsert（新 name+description）
  → 200 updatedTool
```

### 链 4：LLM 搜索并执行工具

```
用户："帮我处理这段 CSV"
  → LLM 调 search_forges({query:"csv"}) → [{id, name, parameters, returnSchema, similarity:0.91}]
  → LLM 调 run_forge({tool_id, input:{csv_text:"..."}})
  → RunTool.InvokableRun
      → resolveAttachments（无 att_ 字段，直接透传）
      → toolSvc.RunTool → sandbox.Run → 写 ForgeRunHistory
      → return {ok:true, output:[...], elapsed_ms:35}
```

### 链 5：LLM 执行工具处理附件

```
用户上传 report.csv → att_abc123
用户："用工具处理这个文件"
  → LLM 调 run_forge({tool_id, input:{file_path:"att_abc123"}})
  → RunTool.InvokableRun
      → resolveAttachments → 查 chat_attachments → {file_path:"/data/.../original.csv"}
      → toolSvc.RunTool → sandbox.Run
```

### 链 6：用户点击"AI 生成测试用例"

```
POST /api/v1/forges/t_xxx:generate-test-cases  (200 JSON)
  → handler 调 toolSvc.GenerateTestCases(ctx, id, 5)
      → llm.Generate(prompt) — 等完整 JSON

      情况 A（可测）：
        → 逐条 SaveTestCase 累积进 saved
        → return &GenerateResult{TestCases:saved}

      情况 B（不可测，如依赖文件路径）：
        → return &GenerateResult{NotSupported:true, Reason:"..."}

  ← 200 envelope: {data: {testCases: [...]} 或 {notSupported:true, reason:"..."}}
```

---

## 15. 数据库表总览

| 表 | 主键前缀 | 说明 |
|---|---|---|
| `tools` | `t_` | 主实体，当前 active 状态 |
| `forge_versions` | `tv_` | 版本历史 + pending 变更（status 字段区分），accepted 最多保留 50 条 |
| `forge_test_cases` | `tc_` | 测试用例定义 |
| `forge_run_history` | `trh_` | 每次 `:run` 记录，最多 100 条/工具 |
| `forge_test_history` | `tth_` | 每次测试用例执行记录，最多 200 条/工具 |

`schema_extras.go` 追加：`UNIQUE(user_id, name) WHERE deleted_at IS NULL`（tools 表）

向量索引由 chromem-go 管理，路径 `{dataDir}/vectordb/tools`，不经过 SQLite。

---

## 16. infra/sandbox/python.go

```go
// internal/infra/sandbox/python.go

type PythonSandbox struct{ pythonPath string }

func New(pythonPath string) *PythonSandbox

func (s *PythonSandbox) Run(
    ctx context.Context,
    code string,
    input map[string]any,
    timeout time.Duration,
) (*toolapp.ExecutionResult, error)
// 1. 拼接驱动代码（读 stdin JSON → 调函数 → 输出 JSON）写临时文件
// 2. JSON 序列化 input → stdin
// 3. subprocess python3，超时 kill
// 4. stdout → output，stderr → errorMsg
// 5. 清理临时文件
```

工具约定只定义函数，sandbox 追加驱动：

```python
def parse_csv(csv_text: str, delimiter: str = ',') -> list:
    """解析 CSV 文本。

    Args:
        csv_text: 要解析的 CSV 文本内容
        delimiter: 字段分隔符

    Returns:
        解析后的行列表，每行是字符串列表
    """
    import csv, io
    return list(csv.reader(io.StringIO(csv_text), delimiter=delimiter))

# sandbox 自动追加：
# if __name__ == "__main__":
#     import json, sys
#     input_data = json.load(sys.stdin)
#     result = parse_csv(**input_data)
#     print(json.dumps(result))
```

---

## 17. 实现清单

- [x] 详设计完成（本文档）
- [x] `domain/tool/tool.go` — 5 个 entity + `ExecutionResult` + 常量 + 9 个 sentinel + Repository 接口 + ListFilter
- [ ] `domain/events/types.go` — 追加 6 个 SSE 事件
- [ ] `infra/sandbox/python.go` — PythonSandbox + 测试
- [ ] `infra/db/schema_extras.go` — partial UNIQUE（tools 表）
- [ ] `infra/store/tool/tool.go` — Repository 实现 + 集成测试
- [ ] `app/tool/ast.go` — parseToolCode（Python subprocess）
- [ ] `app/tool/tool.go` — Service 实现 + 单测
- [ ] `app/agent/forge.go` — 5 个 System Tool（search/get/create/edit/run）+ resolveAttachments
- [ ] `handlers/tool.go` — 22 个端点 + errmap
- [ ] `router/deps.go` + `router/router.go` — 装配
- [ ] `cmd/server/main.go` — 注入 toolService + ForgeTools → chatService
- [ ] service-contract-documents 同步更新
