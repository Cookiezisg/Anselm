package scheduler

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.uber.org/zap"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// StartInput parameterises a new run. WorkflowID is required; the rest are optional. EntryNode picks
// the entry trigger node when a graph has several (manual path); TriggerID picks it by referenced
// trg_ (firing path). Payload becomes the trigger node's result — the data the workflow reads as
// `<triggerNode>.field`. Origin/ConversationID are creation-time provenance (flowrundomain.RunOrigins):
// every production caller stamps them — HTTP "Run now" = manual, the runner adapter derives
// chat(+conversation) vs manual from ctx, claimFiring stamps the trigger's kind.
//
// StartInput 参数化一个新 run。WorkflowID 必填，其余可选。EntryNode 在多 trigger 图里选入口（手动）；
// TriggerID 按引用的 trg_ 选（firing）。Payload 成为 trigger 节点的 result——workflow 读 `<trigger>.字段`。
// Origin/ConversationID 是创建时溯源（flowrundomain.RunOrigins）：所有生产调用方逐个盖章——HTTP「Run now」
// = manual、runner 适配器按 ctx 派生 chat(+conversation) 或 manual、claimFiring 盖 trigger 的 kind。
type StartInput struct {
	WorkflowID     string
	EntryNode      string // explicit entry node id (manual, multi-trigger)
	TriggerID      string // entry by referenced trg_ (firing path)
	Payload        map[string]any
	FiringID       string // source firing (firing path); "" for manual
	Origin         string // run provenance ∈ flowrundomain.RunOrigins ("" only in tests → NULL)
	ConversationID string // origin=chat: the conversation whose turn started the run
}

// StartRun is the manual-trigger path (UI/API "Run now"): build the run + seed its trigger node in
// one transaction, then advance. No firing claim (a human asked once — nothing to dedup). Returns
// the new flowrun id.
//
// StartRun 是手动 trigger 路径（UI/API「Run now」）：单事务建 run + seed trigger 节点，再 advance。
// 无 firing claim（人明确点一次、没东西可去重）。返新 flowrun id。
func (s *Service) StartRun(ctx context.Context, in StartInput) (string, error) {
	run, trig, err := s.buildRun(ctx, in)
	if err != nil {
		return "", err
	}
	if _, err := s.runs.CreateRunWithTrigger(ctx, run, trig); err != nil {
		return "", fmt.Errorf("schedulerapp.StartRun: %w", err)
	}
	s.emitRunStarted(ctx, run) // durable birth signal, before any node tick — see emitRunStarted
	// Manual path: drive INLINE on this request goroutine (the per-run guard makes it the sole driver of
	// this fresh run — the pool never touches it), so StartRun still returns only after the run reaches
	// terminal/parked. No head-of-line blocking here: one user, one run (F174).
	// 手动路径：在本请求 goroutine 上**内联**驱动（per-run guard 使其作为这个 fresh run 的唯一驱动者——池绝不碰
	// 它），故 StartRun 仍跑到终态/parked 才返回。此处无 HOL：一个用户、一个 run（F174）。
	if err := s.drive(ctx, run.ID); err != nil {
		return run.ID, err // run exists; surface the advance error but keep the id
	}
	return run.ID, nil
}

