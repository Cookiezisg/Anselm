package control

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/anselm/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the control-logic library to the capability catalog (name +
// description only). control logics are AI-facing work entities — strong name/description
// (the AI writes them) is what keeps the menu legible despite their per-workflow volume.
//
// AsCatalogSource 把 control 逻辑库暴露给能力 catalog（只 name + description）。control 逻辑是
// 面向 AI 的工作实体——靠清晰的 name/description（AI 写）使菜单在 per-workflow 数量下仍可读。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &controlCatalogSource{svc: s}
}

type controlCatalogSource struct{ svc *Service }

func (c *controlCatalogSource) Name() string { return "control" }

func (c *controlCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	ctls, err := c.svc.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(ctls))
	for _, ctl := range ctls {
		desc := strings.TrimSpace(ctl.Description)
		if desc == "" {
			desc = "(no description)"
		}
		items = append(items, catalogdomain.Item{Source: "control", ID: ctl.ID, Name: ctl.Name, Description: desc})
	}
	return items, nil
}
