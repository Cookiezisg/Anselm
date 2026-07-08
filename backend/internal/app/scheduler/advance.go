package scheduler

import (
	"context"
	"encoding/json"
	"fmt"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
	celpkg "github.com/sunweilin/anselm/backend/internal/pkg/cel"
)

// Advance is the idempotent heart of the engine: walk the run's FROZEN graph against its memoized
// frn rows until no (node, iteration) is ready, then finalize. Calling it repeatedly — including
// after a crash, on the same run — converges to the same state, because completed rows are copied
// (record-once), never re-run. A batch of ready nodes is run, then the rows are re-read and the
// walk recomputed (a freshly-completed node can unblock its successors). The loop ends when nothing
// is ready (→ finalize: completed, or still-running if a node is parked) or a node fails (fail-fast).
//
// Advance 是引擎的幂等核心：照 run 冻结的图、对其记忆化 frn 行走，直到无 (节点,轮次) ready，再
// finalize。反复调用（含崩溃后、同一 run）收敛到同一状态，因为 completed 行被抄（record-once）、绝不
// 重跑。跑一批 ready 节点后重读行、重算 walk（刚完成的节点可解锁后继）。循环在无人 ready（→ finalize：
// completed 或有 parked 则仍 running）或某节点失败（fail-fast）时结束。
func (s *Service) Advance(ctx context.Context, flowrunID string) error {
	run, err := s.runs.GetRun(ctx, flowrunID)
	if err != nil {
		return err
	}
	if run.Status != flowrundomain.StatusRunning {
		return nil // already terminal — nothing to do
	}
	// Register a cancellable child ctx for this drive so KillWorkflow can interrupt a node blocked
	// mid-flight (a long agent). On a normal finish release() just deregisters.
	// 为本次驱动注册可取消子 ctx，使 KillWorkflow 能打断卡在节点中的运行（长 agent）。正常结束时 release() 只注销。
	ctx, release := s.trackInflight(ctx, flowrunID)
	defer release()
	ver, err := s.workflows.GetVersion(ctx, run.VersionID)
	if err != nil {
		return fmt.Errorf("schedulerapp.Advance: pinned version %s: %w", run.VersionID, err)
	}
	graph, err := decodeGraph(ver.Graph)
	if err != nil {
		return err
	}
	senv, err := celScopedEnv(graph)
	if err != nil {
		return fmt.Errorf("schedulerapp.Advance: cel env: %w", err)
	}

	// Read the run's memoized rows ONCE, then carry them in memory across drive turns: each node
	// runNode writes is appended to this slice (record-once — every (node,iteration) is written by
	// exactly one turn, and computeReady only schedules nodes that have no row yet). This avoids the
	// O(N²) re-read where a looping run re-pulled every row's full `result` blob from the single
	// SQLite connection on every one of its up-to-MaxIterations turns. The durable rows are still the
	// truth (a crash just re-enters Advance, which re-reads here); the carried slice is only this
	// drive's working set, rebuilt from disk on the next entry.
	//
	// 一次读 run 记忆化行，再跨驱动轮在内存里携带：每个 runNode 写的节点追加进本切片（record-once——
	// 每个 (节点,轮次) 恰由一轮写、且 computeReady 只调度还没行的节点）。避免了循环 run 在单 SQLite 连接上
	// 每轮（至多 MaxIterations 轮）重拉每行完整 `result` blob 的 O(N²) 重读。durable 行仍是真相（崩溃即
	// 重入 Advance、在此重读）；携带切片只是本次驱动的工作集，下次进入时从盘重建。
	rows, err := s.runs.GetNodes(ctx, flowrunID)
	if err != nil {
		return err
	}
	for {
		// Bail if this drive was interrupted (KillWorkflow cancelled our ctx, or the app is shutting
		// down). Not an error: the durable state is authoritative — kill already marked the run
		// cancelled; a shutdown leaves it running for the next boot's Recover to re-walk.
		// 若本次驱动被打断（KillWorkflow 取消了 ctx，或 app 关停）则退出。非错误：durable 状态为准——kill
		// 已标 run cancelled；shutdown 留 run running 待下次 boot 的 Recover 重走。
		if ctx.Err() != nil {
			return nil
		}
		w := newWalk(graph, rows)
		ready, overflow := w.computeReady()
		if overflow != "" {
			// Fencepost (F175-M1): the cap is on back-edge-driven iterations. The body already ran
			// iterations 0..MaxIterations (MaxIterations+1 frn rows — iteration 0 is the forward-edge
			// entry, not a loop turn); overflow fires when a further back edge would start iteration
			// MaxIterations+1. Spell that out so an operator counting MaxIterations+1 persisted rows
			// doesn't misread the "(%d)" as a row count.
			//
			// 栅栏（F175-M1）：上限管的是回边驱动的迭代数。循环体已跑过 iteration 0..MaxIterations
			// （MaxIterations+1 行 frn——iteration 0 是前向边入口、非循环轮），再来一条回边将开
			// iteration MaxIterations+1 时溢出。讲清楚，免得运维数到 MaxIterations+1 行却把 "(%d)" 当行数读。
			return s.failRun(ctx, run, fmt.Sprintf("loop at node %q exceeded MaxIterations (%d): body ran iterations 0..%d (%d rows), a back edge would start iteration %d", overflow, MaxIterations, MaxIterations, MaxIterations+1, MaxIterations+1))
		}
		if len(ready) == 0 {
			break
		}
		advanced := false
		staleRows := false
		for _, rn := range ready {
			row, status, err := s.runNode(ctx, run, senv, w, rn)
			if err != nil {
				return err
			}
			if row != nil {
				rows = append(rows, row) // carry the just-written row into the next turn's walk
			} else if status != flowrundomain.NodeFailed {
				// A non-failed node with no returned row = a record-once conflict (an existing row won).
				// Our in-memory set lacks that authoritative row, so re-read it from disk before the next
				// walk — else computeReady, seeing no row, would re-schedule the node forever.
				// 非失败却无返回行 = record-once 冲突（已有行胜）。内存集缺该权威行，下轮 walk 前从盘重读——
				// 否则 computeReady 见无行会永远重排该节点。
				staleRows = true
			}
			s.emitNodeProgress(ctx, run, rn.node.ID, rn.iter, status, row) // SSE-C: workflow panel run terminal (+port)
			if status == flowrundomain.NodeFailed {
				return nil // fail-fast: the run was already marked failed inside failNode
			}
			if status == flowrundomain.NodeCompleted {
				advanced = true
			}
		}
		if staleRows {
			if rows, err = s.runs.GetNodes(ctx, flowrunID); err != nil {
				return err
			}
		}
		if !advanced {
			break // every ready node this batch parked → yield, await external signals
		}
	}
	return s.finalize(ctx, run, flowrunID)
}

