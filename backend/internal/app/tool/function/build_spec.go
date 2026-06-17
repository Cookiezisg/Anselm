package function

import toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"

// Build marks create/edit_function as build tools (SSE-C): the loop mirrors their streaming code
// args onto the entities stream so the function panel fills in live.
//
// Build 标记 create/edit_function 为 build 工具（SSE-C）：loop 把它们流式的代码 args 镜像到 entities 流，
// 使 function 面板实时填充。
func (*CreateFunction) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "function", Op: "create"}
}
func (*EditFunction) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "function", Op: "edit"}
}