// buildRun resolves the workflow's active version, pins its referenced entities, finds the entry
// trigger node, and assembles the (run header, seed trigger node) pair — all READS, done outside any
// claim transaction (the firing path then writes them in the claim tx via SeedRunOnTx).
//
// buildRun 解析 workflow 的 active 版本、pin 其引用实体、找入口 trigger 节点、组装 (run 头, seed
// trigger 节点)——全是读，在任何 claim 事务之外做（firing 路径再经 SeedRunOnTx 在 claim 事务里写）。
func (s *Service) buildRun(ctx context.Context, in StartInput) (*flowrundomain.FlowRun, *flowrundomain.FlowRunNode, error) {
	ver, err := s.workflows.GetActiveVersion(ctx, in.WorkflowID)
	if err != nil {
		return nil, nil, fmt.Errorf("schedulerapp.buildRun: active version: %w", err)
	}
	graph, err := decodeGraph(ver.Graph)
	if err != nil {
		return nil, nil, err
	}
	entry, err := resolveEntry(graph, in.EntryNode, in.TriggerID)
	if err != nil {
		return nil, nil, err
	}
	pins, err := s.workflows.BuildPinClosure(ctx, graph)
	if err != nil {
		return nil, nil, fmt.Errorf("schedulerapp.buildRun: pin closure: %w", err)
	}
	payload := in.Payload
	if payload == nil {
		payload = map[string]any{}
	}
	run := &flowrundomain.FlowRun{
		WorkflowID: in.WorkflowID,
		VersionID:  ver.ID,
		PinnedRefs: pins,
		TriggerID:  in.TriggerID,
		FiringID:   in.FiringID,
		Status:     flowrundomain.StatusRunning,
	}
	// Provenance stamps: pointers so an unstamped run stays NULL (distinguishable from any real word),
	// exactly like the pre-provenance rows the wire omits.
	// 溯源盖章：指针使未盖章的 run 保持 NULL（与任何真值可区分），同线缆不发的旧行一致。
	if in.Origin != "" {
		run.Origin = &in.Origin
	}
	if in.ConversationID != "" {
		run.ConversationID = &in.ConversationID
	}
	trig := &flowrundomain.FlowRunNode{
		NodeID: entry.ID,
		Kind:   workflowdomain.NodeKindTrigger,
		Ref:    entry.Ref,
		Status: flowrundomain.NodeCompleted,
		Result: payload,
	}
	return run, trig, nil
}

// resolveEntry picks the entry trigger node: an explicit entryNode id (manual, multi-trigger) wins;
// else the node referencing triggerRef (firing path); else the sole trigger node. Ambiguity (many
// triggers, no selector) or a bad selector is ErrInvalidEntry.
//
// resolveEntry 选入口 trigger 节点：显式 entryNode id（手动、多 trigger）优先；否则引用 triggerRef 的
// 节点（firing）；否则唯一的 trigger 节点。歧义（多 trigger 无选择器）或选择器错 = ErrInvalidEntry。
func resolveEntry(graph *workflowdomain.Graph, entryNode, triggerRef string) (*workflowdomain.Node, error) {
	if entryNode != "" {
		for i := range graph.Nodes {
			n := &graph.Nodes[i]
			if n.ID == entryNode {
				if n.Kind != workflowdomain.NodeKindTrigger {
					return nil, flowrundomain.ErrInvalidEntry.WithDetails(map[string]any{"reason": fmt.Sprintf("entry node %q is kind %q, not a trigger", entryNode, n.Kind)})
				}
				return n, nil
			}
		}
		return nil, flowrundomain.ErrInvalidEntry.WithDetails(map[string]any{"reason": fmt.Sprintf("entry node %q not found", entryNode)})
	}
	if triggerRef != "" {
		for i := range graph.Nodes {
			n := &graph.Nodes[i]
			if n.Kind == workflowdomain.NodeKindTrigger && n.Ref == triggerRef {
				return n, nil
			}
		}
		return nil, flowrundomain.ErrInvalidEntry.WithDetails(map[string]any{"reason": fmt.Sprintf("no trigger node references %q", triggerRef)})
	}
	var sole *workflowdomain.Node
	count := 0
	for i := range graph.Nodes {
		if graph.Nodes[i].Kind == workflowdomain.NodeKindTrigger {
			sole = &graph.Nodes[i]
			count++
		}
	}
	switch count {
	case 0:
		return nil, flowrundomain.ErrInvalidEntry.WithDetails(map[string]any{"reason": "graph has no trigger node"})
	case 1:
		return sole, nil
	default:
		return nil, flowrundomain.ErrInvalidEntry.WithDetails(map[string]any{"reason": "graph has multiple trigger nodes; specify entryNode"})
	}
}