// emitNodeProgress streams one node's terminal status onto the entities stream scoped to the
// workflow, so the workflow panel shows a flowrun progressing node by node (SSE-C). A point Signal
// keyed by flowrunId; the durable record is flowrun_nodes. When the just-written row carries a
// routing decision (control's chosen branch / approval's decision under the reserved __port key)
// the tick carries it as `port` — the client renders the taken branch live without a lazy GET
// per tick (R-11 retires). nil bridge → no-op.
//
// emitNodeProgress 把一个节点的终态流到 workflow scope 的 entities 流，使 workflow 面板逐节点显示 flowrun
// 推进（SSE-C）。按 flowrunId 的点 Signal；耐久记录是 flowrun_nodes。刚落的行携路由决策（control 选中分支 /
// approval 决定，存保留键 __port 下）时 tick 以 `port` 捎带——客户端实时渲选中分支、免逐 tick 惰性 GET
// （R-11 退役）。nil bridge → no-op。
func (s *Service) emitNodeProgress(ctx context.Context, run *flowrundomain.FlowRun, nodeID string, iteration int, status string, row *flowrundomain.FlowRunNode) {
	if s.entities == nil {
		return
	}
	payload := map[string]any{
		"flowrunId": run.ID,
		"nodeId":    nodeID,
		"iteration": iteration,
		"status":    status,
	}
	if row != nil {
		// control routes under the reserved __port key; an approval's decision IS its port
		// (edges route on yes/no). control 走保留键 __port；approval 的 decision 即其 port。
		if port, _ := row.Result[flowrundomain.ResultKeyPort].(string); port != "" {
			payload["port"] = port
		} else if d, _ := row.Result[flowrundomain.ResultKeyDecision].(string); d != "" {
			payload["port"] = d
		}
	}
	content, _ := json.Marshal(payload)
	// ephemeral=true：flowrun_nodes 行是重连真相，tick 仅实时呈现、丢弃无妨、不占 replay 环(E2)。
	entitystreamapp.Signal(ctx, s.entities, streamdomain.Scope{Kind: streamdomain.KindWorkflow, ID: run.WorkflowID}, entitystreamapp.NodeRun, content, true)
}

