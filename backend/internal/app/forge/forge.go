// Package tool (app layer) owns the Service that orchestrates the tool domain:
// CRUD, version/pending lifecycle, sandbox execution, test cases, and
// AI-powered test-case generation.
//
// All three tool packages (domain / app / store) declare `package forge`;
// external callers alias at import (e.g. forgeapp "…/internal/app/forge").
//
// Package tool（app 层）负责 Service 编排 tool domain：CRUD、版本/pending
// 生命周期、沙箱执行、测试用例和 AI 辅助测试用例生成。
//
// 三个 tool 包均声明 `package forge`；外部调用方 import 时按角色起别名，
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

// Sandbox executes user Python tool code.
//
// Sandbox 执行用户 Python 工具代码。
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
	NotSupported bool                       `json:"notSupported"`
	Reason       string                     `json:"reason,omitempty"`
	TestCases    []*forgedomain.ForgeTestCase `json:"testCases,omitempty"`
}

// ── Input / Output types ──────────────────────────────────────────────────────

// CreateInput is the request shape for Service.Create.
//
// CreateInput 是 Service.Create 的请求形状。
type CreateInput struct {
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
//
// PendingSnapshot 是传给 Service.CreatePending 的提案新状态。
type PendingSnapshot struct {
	Name        string
	Description string
	Code        string
	Tags        string // JSON string
	Instruction string
}

// TestCaseInput is the request shape for Service.CreateTestCase.
//
// TestCaseInput 是 Service.CreateTestCase 的请求形状。
type TestCaseInput struct {
	Name           string
	InputData      string // JSON object string
	ExpectedOutput string // JSON string; empty = no assertion
}

// TestRunResult is the outcome of a single test case execution.
//
// TestRunResult 是单次测试用例执行的结果。
type TestRunResult struct {
	TestCaseID string
	Name       string
	Input      string
	Output     string
	OK         bool
	Pass       *bool
	ErrorMsg   string
	ElapsedMs  int64
}

// ForgeDetail extends Forge with a pre-computed TestSummary for get_tool.
//
// ForgeDetail 在 Forge 基础上追加预计算的 TestSummary，供 get_tool 使用。
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

// Service orchestrates the tool domain.
//
// Service 编排 tool domain。
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
//
// Create 解析代码，持久化 Forge，保存 v1 已接受版本。
func (s *Service) Create(ctx context.Context, in CreateInput) (*forgedomain.Forge, error) {
	parsed, err := s.parse(in.Code)
	if err != nil {
		return nil, err
	}
	id := newID("f")
	now := time.Now().UTC()
	t := &forgedomain.Forge{
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
	if err = mustSetUserID(ctx, t); err != nil {
		return nil, err
	}
	if err = s.repo.SaveForge(ctx, t); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return nil, forgedomain.ErrDuplicateName
		}
		return nil, fmt.Errorf("forgeapp.Create: %w", err)
	}
	one := 1
	v := newVersion(t, forgedomain.VersionStatusAccepted, &one, "initial")
	if err = s.repo.SaveVersion(ctx, v); err != nil {
		return nil, fmt.Errorf("forgeapp.Create: save version: %w", err)
	}
	return t, nil
}

// Get fetches a single live Forge.
//
// Get 查询单条活跃 Forge。
func (s *Service) Get(ctx context.Context, id string) (*forgedomain.Forge, error) {
	return s.repo.GetForge(ctx, id)
}

// GetDetail returns the Forge plus a TestSummary for get_tool system tool.
//
// GetDetail 返回 Forge 及 TestSummary，供 get_tool system tool 使用。
func (s *Service) GetDetail(ctx context.Context, id string) (*ForgeDetail, error) {
	t, err := s.repo.GetForge(ctx, id)
	if err != nil {
		return nil, err
	}
	cases, _ := s.repo.ListTestCases(ctx, id)
	summary := TestSummary{Total: len(cases)}

	// Last batch: find most recent batchID from test history.
	hist, _ := s.repo.ListTestHistory(ctx, id, 200)
	if len(hist) > 0 && hist[0].BatchID != "" {
		lastBatch, _ := s.repo.ListTestHistoryByBatch(ctx, hist[0].BatchID)
		if len(lastBatch) > 0 {
			passed := 0
			for _, h := range lastBatch {
				if h.Pass != nil && *h.Pass {
					passed++
				}
			}
			summary.LastPassRate = fmt.Sprintf("%d/%d", passed, len(lastBatch))
			summary.LastRunAt = lastBatch[len(lastBatch)-1].CreatedAt.UTC().Format(time.RFC3339)
		}
	}
	return &ForgeDetail{Forge: t, TestSummary: summary}, nil
}

