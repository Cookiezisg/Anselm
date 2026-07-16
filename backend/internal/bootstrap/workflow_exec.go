package bootstrap

import (
	"context"

	schedulerapp "github.com/sunweilin/anselm/backend/internal/app/scheduler"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// runnerAdapter bridges workflowapp.Runner (primitive params, defined in the workflow package so it
// never imports the scheduler) onto the durable scheduler. StartRun maps (workflowID, payload) →
// schedulerapp.StartInput; KillWorkflow / CountRunning pass straight through. This is the D1
// execution-lifecycle wiring that lets the workflow service drive trigger / kill / drain-count.
//
// runnerAdapter 把 workflowapp.Runner（原生参数，定义在 workflow 包中故绝不 import 调度器）桥到 durable
// 调度器。StartRun 把 (workflowID, payload) 映射成 schedulerapp.StartInput；KillWorkflow / CountRunning 直通。
// 这是 D1 执行生命周期接线，使 workflow service 能驱动 trigger / kill / 排空计数。
type runnerAdapter struct{ sched *schedulerapp.Service }

func (a runnerAdapter) StartRun(ctx context.Context, workflowID string, payload map[string]any) (string, error) {
	return a.sched.StartRun(ctx, startInputFor(ctx, workflowID, payload))
}

// startInputFor stamps run provenance on the shared workflowapp.Trigger throat. The Runner port is
// deliberately primitive (the workflow package knows no scheduler vocabulary), so the caller split
// rides ctx: a chat turn (trigger_workflow — the chat loop / subagent host seeds the conversation
// id) stamps chat + that conversation; a bare HTTP `:trigger` request has no conversation in ctx
// and stamps manual. An agent node running INSIDE a flowrun also carries its invocation
// conversation, so a workflow-launched trigger_workflow honestly records the conversation that
// asked for it.
//
// startInputFor 在 workflowapp.Trigger 这条共享咽喉上给 run 盖溯源章。Runner 端口刻意原生（workflow 包
// 不识调度器词表），故调用方之分走 ctx：chat 回合（trigger_workflow——chat loop / subagent host 埋了
// conversation id）盖 chat + 该对话；裸 HTTP `:trigger` 请求 ctx 无对话、盖 manual。flowrun **内**跑的
// agent 节点同样带其调用对话，故 workflow 里发起的 trigger_workflow 如实记下发起它的对话。
func startInputFor(ctx context.Context, workflowID string, payload map[string]any) schedulerapp.StartInput {
	in := schedulerapp.StartInput{WorkflowID: workflowID, Payload: payload, Origin: flowrundomain.OriginManual}
	if convID, ok := reqctxpkg.GetConversationID(ctx); ok {
		in.Origin = flowrundomain.OriginChat
		in.ConversationID = convID
	}
	return in
}

func (a runnerAdapter) KillWorkflow(ctx context.Context, workflowID string) (int, error) {
	return a.sched.KillWorkflow(ctx, workflowID)
}

func (a runnerAdapter) CountRunning(ctx context.Context, workflowID string) (int, error) {
	return a.sched.CountRunning(ctx, workflowID)
}
