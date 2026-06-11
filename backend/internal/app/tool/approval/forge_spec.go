package approval

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_approval as forge tools (SSE-C): the streaming template + decision rules
// mirror onto the entities stream so the approval panel fills in live.
//
// Forge 标记 create/edit_approval 为 forge 工具（SSE-C）：流式模板 + 决策规则镜像到 entities 流，使 approval 面板实时填充。
func (*CreateApproval) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "approval", Op: "create"}
}
func (*EditApproval) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "approval", Op: "edit"}
}
