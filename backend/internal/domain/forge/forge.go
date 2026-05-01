// Package tool is the domain layer for the user's Python tool library.
// It owns five entities (Forge, ForgeVersion, ForgeTestCase, ForgeRunHistory,
// ForgeTestHistory), the shared ExecutionResult value object, enumeration
// constants, sentinel errors, and the storage contract (Repository).
//
// Design notes:
//
//   - ForgeVersion doubles as pending-change storage: status='pending' means
//     awaiting user confirmation; status='accepted' is a committed version.
//
//   - ExecutionResult lives here (not in app/tool) so that infra/sandbox can
//     return it without importing app/tool, avoiding a circular dependency.
//
//   - All three tool packages (domain / app / store) declare `package forge`.
//     External callers alias by role at import time:
//
//     forgedomain "…/internal/domain/forge"
//     forgeapp    "…/internal/app/forge"
//     forgestore  "…/internal/infra/store/forge"
//
// Package tool 是用户 Python 工具库的 domain 层。拥有 5 个实体
// （Forge / ForgeVersion / ForgeTestCase / ForgeRunHistory / ForgeTestHistory）、
// 共享值对象 ExecutionResult、枚举常量、sentinel 错误及存储契约（Repository）。
//
// 设计说明：
//   - ForgeVersion 同时承担 pending 变更存储：status='pending' 表示待用户确认；
//     status='accepted' 是已提交版本。
//   - ExecutionResult 定义在本层（而非 app/tool），使 infra/sandbox 可直接
//     返回它，不必 import app/tool，避免循环依赖。
//   - 三个 tool 包均声明 `package forge`，调用方 import 时按角色起别名（见上）。
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
// accepted version number (0 before first save).
//
// Forge 是用户锻造的 Python 工具主实体。
// Code 存当前活跃代码；VersionCount 是最大已接受版本号（首次保存前为 0）。
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
	ForgeID  string `gorm:"not null;index;type:text"       json:"forgeId"`
	UserID  string `gorm:"not null;type:text"             json:"-"`
	Version *int   `gorm:"type:integer"                   json:"version"`
	Status  string `gorm:"not null;type:text"             json:"status"` // "pending"|"accepted"|"rejected"

	// Complete tool snapshot at this point in time.
	// 该时刻工具的完整快照。
	Name         string `gorm:"not null;type:text"             json:"name"`
	Description  string `gorm:"type:text;default:''"           json:"description"`
	Code         string `gorm:"not null;type:text"             json:"code"`
	Parameters   string `gorm:"type:text;default:'[]'"         json:"parameters"`
	ReturnSchema string `gorm:"type:text;default:'{}'"         json:"returnSchema"`
	Tags         string `gorm:"type:text;default:'[]'"         json:"tags"`

	// Message records the intent: LLM instruction, "manual edit", "reverted to v{N}", or "initial".
	// Message 记录变更意图：LLM 指令、"manual edit"、"reverted to v{N}" 或 "initial"。
	Message   string    `gorm:"type:text;default:''" json:"message"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// TableName locks the DB table to "forge_versions".
//
// TableName 把表名锁定为 "forge_versions"。
func (ForgeVersion) TableName() string { return "forge_versions" }

// ── ForgeTestCase ──────────────────────────────────────────────────────────────

// ForgeTestCase is a named test case for a tool. ExpectedOutput is optional;
// an empty string means no assertion — the run is judged by sandbox success only.
//
// ForgeTestCase 是工具的命名测试用例。ExpectedOutput 可选；
// 空字符串表示不断言——仅由 sandbox 执行成功与否判断。
type ForgeTestCase struct {
	ID             string    `gorm:"primaryKey;type:text"        json:"id"`
	ForgeID         string    `gorm:"not null;index;type:text"    json:"forgeId"`
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

// ── ForgeRunHistory ────────────────────────────────────────────────────────────

// ForgeRunHistory records every ad-hoc :run execution, success or failure.
// ForgeVersion captures which accepted version was running at the time.
//
// ForgeRunHistory 记录每次临时 :run 执行，无论成功或失败。
// ForgeVersion 记录执行时处于第几个已接受版本。
type ForgeRunHistory struct {
	ID          string    `gorm:"primaryKey;type:text"     json:"id"`
	ForgeID      string    `gorm:"not null;index;type:text" json:"forgeId"`
	UserID      string    `gorm:"not null;type:text"       json:"-"`
	ForgeVersion int       `gorm:"not null"                 json:"forgeVersion"`
	Input       string    `gorm:"type:text;default:'{}'"   json:"input"`
	Output      string    `gorm:"type:text;default:''"     json:"output"`
	OK          bool      `gorm:"not null"                 json:"ok"`
	ErrorMsg    string    `gorm:"type:text;default:''"     json:"errorMsg"`
	ElapsedMs   int64     `gorm:"not null;default:0"       json:"elapsedMs"`
	CreatedAt   time.Time `json:"createdAt"`
}

// TableName locks the DB table to "forge_run_history".
//
// TableName 把表名锁定为 "forge_run_history"。
func (ForgeRunHistory) TableName() string { return "forge_run_history" }

// ── ForgeTestHistory ───────────────────────────────────────────────────────────

// ForgeTestHistory records every test-case execution, whether triggered
// individually or as part of a batch (:test). BatchID ties all records from
// a single :test run together; it is empty for individual runs.
// Pass is nil when ExpectedOutput was empty (no assertion).
//
// ForgeTestHistory 记录每次测试用例执行，无论是单跑还是批跑（:test）。
// BatchID 把同一次 :test 的所有记录串起来；单跑时为空。
// ExpectedOutput 为空时（无断言）Pass 为 nil。
type ForgeTestHistory struct {
	ID          string    `gorm:"primaryKey;type:text"       json:"id"`
	ForgeID      string    `gorm:"not null;index;type:text"   json:"forgeId"`
	UserID      string    `gorm:"not null;type:text"         json:"-"`
	ForgeVersion int       `gorm:"not null"                   json:"forgeVersion"`
	TestCaseID  string    `gorm:"not null;index;type:text"   json:"testCaseId"`
	BatchID     string    `gorm:"type:text;default:'';index" json:"batchId"`
	Input       string    `gorm:"type:text;default:'{}'"     json:"input"`
	Output      string    `gorm:"type:text;default:''"       json:"output"`
	OK          bool      `gorm:"not null"                   json:"ok"`
	Pass        *bool     `gorm:"type:integer"               json:"pass"` // nil = no assertion
	ErrorMsg    string    `gorm:"type:text;default:''"       json:"errorMsg"`
	ElapsedMs   int64     `gorm:"not null;default:0"         json:"elapsedMs"`
	CreatedAt   time.Time `json:"createdAt"`
}

// TableName locks the DB table to "forge_test_history".
//
// TableName 把表名锁定为 "forge_test_history"。
func (ForgeTestHistory) TableName() string { return "forge_test_history" }

// ── ExecutionResult ───────────────────────────────────────────────────────────

// ExecutionResult is the outcome of a single sandbox Run call. It lives in
// the domain layer so that infra/sandbox can return it without depending on
// app/tool (which would create a circular import).
//
// ExecutionResult 是单次 sandbox Run 的执行结果。定义在 domain 层，
// 使 infra/sandbox 可直接返回它而不必 import app/tool（否则循环依赖）。
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

// Retention limits. Enforced at write time by app/tool.Service.
//
// 保留上限。由 app/tool.Service 在写入时强制执行。
const (
	MaxAcceptedVersions   = 50  // per tool / 每工具
	MaxRunHistoryPerForge  = 100 // per tool / 每工具
	MaxTestHistoryPerForge = 200 // per tool / 每工具
)

// ── Sentinel errors ───────────────────────────────────────────────────────────

// Sentinel errors. Mapped to HTTP responses by
// transport/httpapi/response/errmap.go.
//
// Sentinel 错误。由 transport/httpapi/response/errmap.go 映射到 HTTP 响应。
var (
	// ErrNotFound: tool id does not match any live record.
	// ErrNotFound：tool id 未命中任何活跃记录。
	ErrNotFound = errors.New("forge: not found")

	// ErrDuplicateName: name already taken by another live tool for this user.
	// ErrDuplicateName：该用户下已有同名活跃工具。
	ErrDuplicateName = errors.New("forge: name already exists")

	// ErrVersionNotFound: requested version number does not exist for the tool.
	// ErrVersionNotFound：工具下不存在该版本号。
	ErrVersionNotFound = errors.New("forge: version not found")

	// ErrPendingNotFound: accept/reject called but no pending change exists.
	// ErrPendingNotFound：调用 accept/reject 但工具没有待审核的变更。
	ErrPendingNotFound = errors.New("forge: no pending change found")

	// ErrPendingConflict: edit_tool called while an unresolved pending exists.
	// ErrPendingConflict：edit_tool 调用时已有未处理的 pending 变更。
	ErrPendingConflict = errors.New("forge: already has a pending change")

	// ErrTestCaseNotFound: test case id does not match any record for the tool.
	// ErrTestCaseNotFound：test case id 在工具下未命中任何记录。
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

// Repository is the storage contract for all tool-related entities.
// Every method scopes queries to the userID carried in ctx — callers must
// ensure the InjectUserID middleware has run.
//
// Implemented by: infra/store/tool.Store
// Consumer:       app/tool.Service (only)
//
// Repository 是所有工具相关实体的存储契约。
// 每个方法都按 ctx 中的 userID 过滤——调用方必须保证 InjectUserID 中间件已运行。
//
// 实现：infra/store/tool.Store
// 消费：仅 app/tool.Service
type Repository interface {

	// ── Forge CRUD ─────────────────────────────────────────────────────────

	// SaveForge inserts or updates a Forge by primary key.
	//
	// SaveForge 按主键插入或更新 Forge。
	SaveForge(ctx context.Context, t *Forge) error

	// GetForge fetches a single Forge by id, scoped to the current user.
	// Returns ErrNotFound if no live record matches.
	//
	// GetForge 按 id 查单条，按当前用户过滤。未命中活跃记录返回 ErrNotFound。
	GetForge(ctx context.Context, id string) (*Forge, error)

	// GetForgesByIDs fetches multiple Forges by id slice, preserving order.
	// Used by SearchForge after the LLM returns ranked IDs.
	//
	// GetForgesByIDs 按 id 切片批量查询 Forge，保持顺序。
	// 供 SearchForge 在 LLM 返回排序 ID 后取完整对象。
	GetForgesByIDs(ctx context.Context, ids []string) ([]*Forge, error)

	// ListForges returns a cursor-paginated page of live tools for the current user.
	// Returns (rows, nextCursor, err).
	//
	// ListForges 返回当前用户活跃工具的 cursor 分页结果。
	// 返回 (rows, nextCursor, err)。
	ListForges(ctx context.Context, filter ListFilter) ([]*Forge, string, error)

	// ListAllForges returns all live tools for the current user without pagination.
	// Used by SearchForge to build the full tool list for LLM ranking.
	//
	// ListAllForges 返回当前用户全部活跃工具，不分页。
	// 供 SearchForge 构建发给 LLM 排序的完整工具列表。
	ListAllForges(ctx context.Context) ([]*Forge, error)

	// DeleteForge soft-deletes a tool by id, scoped to the current user.
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
	GetVersion(ctx context.Context, toolID string, version int) (*ForgeVersion, error)

	// GetActivePending returns the current pending ForgeVersion for the tool,
	// or ErrPendingNotFound if none exists.
	//
	// GetActivePending 返回工具当前的 pending ForgeVersion。
	// 不存在时返回 ErrPendingNotFound。
	GetActivePending(ctx context.Context, toolID string) (*ForgeVersion, error)

	// ListAcceptedVersions returns all accepted versions for a tool,
	// ordered by version DESC (newest first).
	//
	// ListAcceptedVersions 返回工具所有已接受版本，按版本号降序（最新在前）。
	ListAcceptedVersions(ctx context.Context, toolID string) ([]*ForgeVersion, error)

	// UpdateVersionStatus updates the status field and optionally assigns a
	// version number (pass nil to leave it NULL, e.g. for rejection).
	//
	// UpdateVersionStatus 更新 status 字段，可选分配版本号
	// （拒绝时传 nil 保持 NULL）。
	UpdateVersionStatus(ctx context.Context, id, status string, version *int) error

	// CountAcceptedVersions returns the number of accepted versions for a tool.
	//
	// CountAcceptedVersions 返回工具已接受版本数。
	CountAcceptedVersions(ctx context.Context, toolID string) (int64, error)

	// DeleteOldestAcceptedVersion hard-deletes the accepted version with the
	// lowest version number for the given tool.
	//
	// DeleteOldestAcceptedVersion 硬删除指定工具版本号最小的已接受版本。
	DeleteOldestAcceptedVersion(ctx context.Context, toolID string) error

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

	// ListTestCases returns all test cases for the given tool, ordered by
	// created_at ASC.
	//
	// ListTestCases 返回指定工具所有测试用例，按 created_at ASC 排序。
	ListTestCases(ctx context.Context, toolID string) ([]*ForgeTestCase, error)

	// DeleteTestCase hard-deletes a test case by id.
	//
	// DeleteTestCase 硬删除测试用例。
	DeleteTestCase(ctx context.Context, id string) error

	// ── Run history ───────────────────────────────────────────────────────

	// SaveRunHistory inserts a ForgeRunHistory record.
	//
	// SaveRunHistory 插入 ForgeRunHistory 记录。
	SaveRunHistory(ctx context.Context, h *ForgeRunHistory) error

	// ListRunHistory returns the most recent limit run history records for
	// the given tool, ordered by created_at DESC.
	//
	// ListRunHistory 返回指定工具最近 limit 条运行历史，按 created_at DESC。
	ListRunHistory(ctx context.Context, toolID string, limit int) ([]*ForgeRunHistory, error)

	// CountRunHistory returns the total number of run history records for a tool.
	//
	// CountRunHistory 返回工具运行历史总条数。
	CountRunHistory(ctx context.Context, toolID string) (int64, error)

	// DeleteOldestRunHistory hard-deletes the oldest run history record for
	// the given tool.
	//
	// DeleteOldestRunHistory 硬删除指定工具最早的运行历史记录。
	DeleteOldestRunHistory(ctx context.Context, toolID string) error

	// ── Test history ──────────────────────────────────────────────────────

	// SaveTestHistory inserts a ForgeTestHistory record.
	//
	// SaveTestHistory 插入 ForgeTestHistory 记录。
	SaveTestHistory(ctx context.Context, h *ForgeTestHistory) error

	// ListTestHistory returns the most recent limit test history records for
	// the given tool, ordered by created_at DESC.
	//
	// ListTestHistory 返回指定工具最近 limit 条测试历史，按 created_at DESC。
	ListTestHistory(ctx context.Context, toolID string, limit int) ([]*ForgeTestHistory, error)

	// ListTestHistoryByBatch returns all test history records sharing the
	// given batchID, ordered by created_at ASC.
	//
	// ListTestHistoryByBatch 返回指定 batchID 的所有测试历史记录，
	// 按 created_at ASC 排序。
	ListTestHistoryByBatch(ctx context.Context, batchID string) ([]*ForgeTestHistory, error)

	// CountTestHistory returns the total number of test history records for a tool.
	//
	// CountTestHistory 返回工具测试历史总条数。
	CountTestHistory(ctx context.Context, toolID string) (int64, error)

	// DeleteOldestTestHistory hard-deletes the oldest test history record for
	// the given tool.
	//
	// DeleteOldestTestHistory 硬删除指定工具最早的测试历史记录。
	DeleteOldestTestHistory(ctx context.Context, toolID string) error
}

// ListFilter is the query shape accepted by Repository.ListForges.
//
// ListFilter 是 Repository.ListForges 接受的查询形状。
type ListFilter struct {
	Cursor string
	Limit  int
}
