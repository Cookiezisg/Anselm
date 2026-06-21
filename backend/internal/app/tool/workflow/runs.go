package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	schedulerapp "github.com/sunweilin/anselm/backend/internal/app/scheduler"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// runs.go closes the execution-observability loop trigger_workflow opens: it returns a
// flowrunId, and these two tools let the LLM read that run back — without them the LLM
// could start a workflow but never inspect how it went (which node failed, with what
// error, what each node produced).
//
// runs.go 闭合 trigger_workflow 打开的执行可观测环：它返回 flowrunId，这两个工具让 LLM 把
// 那个 run 读回来——没有它们，LLM 能启动 workflow 却永远查不到跑得怎样（哪个节点挂了、
// 错误是什么、各节点产出了什么）。

// --- get_flowrun -------------------------------------------------------------

type GetFlowrun struct{ sched *schedulerapp.Service }

func (t *GetFlowrun) Name() string { return "get_flowrun" }

func (t *GetFlowrun) Description() string {
	return "Get one workflow run by its flowrun id: the run header (status, error, pinned versions) plus every node's record (status, result, error, iteration). Use this to inspect how a run started via trigger_workflow went, or to diagnose a failed/parked run."
}

func (t *GetFlowrun) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["flowrunId"],
		"properties": {"flowrunId": {"type": "string"}}
	}`)
}

func (t *GetFlowrun) ValidateInput(args json.RawMessage) error {
	var a struct {
		FlowrunID string `json:"flowrunId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_flowrun: bad args: %w", err)
	}
	if a.FlowrunID == "" {
		return ErrFlowrunIDRequired
	}
	return nil
}

func (t *GetFlowrun) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FlowrunID string `json:"flowrunId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_flowrun: bad args: %w", err)
	}
	run, nodes, err := t.sched.GetRunWithNodes(ctx, args.FlowrunID)
	if err != nil {
		return "", fmt.Errorf("get_flowrun: %w", err)
	}
	return toolapp.ToJSON(flowrunNodesResult(run, nodes)), nil
}

// --- search_flowruns ---------------------------------------------------------

type SearchFlowruns struct{ sched *schedulerapp.Service }

func (t *SearchFlowruns) Name() string { return "search_flowruns" }

func (t *SearchFlowruns) Description() string {
	return "List workflow runs (most recent first), optionally filtered to one workflow. Each row carries status, error and timing; use get_flowrun on an id for the per-node detail."
}

func (t *SearchFlowruns) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"workflowId": {"type": "string", "description": "Optional: only this workflow's runs."},
			"status": {"type": "string", "description": "Optional: running | completed | failed | cancelled."},
			"limit": {"type": "integer", "description": "Page size (default 50)."},
			"cursor": {"type": "string", "description": "Opaque pagination cursor."}
		}
	}`)
}

func (t *SearchFlowruns) ValidateInput(args json.RawMessage) error {
	var a struct{}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_flowruns: bad args: %w", err)
	}
	return nil
}

func (t *SearchFlowruns) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		WorkflowID string `json:"workflowId"`
		Status     string `json:"status"`
		Limit      int    `json:"limit"`
		Cursor     string `json:"cursor"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_flowruns: bad args: %w", err)
	}
	runs, next, err := t.sched.ListRuns(ctx, flowrundomain.ListFilter{
		WorkflowID: args.WorkflowID,
		Status:     args.Status,
		Cursor:     args.Cursor,
		Limit:      args.Limit,
	})
	if err != nil {
		return "", fmt.Errorf("search_flowruns: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"runs": runs, "nextCursor": next, "hasMore": next != ""}), nil
}

// --- replay_flowrun ----------------------------------------------------------

type ReplayFlowrun struct{ sched *schedulerapp.Service }

func (t *ReplayFlowrun) Name() string { return "replay_flowrun" }

func (t *ReplayFlowrun) Description() string {
	return "Re-run a FAILED workflow run from where it broke. Replay clears ONLY the failed node(s), keeps every already-completed node memoized (record-once durable semantics — they are NOT re-run), then re-executes the cleared steps. IMPORTANT: it re-runs under the run's ORIGINALLY-PINNED entity versions, so a fix you made by editing the function/handler/workflow AFTER the failure does NOT take effect on a replay — to pick up edits, start a fresh run with trigger_workflow instead. Only a failed run is replayable (a completed/running/parked run is rejected). Returns the updated run + nodes."
}

func (t *ReplayFlowrun) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["flowrunId"],
		"properties": {"flowrunId": {"type": "string", "description": "The failed run to replay."}}
	}`)
}

