// Package forge (app layer) owns the Service that orchestrates the forge domain:
// CRUD, version/pending lifecycle, sandbox execution, test cases, AI-powered
// test-case generation, and unified execution history.
//
// All three forge packages (domain / app / store) declare `package forge`;
// external callers alias at import (e.g. forgeapp "…/internal/app/forge").
//
// Package forge（app 层）负责 Service 编排 forge domain：CRUD、版本/pending
// 生命周期、沙箱执行、测试用例、AI 辅助测试用例生成、统一执行历史。
//
// 三个 forge 包均声明 `package forge`；外部调用方 import 时按角色起别名，
// 如 forgeapp "…/internal/app/forge"。
package forge

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ── Interfaces ────────────────────────────────────────────────────────────────

// Sandbox executes user Python forge code.
//
// Sandbox 执行用户 Python forge 代码。
type Sandbox interface {
	Run(ctx context.Context, code string, input map[string]any) (*forgedomain.ExecutionResult, error)
}

// LLMClient makes non-streaming LLM calls that return complete JSON responses.
// Used by GenerateTestCases. The implementation resolves model/key internally.
//
// LLMClient 进行非流式 LLM 调用，返回完整 JSON 响应。
// 供 GenerateTestCases 使用；实现层内部解析 model/key。
type LLMClient interface {
	Generate(ctx context.Context, prompt string) (string, error)
}

// GenerateResult is the synchronous return shape of GenerateTestCases.
// Either NotSupported is true (with Reason) or TestCases contains the saved cases.
//
// GenerateResult 是 GenerateTestCases 同步返回的形状。
// 要么 NotSupported=true（含 Reason），要么 TestCases 含已保存的用例。
type GenerateResult struct {
	NotSupported bool                         `json:"notSupported"`
	Reason       string                       `json:"reason,omitempty"`
	TestCases    []*forgedomain.ForgeTestCase `json:"testCases,omitempty"`
}

// ── Input / Output types ──────────────────────────────────────────────────────

// CreateInput is the request shape for Service.Create. ID is optional —
// when set (typically by a tool that pre-allocated an ID for streaming
// snapshot identity stability), Service.Create uses it; otherwise a
// fresh ID is generated.
//
// CreateInput 是 Service.Create 的请求形状。ID 可选——若调用方（通常是
// 预分配 ID 以保证流式快照身份稳定的工具）设置了 ID，Service.Create 直接
// 使用；否则生成新 ID。
type CreateInput struct {
	ID          string
	Name        string
	Description string
	Code        string
	Tags        []string
}

// UpdateInput is the request shape for Service.Update. Nil fields are unchanged.
//
// UpdateInput 是 Service.Update 的请求形状。nil 字段不更新。
type UpdateInput struct {
	Name        *string
	Description *string
	Tags        *[]string
	Code        *string
}

// PendingSnapshot is the proposed new state passed to Service.CreatePending.
// ID is optional — when set (typically by a tool that pre-allocated an ID
// for streaming snapshot identity stability), it overrides the generated one.
//
// PendingSnapshot 是传给 Service.CreatePending 的提案新状态。
// ID 可选——预分配（通常用于流式快照身份稳定）时覆盖生成 ID。
type PendingSnapshot struct {
	ID           string
	Name         string
	Description  string
	Code         string
	Tags         string // JSON string
	ChangeReason string
}

// TestCaseInput is the request shape for Service.CreateTestCase.
//
// TestCaseInput 是 Service.CreateTestCase 的请求形状。
type TestCaseInput struct {
	Name           string
	InputData      string // JSON object string
	ExpectedOutput string // JSON string; empty = no assertion
}

// ForgeDetail extends Forge with a pre-computed TestSummary for get_forge.
//
// ForgeDetail 在 Forge 基础上追加预计算的 TestSummary，供 get_forge 使用。
type ForgeDetail struct {
	*forgedomain.Forge
	TestSummary TestSummary
}

// TestSummary is a short digest of the most recent :test batch run.
//
// TestSummary 是最近一次 :test 批跑的简要摘要。
type TestSummary struct {
	Total        int    // current test case count
	LastPassRate string // "3/3" | "2/3" | "" (no record)
	LastRunAt    string // ISO 8601 or ""
}

// ── Service ───────────────────────────────────────────────────────────────────

// Service orchestrates the forge domain.
//
// Service 编排 forge domain。
type Service struct {
	repo    forgedomain.Repository
	sandbox Sandbox
	llm     LLMClient
	log     *zap.Logger
}

