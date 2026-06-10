package handler

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_handler as forge tools (SSE-C): the streaming class-block code mirrors
// onto the entities stream so the handler panel fills in live.
//
// Forge 标记 create/edit_handler 为 forge 工具（SSE-C）：流式类块代码镜像到 entities 流，使 handler 面板实时填充。
func (*CreateHandler) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "handler", Op: "create"}
}
func (*EditHandler) Forge() toolapp.ForgeSpec { return toolapp.ForgeSpec{Kind: "handler", Op: "edit"} }
