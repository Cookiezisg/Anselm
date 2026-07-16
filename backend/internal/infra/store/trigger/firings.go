package trigger

import (
	"context"
	"errors"
	"fmt"
	"slices"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// AppendFiring writes a pending firing. UNIQUE(workflow_id, trigger_id, dedup_key) makes a
// re-materialized fire (cron missed-tick catch-up, crash retry) idempotent: a duplicate
// returns the existing row (not-lost + not-duplicated) instead of erroring.
//
// AppendFiring 写一条 pending firing；(workflow_id, trigger_id, dedup_key) UNIQUE 让重复材化
// 幂等（重复时返已存在行，不丢且不重）。
func (s *Store) AppendFiring(ctx context.Context, f *triggerdomain.Firing) (*triggerdomain.Firing, error) {
	if f.ID == "" {
		f.ID = idgenpkg.New("trf")
	}
	if f.Status == "" {
		f.Status = triggerdomain.FiringPending
	}
	if err := s.frs.Create(ctx, f); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			existing, gErr := s.frs.
				WhereEq("workflow_id", f.WorkflowID).
				WhereEq("trigger_id", f.TriggerID).
				WhereEq("dedup_key", f.DedupKey).
				First(ctx)
			if gErr != nil {
				return nil, fmt.Errorf("triggerstore.AppendFiring dedup-load: %w", gErr)
			}
			return existing, nil
		}
		return nil, fmt.Errorf("triggerstore.AppendFiring: %w", err)
	}
	return f, nil
}

// AppendMissedFiring books a missed firing dated at the tick it stands for (scheduler 工单⑨). It
// reuses AppendFiring (same dedup-key idempotence — a tick that fired, or that a previous sweep
// booked, keeps its row untouched), then backdates created_at: the orm stamps created=now on every
// insert, which is right for a live fire but wrong for a tick recorded after the fact. The backdate
// is a targeted raw UPDATE (no updated_at churn), and only ever touches the row this call created.
//
// AppendMissedFiring 记一条日期为其所代表刻度的 missed firing（scheduler 工单⑨）。它复用 AppendFiring
// （同一 dedup 键幂等——已 fire 的、或上次 sweep 已记的刻度，其行原封不动），再回拨 created_at：orm 每次
// 插入都盖 created=now，这对实时 fire 是对的、对事后补记的刻度是错的。回拨是定点裸 UPDATE（不搅
// updated_at），且只碰本次调用新建的那行。
func (s *Store) AppendMissedFiring(ctx context.Context, f *triggerdomain.Firing) (*triggerdomain.Firing, error) {
	ws, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, err
	}
	tick := f.CreatedAt
	f.Status = triggerdomain.FiringMissed
	out, err := s.AppendFiring(ctx, f)
	if err != nil {
		return nil, err
	}
	if out.ID != f.ID || tick.IsZero() {
		return out, nil // dedup hit (already accounted) — never re-date someone else's row. 去重命中——绝不改别人的行的日期。
	}
	if _, err := s.db.Exec(ctx,
		`UPDATE trigger_firings SET created_at = ? WHERE id = ? AND workspace_id = ?`,
		tick.UTC(), out.ID, ws); err != nil {
		return nil, fmt.Errorf("triggerstore.AppendMissedFiring backdate: %w", err)
	}
	out.CreatedAt = tick.UTC()
	return out, nil
}

// RequeueMissedFiring flips a booked `missed` firing back to `pending` — see the port's contract for
// the two callers and why the row (not a second row) must become the run. The `status = 'missed'`
// guard is the whole safety of it: a row that already reached pending/claimed/started is untouched,
// so this can never re-run work that ran. created_at is deliberately left at the SCHEDULED tick the
// row was backdated to (AppendMissedFiring) — the drain takes oldest-first, and a catch-up really is
// the oldest thing waiting.
//
// RequeueMissedFiring 把已记账的 `missed` firing 翻回 `pending`——两个调用方、以及为什么必须是**这行**
// （而非再开一行）变成那次 run，见端口契约。`status = 'missed'` 守卫就是它的全部安全性：已到
// pending/claimed/started 的行原封不动，故绝不可能把跑过的活儿再跑一遍。created_at 刻意保持在该行被
// 回拨到的**调度刻度**（AppendMissedFiring）——drain 最老优先，而补跑本就是等得最久的那个。
// activation_id 由本次扇出补盖：sweep 记账时它是空的（记账不是一次动作），不盖则审计链断在这一行。
func (s *Store) RequeueMissedFiring(ctx context.Context, firingID, activationID string) error {
	if _, err := s.frs.WhereEq("id", firingID).
		WhereEq("status", triggerdomain.FiringMissed).
		Updates(ctx, map[string]any{
			"status":        triggerdomain.FiringPending,
			"activation_id": activationID,
		}); err != nil {
		return fmt.Errorf("triggerstore.RequeueMissedFiring: %w", err)
	}
	return nil
}

