// crud.go — Function CRUD + version lifecycle (pending → accept / reject /
// revert) at the Service layer. Each method is ctx-scoped to the current user
// via reqctxpkg.RequireUserID; cross-user reads return ErrNotFound by repo.
//
// Notifications: every state change publishes a `function` entity event via
// notif.Publish (conversationID == "" → global broadcast). UI subscribes to
// /api/v1/notifications and refreshes the function list / detail panel on each
// matching envelope.
//
// Sandbox env sync (writing code files + materializing the venv) is wired in
// Task 12 via sandbox_adapter.go. For now Create / Edit / AcceptPending leave
// EnvStatus == "pending" — the adapter (Task 12) starts a background goroutine
// after each accept that runs Sync + writes EnvStatus = ready/failed.
//
// crud.go —— Function CRUD + 版本生命周期(pending → accept / reject /
// revert)在 Service 层。每方法按 ctx userID 过滤;跨用户读由 repo 返
// ErrNotFound。
//
// 通知:每次状态变更经 notif.Publish 推 `function` entity 事件(全局广播)。
// UI 订阅 /api/v1/notifications,刷列表/详情。
//
// Sandbox env sync 在 Task 12 sandbox_adapter.go 接驳。本任务 Create / Edit /
// AcceptPending 留 EnvStatus="pending",adapter 在 accept 后起后台 goroutine
// 跑 Sync 写终态。

package function

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ── Input types ───────────────────────────────────────────────────────────────

// CreateInput is the request shape for Service.Create. Name + Description come
// from explicit fields (used for duplicate-name check before applying ops);
// Ops carry the full editable surface (code / parameters / dependencies / etc).
//
// CreateInput 是 Service.Create 的请求形状。Name + Description 是显式字段(
// 用于 ops 应用前查重),Ops 携带其余可编辑面(代码 / 参数 / 依赖等)。
type CreateInput struct {
	Ops             []Op
	ChangeReason    string
	ProgressBlockID string // optional eventlog block id for progress deltas
}

// EditInput is the request shape for Service.Edit (writes a pending version).
//
// EditInput 是 Service.Edit 的请求形状(写 pending 版本)。
type EditInput struct {
	ID              string
	Ops             []Op
	ChangeReason    string
	ProgressBlockID string
}

// ── Reads ─────────────────────────────────────────────────────────────────────

// List returns a paginated page of live functions for the current user.
// Computed Pending / Env* fields are NOT populated — caller uses Get for detail.
//
// List 返当前用户活跃 function 的 cursor 分页;计算字段不填,详情用 Get。
func (s *Service) List(ctx context.Context, filter functiondomain.ListFilter) ([]*functiondomain.Function, string, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, "", fmt.Errorf("functionapp.List: %w", err)
	}
	rows, next, err := s.repo.ListFunctions(ctx, filter)
	if err != nil {
		return nil, "", fmt.Errorf("functionapp.List: %w", err)
	}
	return rows, next, nil
}

// ListAll returns every live function for the current user (no pagination).
// Used by CatalogSource.ListItems + the search_function LLM tool.
//
// ListAll 返当前用户全部活跃 function(无分页);CatalogSource + search_function
// tool 用。
func (s *Service) ListAll(ctx context.Context) ([]*functiondomain.Function, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.ListAll: %w", err)
	}
	rows, err := s.repo.ListAllFunctions(ctx)
	if err != nil {
		return nil, fmt.Errorf("functionapp.ListAll: %w", err)
	}
	return rows, nil
}

// Search returns functions whose name / description / tags contain query (case-
// insensitive substring). V1 implementation;V1.5 will let the LLM tool layer
// re-rank semantically.
//
// Search 返 name / description / tags 含 query 子串(忽略大小写)的 function。
// V1 实现;V1.5 由 LLM tool 层再语义排序。
func (s *Service) Search(ctx context.Context, query string) ([]*functiondomain.Function, error) {
	all, err := s.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	if query == "" {
		return all, nil
	}
	needle := strings.ToLower(query)
	out := make([]*functiondomain.Function, 0, len(all))
	for _, fn := range all {
		if strings.Contains(strings.ToLower(fn.Name), needle) ||
			strings.Contains(strings.ToLower(fn.Description), needle) {
			out = append(out, fn)
			continue
		}
		for _, tag := range fn.Tags {
			if strings.Contains(strings.ToLower(tag), needle) {
				out = append(out, fn)
				break
			}
		}
	}
	return out, nil
}

