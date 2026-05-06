// catalogsource.go — Skill implements catalogdomain.CatalogSource so
// app/catalog can include skills in the system-prompt summary. Per
// catalog.md §12: skills are PerItem (generator may freely group /
// merge — e.g. "3 deployment skills" — when descriptions are similar).
//
// Skill description comes verbatim from frontmatter.description (author
// writes it). Per catalog.md §12 we don't re-LLM-generate; the author's
// text IS the source of truth.
//
// catalogsource.go ——Skill 实现 catalogdomain.CatalogSource 让 app/catalog
// 把 skill 纳入 system-prompt summary。catalog.md §12：skill 是 PerItem
// （description 相似时 generator 可自由合并，如 "3 个部署 skill"）。
//
// Skill description 直接来自 frontmatter.description（author 写）。§12：
// 不重 LLM 生成；author 文本即事实源。
package skill

import (
	"context"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// AsCatalogSource returns the CatalogSource port adapter for this Service.
// main.go calls this once at boot and registers the result with
// catalogapp.Service.RegisterSource.
//
// AsCatalogSource 返本 Service 的 CatalogSource port 适配器。main.go 在
// boot 调一次 + 把结果注册到 catalogapp.Service.RegisterSource。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &skillCatalogSource{svc: s}
}

type skillCatalogSource struct {
	svc *Service
}

func (c *skillCatalogSource) Name() string                           { return "skill" }
func (c *skillCatalogSource) Granularity() catalogdomain.Granularity { return catalogdomain.PerItem }

func (c *skillCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	skills := c.svc.List(ctx)
	items := make([]catalogdomain.Item, 0, len(skills))
	for _, sk := range skills {
		items = append(items, catalogdomain.Item{
			Source:      "skill",
			ID:          sk.Name, // skill name is its stable identifier (no separate ID)
			Name:        sk.Name,
			Description: sk.Description,
		})
	}
	return items, nil
}
