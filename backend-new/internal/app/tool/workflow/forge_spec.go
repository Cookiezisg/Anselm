package workflow

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_workflow as forge tools (SSE-C): the streaming graph ops mirror onto the
// entities stream so the workflow canvas grows nodes/edges live.
//
// Forge 标记 create/edit_workflow 为 forge 工具（SSE-C）：流式图 ops 镜像到 entities 流，使 workflow 画布
// 实时长出节点/边。
func (*CreateWorkflow) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "workflow", Op: "create"}
}
func (*EditWorkflow) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "workflow", Op: "edit"}
}
