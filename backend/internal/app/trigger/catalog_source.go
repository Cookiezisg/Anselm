package trigger

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the trigger library to the capability catalog (name + description,
// grouped under "trigger").
//
// AsCatalogSource 把 trigger 库暴露给能力 catalog（名字 + 描述，归在 "trigger" 组）。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &triggerCatalogSource{svc: s}
}

type triggerCatalogSource struct{ svc *Service }

func (c *triggerCatalogSource) Name() string { return "trigger" }

func (c *triggerCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	ts, err := c.svc.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(ts))
	for _, t := range ts {
		desc := strings.TrimSpace(t.Description)
		if desc == "" {
			desc = t.Kind + " trigger"
		}
		items = append(items, catalogdomain.Item{Source: "trigger", ID: t.ID, Name: t.Name, Description: desc})
	}
	return items, nil
}
