package function

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_function as forge tools (SSE-C): the loop mirrors their streaming code
// args onto the entities stream so the function panel fills in live.
//
// Forge 标记 create/edit_function 为 forge 工具（SSE-C）：loop 把它们流式的代码 args 镜像到 entities 流，
// 使 function 面板实时填充。
func (*CreateFunction) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "function", Op: "create"}
}
func (*EditFunction) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "function", Op: "edit"}
}
