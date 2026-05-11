// catalog_source.go — Function implements catalogdomain.CatalogSource so
// app/catalog can include functions in the system-prompt summary. Per
// forge_redesign D9 (and catalog.md §12 for the broader convention), function
// items are PerItem granularity — the generator may freely group / merge into
// "5 CSV-processing functions"-style descriptions.
//
// Description comes from Function.Description (LLM-generated at create_function
// time); empty description falls back to joined tags so the catalog never
// shows a blank entry. main.go registers AsCatalogSource() at boot.
//
// catalog_source.go —— Function 实现 catalogdomain.CatalogSource 让 app/catalog
// 把 function 纳入 system-prompt summary。per forge_redesign D9: PerItem 粒度
// (generator 可自由分组)。Description 取 Function.Description,空则退化到 tags
// 拼接保证 catalog 永不显示空条目。

package function

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource returns the CatalogSource port adapter for this Service.
// main.go calls this once at boot and registers the result with
// catalogapp.Service.RegisterSource.
//
// AsCatalogSource 返本 Service 的 CatalogSource port 适配器。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &functionCatalogSource{svc: s}
}

type functionCatalogSource struct {
	svc *Service
}

func (c *functionCatalogSource) Name() string                           { return "function" }
func (c *functionCatalogSource) Granularity() catalogdomain.Granularity { return catalogdomain.PerItem }

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
		items = append(items, catalogdomain.Item{
			Source:      "function",
			ID:          f.ID,
			Name:        f.Name,
			Description: desc,
		})
	}
	return items, nil
}
