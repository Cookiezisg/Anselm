package document

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_document as forge tools (SSE-C): the streaming document body mirrors onto
// the entities stream so the document panel fills in live.
//
// Forge 标记 create/edit_document 为 forge 工具（SSE-C）：流式文档正文镜像到 entities 流，使 document 面板实时填充。
func (*CreateDocument) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "document", Op: "create"}
}
func (*EditDocument) Forge() toolapp.ForgeSpec {
	return toolapp.ForgeSpec{Kind: "document", Op: "edit"}
}
