package workflow

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource returns the CatalogSource port adapter for this Service.
//
// AsCatalogSource 返本 Service 的 CatalogSource port 适配器。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &workflowCatalogSource{svc: s}
}

type workflowCatalogSource struct {
	svc *Service
}

func (c *workflowCatalogSource) Name() string                           { return "workflow" }
func (c *workflowCatalogSource) Granularity() catalogdomain.Granularity { return catalogdomain.PerItem }
func (c *workflowCatalogSource) InvokeTool() string                     { return "trigger_workflow" }

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
		// Active field (doc 11 §S4): LLM sees [INACTIVE] prefix for disabled workflows
		// so it doesn't reference them as callable in trigger_workflow.
		active := w.Enabled
		items = append(items, catalogdomain.Item{
			Source:      "workflow",
			ID:          w.ID,
			Name:        w.Name,
			Description: desc,
			Active:      &active,
		})
	}
	return items, nil
}