func (t *ReplayFlowrun) ValidateInput(args json.RawMessage) error {
	var a struct {
		FlowrunID string `json:"flowrunId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("replay_flowrun: bad args: %w", err)
	}
	if a.FlowrunID == "" {
		return ErrFlowrunIDRequired
	}
	return nil
}

func (t *ReplayFlowrun) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FlowrunID string `json:"flowrunId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("replay_flowrun: bad args: %w", err)
	}
	// Replay is synchronous (clears failed nodes -> reopen -> Advance), so the run has moved to its
	// next terminal/parked state by the time we re-read it for the LLM. ErrNotReplayable bubbles for
	// a non-failed run (the loop surfaces its message/details to the model).
	//
	// Replay 同步（清 failed 节点 → reopen → Advance），重读时 run 已推进到下个终态/park。非 failed
	// run 冒 ErrNotReplayable（loop 把其 message/details 透给模型）。
	if err := t.sched.Replay(ctx, args.FlowrunID); err != nil {
		return "", fmt.Errorf("replay_flowrun: %w", err)
	}
	run, nodes, err := t.sched.GetRunWithNodes(ctx, args.FlowrunID)
	if err != nil {
		return "", fmt.Errorf("replay_flowrun: %w", err)
	}
	return toolapp.ToJSON(flowrunNodesResult(run, nodes)), nil
}

// --- decide_approval ---------------------------------------------------------
//
// Without this an agent can build + trigger an approval-gated workflow but can never approve/reject a
// run parked on its approval node — the human-in-the-loop half of the feature is unreachable, and a
// parked run is unrescuable except by killing it. Wraps the same DecideApproval the HTTP :decide
// endpoint uses (first-decision-wins; a later decide or a timeout no-ops).
//
// 没有它，agent 能建+触发带审批门的 workflow，却永远无法批/拒 park 在审批节点上的 run——人在环那半边不可达、
// park 的 run 除了 kill 无从解救。包 HTTP :decide 同一个 DecideApproval（首决胜；后续 decide 或超时 no-op）。

type DecideApproval struct{ sched *schedulerapp.Service }

func (t *DecideApproval) Name() string { return "decide_approval" }

func (t *DecideApproval) Description() string {
	return "Approve or reject a workflow run PARKED on an approval node (the human-in-the-loop decision). Args: flowrunId, the approval node's id (nodeId), decision ('yes' approves / 'no' rejects), and an optional reason. First decision wins (a later decide, or the approval's timeout, no-ops). Find a parked run + its approval node id with get_flowrun / search_flowruns. Returns the updated run + nodes after the decision resumes (yes) or stops (no, per the node's branches) the run."
}

func (t *DecideApproval) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["flowrunId", "nodeId", "decision"],
		"properties": {
			"flowrunId": {"type": "string", "description": "The run parked on the approval."},
			"nodeId": {"type": "string", "description": "The approval node's id in the graph."},
			"decision": {"type": "string", "enum": ["yes", "no"], "description": "yes = approve, no = reject."},
			"reason": {"type": "string", "description": "Optional reason recorded with the decision."}
		}
	}`)
}

func (t *DecideApproval) ValidateInput(args json.RawMessage) error {
	var a struct {
		FlowrunID string `json:"flowrunId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("decide_approval: bad args: %w", err)
	}
	if a.FlowrunID == "" {
		return ErrFlowrunIDRequired
	}
	// nodeId + decision are validated by scheduler.DecideApproval (a missing/wrong node → not-parked;
	// a non-yes|no decision → invalid) — those errors surface via Execute, so no new wire codes here.
	// nodeId + decision 由 scheduler.DecideApproval 校（坏/缺节点→未 park；非 yes|no→无效）——经 Execute 透出，免新码。
	return nil
}

