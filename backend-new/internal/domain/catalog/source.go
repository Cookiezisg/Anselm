// Package catalog is the domain for the capability overview injected into chat
// system prompts: a flat "what entities do you have" list — name + description per
// entity, grouped by kind, aggregated from per-domain sources. It deliberately
// carries NO ids, invoke tools, or any handle for precise reference: that is the
// search tools' job. The catalog only makes the LLM aware its capabilities exist;
// to actually use one, the LLM searches for it.
//
// Package catalog 是注入 chat system prompt 的能力概览的 domain：一份扁平的「你有哪些
// 实体」清单——每个实体 name + description、按类型分组、从各域 source 聚合。它刻意不带
// id、调用工具或任何精确引用句柄：那是搜索工具的事。catalog 只让 LLM 知道能力存在；真要
// 用某个，LLM 去搜。
package catalog

import "context"

// Item is one capability in a source's ListItems return. The menu renders only
// Name + Description; ID is kept for the structured Coverage view (HTTP inspection),
// never rendered into the LLM-facing text.
//
// Item 是 source ListItems 返回的一条能力。菜单只渲染 Name + Description；ID 留给结构化
// Coverage 视图（HTTP 巡检），从不渲染进给 LLM 的文本。
type Item struct {
	Source      string `json:"source"`
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`

	// Members lists a CONTAINER entity's callable sub-units by NAME only — an mcp server's
	// tools, a handler's methods. Single entities (function/skill/agent) leave it empty. The
	// menu renders these as a one-line name list so the LLM knows what's inside without the
	// full tool/method schemas (those load on demand via search_tools / get_handler).
	//
	// Members 列出容器实体的可调子单元，只列名——mcp server 的工具、handler 的方法。单一实体
	// （function/skill/agent）留空。菜单渲染成一行名字清单，使 LLM 知道里面有什么、而不含完整
	// schema（那些按需经 search_tools / get_handler 加载）。
	Members []string `json:"members,omitempty"`
}

// CatalogSource is what every capability provider implements to join the catalog.
// Each source contributes its entities as name+description items; granularity and
// invocation are explicitly not its concern.
//
// CatalogSource 是所有能力提供方为参与 catalog 而实现的接口。各 source 把自己的实体作为
// name+description 条目贡献；粒度与调用方式明确不归它管。
type CatalogSource interface {
	// Name is the entity kind label used to group the menu (e.g. "function").
	//
	// Name 是用于菜单分组的实体类型标签（如 "function"）。
	Name() string

	// ListItems returns the source's current entities (workspace-scoped via the
	// orm layer). On error the source contributes nothing this build — the others
	// still render.
	//
	// ListItems 返回 source 当前实体（经 orm 层按 workspace 隔离）。出错时该 source 本次
	// 不贡献——其它照常渲染。
	ListItems(ctx context.Context) ([]Item, error)
}