// Get fetches one function with its computed fields populated (active version's
// env state mirrored onto Function;pending version attached if present).
//
// Get 返单 function 含计算字段(active version 的 env 状态镜像到 Function;
// 有 pending 时挂上)。
func (s *Service) Get(ctx context.Context, id string) (*functiondomain.Function, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.Get: %w", err)
	}
	f, err := s.repo.GetFunction(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("functionapp.Get: %w", err)
	}
	s.attachComputed(ctx, f)
	return f, nil
}

// attachComputed populates Function.Pending + Function.Env* from the pending
// version (if any) + active version. Errors fetching either are non-fatal —
// the function row is still usable, just without those decorations.
//
// attachComputed 把 pending + active 版本的状态填到 Function 计算字段。
// 单独失败不影响主返回(降级,只是少装饰)。
func (s *Service) attachComputed(ctx context.Context, f *functiondomain.Function) {
	if f == nil {
		return
	}
	pending, err := s.repo.GetPending(ctx, f.ID)
	if err == nil {
		f.Pending = pending
	} else if !errors.Is(err, functiondomain.ErrPendingNotFound) {
		s.log.Warn("functionapp.Get: attach pending failed", zap.Any("err", err))
	}
	if f.ActiveVersionID == "" {
		return
	}
	active, err := s.repo.GetVersion(ctx, f.ActiveVersionID)
	if err != nil {
		s.log.Warn("functionapp.Get: attach active env failed", zap.Any("err", err))
		return
	}
	f.EnvStatus = active.EnvStatus
	f.EnvError = active.EnvError
	f.EnvSyncedAt = active.EnvSyncedAt
	f.EnvSyncStage = active.EnvSyncStage
	f.EnvSyncDetail = active.EnvSyncDetail
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────

// Create builds a new Function from ops + auto-accepts the resulting version
// as v1 (first-create auto-accept — aligns with forge's TE-15 pattern).
//
// Create 应用 ops → 持久化 Function + Version1(自动 accept)。
//
// Steps:
//  1. ApplyOps with empty base to produce final draft
//  2. Duplicate-name check via repo.GetFunctionByName
//  3. Save Function + Version with Status=accepted, version=1
//  4. Notify (action: created)
//  5. Sandbox sync is deferred to Task 12 (env_synced notification after)
func (s *Service) Create(ctx context.Context, in CreateInput) (*functiondomain.Function, *functiondomain.Version, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("functionapp.Create: %w", err)
	}
	draft, _, err := s.ApplyOps(ctx, nil, in.Ops, in.ProgressBlockID)
	if err != nil {
		return nil, nil, fmt.Errorf("functionapp.Create: %w", err)
	}
	existing, err := s.repo.GetFunctionByName(ctx, draft.Name)
	if err != nil && !errors.Is(err, functiondomain.ErrNotFound) {
		return nil, nil, fmt.Errorf("functionapp.Create: dup-check: %w", err)
	}
	if existing != nil {
		return nil, nil, functiondomain.ErrDuplicateName
	}

	now := time.Now().UTC()
	fnID := idgenpkg.New("fn")
	versionID := idgenpkg.New("fnv")
	versionN := 1
	pyVer := draft.PythonVersion
	if pyVer == "" {
		pyVer = functiondomain.DefaultPythonVersion
	}
	envID := ComputeEnvID(draft.Dependencies, pyVer)

	f := &functiondomain.Function{
		ID:              fnID,
		UserID:          uid,
		Name:            draft.Name,
		Description:     draft.Description,
		Tags:            draft.Tags,
		ActiveVersionID: versionID,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	v := &functiondomain.Version{
		ID:            versionID,
		FunctionID:    fnID,
		Status:        functiondomain.StatusAccepted,
		Version:       &versionN,
		Code:          draft.Code,
		Parameters:    draft.Parameters,
		ReturnSchema:  draft.ReturnSchema,
		Dependencies:  draft.Dependencies,
		PythonVersion: pyVer,
		EnvID:         envID,
		EnvStatus:     functiondomain.EnvStatusPending,
		ChangeReason:  in.ChangeReason,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	if err := s.repo.SaveFunction(ctx, f); err != nil {
		return nil, nil, fmt.Errorf("functionapp.Create: SaveFunction: %w", err)
	}
	if err := s.repo.SaveVersion(ctx, v); err != nil {
		return nil, nil, fmt.Errorf("functionapp.Create: SaveVersion: %w", err)
	}

	s.publish(ctx, fnID, "created", map[string]any{"function": f, "version": v})
	return f, v, nil
}

// Edit writes a new pending version. Errors with ErrPendingConflict if another
// pending already exists — LLM/UI must Accept or Reject before editing again.
//
// Edit 写新 pending 版本。已有 pending 时返 ErrPendingConflict——
// LLM/UI 必须先 accept/reject 才能继续编辑。
func (s *Service) Edit(ctx context.Context, in EditInput) (*functiondomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.Edit: %w", err)
	}
	f, err := s.repo.GetFunction(ctx, in.ID)
	if err != nil {
		return nil, fmt.Errorf("functionapp.Edit: %w", err)
	}
	if _, err := s.repo.GetPending(ctx, in.ID); err == nil {
		return nil, fmt.Errorf("functionapp.Edit: %w", functiondomain.ErrPendingConflict)
	} else if !errors.Is(err, functiondomain.ErrPendingNotFound) {
		return nil, fmt.Errorf("functionapp.Edit: pending-check: %w", err)
	}

	base, err := s.activeAsDraft(ctx, f)
	if err != nil {
		return nil, fmt.Errorf("functionapp.Edit: %w", err)
	}
	draft, _, err := s.ApplyOps(ctx, base, in.Ops, in.ProgressBlockID)
	if err != nil {
		return nil, fmt.Errorf("functionapp.Edit: %w", err)
	}

	now := time.Now().UTC()
	versionID := idgenpkg.New("fnv")
	pyVer := draft.PythonVersion
	if pyVer == "" {
		pyVer = functiondomain.DefaultPythonVersion
	}
	envID := ComputeEnvID(draft.Dependencies, pyVer)

	v := &functiondomain.Version{
		ID:            versionID,
		FunctionID:    in.ID,
		Status:        functiondomain.StatusPending,
		Code:          draft.Code,
		Parameters:    draft.Parameters,
		ReturnSchema:  draft.ReturnSchema,
		Dependencies:  draft.Dependencies,
		PythonVersion: pyVer,
		EnvID:         envID,
		EnvStatus:     functiondomain.EnvStatusPending,
		ChangeReason:  in.ChangeReason,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
	if err := s.repo.SaveVersion(ctx, v); err != nil {
		return nil, fmt.Errorf("functionapp.Edit: SaveVersion: %w", err)
	}
	s.publish(ctx, in.ID, "pending_created", map[string]any{"version": v})
	return v, nil
}

// AcceptPending turns the active pending into a numbered accepted version and
// flips Function.ActiveVersionID. Enforces the per-function accepted-version
// cap (functiondomain.AcceptedVersionCap).
//
// AcceptPending 把 pending 翻为带号 accepted + 翻 ActiveVersionID;
// 应用 per-function accepted 上限。
func (s *Service) AcceptPending(ctx context.Context, id string) (*functiondomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.AcceptPending: %w", err)
	}
	pending, err := s.repo.GetPending(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("functionapp.AcceptPending: %w", err)
	}

	nextN, err := s.nextVersionNumber(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("functionapp.AcceptPending: nextN: %w", err)
	}
	if err := s.repo.UpdateVersionStatus(ctx, pending.ID, functiondomain.StatusAccepted, &nextN); err != nil {
		return nil, fmt.Errorf("functionapp.AcceptPending: UpdateStatus: %w", err)
	}
	if err := s.repo.SetActiveVersion(ctx, id, pending.ID); err != nil {
		return nil, fmt.Errorf("functionapp.AcceptPending: SetActive: %w", err)
	}
	if err := s.repo.HardDeleteOldestAccepted(ctx, id, functiondomain.AcceptedVersionCap); err != nil {
		s.log.Warn("functionapp.AcceptPending: trim oldest failed", zap.Any("err", err), zap.Any("functionId", id))
	}

	pending.Status = functiondomain.StatusAccepted
	pending.Version = &nextN
	s.publish(ctx, id, "version_accepted", map[string]any{"version": pending})
	return pending, nil
}

// RejectPending marks the active pending as rejected (no state change to
// ActiveVersion). UI/LLM can then create a new pending via Edit.
//
// RejectPending 把活动 pending 标 rejected(不动 ActiveVersion);可继续 Edit。
func (s *Service) RejectPending(ctx context.Context, id string) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return fmt.Errorf("functionapp.RejectPending: %w", err)
	}
	pending, err := s.repo.GetPending(ctx, id)
	if err != nil {
		return fmt.Errorf("functionapp.RejectPending: %w", err)
	}
	if err := s.repo.UpdateVersionStatus(ctx, pending.ID, functiondomain.StatusRejected, nil); err != nil {
		return fmt.Errorf("functionapp.RejectPending: %w", err)
	}
	s.publish(ctx, id, "pending_rejected", map[string]any{"versionId": pending.ID})
	return nil
}

