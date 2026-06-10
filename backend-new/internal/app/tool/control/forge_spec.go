package control

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_control as forge tools (SSE-C): the streaming CEL branches mirror onto
// the entities stream so the control panel fills in live.
//
// Forge 标记 create/edit_control 为 forge 工具（SSE-C）：流式 CEL 分支镜像到 entities 流，使 control 面板实时填充。
func (*CreateControl) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "control", Op: "create"}
}
func (*EditControl) Forge() toolapp.ForgeSpec { return toolapp.ForgeSpec{Kind: "control", Op: "edit"} }
