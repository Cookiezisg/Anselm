package handler

import toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"

// Build marks create/edit_handler as build tools (SSE-C): the streaming class-block code mirrors
// onto the entities stream so the handler panel fills in live.
//
// Build 标记 create/edit_handler 为构建工具（SSE-C）：流式类块代码镜像到 entities 流，使 handler 面板实时填充。
func (*CreateHandler) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "handler", Op: "create"}
}
func (*EditHandler) Build() toolapp.BuildSpec { return toolapp.BuildSpec{Kind: "handler", Op: "edit"} }