// DrainFirings claims every pending firing and turns it into a run (the automatic path). No-op when
// no inbox is wired (manual-only deployments). Per-firing failures are logged and skipped — one bad
// firing must not stall the queue.
//
// DrainFirings claim 每条 pending firing 转成 run（自动路径）。无 inbox 时 no-op（纯手动部署）。逐条
// 失败记日志跳过——一条坏 firing 不该卡住队列。
func (s *Service) DrainFirings(ctx context.Context) error {
	if s.inbox == nil {
		return nil
	}
	firings, err := s.inbox.ListPendingFirings(ctx, 100)
	if err != nil {
		return fmt.Errorf("schedulerapp.DrainFirings: list pending: %w", err)
	}
	// Two phases so the overlap policy can SEE siblings: phase 1 decides + claims every firing IN ORDER
	// (each survivor is committed as a running run before the next firing is decided); phase 2 ENQUEUES
	// each seeded run onto the Advance worker pool. Deciding and advancing a firing together (the old
	// inline path) ran firing #1's run to completion before firing #2 was even decided — so
	// CountRunningByWorkflow always saw 0 and skip/replace/buffer_one never engaged for back-to-back
	// fires. Splitting them lets a later sibling's overlapDecision observe the earlier sibling already
	// in-flight. PHASE 1 STAYS STRICTLY SEQUENTIAL+ORDERED (its correctness depends on each survivor
	// being committed running before the next firing is decided). Only phase 2 is parallelized: enqueue
	// is fast (the pool drives the slow nodes off this goroutine), so a slow node can no longer
	// head-of-line-block later firings / workspaces / the next tick / CheckTimeouts (F174). replace just
	// pre-empts the earlier seeded run (cancelRunningForReplace marks it terminal) so its pooled Advance
	// no-ops at the status-entry check.
	//
	// 两阶段使 overlap 策略能**看见**兄弟 firing：阶段 1 按序决策 + claim 每条 firing（每个存活者在下一条被决策前
	// 已落为 running run）；阶段 2 把每个已 seed 的 run **入队**到 Advance worker 池。把决策与 advance 合一（旧
	// 内联路径）会让 firing #1 的 run 在 firing #2 被决策前就跑完——故 CountRunningByWorkflow 永远见 0、
	// skip/replace/buffer_one 对背靠背触发从不生效。拆开使后到兄弟的 overlapDecision 能观测到先到兄弟已在途。
	// **阶段 1 严格顺序+有序**（其正确性依赖每个存活者在下一条被决策前已落 running）。只并行阶段 2：入队很快
	// （池在本 goroutine 之外驱动慢节点），故慢节点再也卡不住后面的 firing / workspace / 下一 tick /
	// CheckTimeouts（F174）。replace 只是抢占先 seed 的 run（cancelRunningForReplace 标其终态），其池上 Advance
	// 在状态入口检查处 no-op。
	type seeded struct {
		runID string
		fctx  context.Context
	}
	pending := make([]seeded, 0, len(firings))
	for _, f := range firings {
		runID, fctx, err := s.claimFiring(ctx, f)
		if err != nil {
			s.log.Warn("schedulerapp: consume firing failed", zap.String("firing", f.ID), zap.Error(err))
			continue
		}
		if runID != "" {
			pending = append(pending, seeded{runID, fctx})
		}
	}
	for _, p := range pending {
		s.enqueueAdvance(p.fctx, p.runID) // pooled (or inline if no pool) — see pool.go
	}
	return nil
}

