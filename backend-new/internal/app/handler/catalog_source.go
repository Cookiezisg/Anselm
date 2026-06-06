package handler

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the handler library to the capability catalog (name + description).
//
// AsCatalogSource 把 handler 库暴露给能力 catalog（名字 + 描述）。
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
		items = append(items, catalogdomain.Item{Source: "handler", ID: h.ID, Name: h.Name, Description: desc})
	}
	return items, nil
}
