package handler

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/anselm/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the handler library to the capability catalog. A handler is a
// CONTAINER entity: each item is name + description + its active version's method names
// (Members), so the LLM sees what methods a handler offers without the full schemas — call
// get_handler for a method's signature, then call_handler to invoke it (aligns mcp).
//
// AsCatalogSource 把 handler 库暴露给能力 catalog。handler 是容器实体：每条 item = 名 + 描述 +
// active 版本的方法名（Members），使 LLM 知道 handler 有哪些方法、而不含完整 schema——用 get_handler
// 看方法签名、再 call_handler 调（对齐 mcp）。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &handlerCatalogSource{svc: s}
}

type handlerCatalogSource struct{ svc *Service }

func (c *handlerCatalogSource) Name() string { return "handler" }

func (c *handlerCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	hs, err := c.svc.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(hs))
	for _, h := range hs {
		desc := strings.TrimSpace(h.Description)
		if desc == "" {
			if joined := strings.Join(h.Tags, ", "); joined != "" {
				desc = joined
			} else {
				desc = "(no description)"
			}
		}
		items = append(items, catalogdomain.Item{
			Source: "handler", ID: h.ID, Name: h.Name, Description: desc,
			Members: c.methodNames(ctx, h.ActiveVersionID),
		})
	}
	return items, nil
}

// methodNames returns the active version's method names — the handler's callable sub-units,
// which the catalog renders as the container's member list (aligns mcp's tool names). A
// handler without an active version (unconfigured) contributes no members.
//
// methodNames 返 active version 的方法名——handler 的可调子单元，catalog 渲染为容器成员清单
// （对齐 mcp 的工具名）。无 active 版本（未配齐）的 handler 不贡献成员。
func (c *handlerCatalogSource) methodNames(ctx context.Context, versionID string) []string {
	if versionID == "" {
		return nil
	}
	v, err := c.svc.repo.GetVersion(ctx, versionID)
	if err != nil {
		return nil
	}
	names := make([]string, 0, len(v.Methods))
	for _, m := range v.Methods {
		names = append(names, m.Name)
	}
	return names
}
