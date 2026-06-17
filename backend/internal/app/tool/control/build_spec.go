package control

import toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"

// Build marks create/edit_control as build tools (SSE-C): the streaming CEL branches mirror onto
// the entities stream so the control panel fills in live.
//
// Build 标记 create/edit_control 为构建工具（SSE-C）：流式 CEL 分支镜像到 entities 流，使 control 面板实时填充。
func (*CreateControl) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "control", Op: "create"}
}
func (*EditControl) Build() toolapp.BuildSpec { return toolapp.BuildSpec{Kind: "control", Op: "edit"} }
