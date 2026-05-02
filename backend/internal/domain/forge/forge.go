// Package forge is the domain layer for the user's Python forge library.
// It owns four entities (Forge, ForgeVersion, ForgeTestCase, ForgeExecution),
// the shared ExecutionResult value object, enumeration constants, sentinel
// errors, and the storage contract (Repository).
//
// Design notes:
//
//   - ForgeVersion doubles as pending-change storage: status='pending' means
//     awaiting user confirmation; status='accepted' is a committed version.
//
//   - ForgeExecution is a single immutable history table for ALL forge
//     executions (ad-hoc :run + test-case runs + LLM-triggered run_forge),
//     discriminated by Kind ("run"|"test"). Test-only fields (TestCaseID,
//     BatchID, Pass) are nullable. Includes chat context (ConversationID,
//     MessageID, ToolCallID) when triggered via LLM, so a chat turn can be
//     fully traced to its forge invocations.
//
//   - ExecutionResult lives here (not in app/forge) so that infra/sandbox can
//     return it without importing app/forge, avoiding a circular dependency.
//
//   - All three forge packages (domain / app / store) declare `package forge`.
//     External callers alias by role at import time:
//
//     forgedomain "…/internal/domain/forge"
//     forgeapp    "…/internal/app/forge"
//     forgestore  "…/internal/infra/store/forge"
//
// Package forge 是用户 Python forge 库的 domain 层。拥有 4 个实体
// （Forge / ForgeVersion / ForgeTestCase / ForgeExecution）、共享值对象
// ExecutionResult、枚举常量、sentinel 错误及存储契约（Repository）。
//
// 设计说明：
//   - ForgeVersion 同时承担 pending 变更存储：status='pending' 表示待用户确认；
//     status='accepted' 是已提交版本。
//   - ForgeExecution 是唯一的不可变历史表，覆盖 forge 所有执行
//     （:run 临时运行 + 测试用例 + LLM 触发的 run_forge），用 Kind 区分
//     ("run"|"test")。test 专属字段（TestCaseID / BatchID / Pass）可空。
//     LLM 触发时记录 chat 上下文（ConversationID / MessageID / ToolCallID），
//     一次 chat turn 可完整追溯触发的 forge 调用。
//   - ExecutionResult 定义在本层（而非 app/forge），使 infra/sandbox 可直接
//     返回它而不必 import app/forge（否则循环依赖）。
//   - 三个 forge 包均声明 `package forge`，调用方 import 时按角色起别名（见上）。
package forge

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// ── Forge ──────────────────────────────────────────────────────────────────────