// NewService wires Service dependencies. Panics on nil logger.
//
// NewService 装配 Service 依赖。nil logger 会 panic。
func NewService(repo forgedomain.Repository, sandbox Sandbox, llm LLMClient, log *zap.Logger) *Service {
	if log == nil {
		panic("forgeapp.NewService: logger is nil")
	}
	return &Service{repo: repo, sandbox: sandbox, llm: llm, log: log}
}

// ── CRUD ──────────────────────────────────────────────────────────────────────

// Create parses the code, persists the Forge, and saves v1 accepted version.
// If in.ID is set the caller-provided value is used; otherwise a fresh ID
// is generated.
//
// Create 解析代码，持久化 Forge，保存 v1 已接受版本。
// in.ID 已设则用调用方传入的值；否则生成新 ID。
func (s *Service) Create(ctx context.Context, in CreateInput) (*forgedomain.Forge, error) {
	parsed, err := s.parse(in.Code)
	if err != nil {
		return nil, err
	}
	id := in.ID
	if id == "" {
		id = newID("f")
	}
	now := time.Now().UTC()
	f := &forgedomain.Forge{
		ID:           id,
		Name:         in.Name,
		Description:  in.Description,
		Code:         in.Code,
		Parameters:   parsed.parametersJSON,
		ReturnSchema: parsed.returnSchemaJSON,
		Tags:         tagsJSON(in.Tags),
		VersionCount: 1,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err = mustSetUserID(ctx, f); err != nil {
		return nil, err
	}
	if err = s.repo.SaveForge(ctx, f); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return nil, forgedomain.ErrDuplicateName
		}
		return nil, fmt.Errorf("forgeapp.Create: %w", err)
	}
	one := 1
	v := newVersion(f, forgedomain.VersionStatusAccepted, &one, "initial")
	if err = s.repo.SaveVersion(ctx, v); err != nil {
		return nil, fmt.Errorf("forgeapp.Create: save version: %w", err)
	}
	return f, nil
}

// Get fetches a single live Forge with its pending change populated (if any).
//
// Get 查询单条活跃 Forge，并填充 pending 变更（如有）。
func (s *Service) Get(ctx context.Context, id string) (*forgedomain.Forge, error) {
	f, err := s.repo.GetForge(ctx, id)
	if err != nil {
		return nil, err
	}
	s.attachPending(ctx, f)
	return f, nil
}

// GetDetail returns the Forge plus a TestSummary for get_forge system tool.
//
// GetDetail 返回 Forge 及 TestSummary，供 get_forge system tool 使用。
func (s *Service) GetDetail(ctx context.Context, id string) (*ForgeDetail, error) {
	f, err := s.repo.GetForge(ctx, id)
	if err != nil {
		return nil, err
	}
	s.attachPending(ctx, f)

	cases, _ := s.repo.ListTestCases(ctx, id)
	summary := TestSummary{Total: len(cases)}

	// Find the most recent test batch: peek at the latest test execution row,
	// then pull all rows sharing that batchID. nextCursor is irrelevant for
	// this internal lookup.
	//
	// 找最近一次 test 批次：取最新一行 test 执行，再按 batchID 拉齐整批。
	// 内部查询不关心 nextCursor。
	recent, _, _ := s.repo.ListExecutions(ctx, forgedomain.ExecutionFilter{
		ForgeID: id, Kind: forgedomain.ExecutionKindTest, Limit: 1,
	})
	if len(recent) > 0 && recent[0].BatchID != "" {
		batch, _, _ := s.repo.ListExecutions(ctx, forgedomain.ExecutionFilter{
			ForgeID: id, BatchID: recent[0].BatchID, Limit: forgedomain.MaxExecutionsPerForge,
		})
		if len(batch) > 0 {
			passed := 0
			for _, e := range batch {
				if e.Pass != nil && *e.Pass {
					passed++
				}
			}
			summary.LastPassRate = fmt.Sprintf("%d/%d", passed, len(batch))
			summary.LastRunAt = batch[len(batch)-1].CreatedAt.UTC().Format(time.RFC3339)
		}
	}
	return &ForgeDetail{Forge: f, TestSummary: summary}, nil
}

// List returns a cursor-paginated page of forges.
//
// List 返回 cursor 分页的 forge 列表。
func (s *Service) List(ctx context.Context, filter forgedomain.ListFilter) ([]*forgedomain.Forge, string, error) {
	rows, next, err := s.repo.ListForges(ctx, filter)
	if err != nil {
		return nil, "", err
	}
	for _, f := range rows {
		s.attachPending(ctx, f)
	}
	return rows, next, nil
}

