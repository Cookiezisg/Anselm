package scheduler

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// ListRuns pages a workspace's flowruns (newest-first; optional WorkflowID filter) for the run
// history view.
//
// ListRuns 分页一个 workspace 的 flowrun（最新优先；可选 WorkflowID）供运行历史视图。
func (s *Service) ListRuns(ctx context.Context, filter flowrundomain.ListFilter) ([]*flowrundomain.FlowRun, string, error) {
	return s.runs.ListRuns(ctx, filter)
}

// GetRunWithNodes returns a run header + all its node rows (the full memoization) for the run-detail
// view — including parked approval rows (the inbox is GetRunWithNodes filtered, or ListInbox).
//
// GetRunWithNodes 返 run 头 + 它全部节点行（完整记忆化）供 run 详情视图——含 parked approval 行。
func (s *Service) GetRunWithNodes(ctx context.Context, id string) (*flowrundomain.FlowRun, []*flowrundomain.FlowRunNode, error) {
	run, err := s.runs.GetRun(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	nodes, err := s.runs.GetNodes(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	return run, nodes, nil
}

// GetRunWithNodesPage returns a run header + ONE keyset page of its node rows + the next cursor (N4) —
// the bounded REST run-detail read. A long loop run has thousands of node rows, so the wire pages them
// (the scheduler's GetRunWithNodes full dump is the interpreter's, not the wire's, F168-M7).
//
// GetRunWithNodesPage 返 run 头 + 它节点行的一页 keyset + 下一 cursor（N4）——有界的 REST run 详情读。
// 长 loop run 有数千节点行，故线缆分页（scheduler 的 GetRunWithNodes 全量倾倒是给解释器的、非线缆的，F168-M7）。
func (s *Service) GetRunWithNodesPage(ctx context.Context, id, cursor string, limit int) (*flowrundomain.FlowRun, []*flowrundomain.FlowRunNode, string, error) {
	run, err := s.runs.GetRun(ctx, id)
	if err != nil {
		return nil, nil, "", err
	}
	nodes, next, err := s.runs.ListNodes(ctx, id, cursor, limit)
	if err != nil {
		return nil, nil, "", err
	}
	return run, nodes, next, nil
}

// ListActivity returns a run's execution-log activity page (scheduler 工单⑤): the four audit
// tables UNIONed by flowrun_id + the queue stamp joined off the flowrun_nodes truth row (工单⑫),
// in gantt order (startedAt ascending). GetRun first so an unknown id is an honest 404
// (FLOWRUN_NOT_FOUND) — the projection alone cannot tell "no activity yet" from "no such run".
//
// ListActivity 返一个 run 的执行日志活动页（scheduler 工单⑤）：四张审计表按 flowrun_id UNION +
// 排队戳 join 自 flowrun_nodes 真相行（工单⑫），按甘特序（startedAt 升序）。先 GetRun 使未知 id 是
// 诚实 404（FLOWRUN_NOT_FOUND）——光靠投影分不清「还没活动」与「无此 run」。
func (s *Service) ListActivity(ctx context.Context, flowrunID, cursor string, limit int) ([]*flowrundomain.ActivityRow, string, error) {
	if _, err := s.runs.GetRun(ctx, flowrunID); err != nil {
		return nil, "", err
	}
	return s.runs.ListActivity(ctx, flowrunID, cursor, limit)
}

// InboxRow is one parked approval node enriched with its run's workflow context (工单④): the
// embedded node row (the decidable truth) + workflowId/workflowName (joined from the run header —
// a parked row alone cannot say WHICH workflow is waiting) + the optional absolute deadline
// (parkedAt + the pinned approval version's timeout, the same semantic CheckTimeouts sweeps on).
// Wire: camelCase, enrich fields omitted when unresolvable (absent run header → no workflow
// fields; no/unparseable timeout → no deadline — absence is honest, never a zero value).
//
// InboxRow 是一条 parked approval 节点行 + 其 run 的 workflow 上下文（工单④）：内嵌节点行（可决策
// 的真相）+ workflowId/workflowName（join 自 run 头——parked 行自身说不出是哪个 workflow 在等）+
// 可空绝对期限（parkedAt + 钉死 approval 版本的 timeout，与 CheckTimeouts 扫描同一语义）。线缆
// camelCase，enrich 字段解析不出即缺席（run 头缺 → 无 workflow 字段；无/不可解析 timeout → 无
// deadline——缺席即诚实、绝不发零值）。
type InboxRow struct {
	flowrundomain.FlowRunNode
	WorkflowID   string     `json:"workflowId,omitempty"`
	WorkflowName string     `json:"workflowName,omitempty"`
	Deadline     *time.Time `json:"deadline,omitempty"`
}

// ListInbox returns every parked approval node in the workspace — the approval inbox (parked rows
// ARE the inbox; no separate projection table) — each row enriched with workflow context (工单④).
// Bounded batch reads, never per-row N+1: run headers in ONE GetRunsByIDs, workflow names in ONE
// NamesByIDs (a soft-deleted workflow's name falls back to the bare id — the relation Namer
// precedent), and approval versions memoized per (ref, pinnedVersion). A form that fails to
// resolve only costs that row its deadline (best-effort, logged) — the row itself must stay
// visible and decidable, exactly like CheckTimeouts keeps sweeping past it.
//
// ListInbox 返 workspace 内所有 parked approval 节点——审批收件箱（parked 行即收件箱，无投影表）——
// 每行带 workflow 上下文 enrich（工单④）。有界批读、绝不逐行 N+1：run 头一条 GetRunsByIDs、
// workflow 名一条 NamesByIDs（软删 workflow 名回落裸 id——relation Namer 先例）、approval 版本按
// (ref, 钉死版本) 记忆化。form 解析失败只让该行没 deadline（best-effort、记日志）——行本身必须
// 保持可见可决策，正如 CheckTimeouts 扫不动它也继续扫。
func (s *Service) ListInbox(ctx context.Context) ([]*InboxRow, error) {
	parked, err := s.runs.ListParkedNodes(ctx)
	if err != nil {
		return nil, err
	}
	if len(parked) == 0 {
		return []*InboxRow{}, nil
	}

	runIDs := make([]string, 0, len(parked))
	seenRun := make(map[string]bool, len(parked))
	for _, p := range parked {
		if !seenRun[p.FlowRunID] {
			seenRun[p.FlowRunID] = true
			runIDs = append(runIDs, p.FlowRunID)
		}
	}
	runs, err := s.runs.GetRunsByIDs(ctx, runIDs)
	if err != nil {
		return nil, fmt.Errorf("schedulerapp.ListInbox: %w", err)
	}
	runByID := make(map[string]*flowrundomain.FlowRun, len(runs))
	wfIDs := make([]string, 0, len(runs))
	seenWf := make(map[string]bool, len(runs))
	for _, r := range runs {
		runByID[r.ID] = r
		if !seenWf[r.WorkflowID] {
			seenWf[r.WorkflowID] = true
			wfIDs = append(wfIDs, r.WorkflowID)
		}
	}
	names, err := s.workflows.NamesByIDs(ctx, wfIDs)
	if err != nil {
		return nil, fmt.Errorf("schedulerapp.ListInbox: %w", err)
	}

	// Approval versions memoized per (ref, pinned version): the inbox is bounded, but many rows can
	// park on the same form version — resolve each distinct one once.
	// approval 版本按 (ref, 钉死版本) 记忆化：收件箱有界，但多行可 park 在同一表版本上——每个不同的只解析一次。
	type formKey struct{ ref, ver string }
	forms := map[formKey]*approvaldomain.Version{}

	rows := make([]*InboxRow, 0, len(parked))
	for _, p := range parked {
		row := &InboxRow{FlowRunNode: *p}
		rows = append(rows, row)
		run := runByID[p.FlowRunID]
		if run == nil {
			continue // no run header (should not happen) — honest absence over invented context
		}
		row.WorkflowID = run.WorkflowID
		if name := names[run.WorkflowID]; name != "" {
			row.WorkflowName = name
		} else {
			row.WorkflowName = run.WorkflowID // soft-deleted / unknown → bare id (relation Namer precedent)
		}
		key := formKey{ref: p.Ref, ver: run.PinnedRefs[entityIDOf(p.Ref)]}
		form, resolved := forms[key]
		if !resolved {
			form, err = s.approval.Resolve(ctx, key.ref, key.ver)
			if err != nil {
				s.log.Warn("schedulerapp.ListInbox: resolve form (deadline omitted)", zap.String("ref", p.Ref), zap.Error(err))
				form = nil
			}
			forms[key] = form
		}
		if form != nil {
			if deadline, ok := form.DeadlineFrom(p.CreatedAt); ok {
				row.Deadline = &deadline
			}
		}
	}
	return rows, nil
}

// RunStats answers the operational statistics batch (scheduler 工单③ + ⑭): workspace-wide totals +
// one health row per requested workflow id. This is the single place defaults + guards live —
// ids dedup preserving request order, the loud >50 rejection (with the cap in Details), RecentN
// default/clamp, and the 7d default window — so every caller (REST today) gets one behavior.
//
// It is also where the ONE cross-domain total is stitched: Totals.Missed counts trigger_firings
// through the FiringInbox port (工单⑭). It lands HERE, after q.Since is defaulted, on purpose —
// the missed window is then not merely documented to match completedSince/failedSince, it is
// physically the same value.
//
// RunStats 应答运营统计批查（scheduler 工单③ + ⑭）：全 workspace 聚合 + 每个请求 workflow id 一条健康行。
// 默认值 + 守卫的唯一居所——ids 保序去重、>50 大声拒（Details 带上限）、RecentN 默认/钳制、7d 默认
// 窗口——所有调用方（今天是 REST）拿同一行为。
//
// 唯一一个**跨域** total 也缝在这里：Totals.Missed 经 FiringInbox 端口数 trigger_firings（工单⑭）。
// 它**刻意**落在 q.Since defaulted **之后**——如此一来，missed 的窗口与 completedSince/failedSince
// 就不只是「文档上说一致」，而是物理上同一个值。
func (s *Service) RunStats(ctx context.Context, q flowrundomain.StatsQuery) (*flowrundomain.RunStats, error) {
	if len(q.WorkflowIDs) > 0 {
		seen := make(map[string]bool, len(q.WorkflowIDs))
		deduped := make([]string, 0, len(q.WorkflowIDs))
		for _, id := range q.WorkflowIDs {
			if id == "" || seen[id] {
				continue
			}
			seen[id] = true
			deduped = append(deduped, id)
		}
		q.WorkflowIDs = deduped
	}
	if len(q.WorkflowIDs) > flowrundomain.StatsMaxWorkflowIDs {
		return nil, flowrundomain.ErrStatsTooManyIDs.WithDetails(map[string]any{
			"allowed": flowrundomain.StatsMaxWorkflowIDs,
			"got":     len(q.WorkflowIDs),
		})
	}
	if q.RecentN <= 0 {
		q.RecentN = flowrundomain.StatsDefaultRecentN
	}
	if q.RecentN > flowrundomain.StatsMaxRecentN {
		q.RecentN = flowrundomain.StatsMaxRecentN
	}
	if q.Since.IsZero() {
		q.Since = time.Now().UTC().Add(-flowrundomain.StatsDefaultWindow)
	}
	stats, err := s.runs.RunStats(ctx, q)
	if err != nil {
		return nil, err
	}
	// The "错过 N" card (工单⑭). A nil inbox is a deployment with no firing store at all, so 0 is the
	// truth. A FAILING count is not: propagate it rather than serve a 0, because "you missed nothing"
	// and "I could not find out" are different sentences and only one of them is safe to render as a
	// reassuring empty card.
	//
	// 「错过 N」牌（工单⑭）。inbox 为 nil = 这个部署根本没有 firing 存储，故 0 就是真相。而计数**失败**
	// 不是：宁可把错误冒上去、也不端一个 0 出去——「你什么都没错过」与「我查不出来」是两句不同的话，
	// 而只有其中一句可以安心地渲成一张让人放心的空牌。
	if s.inbox != nil {
		missed, err := s.inbox.CountFirings(ctx, triggerdomain.FiringFilter{
			Status:       triggerdomain.FiringMissed,
			CreatedAfter: q.Since,
		})
		if err != nil {
			return nil, fmt.Errorf("scheduler.RunStats: count missed firings: %w", err)
		}
		stats.Totals.Missed = missed
	}
	return stats, nil
}

// RunMatrix answers the node×run status grid (scheduler 工单⑩) for an explicit batch of run ids.
// Guards live here, VERBATIM the RunStats ids discipline: dedup preserving request order (blank
// ids skipped), an empty set is a 400 (no runs, no grid — rejecting beats minting a meaningless
// empty answer), and over-cap after dedup rejects loudly with the cap in Details — never a silent
// truncation. Which runs are asked for is the client's business (it pages GET /flowruns); output
// column order is the store's canonical (started_at, id) DESC regardless of request order.
//
// RunMatrix 应答一批显式 run id 的节点×run 状态格阵（scheduler 工单⑩）。守卫落在这里，**逐字**沿用
// RunStats 的 ids 纪律：按请求序去重（空串跳过）、空集 400（无 run 即无格阵——拒绝胜过铸一个无意义的
// 空答案）、去重后越上限带上限大声拒——绝不静默截断。要哪些 run 是客户端的事（它翻 GET /flowruns）；
// 输出列序恒为 store 的正典 (started_at, id) DESC、与请求顺序无关。
func (s *Service) RunMatrix(ctx context.Context, q flowrundomain.MatrixQuery) (*flowrundomain.Matrix, error) {
	seen := make(map[string]bool, len(q.FlowrunIDs))
	deduped := make([]string, 0, len(q.FlowrunIDs))
	for _, id := range q.FlowrunIDs {
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		deduped = append(deduped, id)
	}
	q.FlowrunIDs = deduped
	if len(q.FlowrunIDs) == 0 {
		return nil, errorspkg.ErrInvalidRequest
	}
	if len(q.FlowrunIDs) > flowrundomain.MatrixMaxFlowrunIDs {
		return nil, flowrundomain.ErrMatrixTooManyIDs.WithDetails(map[string]any{
			"allowed": flowrundomain.MatrixMaxFlowrunIDs,
			"got":     len(q.FlowrunIDs),
		})
	}
	return s.runs.RunMatrix(ctx, q)
}