func (t *DecideApproval) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FlowrunID string `json:"flowrunId"`
		NodeID    string `json:"nodeId"`
		Decision  string `json:"decision"`
		Reason    string `json:"reason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("decide_approval: bad args: %w", err)
	}
	if err := t.sched.DecideApproval(ctx, args.FlowrunID, args.NodeID, args.Decision, args.Reason); err != nil {
		return "", fmt.Errorf("decide_approval: %w", err)
	}
	run, nodes, err := t.sched.GetRunWithNodes(ctx, args.FlowrunID)
	if err != nil {
		return "", fmt.Errorf("decide_approval: %w", err)
	}
	return toolapp.ToJSON(flowrunNodesResult(run, nodes)), nil
}

// flowrunNodesResult builds the {flowrun, nodes, nodeSummary?} tool result, capping a large run's nodes
// via capFlowrunNodes so get_flowrun / replay_flowrun / decide_approval cannot dump a long loop's
// thousands of node rows (~650KB at MaxIterations) into the LLM context (F173).
//
// flowrunNodesResult 构建 {flowrun, nodes, nodeSummary?} 工具结果，经 capFlowrunNodes 限大 run 的节点，使
// get_flowrun/replay_flowrun/decide_approval 不把长 loop 的数千节点行（MaxIterations 时约 650KB）倾倒进 LLM 上下文（F173）。
func flowrunNodesResult(run *flowrundomain.FlowRun, nodes []*flowrundomain.FlowRunNode) map[string]any {
	shown, summary := capFlowrunNodes(nodes)
	out := map[string]any{"flowrun": run, "nodes": shown}
	if summary != nil {
		out["nodeSummary"] = summary
	}
	return out
}

// maxFlowrunNodes caps how many node rows the flowrun tools return to the LLM. A loop (back-edge control
// node) produces one row PER iteration — at MaxIterations a single run is ~2000 rows / ~650KB, and the
// whole thing was fed verbatim into the model's context, blowing the token budget on one observability
// call (F173).
const maxFlowrunNodes = 80

// capFlowrunNodes bounds a large run's node set for the LLM tool result. <= the cap → all rows, no
// summary. Otherwise it returns every non-completed node (all failures + parked — what the agent
// debugs) plus the tail of recent nodes up to the cap, and a summary (total count + per-status breakdown
// + a note pointing at the REST endpoint for the full set). The durable record is untouched — this only
// bounds the TOOL projection.
//
// capFlowrunNodes 为 LLM 工具结果限大 run 的节点集。≤cap→全行、无 summary。否则返每个非 completed 节点（全部
// failure + parked）+ 最近节点的尾巴至 cap，并带 summary（总数 + 按状态分布 + 指向 REST 端点取全量的提示）。
// 耐久记录不动——只限**工具投影**。
func capFlowrunNodes(nodes []*flowrundomain.FlowRunNode) ([]*flowrundomain.FlowRunNode, map[string]any) {
	if len(nodes) <= maxFlowrunNodes {
		return nodes, nil
	}
	byStatus := map[string]int{}
	for _, n := range nodes {
		byStatus[n.Status]++
	}
	seen := make(map[string]bool, maxFlowrunNodes)
	shown := make([]*flowrundomain.FlowRunNode, 0, maxFlowrunNodes)
	add := func(n *flowrundomain.FlowRunNode) {
		if !seen[n.ID] {
			seen[n.ID] = true
			shown = append(shown, n)
		}
	}
	for _, n := range nodes { // every failure / parked node — what you debug
		if n.Status != flowrundomain.StatusCompleted {
			add(n)
		}
	}
	for i := len(nodes) - 1; i >= 0 && len(shown) < maxFlowrunNodes; i-- { // recent activity (the tail)
		add(nodes[i])
	}
	return shown, map[string]any{
		"totalNodes": len(nodes),
		"shownNodes": len(shown),
		"byStatus":   byStatus,
		"note":       fmt.Sprintf("This run has %d node rows (a large/looping run). To protect the context, `nodes` shows every non-completed node (all failures + parked) plus the most recent completed ones (cap %d). Page the full set via the REST endpoint GET /api/v1/flowruns/{id}.", len(nodes), maxFlowrunNodes),
	}
}