// ListPendingFirings returns pending firings oldest-first for the scheduler to drain.
//
// ListPendingFirings 返 pending firing（最老优先）供 scheduler 排空。
func (s *Store) ListPendingFirings(ctx context.Context, limit int) ([]*triggerdomain.Firing, error) {
	q := s.frs.WhereEq("status", triggerdomain.FiringPending).Order("created_at ASC, id ASC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	rows, err := q.Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("triggerstore.ListPendingFirings: %w", err)
	}
	return rows, nil
}

// firingQuery applies every FiringFilter predicate — the SINGLE place the filter's meaning is
// expressed, shared by SearchFirings (the page) and CountFirings (the number). The "错过 N" KPI card
// deep-links to the very list it counts, so a second copy of these predicates would be a bug with a
// countdown on it: the card would say 3 and the list it opens would show 4. Cursor/Limit are the
// page's alone and are NOT applied here.
//
// firingQuery 施加 FiringFilter 的每一条谓词——filter 语义的**唯一**居所，由 SearchFirings（一页）与
// CountFirings（一个数）共用。「错过 N」KPI 牌深链到的正是它数的那个列表，故这些谓词若有第二份拷贝，
// 那就是一个装了倒计时的 bug：牌上写 3、点开的列表显示 4。Cursor/Limit 只属于分页，不在此施加。
func (s *Store) firingQuery(filter triggerdomain.FiringFilter) (*ormpkg.Query[triggerdomain.Firing], error) {
	// Reject an out-of-enum status loudly (422) instead of silently matching zero rows (F168-M2, here
	// extended to the firing inbox for F175-M7).
	// 非枚举状态大声拒（422），而非静默匹配 0 行（F168-M2，此处为 F175-M7 延伸到 firing 收件箱）。
	if filter.Status != "" && !slices.Contains(triggerdomain.FiringStatuses, filter.Status) {
		return nil, triggerdomain.ErrInvalidFiringStatus.WithDetails(map[string]any{"allowed": triggerdomain.FiringStatuses, "got": filter.Status})
	}
	q := s.frs.Query()
	if filter.TriggerID != "" {
		q = q.WhereEq("trigger_id", filter.TriggerID)
	}
	if filter.Status != "" {
		q = q.WhereEq("status", filter.Status)
	}
	// Half-open window [CreatedAfter, CreatedBefore) on created_at (scheduler 工单⑭) — the flowrun
	// ListFilter started_at window VERBATIM. Plain column comparisons (no julianday wrapping): bound
	// values and stored values go through the same driver serialization (UTC — the handler normalizes),
	// and a bare created_at predicate stays sargable on idx_trf_ws_created / idx_trf_ws_status /
	// idx_trf_ws_trigger (workspace equality + created_at range).
	//
	// created_at 上的半开窗 [CreatedAfter, CreatedBefore)（scheduler 工单⑭）——**逐字**是 flowrun
	// ListFilter 的 started_at 窗。裸列比较（不包 julianday）：绑定值与存储值走同一 driver 序列化
	// （UTC——handler 归一），裸 created_at 谓词在 idx_trf_ws_created / idx_trf_ws_status /
	// idx_trf_ws_trigger 上可走索引（workspace 等值 + created_at 范围）。
	if !filter.CreatedAfter.IsZero() {
		q = q.Where("created_at >= ?", filter.CreatedAfter)
	}
	if !filter.CreatedBefore.IsZero() {
		q = q.Where("created_at < ?", filter.CreatedBefore)
	}
	return q, nil
}

// SearchFirings pages the firing inbox newest-first (the disposition surface). An empty
// filter.TriggerID spans the whole workspace — a firing is a workspace-level log row, and the
// Overview's 24h schedule track asks exactly that question.
//
// SearchFirings 分页 firing 收件箱（最新优先，处置面）。filter.TriggerID 为空即跨整个 workspace——
// firing 是 workspace 级日志行，Overview 的 24h 调度轨道问的正是这个问题。
func (s *Store) SearchFirings(ctx context.Context, filter triggerdomain.FiringFilter) ([]*triggerdomain.Firing, string, error) {
	q, err := s.firingQuery(filter)
	if err != nil {
		return nil, "", err
	}
	rows, next, err := q.Page(ctx, filter.Cursor, filter.Limit)
	if err != nil {
		return nil, "", fmt.Errorf("triggerstore.SearchFirings: %w", err)
	}
	return rows, next, nil
}

// CountFirings counts the firings SearchFirings would page through (Cursor/Limit ignored — a count
// is not a page). It exists for the Overview's "错过 N" KPI card, which must never be an all-time
// number: an ever-growing count of everything ever missed is a vanity number that says nothing about
// today, so the caller always carries a window.
//
// CountFirings 数 SearchFirings 会翻过的那些 firing（Cursor/Limit 忽略——计数不是一页）。它为 Overview
// 的「错过 N」KPI 牌而在，而那张牌**绝不**能是 all-time 数字：一个「有史以来错过多少」的只增计数是虚荣
// 数字、对今天什么都没说，故调用方恒带窗口。
func (s *Store) CountFirings(ctx context.Context, filter triggerdomain.FiringFilter) (int, error) {
	q, err := s.firingQuery(filter)
	if err != nil {
		return 0, err
	}
	n, err := q.Count(ctx)
	if err != nil {
		return 0, fmt.Errorf("triggerstore.CountFirings: %w", err)
	}
	return int(n), nil
}