// ListAll returns all live forges without pagination (used by SearchForge).
//
// ListAll 返回所有活跃 forge，不分页（供 SearchForge 使用）。
func (s *Service) ListAll(ctx context.Context) ([]*forgedomain.Forge, error) {
	return s.repo.ListAllForges(ctx)
}

// GetForgesByIDs fetches multiple live forges by ID slice, preserving order.
//
// GetForgesByIDs 按 ID 切片批量查活跃 forge，保持顺序。
func (s *Service) GetForgesByIDs(ctx context.Context, ids []string) ([]*forgedomain.Forge, error) {
	return s.repo.GetForgesByIDs(ctx, ids)
}

// ListExecutions exposes Repository.ListExecutions for handlers / system tools.
// Returns (rows, nextCursor, err); nextCursor "" means no more pages.
//
// ListExecutions 把 Repository.ListExecutions 暴露给 handler / system tool 使用。
// 返回 (rows, nextCursor, err)；nextCursor 为 "" 表示无下一页。
func (s *Service) ListExecutions(ctx context.Context, filter forgedomain.ExecutionFilter) ([]*forgedomain.ForgeExecution, string, error) {
	return s.repo.ListExecutions(ctx, filter)
}

// Update applies partial changes to a Forge. Code changes trigger an AST
// re-parse and auto-reject any active pending.
//
// Update 对 Forge 做局部更新。代码变更触发 AST 重解析并自动 reject 现有 pending。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*forgedomain.Forge, error) {
	f, err := s.repo.GetForge(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.Name != nil {
		f.Name = *in.Name
	}
	if in.Description != nil {
		f.Description = *in.Description
	}
	if in.Tags != nil {
		f.Tags = tagsJSON(*in.Tags)
	}
	if in.Code != nil {
		if err = s.autoRejectPending(ctx, id); err != nil {
			return nil, err
		}
		parsed, err := s.parse(*in.Code)
		if err != nil {
			return nil, err
		}
		f.Code = *in.Code
		f.Parameters = parsed.parametersJSON
		f.ReturnSchema = parsed.returnSchemaJSON
		f.VersionCount++
		v := newVersion(f, forgedomain.VersionStatusAccepted, &f.VersionCount, "manual edit")
		if err = s.repo.SaveVersion(ctx, v); err != nil {
			return nil, fmt.Errorf("forgeapp.Update: save version: %w", err)
		}
		if err = s.trimVersions(ctx, id); err != nil {
			return nil, err
		}
	}
	f.UpdatedAt = time.Now().UTC()
	if err = s.repo.SaveForge(ctx, f); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return nil, forgedomain.ErrDuplicateName
		}
		return nil, fmt.Errorf("forgeapp.Update: %w", err)
	}
	return f, nil
}

// Delete soft-deletes a Forge.
//
// Delete 软删除 Forge。
func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.DeleteForge(ctx, id)
}

// ── Version management ────────────────────────────────────────────────────────

// ListVersions returns accepted versions newest-first.
//
// ListVersions 返回已接受版本，最新在前。
func (s *Service) ListVersions(ctx context.Context, forgeID string) ([]*forgedomain.ForgeVersion, error) {
	return s.repo.ListAcceptedVersions(ctx, forgeID)
}

// GetVersion returns a specific accepted version.
//
// GetVersion 返回指定已接受版本。
func (s *Service) GetVersion(ctx context.Context, forgeID string, version int) (*forgedomain.ForgeVersion, error) {
	return s.repo.GetVersion(ctx, forgeID, version)
}

// RevertToVersion restores a forge to the complete snapshot of a prior version.
//
// RevertToVersion 将 forge 恢复到指定历史版本的完整快照。
func (s *Service) RevertToVersion(ctx context.Context, forgeID string, version int) (*forgedomain.Forge, error) {
	v, err := s.repo.GetVersion(ctx, forgeID, version)
	if err != nil {
		return nil, err
	}
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	if err = s.autoRejectPending(ctx, forgeID); err != nil {
		return nil, err
	}
	f.Name = v.Name
	f.Description = v.Description
	f.Code = v.Code
	f.Parameters = v.Parameters
	f.ReturnSchema = v.ReturnSchema
	f.Tags = v.Tags
	f.VersionCount++
	f.UpdatedAt = time.Now().UTC()
	reason := fmt.Sprintf("reverted to v%d", version)
	newV := newVersion(f, forgedomain.VersionStatusAccepted, &f.VersionCount, reason)
	if err = s.repo.SaveVersion(ctx, newV); err != nil {
		return nil, fmt.Errorf("forgeapp.RevertToVersion: %w", err)
	}
	if err = s.repo.SaveForge(ctx, f); err != nil {
		return nil, fmt.Errorf("forgeapp.RevertToVersion: %w", err)
	}
	if err = s.trimVersions(ctx, forgeID); err != nil {
		return nil, err
	}
	return f, nil
}

