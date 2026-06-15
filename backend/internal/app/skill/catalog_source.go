package skill

import (
	"context"
	"strings"

	catalogdomain "github.com/sunweilin/foryx/backend/internal/domain/catalog"
	skilldomain "github.com/sunweilin/foryx/backend/internal/domain/skill"
)

// AsCatalogSource exposes the skill library to the capability catalog (name + description only).
// This IS skill's discovery channel — skills get no search_tools projection and no dedicated
// search tool; the catalog overview is injected into the system prompt, and the LLM reads it
// and calls activate_skill directly.
//
// AsCatalogSource 把 skill 库暴露给能力 catalog（只 name + description）。这就是 skill 的发现
// 通道——skill 不进 search_tools 投影、无专门搜索工具，catalog 概览注入系统提示，LLM 看完直接
// 调 activate_skill。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &skillCatalogSource{svc: s}
}

type skillCatalogSource struct{ svc *Service }

var _ catalogdomain.CatalogSource = (*skillCatalogSource)(nil)

func (c *skillCatalogSource) Name() string { return "skill" }

// ListItems rescans on demand. Skills flagged disable-model-invocation are withheld from the
// LLM overview (user-only trigger); ID = name since file-based skills have no generated id.
//
// ListItems 按需现扫。标了 disable-model-invocation 的 skill 不进 LLM 概览（只人工触发）；
// ID = name，因为文件式 skill 无生成 id。
func (c *skillCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	rows, err := c.svc.repo.List(ctx, skilldomain.ListFilter{})
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(rows))
	for _, sk := range rows {
		if sk.Frontmatter.DisableModelInvocation {
			continue
		}
		desc := strings.TrimSpace(sk.Description)
		if desc == "" {
			desc = "(no description)"
		}
		items = append(items, catalogdomain.Item{Source: "skill", ID: sk.Name, Name: sk.Name, Description: desc})
	}
	return items, nil
}
