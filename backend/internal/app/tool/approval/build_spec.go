package approval

import toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"

// Build marks create/edit_approval as build tools (SSE-C): the streaming template + decision rules
// mirror onto the entities stream so the approval panel fills in live.
//
// Build 标记 create/edit_approval 为 build 工具（SSE-C）：流式模板 + 决策规则镜像到 entities 流，使 approval 面板实时填充。
func (*CreateApproval) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "approval", Op: "create"}
}
func (*EditApproval) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "approval", Op: "edit"}
}
