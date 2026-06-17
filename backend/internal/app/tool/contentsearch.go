package tool

import (
	"context"
	"strings"

	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// ContentSearch routes a vertical search tool's non-empty query through the
// unified content engine (FTS over name/description/tags AND body/code), and
// renders the tool's legacy slim list shape so the LLM-facing schema stays
// identical. ok=false (nil engine / empty query / engine error) tells the
// caller to fall back to its legacy substring path — the tool never breaks
// because the index is unavailable.
//
// ContentSearch 把垂搜工具的非空 query 路由到统一内容引擎（FTS 覆盖名/描述/tags
// **及正文/代码**），并渲染该工具原有的 slim 列表形状，LLM 所见 schema 不变。
// ok=false（引擎缺席/空 query/引擎出错）让调用方回退原子串路径——索引不可用时
// 工具绝不因此坏掉。
func ContentSearch(ctx context.Context, engine *searchapp.Service, t searchdomain.EntityType, query, listKey string) (string, bool) {
	if engine == nil || strings.TrimSpace(query) == "" {
		return "", false
	}
	page, err := engine.Search(ctx, &searchdomain.Query{
		Q: query, Types: []searchdomain.EntityType{t}, IncludeArchived: true, Limit: 20,
	})
	if err != nil {
		return "", false
	}
	out := make([]searchdomain.EntitySlim, 0, len(page.Hits))
	for _, h := range page.Hits {
		out = append(out, searchdomain.EntitySlim{ID: h.EntityID, Name: h.Name, Description: h.Snippet})
	}
	return ToJSON(map[string]any{"count": len(out), listKey: out}), true
}
