package workflow

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	schedulerapp "github.com/sunweilin/anselm/backend/internal/app/scheduler"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// ListApprovalInbox enumerates every run parked on an approval node awaiting a human decision — the
// ONLY faithful way for an agent to discover them. search_flowruns cannot: parked is a NODE status,
// not a run-header status (a parked run's header stays "running"), so its status filter never finds
// them. Pair the returned flowrunId + nodeId with decide_approval to approve/reject. Closes the
// discovery half of human-in-the-loop the backend already had (REST GET /flowrun-inbox) but never
// surfaced as an LLM tool, leaving decide_approval's "use get_flowrun/search_flowruns to find a
// parked run" guidance unfulfillable (F163).
//
// ListApprovalInbox 枚举每个 park 在审批节点等人决策的 run——agent 发现它们的**唯一**忠实途径。
// search_flowruns 找不到：parked 是**节点**状态、非 run 头状态（parked run 头仍 "running"），故其
// status 过滤永远命不中。把返回的 flowrunId + nodeId 配 decide_approval 批/拒。补全后端早有（REST
// GET /flowrun-inbox）却没浮成 LLM 工具的人在环发现半边（F163）。
type ListApprovalInbox struct{ sched *schedulerapp.Service }

func (t *ListApprovalInbox) Name() string { return "list_approval_inbox" }

func (t *ListApprovalInbox) Description() string {
	return "List every workflow run currently PARKED on an approval node, waiting for a human decision (workspace-wide, oldest first). This is the only reliable way to find pending approvals — search_flowruns CANNOT, because 'parked' is a node status, not a run status (a parked run's header still reads 'running'). Each row gives flowrunId, nodeId, the rendered approval prompt and when it parked; pass the flowrunId + nodeId to decide_approval to approve or reject. Takes no arguments."
}

func (t *ListApprovalInbox) Parameters() json.RawMessage {
	return json.RawMessage(`{"type": "object", "properties": {}}`)
}

func (t *ListApprovalInbox) ValidateInput(args json.RawMessage) error {
	var a struct{}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("list_approval_inbox: bad args: %w", err)
	}
	return nil
}

func (t *ListApprovalInbox) Execute(ctx context.Context, _ string) (string, error) {
	nodes, err := t.sched.ListInbox(ctx)
	if err != nil {
		return "", fmt.Errorf("list_approval_inbox: %w", err)
	}
	// Project to a slim row — NOT the whole Result map, which can carry large upstream payloads that
	// would bloat the LLM context (F173 spirit). Keep only what decide_approval needs + the prompt.
	// 投影成 slim 行——不吐整个 Result map（可能带撑爆 LLM 上下文的大上游 payload，F173 精神）。只留
	// decide_approval 所需 + 提示文本。
	type parkedRow struct {
		FlowrunID string `json:"flowrunId"`
		NodeID    string `json:"nodeId"`
		Ref       string `json:"ref"`
		Rendered  string `json:"rendered,omitempty"`
		ParkedAt  string `json:"parkedAt"`
	}
	rows := make([]parkedRow, 0, len(nodes))
	for _, n := range nodes {
		rendered, _ := n.Result[flowrundomain.ResultKeyRendered].(string)
		rows = append(rows, parkedRow{
			FlowrunID: n.FlowRunID,
			NodeID:    n.NodeID,
			Ref:       n.Ref,
			Rendered:  rendered,
			ParkedAt:  n.CreatedAt.Format(time.RFC3339),
		})
	}
	return toolapp.ToJSON(map[string]any{"parked": rows, "count": len(rows)}), nil
}