// ── Pending management ────────────────────────────────────────────────────────

// GetActivePending returns the pending ForgeVersion or ErrPendingNotFound.
//
// GetActivePending 返回 pending ForgeVersion，不存在时返回 ErrPendingNotFound。
func (s *Service) GetActivePending(ctx context.Context, forgeID string) (*forgedomain.ForgeVersion, error) {
	return s.repo.GetActivePending(ctx, forgeID)
}

// CreatePending checks for conflict, parses code if present, and saves a
// pending ForgeVersion. Called by edit_forge system tool.
//
// CreatePending 检查冲突，解析代码（如有），保存 pending ForgeVersion。
// 由 edit_forge system tool 调用。
func (s *Service) CreatePending(ctx context.Context, forgeID string, snap PendingSnapshot) (*forgedomain.ForgeVersion, error) {
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	_, err = s.repo.GetActivePending(ctx, forgeID)
	if err == nil {
		return nil, forgedomain.ErrPendingConflict
	}
	if !errors.Is(err, forgedomain.ErrPendingNotFound) {
		return nil, fmt.Errorf("forgeapp.CreatePending: %w", err)
	}

	name := f.Name
	if snap.Name != "" {
		name = snap.Name
	}
	description := f.Description
	if snap.Description != "" {
		description = snap.Description
	}
	tags := f.Tags
	if snap.Tags != "" {
		tags = snap.Tags
	}
	code := f.Code
	params := f.Parameters
	returnSchema := f.ReturnSchema
	if snap.Code != "" {
		code = snap.Code
		parsed, err := s.parse(code)
		if err != nil {
			return nil, err
		}
		params = parsed.parametersJSON
		returnSchema = parsed.returnSchemaJSON
	}

	uid, _ := uidFromForge(f)
	pendingID := snap.ID
	if pendingID == "" {
		pendingID = newID("fv")
	}
	v := &forgedomain.ForgeVersion{
		ID:           pendingID,
		ForgeID:      forgeID,
		UserID:       uid,
		Status:       forgedomain.VersionStatusPending,
		Name:         name,
		Description:  description,
		Code:         code,
		Parameters:   params,
		ReturnSchema: returnSchema,
		Tags:         tags,
		ChangeReason: snap.ChangeReason,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	if err = s.repo.SaveVersion(ctx, v); err != nil {
		return nil, fmt.Errorf("forgeapp.CreatePending: %w", err)
	}
	return v, nil
}

// AcceptPending promotes the active pending for forgeID to accepted and updates the forge.
//
// AcceptPending 将 forgeID 的 active pending 提升为 accepted，并更新 forge 主表。
func (s *Service) AcceptPending(ctx context.Context, forgeID string) (*forgedomain.Forge, error) {
	pv, err := s.repo.GetActivePending(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	f.Name = pv.Name
	f.Description = pv.Description
	f.Code = pv.Code
	f.Parameters = pv.Parameters
	f.ReturnSchema = pv.ReturnSchema
	f.Tags = pv.Tags
	f.VersionCount++
	f.UpdatedAt = time.Now().UTC()

	if err = s.repo.UpdateVersionStatus(ctx, pv.ID, forgedomain.VersionStatusAccepted, &f.VersionCount); err != nil {
		return nil, fmt.Errorf("forgeapp.AcceptPending: %w", err)
	}
	if err = s.repo.SaveForge(ctx, f); err != nil {
		return nil, fmt.Errorf("forgeapp.AcceptPending: %w", err)
	}
	if err = s.trimVersions(ctx, forgeID); err != nil {
		return nil, err
	}
	return f, nil
}

// RejectPending marks the active pending for forgeID as rejected.
//
// RejectPending 将 forgeID 的 active pending 标记为 rejected。
func (s *Service) RejectPending(ctx context.Context, forgeID string) error {
	pv, err := s.repo.GetActivePending(ctx, forgeID)
	if err != nil {
		return err
	}
	if err = s.repo.UpdateVersionStatus(ctx, pv.ID, forgedomain.VersionStatusRejected, nil); err != nil {
		return fmt.Errorf("forgeapp.RejectPending: %w", err)
	}
	return nil
}

// ── Execution ─────────────────────────────────────────────────────────────────

// RunForge executes the forge's current code in the sandbox and records an
// execution row. Chat-context (conversation/message/toolCallID) is read from
// ctx via reqctxpkg; if present, the row is tagged TriggeredByChat, otherwise
// TriggeredByHTTP. input must already have att_ids resolved by the caller.
//
// RunForge 在沙箱中执行 forge 当前代码并记录一行执行历史。chat 上下文
// （conversation/message/toolCallID）从 ctx 通过 reqctxpkg 读取；存在则标
// TriggeredByChat，否则 TriggeredByHTTP。input 中的 att_id 必须由调用方
// 预先解析为真实路径。
func (s *Service) RunForge(ctx context.Context, forgeID string, input map[string]any) (*forgedomain.ExecutionResult, error) {
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	result, err := s.sandbox.Run(ctx, f.Code, input)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", forgedomain.ErrRunFailed, err)
	}
	s.recordExecution(ctx, f, forgedomain.ExecutionKindRun, input, result, "", "", nil)
	return result, nil
}

// RunTestCase executes a single test case and records an execution row.
// batchID is empty for individual runs. Returns the persisted row so callers
// can present the result without re-querying.
//
// RunTestCase 执行单条测试用例并记录一行执行历史。单跑时 batchID 为空。
// 返回已落库的行，调用方无需再查。
func (s *Service) RunTestCase(ctx context.Context, testCaseID, batchID string) (*forgedomain.ForgeExecution, error) {
	tc, err := s.repo.GetTestCase(ctx, testCaseID)
	if err != nil {
		return nil, err
	}
	f, err := s.repo.GetForge(ctx, tc.ForgeID)
	if err != nil {
		return nil, err
	}
	var input map[string]any
	_ = json.Unmarshal([]byte(tc.InputData), &input)

	result, sandboxErr := s.sandbox.Run(ctx, f.Code, input)
	if sandboxErr != nil {
		return nil, fmt.Errorf("%w: %v", forgedomain.ErrRunFailed, sandboxErr)
	}

	var pass *bool
	if tc.ExpectedOutput != "" && result.OK {
		actual, _ := json.Marshal(result.Output)
		p := strings.TrimSpace(string(actual)) == strings.TrimSpace(tc.ExpectedOutput)
		pass = &p
	}

	return s.recordExecution(ctx, f, forgedomain.ExecutionKindTest, input, result, testCaseID, batchID, pass), nil
}

// RunAllTests runs all test cases for a forge under a shared batch ID.
//
// RunAllTests 使用共享 batchID 运行 forge 的全部测试用例。
func (s *Service) RunAllTests(ctx context.Context, forgeID string) ([]*forgedomain.ForgeExecution, error) {
	cases, err := s.repo.ListTestCases(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	batchID := newID("b")
	results := make([]*forgedomain.ForgeExecution, 0, len(cases))
	for _, tc := range cases {
		r, err := s.RunTestCase(ctx, tc.ID, batchID)
		if err != nil {
			return nil, err
		}
		results = append(results, r)
	}
	return results, nil
}

// recordExecution serialises the input/output, fills chat context from ctx,
// inserts a ForgeExecution row, and trims oldest if MaxExecutionsPerForge is
// exceeded. Returns the row written for the caller's convenience.
//
// recordExecution 序列化 input/output，从 ctx 填 chat 上下文，插入 ForgeExecution
// 行，并在超过 MaxExecutionsPerForge 时裁剪最旧记录。返回已落库行供调用方使用。
func (s *Service) recordExecution(
	ctx context.Context,
	f *forgedomain.Forge,
	kind string,
	input map[string]any,
	result *forgedomain.ExecutionResult,
	testCaseID, batchID string,
	pass *bool,
) *forgedomain.ForgeExecution {
	inputJSON, _ := json.Marshal(input)
	outputJSON := ""
	if result.Output != nil {
		if b, e := json.Marshal(result.Output); e == nil {
			outputJSON = string(b)
		}
	}
	uid, _ := uidFromForge(f)

	convID, _ := reqctxpkg.GetConversationID(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	triggeredBy := forgedomain.TriggeredByHTTP
	if convID != "" {
		triggeredBy = forgedomain.TriggeredByChat
	}

	e := &forgedomain.ForgeExecution{
		ID:             newID("fe"),
		ForgeID:        f.ID,
		UserID:         uid,
		ForgeVersion:   f.VersionCount,
		Kind:           kind,
		Input:          string(inputJSON),
		Output:         outputJSON,
		OK:             result.OK,
		ErrorMsg:       result.ErrorMsg,
		ElapsedMs:      result.ElapsedMs,
		TestCaseID:     testCaseID,
		BatchID:        batchID,
		Pass:           pass,
		TriggeredBy:    triggeredBy,
		ConversationID: convID,
		MessageID:      msgID,
		ToolCallID:     toolCallID,
		CreatedAt:      time.Now().UTC(),
	}
	if err := s.repo.SaveExecution(ctx, e); err != nil {
		s.log.Warn("recordExecution: save failed",
			zap.String("forge_id", f.ID), zap.String("kind", kind), zap.Error(err))
		return e
	}
	if n, _ := s.repo.CountExecutions(ctx, f.ID); n > forgedomain.MaxExecutionsPerForge {
		_ = s.repo.DeleteOldestExecution(ctx, f.ID)
	}
	return e
}

// ── Test cases ────────────────────────────────────────────────────────────────

// CreateTestCase adds a test case to a forge.
//
// CreateTestCase 为 forge 添加测试用例。
func (s *Service) CreateTestCase(ctx context.Context, forgeID string, in TestCaseInput) (*forgedomain.ForgeTestCase, error) {
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	uid, _ := uidFromForge(f)
	tc := &forgedomain.ForgeTestCase{
		ID:             newID("tc"),
		ForgeID:        forgeID,
		UserID:         uid,
		Name:           in.Name,
		InputData:      in.InputData,
		ExpectedOutput: in.ExpectedOutput,
		CreatedAt:      time.Now().UTC(),
		UpdatedAt:      time.Now().UTC(),
	}
	if err = s.repo.SaveTestCase(ctx, tc); err != nil {
		return nil, fmt.Errorf("forgeapp.CreateTestCase: %w", err)
	}
	return tc, nil
}

// ListTestCases returns all test cases for a forge.
//
// ListTestCases 返回 forge 所有测试用例。
func (s *Service) ListTestCases(ctx context.Context, forgeID string) ([]*forgedomain.ForgeTestCase, error) {
	return s.repo.ListTestCases(ctx, forgeID)
}

// DeleteTestCase hard-deletes a test case.
//
// DeleteTestCase 硬删除测试用例。
func (s *Service) DeleteTestCase(ctx context.Context, id string) error {
	return s.repo.DeleteTestCase(ctx, id)
}

// GenerateTestCases asks the LLM to generate test cases and returns them
// as a single batch. The LLM call is non-streaming, so any "streaming" of
// individual cases would be cosmetic—plain JSON keeps the contract simple.
//
// GenerateTestCases 请求 LLM 一次性生成测试用例并整批返回。
// LLM 调用本身是非流式的，逐条"流式推送"只是化妆——直接返回 JSON 更清晰。
func (s *Service) GenerateTestCases(ctx context.Context, forgeID string, count int) (*GenerateResult, error) {
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	prompt := buildGeneratePrompt(f, count)
	raw, err := s.llm.Generate(ctx, prompt)
	if err != nil {
		return nil, fmt.Errorf("forgeapp.GenerateTestCases: llm: %w", err)
	}
	jsonRaw := extractJSONFromLLM(raw)
	var resp struct {
		NotSupported bool   `json:"not_supported"`
		Reason       string `json:"reason"`
		TestCases    []struct {
			Name           string          `json:"name"`
			Input          json.RawMessage `json:"input"`
			ExpectedOutput json.RawMessage `json:"expected_output"`
		} `json:"test_cases"`
	}
	if err = json.Unmarshal([]byte(jsonRaw), &resp); err != nil {
		return nil, fmt.Errorf("forgeapp.GenerateTestCases: parse response: %w", err)
	}
	if resp.NotSupported {
		return &GenerateResult{NotSupported: true, Reason: resp.Reason}, nil
	}
	uid, _ := uidFromForge(f)
	saved := make([]*forgedomain.ForgeTestCase, 0, len(resp.TestCases))
	for _, tc := range resp.TestCases {
		item := &forgedomain.ForgeTestCase{
			ID:             newID("tc"),
			ForgeID:        forgeID,
			UserID:         uid,
			Name:           tc.Name,
			InputData:      string(tc.Input),
			ExpectedOutput: string(tc.ExpectedOutput),
			CreatedAt:      time.Now().UTC(),
			UpdatedAt:      time.Now().UTC(),
		}
		if err = s.repo.SaveTestCase(ctx, item); err != nil {
			return nil, fmt.Errorf("forgeapp.GenerateTestCases: save: %w", err)
		}
		saved = append(saved, item)
	}
	return &GenerateResult{TestCases: saved}, nil
}

// ── Import / Export ───────────────────────────────────────────────────────────

// exportShape is the JSON shape for forge export/import.
//
// exportShape 是 forge 导入/导出的 JSON 形状。
type exportShape struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Code        string          `json:"code"`
	Tags        []string        `json:"tags"`
	TestCases   []TestCaseInput `json:"testCases"`
}

// Export serialises a forge and its test cases to JSON.
//
// Export 把 forge 及测试用例序列化为 JSON。
func (s *Service) Export(ctx context.Context, forgeID string) ([]byte, error) {
	f, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	cases, err := s.repo.ListTestCases(ctx, forgeID)
	if err != nil {
		s.log.Warn("export: failed to list test cases, exporting without them",
			zap.String("forge_id", forgeID), zap.Error(err))
		cases = nil
	}
	var tags []string
	if err := json.Unmarshal([]byte(f.Tags), &tags); err != nil {
		s.log.Warn("export: malformed tags JSON, exporting empty tags",
			zap.String("forge_id", forgeID), zap.Error(err))
		tags = nil
	}
	tcInputs := make([]TestCaseInput, len(cases))
	for i, tc := range cases {
		tcInputs[i] = TestCaseInput{Name: tc.Name, InputData: tc.InputData, ExpectedOutput: tc.ExpectedOutput}
	}
	return json.Marshal(exportShape{
		Name: f.Name, Description: f.Description, Code: f.Code,
		Tags: tags, TestCases: tcInputs,
	})
}

// Import creates a new forge from exported JSON, including test cases.
//
// Import 从导出的 JSON 新建 forge，包含测试用例。
func (s *Service) Import(ctx context.Context, data []byte) (*forgedomain.Forge, error) {
	var shape exportShape
	if err := json.Unmarshal(data, &shape); err != nil || shape.Name == "" || shape.Code == "" {
		return nil, forgedomain.ErrImportInvalid
	}
	f, err := s.Create(ctx, CreateInput{
		Name: shape.Name, Description: shape.Description,
		Code: shape.Code, Tags: shape.Tags,
	})
	if err != nil {
		return nil, err
	}
	for _, tc := range shape.TestCases {
		if _, err := s.CreateTestCase(ctx, f.ID, tc); err != nil {
			s.log.Warn("import: skipped test case",
				zap.String("forge_id", f.ID),
				zap.String("test_case_name", tc.Name),
				zap.Error(err),
			)
		}
	}
	return f, nil
}

// ── Internal helpers ──────────────────────────────────────────────────────────

type parsedFields struct {
	parametersJSON   string
	returnSchemaJSON string
}

// ParseCode validates that code is parseable as a single-function Python forge.
// Returns forgedomain.ErrASTParseError if AST parsing fails. Used by callers
// (e.g. CreateForge system tool) to dry-run validation before calling Create()
// which also does storage I/O — keeps the error path simple and fast.
//
// ParseCode 验证 code 是否可解析为单函数 Python forge。AST 解析失败返
// forgedomain.ErrASTParseError。供调用方（如 CreateForge 系统工具）在调用
// Create()（含存储 I/O）前先做 dry-run 验证——错误路径简单且快。
func (s *Service) ParseCode(code string) error {
	_, err := s.parse(code)
	return err
}

func (s *Service) parse(code string) (parsedFields, error) {
	p, err := parseForgeCode(code)
	if err != nil {
		return parsedFields{}, forgedomain.ErrASTParseError
	}
	params := make([]map[string]any, len(p.Parameters))
	for i, pp := range p.Parameters {
		m := map[string]any{
			"name": pp.Name, "type": pp.Type,
			"required": pp.Required, "description": pp.Description,
		}
		if pp.Default != nil {
			m["default"] = *pp.Default
		} else {
			m["default"] = nil
		}
		params[i] = m
	}
	pb, _ := json.Marshal(params)
	rb, _ := json.Marshal(map[string]string{"type": p.Return.Type, "description": p.Return.Description})
	return parsedFields{parametersJSON: string(pb), returnSchemaJSON: string(rb)}, nil
}

func (s *Service) autoRejectPending(ctx context.Context, forgeID string) error {
	v, err := s.repo.GetActivePending(ctx, forgeID)
	if errors.Is(err, forgedomain.ErrPendingNotFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("forgeapp.autoRejectPending: %w", err)
	}
	return s.repo.UpdateVersionStatus(ctx, v.ID, forgedomain.VersionStatusRejected, nil)
}

// attachPending best-effort populates f.Pending from the pending row, if any.
// Errors other than ErrPendingNotFound are logged and the field is left nil.
//
// attachPending 尽力填充 f.Pending；除 ErrPendingNotFound 外的错误记日志并
// 保持字段为 nil。
func (s *Service) attachPending(ctx context.Context, f *forgedomain.Forge) {
	pv, err := s.repo.GetActivePending(ctx, f.ID)
	if err == nil {
		f.Pending = pv
		return
	}
	if !errors.Is(err, forgedomain.ErrPendingNotFound) {
		s.log.Warn("attachPending: failed to query",
			zap.String("forge_id", f.ID), zap.Error(err))
	}
}

func (s *Service) trimVersions(ctx context.Context, forgeID string) error {
	n, err := s.repo.CountAcceptedVersions(ctx, forgeID)
	if err != nil {
		return fmt.Errorf("forgeapp.trimVersions: %w", err)
	}
	if n > forgedomain.MaxAcceptedVersions {
		return s.repo.DeleteOldestAcceptedVersion(ctx, forgeID)
	}
	return nil
}

func newVersion(f *forgedomain.Forge, status string, version *int, changeReason string) *forgedomain.ForgeVersion {
	now := time.Now().UTC()
	return &forgedomain.ForgeVersion{
		ID:           newID("fv"),
		ForgeID:      f.ID,
		UserID:       f.UserID,
		Version:      version,
		Status:       status,
		Name:         f.Name,
		Description:  f.Description,
		Code:         f.Code,
		Parameters:   f.Parameters,
		ReturnSchema: f.ReturnSchema,
		Tags:         f.Tags,
		ChangeReason: changeReason,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
}

// NewForgeID returns a fresh forge entity ID ("f_<16hex>"). Exposed so
// callers (e.g. the create_forge system tool) can pre-allocate an ID for
// stable identity across streaming snapshots before the entity is persisted.
//
// NewForgeID 返回新的 forge 主键 ID（"f_<16hex>"）。导出供调用方
// （如 create_forge 系统工具）在落库前预分配，使流式快照身份稳定。
func NewForgeID() string { return newID("f") }

// NewVersionID returns a fresh forge_version entity ID ("fv_<16hex>").
// Same use-case as NewForgeID but for the pending row in edit_forge.
//
// NewVersionID 返回新的 forge_version 主键 ID（"fv_<16hex>"）。
// 用途同 NewForgeID，但用于 edit_forge 的 pending 行。
func NewVersionID() string { return newID("fv") }

func newID(prefix string) string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		// crypto/rand failure means broken entropy source — IDs would
		// collide, so fail loudly and let the caller crash.
		//
		// crypto/rand 失败说明熵源损坏——继续会生成碰撞 ID，必须立刻 panic。
		panic(fmt.Sprintf("forge: crypto/rand failed: %v", err))
	}
	return prefix + "_" + hex.EncodeToString(b)
}

func tagsJSON(tags []string) string {
	if tags == nil {
		tags = []string{}
	}
	b, _ := json.Marshal(tags)
	return string(b)
}

func mustSetUserID(ctx context.Context, f *forgedomain.Forge) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("forgeapp: %w", err)
	}
	f.UserID = uid
	return nil
}

