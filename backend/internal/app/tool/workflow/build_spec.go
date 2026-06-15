package workflow

import toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"

// Build marks create/edit_workflow as build tools (SSE-C): the streaming graph ops mirror onto the
// entities stream so the workflow canvas grows nodes/edges live.
//
// Build 标记 create/edit_workflow 为 build 工具（SSE-C）：流式图 ops 镜像到 entities 流，使 workflow 画布
// 实时长出节点/边。
func (*CreateWorkflow) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "workflow", Op: "create"}
}
func (*EditWorkflow) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "workflow", Op: "edit"}
}