// List returns a cursor-paginated page of tools.
//
// List 返回 cursor 分页的工具列表。
func (s *Service) List(ctx context.Context, filter forgedomain.ListFilter) ([]*forgedomain.Forge, string, error) {
	return s.repo.ListForges(ctx, filter)
}

// ListAll returns all live tools without pagination (used by SearchForge).
//
// ListAll 返回所有活跃工具，不分页（供 SearchForge 使用）。
func (s *Service) ListAll(ctx context.Context) ([]*forgedomain.Forge, error) {
	return s.repo.ListAllForges(ctx)
}

// GetForgesByIDs fetches multiple live tools by ID slice, preserving order.
//
// GetForgesByIDs 按 ID 切片批量查活跃工具，保持顺序。
func (s *Service) GetForgesByIDs(ctx context.Context, ids []string) ([]*forgedomain.Forge, error) {
	return s.repo.GetForgesByIDs(ctx, ids)
}

// ListRunHistoryForForge returns recent run history for a tool.
//
// ListRunHistoryForForge 返回工具最近的运行历史。
func (s *Service) ListRunHistoryForForge(ctx context.Context, forgeID string, limit int) ([]*forgedomain.ForgeRunHistory, error) {
	return s.repo.ListRunHistory(ctx, forgeID, limit)
}

// ListTestHistoryForForge returns recent test history for a tool.
//
// ListTestHistoryForForge 返回工具最近的测试历史。
func (s *Service) ListTestHistoryForForge(ctx context.Context, forgeID string, limit int) ([]*forgedomain.ForgeTestHistory, error) {
	return s.repo.ListTestHistory(ctx, forgeID, limit)
}

// ListTestHistoryByBatch returns test history records for a batch run.
//
// ListTestHistoryByBatch 返回指定批次的测试历史记录。
func (s *Service) ListTestHistoryByBatch(ctx context.Context, batchID string) ([]*forgedomain.ForgeTestHistory, error) {
	return s.repo.ListTestHistoryByBatch(ctx, batchID)
}

// Update applies partial changes to a Forge. Code changes trigger an AST
// re-parse and auto-reject any active pending.
//
// Update 对 Forge 做局部更新。代码变更触发 AST 重解析并自动 reject 现有 pending。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*forgedomain.Forge, error) {
	t, err := s.repo.GetForge(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.Name != nil {
		t.Name = *in.Name
	}
	if in.Description != nil {
		t.Description = *in.Description
	}
	if in.Tags != nil {
		t.Tags = tagsJSON(*in.Tags)
	}
	if in.Code != nil {
		if err = s.autoRejectPending(ctx, id); err != nil {
			return nil, err
		}
		parsed, err := s.parse(*in.Code)
		if err != nil {
			return nil, err
		}
		t.Code = *in.Code
		t.Parameters = parsed.parametersJSON
		t.ReturnSchema = parsed.returnSchemaJSON
		t.VersionCount++
		v := newVersion(t, forgedomain.VersionStatusAccepted, &t.VersionCount, "manual edit")
		if err = s.repo.SaveVersion(ctx, v); err != nil {
			return nil, fmt.Errorf("forgeapp.Update: save version: %w", err)
		}
		if err = s.trimVersions(ctx, id); err != nil {
			return nil, err
		}
	}
	t.UpdatedAt = time.Now().UTC()
	if err = s.repo.SaveForge(ctx, t); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return nil, forgedomain.ErrDuplicateName
		}
		return nil, fmt.Errorf("forgeapp.Update: %w", err)
	}
	return t, nil
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