// extractJSONFromLLM strips markdown code fences that LLMs often wrap around
// JSON responses, then finds the outermost JSON object or array.
// Returns the original string unchanged if no JSON delimiter is found.
func extractJSONFromLLM(s string) string {
	s = strings.TrimSpace(s)
	for _, fence := range []string{"```json\n", "```\n", "```json", "```"} {
		if after, ok := strings.CutPrefix(s, fence); ok {
			s = after
			if idx := strings.LastIndex(s, "```"); idx >= 0 {
				s = s[:idx]
			}
			s = strings.TrimSpace(s)
			break
		}
	}
	for _, pair := range [][2]byte{{'{', '}'}, {'[', ']'}} {
		start := strings.IndexByte(s, pair[0])
		end := strings.LastIndexByte(s, pair[1])
		if start >= 0 && end > start {
			return s[start : end+1]
		}
	}
	return s
}

func uidFromForge(f *forgedomain.Forge) (string, bool) {
	return f.UserID, f.UserID != ""
}

func buildGeneratePrompt(f *forgedomain.Forge, count int) string {
	return fmt.Sprintf(`Analyze this Python function and generate test cases.

Function name: %s
Description: %s
Code:
%s

If the function depends on external state (file paths, network, randomness, side effects),
respond with: {"not_supported": true, "reason": "<explanation>"}

Otherwise, generate %d diverse test cases and respond with:
{"test_cases": [{"name": "<name>", "input": <json_object>, "expected_output": <json_value>}, ...]}

Respond with valid JSON only, no explanation.`,
		f.Name, f.Description, f.Code, count)
}