// MarkFiringOutcome sets a non-started terminal status (skipped/superseded/shed) — every
// firing reaches a terminal status, never silently dropped. Best-effort on a missing row.
//
// MarkFiringOutcome 置非 started 终态（skipped/superseded/shed）——每条 firing 都有终态，绝不静默丢。
func (s *Store) MarkFiringOutcome(ctx context.Context, firingID, status string) error {
	if _, err := s.frs.WhereEq("id", firingID).Update(ctx, "status", status); err != nil {
		return fmt.Errorf("triggerstore.MarkFiringOutcome: %w", err)
	}
	return nil
}

// SupersedeAllButNewestPending collapses a workflow's PENDING firings to the latest — buffer_one's
// "keep only the latest waiting" disposition. It finds the newest pending firing (created_at, then id,
// DESC for a deterministic same-instant tiebreak) and marks every OTHER pending firing for that
// workflow superseded, returning the survivor's id ("" if none pending) and the count superseded.
// Order-independent: whichever firing the drain happens to process, only the newest is ever a run
// candidate — so an older waiting firing can never escape the policy by being evaluated when nothing
// is in flight. Workspace-isolated by the orm from ctx.
//
// SupersedeAllButNewestPending 把某 workflow 的 PENDING firing 收敛到最新一条——buffer_one「只留最新待处理」
// 处置。找最新待处理 firing（created_at、再 id，DESC 使同刻确定 tiebreak），把该 workflow **其余**每条待处理
// firing 标 superseded，返存活者 id（无待处理则 ""）与被 supersede 数。与处理顺序无关：无论 drain 先处理哪条，
// 只有最新一条会成为 run 候选——故更早的待处理 firing 不会因「评估时恰无 run 在途」而漏过策略。orm 据 ctx 隔离。
func (s *Store) SupersedeAllButNewestPending(ctx context.Context, workflowID string) (string, int64, error) {
	newest, err := s.frs.WhereEq("workflow_id", workflowID).
		WhereEq("status", triggerdomain.FiringPending).
		Order("created_at DESC, id DESC").First(ctx)
	if err != nil {
		if errors.Is(err, ormpkg.ErrNotFound) {
			return "", 0, nil // nothing pending for this workflow
		}
		return "", 0, fmt.Errorf("triggerstore.SupersedeAllButNewestPending: newest: %w", err)
	}
	n, err := s.frs.WhereEq("workflow_id", workflowID).
		WhereEq("status", triggerdomain.FiringPending).
		Where("id != ?", newest.ID).
		Update(ctx, "status", triggerdomain.FiringSuperseded)
	if err != nil {
		return "", 0, fmt.Errorf("triggerstore.SupersedeAllButNewestPending: %w", err)
	}
	return newest.ID, n, nil
}

// ClaimFiring is store-concrete (NOT in the domain Repository): the single-transaction claim
// + flowrun build, consumed by the scheduler. It atomically claims the
// firing (pending→claimed only if still pending), runs create(tx) to build the flowrun in the
// SAME tx, then backfills started + flowrun_id. A crash before commit rolls back (firing stays
// pending); there is never a claimed-but-no-flowrun strand. ErrFiringNotPending = race lost.
//
// ClaimFiring 是 store 具体方法（不在 domain 接口）：单事务 claim + 建 flowrun，
// scheduler 消费。同事务内 claim（仅当仍 pending）→ create(tx) 建 flowrun → 回填 started+flowrun_id；
// commit 前崩溃则回滚（firing 仍 pending），无 claimed-但-无-flowrun 残留态。
func (s *Store) ClaimFiring(ctx context.Context, firingID string, create func(tx *ormpkg.DB) (string, error)) (string, error) {
	var flowrunID string
	err := s.db.Transaction(ctx, func(tx *ormpkg.DB) error {
		frs := ormpkg.For[triggerdomain.Firing](tx, "trigger_firings")
		n, uErr := frs.
			WhereEq("id", firingID).
			WhereEq("status", triggerdomain.FiringPending).
			Update(ctx, "status", triggerdomain.FiringClaimed)
		if uErr != nil {
			return uErr
		}
		if n == 0 {
			return triggerdomain.ErrFiringNotPending
		}
		fid, cErr := create(tx)
		if cErr != nil {
			return cErr
		}
		flowrunID = fid
		_, fErr := frs.WhereEq("id", firingID).Updates(ctx, map[string]any{
			"status":     triggerdomain.FiringStarted,
			"flowrun_id": fid,
		})
		return fErr
	})
	if err != nil {
		if errors.Is(err, triggerdomain.ErrFiringNotPending) {
			return "", err
		}
		return "", fmt.Errorf("triggerstore.ClaimFiring: %w", err)
	}
	return flowrunID, nil
}