// claimFiring applies the workflow's overlap policy to one firing and, if it should run, claims it into
// a seeded (running) run — returning that run's id (and the firing's workspace ctx) for DrainFirings to
// advance in phase 2. It does NOT advance: seeding every batch firing before advancing any is what lets
// the overlap policy see siblings (see DrainFirings). A "" runID means there is nothing to advance —
// the firing was deferred (serial/buffer_one waiting), skipped, shed (deleted workflow), or it lost the
// claim race. The single-tx claim (ClaimFiring) does pending→claimed + SeedRunOnTx + the started
// backfill atomically so a crash can never leave a claimed-but-no-run strand.
//
// claimFiring 对一条 firing 应用 workflow overlap 策略，若该跑则 claim 成已 seed（running）的 run——返回该 run
// id（与 firing 的 workspace ctx）供 DrainFirings 阶段 2 advance。它**不** advance：先 seed 批内每条再 advance
// 是 overlap 策略能看见兄弟的关键（见 DrainFirings）。"" runID 表无可 advance——firing 被 defer（serial/buffer_one
// 等待）、skip、shed（workflow 已删）、或抢 claim 失败。单事务 claim 原子做 pending→claimed + SeedRunOnTx + started
// 回填，崩溃绝不留 claimed-但-无-run 残留。
func (s *Service) claimFiring(ctx context.Context, f *triggerdomain.Firing) (string, context.Context, error) {
	fctx := reqctxpkg.SetWorkspaceID(ctx, f.WorkspaceID)

	action, outcome, err := s.overlapDecision(fctx, f)
	if err != nil {
		// A firing whose workflow has been DELETED can never become a run — shed it terminally instead
		// of returning a retryable error, which would leave it pending and make DrainFirings re-attempt
		// (and re-log) the orphan every tick forever. FiringShed is the existing "won't run" terminal
		// status; the firing inbox is a Log table so this is its proper resting state.
		// workflow 已被删的 firing 永远成不了 run——终态 shed 之，而非返可重试错误（那会留它 pending、使
		// DrainFirings 每 tick 重试+重记这条孤儿、永不终结）。FiringShed 是既有「不会跑」终态；firing 收件箱是
		// Log 表，这就是它该有的归宿态。
		if errors.Is(err, workflowdomain.ErrNotFound) {
			return "", fctx, s.inbox.MarkFiringOutcome(fctx, f.ID, triggerdomain.FiringShed)
		}
		return "", fctx, err
	}
	switch action {
	case overlapDefer:
		return "", fctx, nil // serial/buffer_one + a run already in flight → leave pending, re-drained later
	case overlapSkip:
		return "", fctx, s.inbox.MarkFiringOutcome(fctx, f.ID, outcome)
	case overlapReplace:
		// replace: gracefully cancel the in-flight run(s) (incl. a sibling just seeded earlier in this
		// same batch), then fall through to claim this firing — the cancelled run's phase-2 Advance no-ops.
		if err := s.cancelRunningForReplace(fctx, f.WorkflowID); err != nil {
			return "", fctx, err
		}
	}

	// Provenance: a fired run's origin IS its trigger's source kind (one vocabulary — see
	// flowrundomain.RunOrigins). Best-effort: a lookup failure (e.g. the trigger was deleted after
	// firing) leaves origin NULL — provenance is presentation metadata and must never stall a run.
	// 溯源：firing 起的 run，origin 即其 trigger 的 source kind（同一词表——见 flowrundomain.RunOrigins）。
	// best-effort：查失败（如 firing 后 trigger 被删）origin 留 NULL——溯源是呈现元数据，绝不拖垮 run。
	origin := ""
	if kind, kerr := s.inbox.TriggerKind(fctx, f.TriggerID); kerr == nil {
		origin = kind
	} else {
		s.log.Warn("schedulerapp.claimFiring: resolve trigger kind for provenance", zap.String("trigger", f.TriggerID), zap.Error(kerr))
	}

	// reads outside the tx (active version + pin + entry resolution).
	run, trig, err := s.buildRun(fctx, StartInput{
		WorkflowID: f.WorkflowID,
		TriggerID:  f.TriggerID,
		Payload:    f.Payload,
		FiringID:   f.ID,
		Origin:     origin,
	})
	if err != nil {
		return "", fctx, err
	}

	runID, err := s.inbox.ClaimFiring(fctx, f.ID, func(tx *ormpkg.DB) (string, error) {
		if err := s.runs.SeedRunOnTx(fctx, tx, run, trig); err != nil {
			return "", err
		}
		return run.ID, nil
	})
	if err != nil {
		if errors.Is(err, triggerdomain.ErrFiringNotPending) {
			return "", fctx, nil // lost the claim race (already consumed) — fine
		}
		return "", fctx, fmt.Errorf("schedulerapp.claimFiring: claim: %w", err)
	}
	s.emitRunStarted(fctx, run) // durable birth signal at claim commit (phase-2 advance comes later)
	return runID, fctx, nil
}

