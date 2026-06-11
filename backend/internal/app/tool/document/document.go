// Package document provides the LLM system tools for navigating and mutating the
// Notion-style document tree: search / list / read / create / edit / move / delete.
// These are thin adapters over documentapp.Service — no domain / store / handler / DDL
// / HTTP — implementing only the app/tool 5-method contract. They are lazy tools
// (Toolset.Lazy), surfaced via search_tools. Domain errors are translated into
// soft-failure strings for the LLM to self-correct; nothing bubbles to HTTP here.
//
// Package document 提供浏览 / 改动 Notion-style 文档树的 LLM system tool：search / list /
// read / create / edit / move / delete。它们是 documentapp.Service 之上的薄适配器——无
// domain/store/handler/DDL/HTTP——只实现 app/tool 的 5 方法契约。是懒加载工具
// （Toolset.Lazy），经 search_tools 浮现。domain 错误转软失败串供 LLM 自纠，不冒泡 HTTP。
package document

import (
	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// DocumentTools constructs the 7 document system tools over one Service.
//
// DocumentTools 用一个 Service 构造 7 个 document 系统工具。
func DocumentTools(svc *documentapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchDocuments{svc: svc},
		&ListDocuments{svc: svc},
		&ReadDocument{svc: svc},
		&CreateDocument{svc: svc},
		&EditDocument{svc: svc},
		&MoveDocument{svc: svc},
		&DeleteDocument{svc: svc},
	}
}

var (
	_ toolapp.Tool = (*SearchDocuments)(nil)
	_ toolapp.Tool = (*ListDocuments)(nil)
	_ toolapp.Tool = (*ReadDocument)(nil)
	_ toolapp.Tool = (*CreateDocument)(nil)
	_ toolapp.Tool = (*EditDocument)(nil)
	_ toolapp.Tool = (*MoveDocument)(nil)
	_ toolapp.Tool = (*DeleteDocument)(nil)
)
