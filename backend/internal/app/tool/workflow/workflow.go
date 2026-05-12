// Package workflow provides the 6 system tools the LLM uses to interact
// with the user's workflow library: search / get / create / edit / revert /
// delete. Trigger / executions tools (per Plan 04 spec §9) require Plan 05
// scheduler / flowrun domains; deferred.
//
// Per §S13 nested sub-package alias rule, importers alias as `workflowtool`
// (distinct from workflowapp / workflowdomain).
//
// Streaming model (CLAUDE.md §S18 + §E1 three-stream):
//   - create_workflow / edit_workflow — ApplyOps emits one progress delta
//     per op via the eventlog Emitter; the tool also double-writes
//     forge_started + forge_completed on the forge bus (C4 D-redo-4).
//   - search / get / revert / delete — one-shot tool_result, no streaming.
//
// Package workflow 提供 6 个 system tool;alias `workflowtool`;trigger /
// executions 工具留 Plan 05(scheduler / flowrun)。create/edit 工具双写
// chat eventlog progress block + forge bus forge_started/completed。
package workflow

import (
	"go.uber.org/zap"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	forgepkg "github.com/sunweilin/forgify/backend/internal/pkg/forge"
)

// WorkflowTools constructs the 6 workflow system tools wired with their
// dependencies.
//
// forge is the forge-stream Publisher (C4 D-redo-4) used by create / edit
// to emit forge_started / forge_completed. Pass forgepkg.New(nil, log) in
// tests / unwired services to disable forge double-write.
//
// WorkflowTools 装配 6 个 workflow system tool。forge 用于双写;测试 / 未
// 接线传 noop 关闭双写。
func WorkflowTools(svc *workflowapp.Service, forge forgepkg.Publisher, log *zap.Logger) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchWorkflow{svc: svc, log: log},
		&GetWorkflow{svc: svc},
		&CreateWorkflow{svc: svc, forge: forge},
		&EditWorkflow{svc: svc, forge: forge},
		&RevertWorkflow{svc: svc, forge: forge},
		&DeleteWorkflow{svc: svc, forge: forge},
	}
}
