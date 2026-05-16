// Package document provides system tools for the LLM to navigate / mutate the Notion-style document tree.
//
// Package document 提供让 LLM 浏览 / 改动 Notion-style 文档树的 system tool。
package document

import (
	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// DocumentTools wires the 7 document system tools to one Service.
//
// DocumentTools 用同一 Service 装配 7 个 document 系统工具。
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