type overlapAction int

const (
	overlapRun overlapAction = iota
	overlapSkip
	overlapDefer
	overlapReplace
)

// overlapDecision applies the workflow's concurrency policy to a new firing when a run is already in
// flight. All five policies are implemented: skip drops the new firing, serial defers it, buffer_one
// defers it AND supersedes this workflow's older pending firings (keep only the latest waiting),
// replace cancels the in-flight run(s) so the new firing runs in their place (claimFiring does the
// cancel), and allow_all runs concurrently. With nothing in flight, every policy just runs.
//
// overlapDecision 在已有 run 在途时对新 firing 应用 workflow 并发策略。五种全实现：skip 丢新 firing，serial
// 推迟它，buffer_one 推迟它**并** supersede 该 workflow 更早的待处理 firing（只留最新待处理），replace 取消
// 在途 run 使新 firing 顶替（取消在 claimFiring 做），allow_all 并发跑。无 run 在途时各策略都直接跑。
func (s *Service) overlapDecision(ctx context.Context, f *triggerdomain.Firing) (overlapAction, string, error) {
	w, err := s.workflows.GetWorkflow(ctx, f.WorkflowID)
	if err != nil {
		return overlapRun, "", fmt.Errorf("schedulerapp.overlapDecision: %w", err)
	}
	running, err := s.runs.CountRunningByWorkflow(ctx, f.WorkflowID)
	if err != nil {
		return overlapRun, "", err
	}
	switch w.Concurrency {
	case workflowdomain.ConcurrencySkip:
		if running > 0 {
			return overlapSkip, triggerdomain.FiringSkipped, nil
		}
		return overlapRun, "", nil
	case workflowdomain.ConcurrencySerial:
		if running > 0 {
			return overlapDefer, "", nil // wait, stays pending
		}
		return overlapRun, "", nil
	case workflowdomain.ConcurrencyBufferOne:
		// Keep only the LATEST waiting firing — collapse this workflow's pending firings to the newest
		// REGARDLESS of the in-flight count. (If we only superseded when running>0, an older waiting
		// firing evaluated while nothing is in flight would slip through overlapRun and execute,
		// violating keep-only-latest.) If this firing is not the survivor, it was just superseded → defer.
		//
		// 只留最新待处理 firing——无论是否有 run 在途，都把该 workflow 的待处理 firing 收敛到最新一条。（若只在
		// running>0 时 supersede，一条更早的待处理 firing 在无 run 在途时被评估就会从 overlapRun 漏过去执行、
		// 违反只留最新。）若本 firing 非存活者，它刚被 supersede → defer。
		if s.inbox != nil {
			newestID, _, err := s.inbox.SupersedeAllButNewestPending(ctx, f.WorkflowID)
			if err != nil {
				return overlapRun, "", fmt.Errorf("schedulerapp.overlapDecision: buffer_one: %w", err)
			}
			if f.ID != newestID {
				return overlapDefer, "", nil // not the latest — this firing was superseded
			}
		}
		if running > 0 {
			return overlapDefer, "", nil // the latest, but a run is in flight → wait
		}
		return overlapRun, "", nil // the latest + nothing in flight → run it
	case workflowdomain.ConcurrencyReplace:
		if running > 0 {
			return overlapReplace, "", nil // claimFiring cancels the in-flight run(s), then runs this one
		}
		return overlapRun, "", nil
	default: // allow_all
		return overlapRun, "", nil
	}
}

// Recover re-walks every still-running flowrun across all workspaces (boot crash recovery): each
// advance copies completed rows and re-runs whatever the crash interrupted (at-least-once). Each run
// advances in a context scoped to its own workspace.
//
// Recover 重走所有 workspace 中每个仍 running 的 flowrun（boot 崩溃恢复）：每次 advance 抄 completed
// 行、重跑崩溃打断的（at-least-once）。每个 run 在其自己 workspace 的 ctx 里 advance。
func (s *Service) Recover(ctx context.Context) error {
	running, err := s.runs.ListRunningRuns(ctx)
	if err != nil {
		return fmt.Errorf("schedulerapp.Recover: %w", err)
	}
	for _, run := range running {
		rctx := reqctxpkg.SetWorkspaceID(ctx, run.WorkspaceID)
		s.enqueueAdvance(rctx, run.ID) // pooled — a slow recovered run must not block boot (F174 boot variant)
	}
	return nil
}