// Forge is the main entity representing a user-forged Python tool.
// Code holds the currently active version; VersionCount is the highest
// accepted version number (0 before first save). Pending is a computed field
// (not a DB column) populated by the handler/service layer when present.
//
// Forge 是用户锻造的 Python 工具主实体。
// Code 存当前活跃代码；VersionCount 是最大已接受版本号（首次保存前为 0）。
// Pending 是计算字段（非 DB 列），存在时由 handler/service 层填充。
type Forge struct {
	ID           string         `gorm:"primaryKey;type:text"           json:"id"`
	UserID       string         `gorm:"not null;index;type:text"       json:"-"`
	Name         string         `gorm:"not null;type:text"             json:"name"`
	Description  string         `gorm:"not null;type:text;default:''"  json:"description"`
	Code         string         `gorm:"not null;type:text"             json:"code"`
	Parameters   string         `gorm:"type:text;default:'[]'"         json:"parameters"`   // JSON: [{name,type,required,description,default?}]
	ReturnSchema string         `gorm:"type:text;default:'{}'"         json:"returnSchema"` // JSON: {type,description}
	Tags         string         `gorm:"type:text;default:'[]'"         json:"tags"`         // JSON: ["tag1","tag2"]
	VersionCount int            `gorm:"not null;default:0"             json:"versionCount"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt `gorm:"index"                          json:"-"`

	// Pending is the active pending change (if any). Computed field —
	// populated by handler/service before serialization, NOT a DB column.
	// nil means no pending change.
	//
	// Pending 是当前活跃的 pending 变更（如有）。计算字段——
	// 序列化前由 handler/service 填充，不是 DB 列。nil 表示无 pending。
	Pending *ForgeVersion `gorm:"-" json:"pending,omitempty"`
}

// TableName locks the DB table to "forges".
//
// TableName 把表名锁定为 "forges"。
func (Forge) TableName() string { return "forges" }

// ── ForgeVersion ───────────────────────────────────────────────────────────────

// ForgeVersion is a complete snapshot of a Forge at a point in time.
// It serves dual purpose: status='accepted' records committed history;
// status='pending' is an unconfirmed LLM proposal waiting for user review.
// Version is nil for pending/rejected rows; assigned on acceptance.
//
// ForgeVersion 是工具在某一时刻的完整快照。双重职责：
// status='accepted' 记录已提交历史；status='pending' 是待用户审核的 LLM 提案。
// Version 在 pending/rejected 时为 nil；接受时分配版本号。
type ForgeVersion struct {
	ID      string `gorm:"primaryKey;type:text"           json:"id"`
	ForgeID string `gorm:"not null;index;type:text"       json:"forgeId"`
	UserID  string `gorm:"not null;type:text"             json:"-"`
	Version *int   `gorm:"type:integer"                   json:"version"`
	Status  string `gorm:"not null;type:text"             json:"status"` // "pending"|"accepted"|"rejected"

	// Complete forge snapshot at this point in time.
	// 该时刻 forge 的完整快照。
	Name         string `gorm:"not null;type:text"             json:"name"`
	Description  string `gorm:"type:text;default:''"           json:"description"`
	Code         string `gorm:"not null;type:text"             json:"code"`
	Parameters   string `gorm:"type:text;default:'[]'"         json:"parameters"`
	ReturnSchema string `gorm:"type:text;default:'{}'"         json:"returnSchema"`
	Tags         string `gorm:"type:text;default:'[]'"         json:"tags"`

	// ChangeReason records the intent behind this version: LLM instruction,
	// "manual edit", "reverted to v{N}", or "initial".
	//
	// ChangeReason 记录此版本的变更意图：LLM 指令、"manual edit"、
	// "reverted to v{N}" 或 "initial"。
	ChangeReason string    `gorm:"type:text;default:''" json:"changeReason"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

// TableName locks the DB table to "forge_versions".
//
// TableName 把表名锁定为 "forge_versions"。
func (ForgeVersion) TableName() string { return "forge_versions" }

// ── ForgeTestCase ──────────────────────────────────────────────────────────────

// ForgeTestCase is a named test case for a forge. ExpectedOutput is optional;
// an empty string means no assertion — the run is judged by sandbox success only.
//
// ForgeTestCase 是 forge 的命名测试用例。ExpectedOutput 可选；
// 空字符串表示不断言——仅由 sandbox 执行成功与否判断。
type ForgeTestCase struct {
	ID             string    `gorm:"primaryKey;type:text"        json:"id"`
	ForgeID        string    `gorm:"not null;index;type:text"    json:"forgeId"`
	UserID         string    `gorm:"not null;type:text"          json:"-"`
	Name           string    `gorm:"not null;type:text"          json:"name"`
	InputData      string    `gorm:"type:text;default:'{}'"      json:"inputData"`      // JSON object
	ExpectedOutput string    `gorm:"type:text;default:''"        json:"expectedOutput"` // JSON; empty = no assertion
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

// TableName locks the DB table to "forge_test_cases".
//
// TableName 把表名锁定为 "forge_test_cases"。
func (ForgeTestCase) TableName() string { return "forge_test_cases" }

// ── ForgeExecution ─────────────────────────────────────────────────────────────

// ForgeExecution is a single immutable record of one forge invocation, whether
// triggered by ad-hoc :run, a test case, or by an LLM via the run_forge tool.
// Kind distinguishes "run" vs "test"; test-only fields (TestCaseID, BatchID,
// Pass) are nullable for run rows. Chat-context fields (ConversationID,
// MessageID, ToolCallID) are populated when triggered via LLM, allowing full
// traceability from a chat turn to its forge invocations.
//
// ForgeExecution 是一次 forge 调用的不可变记录，无论触发源是临时 :run、
// 测试用例还是 LLM 通过 run_forge 工具发起。Kind 区分 "run" / "test"；
// test 专属字段（TestCaseID / BatchID / Pass）在 run 行可空。
// chat 上下文字段（ConversationID / MessageID / ToolCallID）在 LLM 触发时填，
// 一次 chat turn 可完整追溯触发的 forge 调用。
type ForgeExecution struct {
	ID           string `gorm:"primaryKey;type:text"                                            json:"id"`
	ForgeID      string `gorm:"not null;index:idx_fe_forge_created,priority:1;type:text"        json:"forgeId"`
	UserID       string `gorm:"not null;type:text"                                              json:"-"`
	ForgeVersion int    `gorm:"not null"                                                        json:"forgeVersion"`

	// Discriminator + result.
	Kind      string `gorm:"not null;type:text"     json:"kind"`     // "run" | "test"
	Input     string `gorm:"type:text;default:'{}'" json:"input"`    // JSON
	Output    string `gorm:"type:text;default:''"   json:"output"`
	OK        bool   `gorm:"not null"               json:"ok"`
	ErrorMsg  string `gorm:"type:text;default:''"   json:"errorMsg"`
	ElapsedMs int64  `gorm:"not null;default:0"     json:"elapsedMs"`

	// Test-only fields (nullable when Kind="run").
	// test 专属字段（Kind="run" 时为空）。
	TestCaseID string `gorm:"type:text;default:'';index"          json:"testCaseId,omitempty"`
	BatchID    string `gorm:"type:text;default:'';index"          json:"batchId,omitempty"`
	Pass       *bool  `gorm:"type:integer"                        json:"pass,omitempty"` // nil = no assertion

	// Trigger context.
	// 触发上下文。
	TriggeredBy    string `gorm:"not null;type:text;default:'http'"             json:"triggeredBy"`     // "chat" | "http"
	ConversationID string `gorm:"type:text;default:'';index:idx_fe_msg"         json:"conversationId,omitempty"`
	MessageID      string `gorm:"type:text;default:'';index:idx_fe_msg"         json:"messageId,omitempty"`
	ToolCallID     string `gorm:"type:text;default:''"                          json:"toolCallId,omitempty"`

	CreatedAt time.Time `gorm:"index:idx_fe_forge_created,priority:2" json:"createdAt"`
}

// TableName locks the DB table to "forge_executions".
//
// TableName 把表名锁定为 "forge_executions"。
func (ForgeExecution) TableName() string { return "forge_executions" }

// ── ExecutionResult ───────────────────────────────────────────────────────────

// ExecutionResult is the outcome of a single sandbox Run call. It lives in
// the domain layer so that infra/sandbox can return it without depending on
// app/forge (which would create a circular import).
//
// ExecutionResult 是单次 sandbox Run 的执行结果。定义在 domain 层，
// 使 infra/sandbox 可直接返回它而不必 import app/forge（否则循环依赖）。
type ExecutionResult struct {
	OK        bool   `json:"ok"`
	Output    any    `json:"output"`
	ErrorMsg  string `json:"errorMsg"`
	ElapsedMs int64  `json:"elapsedMs"`
}

// ── Constants ─────────────────────────────────────────────────────────────────

// VersionStatus values for ForgeVersion.Status.
//
// ForgeVersion.Status 的取值。
const (
	VersionStatusPending  = "pending"  // LLM proposal awaiting user review / LLM 提案，等待用户审核
	VersionStatusAccepted = "accepted" // committed version / 已提交版本
	VersionStatusRejected = "rejected" // user-rejected proposal / 用户已拒绝的提案
)

// ExecutionKind values for ForgeExecution.Kind.
//
// ForgeExecution.Kind 的取值。
const (
	ExecutionKindRun  = "run"  // ad-hoc :run or LLM run_forge / 临时运行或 LLM 调用
	ExecutionKindTest = "test" // test case execution / 测试用例
)

// TriggeredBy values for ForgeExecution.TriggeredBy.
//
// ForgeExecution.TriggeredBy 的取值。
const (
	TriggeredByChat = "chat" // invoked via LLM tool call in a chat turn / LLM 在 chat 中调用
	TriggeredByHTTP = "http" // invoked directly via HTTP API (e.g., user UI) / 用户直接调 HTTP
)

// Retention limits. Enforced at write time by app/forge.Service.
//
// 保留上限。由 app/forge.Service 在写入时强制执行。
const (
	MaxAcceptedVersions   = 50  // per forge / 每 forge
	MaxExecutionsPerForge = 300 // per forge (combined run+test history) / 每 forge（run+test 合并历史）
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

// Sentinel errors. Mapped to HTTP responses by
// transport/httpapi/response/errmap.go.
//
// Sentinel 错误。由 transport/httpapi/response/errmap.go 映射到 HTTP 响应。
var (
	// ErrNotFound: forge id does not match any live record.
	// ErrNotFound：forge id 未命中任何活跃记录。
	ErrNotFound = errors.New("forge: not found")

	// ErrDuplicateName: name already taken by another live forge for this user.
	// ErrDuplicateName：该用户下已有同名活跃 forge。
	ErrDuplicateName = errors.New("forge: name already exists")

	// ErrVersionNotFound: requested version number does not exist for the forge.
	// ErrVersionNotFound：forge 下不存在该版本号。
	ErrVersionNotFound = errors.New("forge: version not found")

	// ErrPendingNotFound: accept/reject called but no pending change exists.
	// ErrPendingNotFound：调用 accept/reject 但 forge 没有待审核的变更。
	ErrPendingNotFound = errors.New("forge: no pending change found")

	// ErrPendingConflict: edit_forge called while an unresolved pending exists.
	// ErrPendingConflict：edit_forge 调用时已有未处理的 pending 变更。
	ErrPendingConflict = errors.New("forge: already has a pending change")

	// ErrTestCaseNotFound: test case id does not match any record for the forge.
	// ErrTestCaseNotFound：test case id 在 forge 下未命中任何记录。
	ErrTestCaseNotFound = errors.New("forge: test case not found")

	// ErrRunFailed: sandbox internal error (distinct from ok=false execution failure).
	// ErrRunFailed：sandbox 内部错误（与 ok=false 的执行失败不同）。
	ErrRunFailed = errors.New("forge: execution failed")

	// ErrASTParseError: Python AST parsing of the submitted code failed.
	// ErrASTParseError：提交代码的 Python AST 解析失败。
	ErrASTParseError = errors.New("forge: code AST parse failed")

	// ErrImportInvalid: import payload is malformed or missing required fields.
	// ErrImportInvalid：导入数据格式错误或缺少必填字段。
	ErrImportInvalid = errors.New("forge: import data invalid")
)

// ── Repository ────────────────────────────────────────────────────────────────

// Repository is the storage contract for all forge-related entities.
// Every method scopes queries to the userID carried in ctx — callers must
// ensure the InjectUserID middleware has run.
//
// Implemented by: infra/store/forge.Store
// Consumer:       app/forge.Service (only)
//
// Repository 是所有 forge 相关实体的存储契约。
// 每个方法都按 ctx 中的 userID 过滤——调用方必须保证 InjectUserID 中间件已运行。
//
// 实现：infra/store/forge.Store
// 消费：仅 app/forge.Service
type Repository interface {

	// ── Forge CRUD ─────────────────────────────────────────────────────────

	// SaveForge inserts or updates a Forge by primary key.
	//
	// SaveForge 按主键插入或更新 Forge。
	SaveForge(ctx context.Context, f *Forge) error

	// GetForge fetches a single Forge by id, scoped to the current user.
	// Returns ErrNotFound if no live record matches. Pending field is NOT
	// populated — callers wanting pending should use GetActivePending.
	//
	// GetForge 按 id 查单条，按当前用户过滤。未命中活跃记录返回 ErrNotFound。
	// Pending 字段不填充——需要 pending 的调用方另外调 GetActivePending。
	GetForge(ctx context.Context, id string) (*Forge, error)

	// GetForgesByIDs fetches multiple Forges by id slice, preserving order.
	// Used by SearchForge after the LLM returns ranked IDs.
	//
	// GetForgesByIDs 按 id 切片批量查询 Forge，保持顺序。
	// 供 SearchForge 在 LLM 返回排序 ID 后取完整对象。
	GetForgesByIDs(ctx context.Context, ids []string) ([]*Forge, error)

	// ListForges returns a cursor-paginated page of live forges for the current user.
	// Returns (rows, nextCursor, err).
	//
	// ListForges 返回当前用户活跃 forge 的 cursor 分页结果。
	// 返回 (rows, nextCursor, err)。
	ListForges(ctx context.Context, filter ListFilter) ([]*Forge, string, error)

	// ListAllForges returns all live forges for the current user without pagination.
	// Used by SearchForge to build the full forge list for LLM ranking.
	//
	// ListAllForges 返回当前用户全部活跃 forge，不分页。
	// 供 SearchForge 构建发给 LLM 排序的完整 forge 列表。
	ListAllForges(ctx context.Context) ([]*Forge, error)

	// DeleteForge soft-deletes a forge by id, scoped to the current user.
	//
	// DeleteForge 软删除（按当前用户过滤）。
	DeleteForge(ctx context.Context, id string) error

	// ── Versions (including pending) ──────────────────────────────────────

	// SaveVersion inserts a ForgeVersion record.
	//
	// SaveVersion 插入一条 ForgeVersion 记录。
	SaveVersion(ctx context.Context, v *ForgeVersion) error

	// GetVersion fetches the accepted ForgeVersion with the given version number.
	// Returns ErrVersionNotFound if it does not exist.
	//
	// GetVersion 查询指定版本号的已接受版本记录。
	// 不存在时返回 ErrVersionNotFound。
	GetVersion(ctx context.Context, forgeID string, version int) (*ForgeVersion, error)

	// GetActivePending returns the current pending ForgeVersion for the forge,
	// or ErrPendingNotFound if none exists.
	//
	// GetActivePending 返回 forge 当前的 pending ForgeVersion。
	// 不存在时返回 ErrPendingNotFound。
	GetActivePending(ctx context.Context, forgeID string) (*ForgeVersion, error)

	// ListAcceptedVersions returns all accepted versions for a forge,
	// ordered by version DESC (newest first).
	//
	// ListAcceptedVersions 返回 forge 所有已接受版本，按版本号降序（最新在前）。
	ListAcceptedVersions(ctx context.Context, forgeID string) ([]*ForgeVersion, error)

	// UpdateVersionStatus updates the status field and optionally assigns a
	// version number (pass nil to leave it NULL, e.g. for rejection).
	//
	// UpdateVersionStatus 更新 status 字段，可选分配版本号
	// （拒绝时传 nil 保持 NULL）。
	UpdateVersionStatus(ctx context.Context, id, status string, version *int) error

	// CountAcceptedVersions returns the number of accepted versions for a forge.
	//
	// CountAcceptedVersions 返回 forge 已接受版本数。
	CountAcceptedVersions(ctx context.Context, forgeID string) (int64, error)

	// DeleteOldestAcceptedVersion hard-deletes the accepted version with the
	// lowest version number for the given forge.
	//
	// DeleteOldestAcceptedVersion 硬删除指定 forge 版本号最小的已接受版本。
	DeleteOldestAcceptedVersion(ctx context.Context, forgeID string) error

	// ── Test cases ────────────────────────────────────────────────────────

	// SaveTestCase inserts a ForgeTestCase.
	//
	// SaveTestCase 插入 ForgeTestCase。
	SaveTestCase(ctx context.Context, tc *ForgeTestCase) error

	// GetTestCase fetches a test case by id.
	// Returns ErrTestCaseNotFound if no record matches.
	//
	// GetTestCase 按 id 查测试用例。未命中返回 ErrTestCaseNotFound。
	GetTestCase(ctx context.Context, id string) (*ForgeTestCase, error)

	// ListTestCases returns all test cases for the given forge, ordered by
	// created_at ASC.
	//
	// ListTestCases 返回指定 forge 所有测试用例，按 created_at ASC 排序。
	ListTestCases(ctx context.Context, forgeID string) ([]*ForgeTestCase, error)

	// DeleteTestCase hard-deletes a test case by id.
	//
	// DeleteTestCase 硬删除测试用例。
	DeleteTestCase(ctx context.Context, id string) error

	// ── Executions (unified run + test history) ───────────────────────────

	// SaveExecution inserts a ForgeExecution record.
	//
	// SaveExecution 插入一条 ForgeExecution 记录。
	SaveExecution(ctx context.Context, e *ForgeExecution) error

	// ListExecutions returns a cursor-paginated page of execution records
	// matching the filter, ordered by created_at DESC with id as tiebreaker.
	// When BatchID is set the order flips to ASC (single test batch reads
	// chronologically). Filter combines forge / kind / batch_id / chat-context
	// predicates; an empty filter lists all executions for the current user.
	// Returns (rows, nextCursor, err); nextCursor is "" when there are no
	// more pages.
	//
	// ListExecutions 返回匹配 filter 的执行记录 cursor 分页结果，按
	// created_at DESC（id 作为 tiebreaker）排序。指定 BatchID 时反转为 ASC
	// （单批次按运行顺序展示）。Filter 组合 forge / kind / batch_id / chat 上下文
	// 条件；空 filter 列出当前用户全部执行。返回 (rows, nextCursor, err)；
	// nextCursor 为 "" 表示无下一页。
	ListExecutions(ctx context.Context, filter ExecutionFilter) ([]*ForgeExecution, string, error)

	// CountExecutions returns the total number of execution records for a forge.
	// Used to enforce MaxExecutionsPerForge retention.
	//
	// CountExecutions 返回 forge 执行记录总数。供 MaxExecutionsPerForge 保留策略使用。
	CountExecutions(ctx context.Context, forgeID string) (int64, error)

	// DeleteOldestExecution hard-deletes the oldest execution record for the
	// given forge. Used to trim history when MaxExecutionsPerForge is exceeded.
	//
	// DeleteOldestExecution 硬删除指定 forge 最早的执行记录。
	// 超过 MaxExecutionsPerForge 时用于裁剪历史。
	DeleteOldestExecution(ctx context.Context, forgeID string) error
}

// ListFilter is the query shape accepted by Repository.ListForges.
//
// ListFilter 是 Repository.ListForges 接受的查询形状。
type ListFilter struct {
	Cursor string
	Limit  int
}

// ExecutionFilter is the query shape accepted by Repository.ListExecutions.
// All fields are optional; an empty filter lists everything (subject to user
// scoping by ctx). Common patterns:
//
//   - {ForgeID: "f_x", Limit: 20}                          → recent 20 executions of one forge
//   - {ForgeID: "f_x", Kind: "test", BatchID: "..."}      → all rows of a single :test batch
//   - {MessageID: "msg_x"}                                 → all forge executions triggered by one chat msg
//   - {ConversationID: "cv_x", Limit: 100}                 → all executions in a conversation
//
// ExecutionFilter 是 Repository.ListExecutions 接受的查询形状。所有字段可选；
// 空 filter 列出全部（按 ctx 用户过滤）。常用模式：
//
//   - {ForgeID, Limit:20} 某 forge 最近 20 条执行
//   - {ForgeID, Kind:"test", BatchID:"..."} 一次 :test 批次的所有行
//   - {MessageID} 某 chat 消息触发的所有 forge 执行
//   - {ConversationID, Limit:100} 一个对话中所有执行
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
