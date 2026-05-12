// crud.go — Workflow CRUD + version/pending lifecycle. Mirrors function /
// handler crud.go shapes so Service code feels uniform across trinity.
//
// Key model decisions (post-D-redo-11 trinity convention):
//   - Create auto-accepts v1 when validation passes (TE-15 alignment)
//   - Edit uses iterate-same-pending — second edit rewrites the row,
//     never returns ErrPendingConflict
//   - AcceptPending is a pure pointer flip (graph is already frozen on
//     pending row)
//   - RejectPending hard-deletes the pending Version row (D-redo-12)
//   - Revert flips active_version_id to a numbered accepted version
//   - All notifications carry slim payloads (D-redo-6): {action, versionId?,
//     versionNumber?} — UI does GET for full entity
//
// crud.go —— Workflow CRUD + 版本生命周期;镜像 function/handler 模式。
// Create 自动 accept v1;Edit iterate-same-pending(无 ErrPendingConflict);
// AcceptPending 纯指针;RejectPending hard-delete;通知瘦身。

package workflow

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"go.uber.org/zap"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// validNameRe — workflow name char set (mirror function / handler).
//
// validNameRe — workflow name 字符集;跟 function/handler 同。
var validNameRe = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_\-]{0,63}$`)

// ── Inputs ───────────────────────────────────────────────────────────────────

// CreateInput is the request shape for Service.Create. Ops carry the full
// editable surface; the LLM tool layer constructs the ops slice from its
// JSON-RPC args.
//
// CreateInput Service.Create 请求形状;LLM 工具层从 JSON-RPC args 构 ops。
type CreateInput struct {
	Ops             []Op
	ChangeReason    string
	ProgressBlockID string // optional eventlog block for streaming UX
}

// EditInput is the request shape for Service.Edit (writes a pending).
//
// EditInput Service.Edit 请求形状(写 pending)。
type EditInput struct {
	ID              string
	Ops             []Op
	ChangeReason    string
	ProgressBlockID string
}

// UpdateMetaInput patches Workflow metadata (no version side effects).
//
// UpdateMetaInput 改元数据(不动版本)。
type UpdateMetaInput struct {
	ID             string
	Name           *string
	Description    *string
	Tags           *[]string
	Enabled        *bool
	Concurrency    *string
	NeedsAttention *bool
	AttentionReason *string
}

// ── Reads ────────────────────────────────────────────────────────────────────

// List returns a paginated page of live workflows. Computed Pending /
// LiveRuns / LastFiredAt fields are NOT populated — Get fills them.
//
// List 返当前用户活跃 workflow 分页;计算字段不填,详情用 Get。
func (s *Service) List(ctx context.Context, filter workflowdomain.ListFilter) ([]*workflowdomain.Workflow, string, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, "", fmt.Errorf("workflowapp.List: %w", err)
	}
	rows, next, err := s.repo.ListWorkflows(ctx, filter)
	if err != nil {
		return nil, "", fmt.Errorf("workflowapp.List: %w", err)
	}
	return rows, next, nil
}

// ListAll returns every live workflow (no pagination) — used by
// SearchWorkflow LLM ranking + Plan 05 scheduler bootstrap.
//
// ListAll 返当前用户全部活跃 workflow(无分页);SearchWorkflow + Plan 05
// scheduler 用。
func (s *Service) ListAll(ctx context.Context) ([]*workflowdomain.Workflow, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.ListAll: %w", err)
	}
	rows, err := s.repo.ListAllWorkflows(ctx)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.ListAll: %w", err)
	}
	return rows, nil
}

// Search returns workflows whose name / description / tags contain query
// (case-insensitive substring). V1 implementation; LLM tool layer may
// re-rank semantically.
//
// Search 返 name/description/tags 含 query 子串的 workflow。
func (s *Service) Search(ctx context.Context, query string) ([]*workflowdomain.Workflow, error) {
	all, err := s.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	if query == "" {
		return all, nil
	}
	needle := strings.ToLower(query)
	out := make([]*workflowdomain.Workflow, 0, len(all))
	for _, w := range all {
		if strings.Contains(strings.ToLower(w.Name), needle) ||
			strings.Contains(strings.ToLower(w.Description), needle) {
			out = append(out, w)
			continue
		}
		for _, tag := range w.Tags {
			if strings.Contains(strings.ToLower(tag), needle) {
				out = append(out, w)
				break
			}
		}
	}
	return out, nil
}

// Get fetches one workflow with computed fields populated. attachComputed
// loads pending; LiveRuns / LastFiredAt / NextFireAt are Plan 05 territory.
//
// Get 返单 workflow 含计算字段(pending)。LiveRuns 等留 Plan 05。
func (s *Service) Get(ctx context.Context, id string) (*workflowdomain.Workflow, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.Get: %w", err)
	}
	w, err := s.repo.GetWorkflow(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.Get: %w", err)
	}
	s.attachComputed(ctx, w)
	return w, nil
}

// ListVersions paginates a workflow's versions.
//
// ListVersions 返某 workflow 版本分页。
func (s *Service) ListVersions(ctx context.Context, workflowID string, filter workflowdomain.VersionListFilter) ([]*workflowdomain.Version, string, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, "", fmt.Errorf("workflowapp.ListVersions: %w", err)
	}
	rows, next, err := s.repo.ListVersions(ctx, workflowID, filter)
	if err != nil {
		return nil, "", fmt.Errorf("workflowapp.ListVersions: %w", err)
	}
	for _, v := range rows {
		s.attachGraph(v)
	}
	return rows, next, nil
}

// GetVersion fetches one version by id (GraphParsed populated).
//
// GetVersion 按 id 取版本(填 GraphParsed)。
func (s *Service) GetVersion(ctx context.Context, versionID string) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.GetVersion: %w", err)
	}
	v, err := s.repo.GetVersion(ctx, versionID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.GetVersion: %w", err)
	}
	s.attachGraph(v)
	return v, nil
}

// GetVersionByNumber fetches an accepted version by integer.
//
// GetVersionByNumber 按整数版本号取 accepted。
func (s *Service) GetVersionByNumber(ctx context.Context, workflowID string, versionN int) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.GetVersionByNumber: %w", err)
	}
	v, err := s.repo.GetVersionByNumber(ctx, workflowID, versionN)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.GetVersionByNumber: %w", err)
	}
	s.attachGraph(v)
	return v, nil
}

// GetPending returns the active pending (with GraphParsed); ErrPendingNotFound
// if absent.
//
// GetPending 返活动 pending(填 GraphParsed)。
func (s *Service) GetPending(ctx context.Context, workflowID string) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.GetPending: %w", err)
	}
	v, err := s.repo.GetPending(ctx, workflowID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.GetPending: %w", err)
	}
	s.attachGraph(v)
	return v, nil
}

// ── WorkflowReader satisfaction (Plan 05 consumers) ─────────────────────────

// GetActiveVersion is the WorkflowReader entry the Plan 05 scheduler calls
// to fetch the frozen graph it should execute.
//
// GetActiveVersion 给 Plan 05 scheduler 拿冻结图执行。
func (s *Service) GetActiveVersion(ctx context.Context, workflowID string) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.GetActiveVersion: %w", err)
	}
	w, err := s.repo.GetWorkflow(ctx, workflowID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.GetActiveVersion: %w", err)
	}
	if w.ActiveVersionID == "" {
		return nil, fmt.Errorf("workflowapp.GetActiveVersion: %w", workflowdomain.ErrNoActiveVersion)
	}
	v, err := s.repo.GetVersion(ctx, w.ActiveVersionID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.GetActiveVersion: %w", err)
	}
	s.attachGraph(v)
	return v, nil
}

// GetWorkflow satisfies WorkflowReader. Same as Get but skips attachComputed
// — schedulers don't need pending.
//
// GetWorkflow 同 Get;scheduler 不需要 pending,跳 attachComputed。
func (s *Service) GetWorkflow(ctx context.Context, workflowID string) (*workflowdomain.Workflow, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.GetWorkflow: %w", err)
	}
	return s.repo.GetWorkflow(ctx, workflowID)
}

// ListEnabled returns enabled live workflows. Plan 05 trigger domain calls
// this at bootstrap to register listeners.
//
// ListEnabled 返启用的 workflow;Plan 05 trigger 启动时调。
func (s *Service) ListEnabled(ctx context.Context) ([]*workflowdomain.Workflow, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.ListEnabled: %w", err)
	}
	rows, _, err := s.repo.ListWorkflows(ctx, workflowdomain.ListFilter{EnabledOnly: true, Limit: 200})
	if err != nil {
		return nil, fmt.Errorf("workflowapp.ListEnabled: %w", err)
	}
	return rows, nil
}

// ── Lifecycle ────────────────────────────────────────────────────────────────

// Create applies ops + persists Workflow + v1 (auto-accepted on validation
// success). Returns ErrDuplicateName / ErrNoTrigger / ErrDAGCycle / etc.
// on validation failure.
//
// Create 应用 ops + 持久化 Workflow + v1(校验通过自动 accept)。
func (s *Service) Create(ctx context.Context, in CreateInput) (*workflowdomain.Workflow, *workflowdomain.Version, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("workflowapp.Create: %w", err)
	}

	graph, err := ApplyOps(ctx, nil, in.Ops, in.ProgressBlockID)
	if err != nil {
		return nil, nil, fmt.Errorf("workflowapp.Create: %w", err)
	}
	if graph.Name == "" {
		return nil, nil, fmt.Errorf("workflowapp.Create: %w: graph name is required (use set_meta op)", workflowdomain.ErrOpInvalid)
	}
	if !validNameRe.MatchString(graph.Name) {
		return nil, nil, fmt.Errorf("workflowapp.Create: %w: invalid name %q", workflowdomain.ErrOpInvalid, graph.Name)
	}
	if err := ValidateGraph(ctx, graph, s.checker); err != nil {
		return nil, nil, fmt.Errorf("workflowapp.Create: %w", err)
	}
	existing, err := s.repo.GetWorkflowByName(ctx, graph.Name)
	if err != nil && !errors.Is(err, workflowdomain.ErrNotFound) {
		return nil, nil, fmt.Errorf("workflowapp.Create: dup-check: %w", err)
	}
	if existing != nil {
		return nil, nil, workflowdomain.ErrDuplicateName
	}

	now := time.Now().UTC()
	wfID := idgenpkg.New("wf")
	versionID := idgenpkg.New("wfv")
	versionN := 1
	graphJSON, err := json.Marshal(graph)
	if err != nil {
		return nil, nil, fmt.Errorf("workflowapp.Create: marshal graph: %w", err)
	}

	w := &workflowdomain.Workflow{
		ID:              wfID,
		UserID:          uid,
		Name:            graph.Name,
		Description:     graph.Description,
		Tags:            append([]string(nil), graph.Tags...),
		Enabled:         true,
		Concurrency:     workflowdomain.ConcurrencySerial,
		NeedsAttention:  false,
		ActiveVersionID: versionID,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	v := &workflowdomain.Version{
		ID:           versionID,
		WorkflowID:   wfID,
		Status:       workflowdomain.StatusAccepted,
		Version:      &versionN,
		Graph:        string(graphJSON),
		ChangeReason: in.ChangeReason,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := s.repo.SaveWorkflow(ctx, w); err != nil {
		return nil, nil, fmt.Errorf("workflowapp.Create: SaveWorkflow: %w", err)
	}
	if err := s.repo.SaveVersion(ctx, v); err != nil {
		return nil, nil, fmt.Errorf("workflowapp.Create: SaveVersion: %w", err)
	}
	s.attachGraph(v)
	s.publish(ctx, wfID, "created", map[string]any{"versionId": v.ID, "versionNumber": versionN})
	return w, v, nil
}

// Edit produces a pending under iterate-same-pending semantics (mirror
// function / handler Edit per D-redo-11):
//   - no pending → apply ops on top of active → new pending row
//   - pending exists → apply ops on top of pending → rewrite same row
//   - ops=[] is forbidden here (workflow has no env to "force-rebuild"
//     like function / handler;callers needing the same effect should
//     instead call Edit with set_meta NOP)
//
// Edit 按 iterate-same-pending(D-redo-11):无 pending 新建,有 pending 重写
// 同行。ops=[] 在 workflow 域无意义(没 env 要重建),返 ErrOpInvalid。
func (s *Service) Edit(ctx context.Context, in EditInput) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.Edit: %w", err)
	}
	if len(in.Ops) == 0 {
		return nil, fmt.Errorf("workflowapp.Edit: %w: ops is empty", workflowdomain.ErrOpInvalid)
	}
	w, err := s.repo.GetWorkflow(ctx, in.ID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.Edit: %w", err)
	}

	pending, perr := s.repo.GetPending(ctx, in.ID)
	switch {
	case perr == nil:
		// pending exists → iterate same row
	case errors.Is(perr, workflowdomain.ErrPendingNotFound):
		pending = nil
	default:
		return nil, fmt.Errorf("workflowapp.Edit: pending-check: %w", perr)
	}

	var base *workflowdomain.Graph
	if pending != nil {
		s.attachGraph(pending)
		base = pending.GraphParsed
	} else if w.ActiveVersionID != "" {
		active, err := s.repo.GetVersion(ctx, w.ActiveVersionID)
		if err != nil {
			return nil, fmt.Errorf("workflowapp.Edit: load active: %w", err)
		}
		s.attachGraph(active)
		base = active.GraphParsed
	}

	draft, err := ApplyOps(ctx, base, in.Ops, in.ProgressBlockID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.Edit: %w", err)
	}
	// Edit-time validation is full strict — we don't accept invalid
	// pendings even though the user can Reject afterwards (catching
	// errors earlier is better UX).
	// Edit 期强校验;Reject 路径在,但提前抓错更好。
	if err := ValidateGraph(ctx, draft, s.checker); err != nil {
		return nil, fmt.Errorf("workflowapp.Edit: %w", err)
	}
	graphJSON, err := json.Marshal(draft)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.Edit: marshal graph: %w", err)
	}

	now := time.Now().UTC()
	var v *workflowdomain.Version
	if pending != nil {
		pending.Graph = string(graphJSON)
		pending.ChangeReason = in.ChangeReason
		pending.UpdatedAt = now
		v = pending
	} else {
		v = &workflowdomain.Version{
			ID:           idgenpkg.New("wfv"),
			WorkflowID:   in.ID,
			Status:       workflowdomain.StatusPending,
			Graph:        string(graphJSON),
			ChangeReason: in.ChangeReason,
			CreatedAt:    now,
			UpdatedAt:    now,
		}
	}
	if err := s.repo.SaveVersion(ctx, v); err != nil {
		return nil, fmt.Errorf("workflowapp.Edit: SaveVersion: %w", err)
	}
	s.attachGraph(v)
	s.publish(ctx, in.ID, "pending_created", map[string]any{"versionId": v.ID})
	return v, nil
}

// AcceptPending flips pending → accepted (numbered) and points
// active_version_id at it. Trims accepted versions to the cap. Also
// clears NeedsAttention since the user has actively re-affirmed the
// workflow shape.
//
// AcceptPending pending → 带号 accepted + 翻 active_version_id;裁剪至上限;
// 同时清 NeedsAttention(用户已重 re-affirm)。
func (s *Service) AcceptPending(ctx context.Context, id string) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.AcceptPending: %w", err)
	}
	pending, err := s.repo.GetPending(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.AcceptPending: %w", err)
	}
	nextN, err := s.nextVersionNumber(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.AcceptPending: nextN: %w", err)
	}
	if err := s.repo.UpdateVersionStatus(ctx, pending.ID, workflowdomain.StatusAccepted, &nextN); err != nil {
		return nil, fmt.Errorf("workflowapp.AcceptPending: UpdateStatus: %w", err)
	}
	if err := s.repo.SetActiveVersion(ctx, id, pending.ID); err != nil {
		return nil, fmt.Errorf("workflowapp.AcceptPending: SetActive: %w", err)
	}
	if err := s.repo.SetNeedsAttention(ctx, id, false, ""); err != nil {
		s.log.Warn("workflowapp.AcceptPending: clear needs_attention failed", zap.String("id", id), zap.Error(err))
	}
	if err := s.repo.HardDeleteOldestAccepted(ctx, id, workflowdomain.AcceptedVersionCap); err != nil {
		s.log.Warn("workflowapp.AcceptPending: trim oldest failed", zap.Any("err", err), zap.Any("workflowId", id))
	}
	pending.Status = workflowdomain.StatusAccepted
	pending.Version = &nextN
	s.publish(ctx, id, "version_accepted", map[string]any{"versionId": pending.ID, "versionNumber": nextN})
	return pending, nil
}

// RejectPending hard-deletes the pending Version row (D-redo-12 mirror).
// ActiveVersion unchanged; UI/LLM can Edit again to create a fresh pending.
//
// RejectPending 物理删 pending 行;不动 ActiveVersion。
func (s *Service) RejectPending(ctx context.Context, id string) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return fmt.Errorf("workflowapp.RejectPending: %w", err)
	}
	pending, err := s.repo.GetPending(ctx, id)
	if err != nil {
		return fmt.Errorf("workflowapp.RejectPending: %w", err)
	}
	if err := s.repo.HardDeleteVersion(ctx, pending.ID); err != nil {
		return fmt.Errorf("workflowapp.RejectPending: %w", err)
	}
	s.publish(ctx, id, "pending_rejected", map[string]any{"versionId": pending.ID})
	return nil
}

// Revert flips active_version_id to a target accepted version number.
//
// Revert 把 ActiveVersionID 翻到指定 accepted 版本号。
func (s *Service) Revert(ctx context.Context, id string, targetVersion int) (*workflowdomain.Version, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.Revert: %w", err)
	}
	target, err := s.repo.GetVersionByNumber(ctx, id, targetVersion)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.Revert: %w", err)
	}
	if err := s.repo.SetActiveVersion(ctx, id, target.ID); err != nil {
		return nil, fmt.Errorf("workflowapp.Revert: %w", err)
	}
	s.attachGraph(target)
	s.publish(ctx, id, "reverted", map[string]any{"versionId": target.ID, "versionNumber": targetVersion})
	return target, nil
}

// UpdateMeta patches Workflow metadata (name / description / tags / enabled /
// concurrency / needs_attention) without creating a new version.
//
// UpdateMeta 改元数据(name/description/tags/enabled/concurrency/needs_attention)
// 不创建新版本。
func (s *Service) UpdateMeta(ctx context.Context, in UpdateMetaInput) (*workflowdomain.Workflow, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("workflowapp.UpdateMeta: %w", err)
	}
	w, err := s.repo.GetWorkflow(ctx, in.ID)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.UpdateMeta: %w", err)
	}
	if in.Name != nil {
		if !validNameRe.MatchString(*in.Name) {
			return nil, fmt.Errorf("workflowapp.UpdateMeta: invalid name %q", *in.Name)
		}
		if *in.Name != w.Name {
			existing, err := s.repo.GetWorkflowByName(ctx, *in.Name)
			if err != nil && !errors.Is(err, workflowdomain.ErrNotFound) {
				return nil, fmt.Errorf("workflowapp.UpdateMeta: dup-check: %w", err)
			}
			if existing != nil && existing.ID != w.ID {
				return nil, workflowdomain.ErrDuplicateName
			}
		}
		w.Name = *in.Name
	}
	if in.Description != nil {
		w.Description = *in.Description
	}
	if in.Tags != nil {
		w.Tags = *in.Tags
	}
	if in.Enabled != nil {
		w.Enabled = *in.Enabled
	}
	if in.Concurrency != nil {
		w.Concurrency = *in.Concurrency
	}
	if in.NeedsAttention != nil {
		w.NeedsAttention = *in.NeedsAttention
	}
	if in.AttentionReason != nil {
		w.AttentionReason = *in.AttentionReason
	}
	if err := s.repo.SaveWorkflow(ctx, w); err != nil {
		return nil, fmt.Errorf("workflowapp.UpdateMeta: %w", err)
	}
	s.publish(ctx, w.ID, "updated", nil)
	return w, nil
}

// Delete soft-deletes a workflow.
//
// Delete 软删 workflow。
func (s *Service) Delete(ctx context.Context, id string) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return fmt.Errorf("workflowapp.Delete: %w", err)
	}
	if err := s.repo.DeleteWorkflow(ctx, id); err != nil {
		return fmt.Errorf("workflowapp.Delete: %w", err)
	}
	s.publish(ctx, id, "deleted", nil)
	return nil
}

// ── Helpers ──────────────────────────────────────────────────────────────────

// attachComputed populates Pending on w (best-effort; failure logged).
//
// attachComputed 给 w 填 Pending(尽力,失败 log 不抛)。
func (s *Service) attachComputed(ctx context.Context, w *workflowdomain.Workflow) {
	if w == nil {
		return
	}
	pending, err := s.repo.GetPending(ctx, w.ID)
	if err == nil {
		s.attachGraph(pending)
		w.Pending = pending
	} else if !errors.Is(err, workflowdomain.ErrPendingNotFound) {
		s.log.Warn("workflowapp.Get: attach pending failed", zap.Any("err", err))
	}
}

// attachGraph unmarshals v.Graph into v.GraphParsed (gorm:"-" computed
// field). Failure is logged (caller already has the raw blob).
//
// attachGraph 解 v.Graph 到 v.GraphParsed。
func (s *Service) attachGraph(v *workflowdomain.Version) {
	if v == nil || v.Graph == "" {
		return
	}
	var g workflowdomain.Graph
	if err := json.Unmarshal([]byte(v.Graph), &g); err != nil {
		s.log.Warn("workflowapp.attachGraph: unmarshal failed",
			zap.String("versionId", v.ID), zap.Error(err))
		return
	}
	v.GraphParsed = &g
}

// nextVersionNumber returns max(accepted.version)+1.
//
// nextVersionNumber 返当前 workflow 下 max(accepted.version)+1。
func (s *Service) nextVersionNumber(ctx context.Context, workflowID string) (int, error) {
	rows, _, err := s.repo.ListVersions(ctx, workflowID, workflowdomain.VersionListFilter{
		Status: workflowdomain.StatusAccepted,
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

// publish emits a `workflow` entity notification with slim payload
// (D-redo-6 — UI does GET for full entity).
//
// publish 推 `workflow` entity 通知;瘦身 payload(D-redo-6)。
func (s *Service) publish(ctx context.Context, workflowID, action string, data map[string]any) {
	envelope := map[string]any{"action": action}
	for k, v := range data {
		envelope[k] = v
	}
	s.notif.Publish(ctx, "workflow", workflowID, envelope, "")
}