// DecideApproval resolves a parked approval node with a human decision and re-drives the run. The
// conditional update is first-wins: a decision that loses to an earlier decision/timeout returns
// ErrNodeNotParked (a clean 422), never corrupting the recorded outcome.
//
// DecideApproval 用人工决策落定一个 parked approval 节点并重驱 run。条件更新 first-wins：输给更早
// 决策/超时的决策返 ErrNodeNotParked（干净 422），绝不污染已记结果。
func (s *Service) DecideApproval(ctx context.Context, flowrunID, nodeID, decision, reason string) error {
	if decision != workflowdomain.ApprovalPortYes && decision != workflowdomain.ApprovalPortNo {
		return flowrundomain.ErrInvalidDecision
	}
	won, err := s.runs.ResolveParkedNode(ctx, flowrunID, nodeID, flowrundomain.NodeCompleted, flowrundomain.ApprovalDecision(decision, reason))
	if err != nil {
		return fmt.Errorf("schedulerapp.DecideApproval: %w", err)
	}
	if !won {
		return flowrundomain.ErrNodeNotParked // already decided / timed out — first-wins loser
	}
	if run, gerr := s.runs.GetRun(ctx, flowrunID); gerr == nil {
		s.emitApprovalDecided(ctx, run, nodeID)
	}
	return s.drive(ctx, flowrunID) // manual path — inline (this run is parked, not pool-driven; sole driver)
}

// CheckTimeouts settles parked approvals whose deadline has passed (the one durable timer). For each
// parked node it resolves the pinned form's Timeout/TimeoutBehavior; reject→no, approve→yes,
// fail→fail the run. first-wins guards against racing a human decision. Workspace-scoped (the caller
// ticks it per workspace; for a single-user app that is the one workspace).
//
// CheckTimeouts 落定到期的 parked approval（唯一 durable timer）。对每个 parked 节点解析 pin 表单的
// Timeout/TimeoutBehavior；reject→no、approve→yes、fail→run 失败。first-wins 防与人工决策竞争。
// 按 workspace 隔离（调用方逐 workspace tick；单用户即一个 workspace）。
func (s *Service) CheckTimeouts(ctx context.Context, now time.Time) error {
	parked, err := s.runs.ListParkedNodes(ctx)
	if err != nil {
		return fmt.Errorf("schedulerapp.CheckTimeouts: %w", err)
	}
	for _, p := range parked {
		run, err := s.runs.GetRun(ctx, p.FlowRunID)
		if err != nil {
			s.log.Warn("schedulerapp.CheckTimeouts: get run", zap.String("flowrun", p.FlowRunID), zap.Error(err))
			continue
		}
		form, err := s.approval.Resolve(ctx, p.Ref, run.PinnedRefs[entityIDOf(p.Ref)])
		if err != nil {
			s.log.Warn("schedulerapp.CheckTimeouts: resolve form", zap.String("ref", p.Ref), zap.Error(err))
			continue
		}
		// DeadlineFrom is the single timeout-resolution semantic — the inbox's wire `deadline`
		// (ListInbox, 工单④) derives from the same call, so the countdown a user sees and the
		// sweep that fires agree by construction.
		// DeadlineFrom 是唯一的超时解析语义——收件箱线缆 `deadline`（ListInbox，工单④）出自同一调用，
		// 用户看到的倒计时与真正触发的扫描构造上一致。
		deadline, ok := form.DeadlineFrom(p.CreatedAt)
		if !ok {
			continue // unparseable or never-times-out
		}
		if deadline.After(now) {
			continue // not yet due
		}
		if err := s.settleTimeout(ctx, run, p, form.TimeoutBehavior); err != nil {
			s.log.Warn("schedulerapp.CheckTimeouts: settle", zap.String("flowrun", p.FlowRunID), zap.Error(err))
		}
	}
	return nil
}

