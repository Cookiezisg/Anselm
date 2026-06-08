package workflow

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the workflow library to the capability catalog (name + description
// only — catalog is a pure entity menu).
//
// AsCatalogSource 把 workflow 库暴露给能力 catalog（只 name + description——catalog 是纯实体名录）。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &workflowCatalogSource{svc: s}
}

type workflowCatalogSource struct{ svc *Service }

func (c *workflowCatalogSource) Name() string { return "workflow" }

func (c *workflowCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	wfs, err := c.svc.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(wfs))
	for _, w := range wfs {
		desc := strings.TrimSpace(w.Description)
		if desc == "" {
			if joined := strings.Join(w.Tags, ", "); joined != "" {
				desc = joined
			} else {
				desc = "(no description)"
			}
		}
		items = append(items, catalogdomain.Item{Source: "workflow", ID: w.ID, Name: w.Name, Description: desc})
	}
	return items, nil
}