// RevertToVersion restores a tool to the complete snapshot of a prior version.
//
// RevertToVersion 将工具恢复到指定历史版本的完整快照。
func (s *Service) RevertToVersion(ctx context.Context, forgeID string, version int) (*forgedomain.Forge, error) {
	v, err := s.repo.GetVersion(ctx, forgeID, version)
	if err != nil {
		return nil, err
	}
	t, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	if err = s.autoRejectPending(ctx, forgeID); err != nil {
		return nil, err
	}
	t.Name = v.Name
	t.Description = v.Description
	t.Code = v.Code
	t.Parameters = v.Parameters
	t.ReturnSchema = v.ReturnSchema
	t.Tags = v.Tags
	t.VersionCount++
	t.UpdatedAt = time.Now().UTC()
	msg := fmt.Sprintf("reverted to v%d", version)
	newV := newVersion(t, forgedomain.VersionStatusAccepted, &t.VersionCount, msg)
	if err = s.repo.SaveVersion(ctx, newV); err != nil {
		return nil, fmt.Errorf("forgeapp.RevertToVersion: %w", err)
	}
	if err = s.repo.SaveForge(ctx, t); err != nil {
		return nil, fmt.Errorf("forgeapp.RevertToVersion: %w", err)
	}
	if err = s.trimVersions(ctx, forgeID); err != nil {
		return nil, err
	}
	return t, nil
}

// ── Pending management ────────────────────────────────────────────────────────

// GetActivePending returns the pending ForgeVersion or ErrPendingNotFound.
//
// GetActivePending 返回 pending ForgeVersion，不存在时返回 ErrPendingNotFound。
func (s *Service) GetActivePending(ctx context.Context, forgeID string) (*forgedomain.ForgeVersion, error) {
	return s.repo.GetActivePending(ctx, forgeID)
}

// CreatePending checks for conflict, parses code if present, and saves a
// pending ForgeVersion. Called by edit_tool system tool.
//
// CreatePending 检查冲突，解析代码（如有），保存 pending ForgeVersion。
// 由 edit_tool system tool 调用。
func (s *Service) CreatePending(ctx context.Context, forgeID string, snap PendingSnapshot) (*forgedomain.ForgeVersion, error) {
	t, err := s.repo.GetForge(ctx, forgeID)
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

	// Use snapshot fields if provided; fall back to current tool state.
	name := t.Name
	if snap.Name != "" {
		name = snap.Name
	}
	description := t.Description
	if snap.Description != "" {
		description = snap.Description
	}
	tags := t.Tags
	if snap.Tags != "" {
		tags = snap.Tags
	}
	code := t.Code
	params := t.Parameters
	returnSchema := t.ReturnSchema
	if snap.Code != "" {
		code = snap.Code
		parsed, err := s.parse(code)
		if err != nil {
			return nil, err
		}
		params = parsed.parametersJSON
		returnSchema = parsed.returnSchemaJSON
	}

	uid, _ := uidFromForge(t)
	v := &forgedomain.ForgeVersion{
		ID:           newID("fv"),
		ForgeID:       forgeID,
		UserID:       uid,
		Status:       forgedomain.VersionStatusPending,
		Name:         name,
		Description:  description,
		Code:         code,
		Parameters:   params,
		ReturnSchema: returnSchema,
		Tags:         tags,
		Message:      snap.Instruction,
		CreatedAt:    time.Now().UTC(),
		UpdatedAt:    time.Now().UTC(),
	}
	if err = s.repo.SaveVersion(ctx, v); err != nil {
		return nil, fmt.Errorf("forgeapp.CreatePending: %w", err)
	}
	return v, nil
}