// settleTimeout resolves one timed-out parked node per its behavior (first-wins), then re-drives or
// fails the run.
//
// settleTimeout 按 behavior 落定一个到期 parked 节点（first-wins），再重驱或失败 run。
func (s *Service) settleTimeout(ctx context.Context, run *flowrundomain.FlowRun, p *flowrundomain.FlowRunNode, behavior string) error {
	if behavior == approvaldomain.TimeoutFail {
		won, err := s.runs.ResolveParkedNode(ctx, p.FlowRunID, p.NodeID, flowrundomain.NodeFailed, map[string]any{"reason": "approval timed out"})
		if err != nil || !won {
			return err
		}
		s.emitApprovalDecided(ctx, run, p.NodeID)
		return s.markRunTerminal(ctx, run, flowrundomain.StatusFailed, fmt.Sprintf("approval %s timed out", p.NodeID))
	}
	decision := workflowdomain.ApprovalPortNo
	if behavior == approvaldomain.TimeoutApprove {
		decision = workflowdomain.ApprovalPortYes
	}
	won, err := s.runs.ResolveParkedNode(ctx, p.FlowRunID, p.NodeID, flowrundomain.NodeCompleted, flowrundomain.ApprovalDecision(decision, "timeout"))
	if err != nil || !won {
		return err
	}
	s.emitApprovalDecided(ctx, run, p.NodeID)
	s.enqueueAdvance(ctx, p.FlowRunID) // pooled — CheckTimeouts must not block on the re-driven run (F174)
	return nil
}

// emitApprovalDecided re-reads the just-resolved node row from disk (record-once truth) and emits
// its tick with the decision port. Approvals need this dedicated emit: Advance never ticks them
// past parked — the resolved row already exists when the run re-enters, so computeReady skips it
// and emitNodeProgress never fires for the decided transition. Best-effort presentation (read
// errors are swallowed; flowrun_nodes stays the reconnect truth).
//
// emitApprovalDecided 从盘重读刚落定的节点行（record-once 真相）、带决策 port 发其 tick。approval 需要
// 这条专用 emit：Advance 从不 tick 它越过 parked——run 重入时已决行已存在，computeReady 跳过它、
// emitNodeProgress 对「已决」转变永不触发。best-effort 呈现（读错吞掉；flowrun_nodes 仍是重连真相）。
func (s *Service) emitApprovalDecided(ctx context.Context, run *flowrundomain.FlowRun, nodeID string) {
	if s.entities == nil {
		return
	}
	rows, err := s.runs.GetNodes(ctx, run.ID)
	if err != nil {
		return
	}
	var row *flowrundomain.FlowRunNode
	for _, r := range rows {
		if r.NodeID == nodeID && (row == nil || r.Iteration > row.Iteration) {
			row = r
		}
	}
	if row == nil {
		return
	}
	s.emitNodeProgress(ctx, run, nodeID, row.Iteration, row.Status, row)
}

// Replay fixes a failed run: clear its failed node rows (a non-result), reopen the run to running +
// bump replay_count, then re-walk — completed rows are reused, the cleared steps re-run. ErrNotReplayable
// if the run is not failed.
//
// Replay 修复失败的 run：清其 failed 节点行（非结果）、把 run 翻回 running + replay_count++、再重走——
// completed 行复用、被清的步骤重跑。run 非 failed 则 ErrNotReplayable。
func (s *Service) Replay(ctx context.Context, flowrunID string) error {
	run, err := s.runs.GetRun(ctx, flowrunID)
	if err != nil {
		return err
	}
	if run.Status != flowrundomain.StatusFailed {
		return flowrundomain.ErrNotReplayable
	}
	if _, err := s.runs.DeleteFailedNodes(ctx, flowrunID); err != nil {
		return fmt.Errorf("schedulerapp.Replay: %w", err)
	}
	if err := s.runs.ReopenForReplay(ctx, flowrunID); err != nil {
		return err
	}
	return s.drive(ctx, flowrunID) // manual path — inline (this run was failed, not pool-driven; sole driver)
}