// Revert flips ActiveVersionID to a target accepted version. Returns
// ErrVersionNotFound if no accepted version with that number exists.
//
// Revert 把 ActiveVersionID 翻到指定 accepted 版本号;无则 ErrVersionNotFound。
func (s *Service) Revert(ctx context.Context, id string, targetVersion int) (*functiondomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.Revert: %w", err)
	}
	target, err := s.repo.GetVersionByNumber(ctx, id, targetVersion)
	if err != nil {
		return nil, fmt.Errorf("functionapp.Revert: %w", err)
	}
	if err := s.repo.SetActiveVersion(ctx, id, target.ID); err != nil {
		return nil, fmt.Errorf("functionapp.Revert: %w", err)
	}
	s.publish(ctx, id, "reverted", map[string]any{"version": target})
	return target, nil
}

// Delete soft-deletes a function. Publishes a deletion notification — the
// workflow domain subscribes to mark referencing workflows as needs_attention
// (per forge_redesign D20).
//
// Delete 软删 function。发删除通知——workflow domain 订阅后把引用此 function
// 的 workflow 标 needs_attention(D20)。
func (s *Service) Delete(ctx context.Context, id string) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return fmt.Errorf("functionapp.Delete: %w", err)
	}
	if err := s.repo.DeleteFunction(ctx, id); err != nil {
		return fmt.Errorf("functionapp.Delete: %w", err)
	}
	s.publish(ctx, id, "deleted", nil)
	return nil
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// activeAsDraft loads the function's active version and returns it as a
// VersionDraft suitable as base for ApplyOps. If ActiveVersionID is empty
// (draft state) returns a zero-value draft preserving function name/desc/tags.
//
// activeAsDraft 把 active 版本加载为 VersionDraft 作为 Edit 的 base。
// ActiveVersionID 空时返保留 function 元数据的空 draft。
func (s *Service) activeAsDraft(ctx context.Context, f *functiondomain.Function) (*VersionDraft, error) {
	d := &VersionDraft{
		Name:        f.Name,
		Description: f.Description,
		Tags:        append([]string(nil), f.Tags...),
	}
	if f.ActiveVersionID == "" {
		return d, nil
	}
	active, err := s.repo.GetVersion(ctx, f.ActiveVersionID)
	if err != nil {
		return nil, err
	}
	d.Code = active.Code
	d.Parameters = append([]functiondomain.ParameterSpec(nil), active.Parameters...)
	d.ReturnSchema = active.ReturnSchema
	d.Dependencies = append([]string(nil), active.Dependencies...)
	d.PythonVersion = active.PythonVersion
	return d, nil
}

// nextVersionNumber returns max(accepted.version)+1 for the function. First
// accepted gets 1. Walks ListVersions accepted page (size 1) to find current
// max.
//
// nextVersionNumber 返该 function 下 max(accepted.version)+1。首个 accepted
// 返 1。
func (s *Service) nextVersionNumber(ctx context.Context, functionID string) (int, error) {
	rows, _, err := s.repo.ListVersions(ctx, functionID, functiondomain.VersionListFilter{
		Status: functiondomain.StatusAccepted,
		Limit:  1,
	})
	if err != nil {
		return 0, err
	}
	if len(rows) == 0 || rows[0].Version == nil {
		return 1, nil
	}
	return *rows[0].Version + 1, nil
}

// publish emits a `function` entity notification. data may be nil for purely
// state-transition events (e.g. deleted).
//
// publish 推 `function` entity 通知;data 可为 nil(纯状态变更事件)。
func (s *Service) publish(ctx context.Context, functionID, action string, data map[string]any) {
	envelope := map[string]any{"action": action}
	for k, v := range data {
		envelope[k] = v
	}
	s.notif.Publish(ctx, "function", functionID, envelope, "")
}
