package agent

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource exposes the agent library to the capability catalog (name + description). An
// agent is NOT a container entity — its mounted tools are an internal whitelist, not callable
// sub-units of the agent, so it reports no Members (unlike mcp/handler).
//
// AsCatalogSource 把 agent 库暴露给能力 catalog（名 + 描述）。agent **不是容器实体**——它挂载的工具
// 是内部白名单、非 agent 的可调子单元，故不报 Members（不同于 mcp/handler）。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &agentCatalogSource{svc: s}
}

type agentCatalogSource struct{ svc *Service }

func (c *agentCatalogSource) Name() string { return "agent" }

func (c *agentCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	as, err := c.svc.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(as))
	for _, a := range as {
		desc := strings.TrimSpace(a.Description)
		if desc == "" {
			if joined := strings.Join(a.Tags, ", "); joined != "" {
				desc = joined
			} else {
				desc = "(no description)"
			}
		}
		items = append(items, catalogdomain.Item{Source: "agent", ID: a.ID, Name: a.Name, Description: desc})
	}
	return items, nil
}
