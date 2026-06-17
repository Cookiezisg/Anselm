package document

import toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"

// Build marks create/edit_document as build tools (SSE-C): the streaming document body mirrors onto
// the entities stream so the document panel fills in live.
//
// Build 标记 create/edit_document 为 build 工具（SSE-C）：流式文档正文镜像到 entities 流，使 document 面板实时填充。
func (*CreateDocument) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "document", Op: "create"}
}
func (*EditDocument) Build() toolapp.BuildSpec {
	return toolapp.BuildSpec{Kind: "document", Op: "edit"}
}