// emitRunTerminal streams a flowrun's terminal status as the one DURABLE flowrun signal (seq +
// replay ring, E2): node ticks may be dropped, but "the run is over" must survive a reconnect so
// a client tracking a run (the chat sidestage's trigger_workflow poll fallback, the workflow
// cockpit) never spins on a terminal it missed. errMsg rides only a failed terminal.
//
// emitRunTerminal 把 flowrun 终态作为唯一 **durable** flowrun 信号流出（入 seq + replay 环，E2）：
// 节点 tick 可丢，但「run 结束了」必须活过重连，使追踪 run 的客户端（chat 侧幕 trigger_workflow 的
// poll 兜底、workflow 驾驶舱）绝不因错过终态而空转。errMsg 只随 failed 终态。
func (s *Service) emitRunTerminal(ctx context.Context, workflowID, flowrunID, status, errMsg string) {
	if s.entities == nil {
		return
	}
	payload := map[string]any{
		"flowrunId": flowrunID,
		"status":    status,
	}
	if errMsg != "" && status == flowrundomain.StatusFailed {
		payload["error"] = errMsg
	}
	content, _ := json.Marshal(payload)
	entitystreamapp.Signal(ctx, s.entities, streamdomain.Scope{Kind: streamdomain.KindWorkflow, ID: workflowID}, entitystreamapp.NodeRunTerminal, content, false)
}

// finalize settles a run that has no ready nodes left: still-running if any node is parked (awaiting
// a human/timeout signal), otherwise completed. (Failure is handled inline by failNode/failRun.)
//
// finalize 结算无 ready 节点的 run：有 parked 节点则仍 running（等人/超时信号），否则 completed。
// （失败由 failNode/failRun 内联处理。）
func (s *Service) finalize(ctx context.Context, run *flowrundomain.FlowRun, flowrunID string) error {
	rows, err := s.runs.GetNodes(ctx, flowrunID)
	if err != nil {
		return err
	}
	for _, r := range rows {
		if r.Status == flowrundomain.NodeParked {
			return nil // waiting on a signal — the run stays running
		}
	}
	if err := s.markRunTerminal(ctx, run, flowrundomain.StatusCompleted, ""); err != nil {
		return fmt.Errorf("schedulerapp.finalize: %w", err)
	}
	return nil
}

// failRun marks the whole run failed (used for engine-level failures like a loop overflow; node
// activity failures go through failNode which also writes the failed node row).
//
// failRun 把整个 run 标 failed（用于引擎级失败如循环溢出；节点 activity 失败走 failNode，它还写
// failed 节点行）。
func (s *Service) failRun(ctx context.Context, run *flowrundomain.FlowRun, msg string) error {
	if err := s.markRunTerminal(ctx, run, flowrundomain.StatusFailed, msg); err != nil {
		return fmt.Errorf("schedulerapp.failRun: %w", err)
	}
	return nil
}

// celScopedEnv builds the CEL environment whose roots are the graph's node ids — so a node's Input
// CEL can address ancestors by node id (model B). The same env is reused for every node in the run.
//
// celScopedEnv 构建以图 node id 为根的 CEL 环境——使节点 Input CEL 能按 node id 寻址祖先（model B）。
// 同一 env 复用于该 run 的每个节点。
func celScopedEnv(graph *workflowdomain.Graph) (*celpkg.ScopedEnv, error) {
	roots := make([]string, len(graph.Nodes))
	for i := range graph.Nodes {
		roots[i] = graph.Nodes[i].ID
	}
	return celpkg.NewScopedEnv(roots)
}