// AcceptPending promotes the active pending for forgeID to accepted and updates the tool.
//
// AcceptPending 将 forgeID 的 active pending 提升为 accepted，并更新工具主表。
func (s *Service) AcceptPending(ctx context.Context, forgeID string) (*forgedomain.Forge, error) {
	pv, err := s.repo.GetActivePending(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	t, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	t.Name = pv.Name
	t.Description = pv.Description
	t.Code = pv.Code
	t.Parameters = pv.Parameters
	t.ReturnSchema = pv.ReturnSchema
	t.Tags = pv.Tags
	t.VersionCount++
	t.UpdatedAt = time.Now().UTC()

	if err = s.repo.UpdateVersionStatus(ctx, pv.ID, forgedomain.VersionStatusAccepted, &t.VersionCount); err != nil {
		return nil, fmt.Errorf("forgeapp.AcceptPending: %w", err)
	}
	if err = s.repo.SaveForge(ctx, t); err != nil {
		return nil, fmt.Errorf("forgeapp.AcceptPending: %w", err)
	}
	if err = s.trimVersions(ctx, forgeID); err != nil {
		return nil, err
	}
	return t, nil
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

// RunForge executes the tool's current code in the sandbox and records history.
// input must already have att_ids resolved to file paths by the caller.
//
// RunForge 在沙箱中执行工具当前代码并记录历史。
// input 中的 att_id 必须由调用方预先解析为真实路径。
func (s *Service) RunForge(ctx context.Context, forgeID string, input map[string]any) (*forgedomain.ExecutionResult, error) {
	t, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	result, err := s.sandbox.Run(ctx, t.Code, input)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", forgedomain.ErrRunFailed, err)
	}
	inputJSON, _ := json.Marshal(input)
	outputJSON := ""
	if result.Output != nil {
		if b, e := json.Marshal(result.Output); e == nil {
			outputJSON = string(b)
		}
	}
	uid, _ := uidFromForge(t)
	h := &forgedomain.ForgeRunHistory{
		ID:          newID("frh"),
		ForgeID:      forgeID,
		UserID:      uid,
		ForgeVersion: t.VersionCount,
		Input:       string(inputJSON),
		Output:      outputJSON,
		OK:          result.OK,
		ErrorMsg:    result.ErrorMsg,
		ElapsedMs:   result.ElapsedMs,
		CreatedAt:   time.Now().UTC(),
	}
	_ = s.repo.SaveRunHistory(ctx, h)
	if n, _ := s.repo.CountRunHistory(ctx, forgeID); n > forgedomain.MaxRunHistoryPerForge {
		_ = s.repo.DeleteOldestRunHistory(ctx, forgeID)
	}
	return result, nil
}

// ── Test cases ────────────────────────────────────────────────────────────────

// CreateTestCase adds a test case to a tool.
//
// CreateTestCase 为工具添加测试用例。
func (s *Service) CreateTestCase(ctx context.Context, forgeID string, in TestCaseInput) (*forgedomain.ForgeTestCase, error) {
	t, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	uid, _ := uidFromForge(t)
	tc := &forgedomain.ForgeTestCase{
		ID:             newID("tc"),
		ForgeID:         forgeID,
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

// ListTestCases returns all test cases for a tool.
//
// ListTestCases 返回工具所有测试用例。
func (s *Service) ListTestCases(ctx context.Context, forgeID string) ([]*forgedomain.ForgeTestCase, error) {
	return s.repo.ListTestCases(ctx, forgeID)
}

// DeleteTestCase hard-deletes a test case.
//
// DeleteTestCase 硬删除测试用例。
func (s *Service) DeleteTestCase(ctx context.Context, id string) error {
	return s.repo.DeleteTestCase(ctx, id)
}

// RunTestCase executes a single test case and records history.
// batchID is empty for individual runs.
//
// RunTestCase 执行单条测试用例并记录历史。单跑时 batchID 为空。
func (s *Service) RunTestCase(ctx context.Context, testCaseID, batchID string) (*TestRunResult, error) {
	tc, err := s.repo.GetTestCase(ctx, testCaseID)
	if err != nil {
		return nil, err
	}
	t, err := s.repo.GetForge(ctx, tc.ForgeID)
	if err != nil {
		return nil, err
	}
	var input map[string]any
	_ = json.Unmarshal([]byte(tc.InputData), &input)

	result, sandboxErr := s.sandbox.Run(ctx, t.Code, input)
	if sandboxErr != nil {
		return nil, fmt.Errorf("%w: %v", forgedomain.ErrRunFailed, sandboxErr)
	}

	var pass *bool
	if tc.ExpectedOutput != "" && result.OK {
		actual, _ := json.Marshal(result.Output)
		p := strings.TrimSpace(string(actual)) == strings.TrimSpace(tc.ExpectedOutput)
		pass = &p
	}

	outputJSON := ""
	if b, e := json.Marshal(result.Output); e == nil {
		outputJSON = string(b)
	}

	uid, _ := uidFromForge(t)
	h := &forgedomain.ForgeTestHistory{
		ID:          newID("fth"),
		ForgeID:      t.ID,
		UserID:      uid,
		ForgeVersion: t.VersionCount,
		TestCaseID:  testCaseID,
		BatchID:     batchID,
		Input:       tc.InputData,
		Output:      outputJSON,
		OK:          result.OK,
		Pass:        pass,
		ErrorMsg:    result.ErrorMsg,
		ElapsedMs:   result.ElapsedMs,
		CreatedAt:   time.Now().UTC(),
	}
	_ = s.repo.SaveTestHistory(ctx, h)
	if n, _ := s.repo.CountTestHistory(ctx, t.ID); n > forgedomain.MaxTestHistoryPerForge {
		_ = s.repo.DeleteOldestTestHistory(ctx, t.ID)
	}

	return &TestRunResult{
		TestCaseID: testCaseID,
		Name:       tc.Name,
		Input:      tc.InputData,
		Output:     outputJSON,
		OK:         result.OK,
		Pass:       pass,
		ErrorMsg:   result.ErrorMsg,
		ElapsedMs:  result.ElapsedMs,
	}, nil
}

// RunAllTests runs all test cases for a tool under a shared batch ID.
//
// RunAllTests 使用共享 batchID 运行工具的全部测试用例。
func (s *Service) RunAllTests(ctx context.Context, forgeID string) ([]*TestRunResult, error) {
	cases, err := s.repo.ListTestCases(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	batchID := newID("b")
	results := make([]*TestRunResult, 0, len(cases))
	for _, tc := range cases {
		r, err := s.RunTestCase(ctx, tc.ID, batchID)
		if err != nil {
			return nil, err
		}
		results = append(results, r)
	}
	return results, nil
}

// GenerateTestCases asks the LLM to generate test cases and returns them
// as a single batch. The LLM call is non-streaming, so any "streaming" of
// individual cases would be cosmetic—plain JSON keeps the contract simple.
//
// GenerateTestCases 请求 LLM 一次性生成测试用例并整批返回。
// LLM 调用本身是非流式的，逐条"流式推送"只是化妆——直接返回 JSON 更清晰。
func (s *Service) GenerateTestCases(ctx context.Context, forgeID string, count int) (*GenerateResult, error) {
	t, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	prompt := buildGeneratePrompt(t, count)
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
	uid, _ := uidFromForge(t)
	saved := make([]*forgedomain.ForgeTestCase, 0, len(resp.TestCases))
	for _, tc := range resp.TestCases {
		item := &forgedomain.ForgeTestCase{
			ID:             newID("tc"),
			ForgeID:         forgeID,
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

// exportShape is the JSON shape for tool export/import.
//
// exportShape 是工具导入/导出的 JSON 形状。
type exportShape struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Code        string          `json:"code"`
	Tags        []string        `json:"tags"`
	TestCases   []TestCaseInput `json:"testCases"`
}

// Export serialises a tool and its test cases to JSON.
//
// Export 把工具及测试用例序列化为 JSON。
func (s *Service) Export(ctx context.Context, forgeID string) ([]byte, error) {
	t, err := s.repo.GetForge(ctx, forgeID)
	if err != nil {
		return nil, err
	}
	cases, err := s.repo.ListTestCases(ctx, forgeID)
	if err != nil {
		// Test cases failure shouldn't block exporting the tool body itself —
		// degrade gracefully but log so the user can see the partial export.
		//
		// 测试用例查询失败不应阻止工具本身的导出——降级处理但记日志。
		s.log.Warn("export: failed to list test cases, exporting without them",
			zap.String("forge_id", forgeID), zap.Error(err))
		cases = nil
	}
	var tags []string
	if err := json.Unmarshal([]byte(t.Tags), &tags); err != nil {
		s.log.Warn("export: malformed tags JSON, exporting empty tags",
			zap.String("forge_id", forgeID), zap.Error(err))
		tags = nil
	}
	tcInputs := make([]TestCaseInput, len(cases))
	for i, tc := range cases {
		tcInputs[i] = TestCaseInput{Name: tc.Name, InputData: tc.InputData, ExpectedOutput: tc.ExpectedOutput}
	}
	return json.Marshal(exportShape{
		Name: t.Name, Description: t.Description, Code: t.Code,
		Tags: tags, TestCases: tcInputs,
	})
}

// Import creates a new tool from exported JSON, including test cases.
//
// Import 从导出的 JSON 新建工具，包含测试用例。
func (s *Service) Import(ctx context.Context, data []byte) (*forgedomain.Forge, error) {
	var shape exportShape
	if err := json.Unmarshal(data, &shape); err != nil || shape.Name == "" || shape.Code == "" {
		return nil, forgedomain.ErrImportInvalid
	}
	t, err := s.Create(ctx, CreateInput{
		Name: shape.Name, Description: shape.Description,
		Code: shape.Code, Tags: shape.Tags,
	})
	if err != nil {
		return nil, err
	}
	// Best-effort import of test cases: a single bad case (e.g. malformed
	// JSON in InputData) shouldn't abort the whole import — the tool itself
	// is already saved. Log each failure so the user knows partial import.
	//
	// 测试用例尽力导入：单条用例失败（如 InputData JSON 损坏）不应中断整体——
	// 工具本身已保存。每条失败记日志，让用户知晓部分导入。
	for _, tc := range shape.TestCases {
		if _, err := s.CreateTestCase(ctx, t.ID, tc); err != nil {
			s.log.Warn("import: skipped test case",
				zap.String("forge_id", t.ID),
				zap.String("test_case_name", tc.Name),
				zap.Error(err),
			)
		}
	}
	return t, nil
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

func newVersion(t *forgedomain.Forge, status string, version *int, message string) *forgedomain.ForgeVersion {
	now := time.Now().UTC()
	return &forgedomain.ForgeVersion{
		ID:           newID("fv"),
		ForgeID:       t.ID,
		UserID:       t.UserID,
		Version:      version,
		Status:       status,
		Name:         t.Name,
		Description:  t.Description,
		Code:         t.Code,
		Parameters:   t.Parameters,
		ReturnSchema: t.ReturnSchema,
		Tags:         t.Tags,
		Message:      message,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
}

func newID(prefix string) string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		// crypto/rand failure means broken entropy source — IDs would
		// collide, so fail loudly and let the caller crash. Matches the
		// other newID functions (apikey / model / conversation / chat).
		//
		// crypto/rand 失败说明熵源损坏——继续会生成碰撞 ID，必须立刻 panic。
		// 与其他 newID（apikey / model / conversation / chat）保持一致。
		panic(fmt.Sprintf("tool: crypto/rand failed: %v", err))
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

func mustSetUserID(ctx context.Context, t *forgedomain.Forge) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("forgeapp: %w", err)
	}
	t.UserID = uid
	return nil
}

// extractJSONFromLLM strips markdown code fences that LLMs often wrap around
// JSON responses, then finds the outermost JSON object or array.
// Returns the original string unchanged if no JSON delimiter is found.
func extractJSONFromLLM(s string) string {
	s = strings.TrimSpace(s)
	// Strip ```json ... ``` or ``` ... ``` fences.
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
	// Find outermost { } or [ ].
	for _, pair := range [][2]byte{{'{', '}'}, {'[', ']'}} {
		start := strings.IndexByte(s, pair[0])
		end := strings.LastIndexByte(s, pair[1])
		if start >= 0 && end > start {
			return s[start : end+1]
		}
	}
	return s
}

func uidFromForge(t *forgedomain.Forge) (string, bool) {
	return t.UserID, t.UserID != ""
}

func buildGeneratePrompt(t *forgedomain.Forge, count int) string {
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
		t.Name, t.Description, t.Code, count)
}
