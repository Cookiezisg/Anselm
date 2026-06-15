package function

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/foryx/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the function library to the capability catalog (name +
// description only — the catalog is a pure entity menu).
//
// AsCatalogSource 把 function 库暴露给能力 catalog（只 name + description——catalog
// 是纯实体名录）。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &functionCatalogSource{svc: s}
}

type functionCatalogSource struct{ svc *Service }

func (c *functionCatalogSource) Name() string { return "function" }

func (c *functionCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	fns, err := c.svc.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(fns))
	for _, f := range fns {
		desc := strings.TrimSpace(f.Description)
		if desc == "" {
			if joined := strings.Join(f.Tags, ", "); joined != "" {
				desc = joined
			} else {
				desc = "(no description)"
			}
		}
		items = append(items, catalogdomain.Item{Source: "function", ID: f.ID, Name: f.Name, Description: desc})
	}
	return items, nil
}
